/* ari_garage — NUI app.js  v1.14.0-ari */

(function () {
  'use strict';

  // ── State ──────────────────────────────────────────────────────────────────
  let state = {
    tab: 'garage',           // 'garage' | 'impounded'
    garageVehicles: [],
    impoundedVehicles: [],
    spawnPoint: null,
    poundCost: 0,
    poundName: null,
    poundSpawnPoint: null,
    locales: {},
    animateCards: true,
    showFuel: false,
    menuType: 'garage',      // 'garage' | 'impound'
  };

  // ── DOM Refs ───────────────────────────────────────────────────────────────
  const overlay       = document.getElementById('overlay');
  const panel         = document.getElementById('panel');
  const garageLabel   = document.getElementById('garage-label');
  const contentTitle  = document.getElementById('content-title');
  const tabImpounded  = document.getElementById('tab-impounded');
  const badgeGarage   = document.getElementById('badge-garage');
  const badgeImpounded= document.getElementById('badge-impounded');
  const vehicleGrid   = document.getElementById('vehicle-grid');
  const emptyState    = document.getElementById('empty-state');
  const emptyMsg      = document.getElementById('empty-msg');
  const searchInput   = document.getElementById('search-input');
  const btnClose      = document.getElementById('btn-close');

  // ── Helpers ────────────────────────────────────────────────────────────────
  function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)); }

  function conditionClass(pct) {
    if (pct >= 70) return 'good';
    if (pct >= 35) return 'ok';
    return 'bad';
  }

  function conditionColor(pct) {
    // returns inline gradient override for accent theming
    return null; // uses CSS classes
  }

  function calcCondition(props) {
    const p = props || {};
    const b = typeof p.bodyHealth   === 'number' ? p.bodyHealth   : 1000;
    const e = typeof p.engineHealth === 'number' ? p.engineHealth : 1000;
    const t = typeof p.tankHealth   === 'number' ? p.tankHealth   : 1000;
    const bPct = clamp((b / 1000) * 100, 0, 100);
    const ePct = clamp((e / 1000) * 100, 0, 100);
    const tPct = clamp((t / 1000) * 100, 0, 100);
    return clamp(Math.round(((bPct + ePct + tPct) / 300) * 100), 0, 100);
  }

  function post(endpoint, payload) {
    return fetch('https://ari_garage/' + endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
  }

  // ── Card Builder ───────────────────────────────────────────────────────────
  function buildCard(veh, type, idx) {
    const cond    = calcCondition(veh.props);
    const cls     = conditionClass(cond);
    const isImpound = (type === 'impounded');
    const loc     = state.locales;
    const delay   = state.animateCards ? `animation-delay:${idx * 55}ms` : '';

    let fuelHtml = '';
    if (state.showFuel && veh.props && typeof veh.props.fuelLevel === 'number') {
      const fuelPct = clamp(Math.round(veh.props.fuelLevel), 0, 100);
      fuelHtml = `
        <div class="vcard-fuel">
          <div class="condition-label">
            <span>${loc.fuel || 'Fuel'}</span>
            <strong style="color:var(--text-secondary)">${fuelPct}%</strong>
          </div>
          <div class="fuel-bar"><div class="fuel-fill" style="width:${fuelPct}%"></div></div>
        </div>`;
    }

    let actionHtml = '';
    if (isImpound) {
      actionHtml = `
        <button class="btn-action btn-danger vcard-impound-btn"
          data-props='${JSON.stringify(veh.props).replace(/'/g, '&apos;')}'>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M9 3H5a2 2 0 0 0-2 2v4m6-6h10a2 2 0 0 1 2 2v4M9 3v18m0 0h10a2 2 0 0 0 2-2V9M9 21H5a2 2 0 0 1-2-2V9m0 0h18"/>
          </svg>
          ${loc.impound_action || 'Send to Impound'}
        </button>`;
    } else {
      const costLabel = (state.poundCost && state.menuType === 'impound')
        ? ` ($${state.poundCost})`
        : '';
      actionHtml = `
        <button class="btn-action btn-primary vcard-spawn-btn"
          data-props='${JSON.stringify(veh.props).replace(/'/g, '&apos;')}'>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="5 12 19 12"/><polyline points="12 5 19 12 12 19"/>
          </svg>
          ${loc.action || loc.veh_exit || 'Retrieve'}${costLabel}
        </button>`;
    }

    return `
      <div class="vcard${state.animateCards ? ' animate-in' : ''}" style="${delay}"
           data-model="${(veh.model || '').toLowerCase()}"
           data-plate="${(veh.plate || '').toLowerCase()}">
        <div class="vcard-header">
          <span class="vcard-model">${veh.model || 'Unknown'}</span>
          <span class="vcard-plate">${veh.plate || '—'}</span>
        </div>
        <div class="vcard-condition">
          <div class="condition-label">
            <span>${loc.veh_condition || 'Condition'}</span>
            <strong style="color:var(--text-secondary)">${cond}%</strong>
          </div>
          <div class="condition-bar">
            <div class="condition-fill ${cls}" style="width:${cond}%"></div>
          </div>
        </div>
        ${fuelHtml}
        <div class="vcard-actions">${actionHtml}</div>
      </div>`;
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  function renderGrid() {
    const query = searchInput.value.trim().toLowerCase();
    const list  = state.tab === 'impounded' ? state.impoundedVehicles : state.garageVehicles;
    const type  = state.tab === 'impounded' ? 'impounded' : 'garage';

    const filtered = list.filter(v => {
      if (!query) return true;
      return (v.model || '').toLowerCase().includes(query)
          || (v.plate || '').toLowerCase().includes(query);
    });

    vehicleGrid.innerHTML = filtered.map((v, i) => buildCard(v, type, i)).join('');

    const isEmpty = filtered.length === 0;
    emptyState.classList.toggle('hidden', !isEmpty);
    emptyMsg.textContent = isEmpty && list.length === 0
      ? (state.tab === 'impounded'
          ? (state.locales.no_veh_impounded || 'No impounded vehicles.')
          : (state.locales.no_veh_parking   || 'No vehicles stored here.'))
      : 'No results for "' + query + '"';
  }

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.nav-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.tab === tab);
    });
    contentTitle.textContent = tab === 'impounded' ? 'Impounded' : 'Garage';
    searchInput.value = '';
    renderGrid();
  }

  // ── Show / Hide ────────────────────────────────────────────────────────────
  function showMenu(data) {
    // Populate state
    state.locales       = data.locales || {};
    state.spawnPoint    = data.spawnPoint || null;
    state.poundCost     = data.poundCost || 0;
    state.poundName     = data.poundName || null;
    state.poundSpawnPoint = data.poundSpawnPoint || null;
    state.menuType      = data.menuType || 'garage';
    state.animateCards  = data.animateCards !== false;
    state.showFuel      = data.showFuel === true;

    // Apply accent color from config
    if (data.accentColor) {
      document.documentElement.style.setProperty('--accent', data.accentColor);
      // rebuild dim/glow
      const hex = data.accentColor.replace('#','');
      const r   = parseInt(hex.slice(0,2),16);
      const g   = parseInt(hex.slice(2,4),16);
      const b   = parseInt(hex.slice(4,6),16);
      document.documentElement.style.setProperty('--accent-dim',  `rgba(${r},${g},${b},.18)`);
      document.documentElement.style.setProperty('--accent-glow', `rgba(${r},${g},${b},.32)`);
    }

    // Label
    garageLabel.textContent = data.garageLabel || '';

    // Parse vehicles
    state.garageVehicles    = data.vehiclesList          ? JSON.parse(data.vehiclesList)          : [];
    state.impoundedVehicles = data.vehiclesImpoundedList ? JSON.parse(data.vehiclesImpoundedList) : [];

    // Badges
    badgeGarage.textContent    = state.garageVehicles.length;
    badgeImpounded.textContent = state.impoundedVehicles.length;

    // Hide impound tab in impound-only mode
    if (data.menuType === 'impound') {
      tabImpounded.style.display = 'none';
    } else {
      tabImpounded.style.display = '';
    }

    // Start on correct tab
    switchTab('garage');

    overlay.classList.remove('hidden');
    searchInput.value = '';
    searchInput.focus();
  }

  function hideMenu() {
    overlay.classList.add('hidden');
    post('escape', {});
  }

  // ── Event Listeners ────────────────────────────────────────────────────────

  btnClose.addEventListener('click', hideMenu);

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') hideMenu();
  });

  searchInput.addEventListener('input', renderGrid);

  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // Spawn / retrieve
  vehicleGrid.addEventListener('click', e => {
    const spawnBtn = e.target.closest('.vcard-spawn-btn');
    if (spawnBtn) {
      const props = JSON.parse(spawnBtn.dataset.props);
      post('spawnVehicle', {
        vehicleProps:  props,
        spawnPoint:    state.spawnPoint,
        exitVehicleCost: state.poundCost,
      });
      hideMenu();
    }

    const impoundBtn = e.target.closest('.vcard-impound-btn');
    if (impoundBtn) {
      const props = JSON.parse(impoundBtn.dataset.props);
      post('impound', {
        vehicleProps:   props,
        poundName:      state.poundName,
        poundSpawnPoint: state.poundSpawnPoint,
      });
      hideMenu();
    }
  });

  // ── NUI Message Handler ────────────────────────────────────────────────────
  window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.action) return;

    if (d.action === 'show') {
      showMenu(d);
    } else if (d.action === 'hide') {
      overlay.classList.add('hidden');
    }
  });

})();
