/* ari_garage — NUI app.js  v1.15.0-ari */

(function () {
  'use strict';

  const DEFAULT_ACCENT = '#A855F7';

  let state = {
    tab: 'garage',
    garageVehicles: [],
    impoundedVehicles: [],
    spawnPoint: null,
    poundName: null,
    poundSpawnPoint: null,
    locales: {},
    animateCards: true,
    showFuel: false,
    menuType: 'garage',
    defaultPoundCost: 0,
    freeRelease: false,
  };

  const overlay = document.getElementById('overlay');
  const garageLabel = document.getElementById('garage-label');
  const contentTitle = document.getElementById('content-title');
  const tabImpounded = document.getElementById('tab-impounded');
  const badgeGarage = document.getElementById('badge-garage');
  const badgeImpounded = document.getElementById('badge-impounded');
  const vehicleGrid = document.getElementById('vehicle-grid');
  const emptyState = document.getElementById('empty-state');
  const emptyMsg = document.getElementById('empty-msg');
  const searchInput = document.getElementById('search-input');
  const btnClose = document.getElementById('btn-close');

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function formatCurrency(value) {
    return `$${Number(value || 0).toLocaleString('en-US')}`;
  }

  function conditionClass(percent) {
    if (percent >= 70) return 'good';
    if (percent >= 35) return 'ok';
    return 'bad';
  }

  function calcCondition(props) {
    const data = props || {};
    const body = typeof data.bodyHealth === 'number' ? data.bodyHealth : 1000;
    const engine = typeof data.engineHealth === 'number' ? data.engineHealth : 1000;
    const tank = typeof data.tankHealth === 'number' ? data.tankHealth : 1000;
    const bodyPct = clamp((body / 1000) * 100, 0, 100);
    const enginePct = clamp((engine / 1000) * 100, 0, 100);
    const tankPct = clamp((tank / 1000) * 100, 0, 100);

    return clamp(Math.round((bodyPct + enginePct + tankPct) / 3), 0, 100);
  }

  function post(endpoint, payload) {
    const resource = typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'ari_garage';
    return fetch(`https://${resource}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
  }

  function escapeAttr(value) {
    return JSON.stringify(value || {}).replace(/'/g, '&apos;');
  }

  function getStateLabel(vehicle) {
    const loc = state.locales;
    if (vehicle.state === 'impounded') return loc.state_impound || 'Impounded';
    if (vehicle.state === 'out') return loc.state_out || 'Out';
    return loc.state_garage || 'Stored';
  }

  function getTabTitle(tab) {
    return tab === 'impounded' ? 'Impounded' : 'Garage';
  }

  function getActionLabel(type, vehicle) {
    const loc = state.locales;
    if (type === 'impounded') {
      if (vehicle.state === 'out') {
        return loc.out_action || 'Outside';
      }

      return state.menuType === 'impound'
        ? (loc.pay_impound || 'Pay & Release')
        : (loc.locate_impound || 'Mark impound');
    }

    return loc.action || loc.veh_exit || 'Retrieve';
  }

  function buildMetaPills(vehicle, condition) {
    const loc = state.locales;
    const pills = [
      `<span class="meta-pill"><span>${loc.state_label || 'State'}</span><strong>${getStateLabel(vehicle)}</strong></span>`,
      `<span class="meta-pill"><span>${loc.veh_condition || 'Condition'}</span><strong>${condition}%</strong></span>`,
    ];

    if (vehicle.state === 'impounded') {
      const costLabel = vehicle.releaseFree
        ? (loc.free_release || 'Free release')
        : `${loc.release_cost || 'Release cost'} ${formatCurrency(vehicle.releaseCost)}`;
      pills.push(`<span class="meta-pill accent"><span>${loc.pay_impound || 'Pay & Release'}</span><strong>${costLabel}</strong></span>`);
    }

    return pills.join('');
  }

  function buildActionButton(type, vehicle) {
    const label = getActionLabel(type, vehicle);

    if (type === 'impounded') {
      if (vehicle.state === 'out') {
        return `
          <button class="btn-action btn-disabled" disabled>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="9"></circle><path d="M8 12h8"></path>
            </svg>
            ${label}
          </button>`;
      }

      return `
        <button class="btn-action btn-secondary vcard-impound-btn"
          data-mode="${state.menuType === 'impound' ? 'release' : 'track'}"
          data-props='${escapeAttr(vehicle.props)}'
          data-release-cost="${vehicle.releaseCost || 0}">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
            <path d="M4 12h16"></path><path d="M14 6l6 6-6 6"></path>
          </svg>
          ${label}
        </button>`;
    }

    return `
      <button class="btn-action btn-primary vcard-spawn-btn"
        data-props='${escapeAttr(vehicle.props)}'
        data-release-cost="${vehicle.releaseCost || 0}">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="5 12 19 12"></polyline><polyline points="12 5 19 12 12 19"></polyline>
        </svg>
        ${label}
      </button>`;
  }

  function buildCard(vehicle, type, index) {
    const condition = calcCondition(vehicle.props);
    const conditionState = conditionClass(condition);
    const delay = state.animateCards ? `animation-delay:${index * 50}ms` : '';
    const loc = state.locales;

    let fuelBlock = '';
    if (state.showFuel && vehicle.props && typeof vehicle.props.fuelLevel === 'number') {
      const fuelPct = clamp(Math.round(vehicle.props.fuelLevel), 0, 100);
      fuelBlock = `
        <div class="vcard-fuel">
          <div class="metric-row">
            <span>${loc.fuel || 'Fuel'}</span>
            <strong>${fuelPct}%</strong>
          </div>
          <div class="fuel-bar"><div class="fuel-fill" style="width:${fuelPct}%"></div></div>
        </div>`;
    }

    return `
      <article class="vcard${state.animateCards ? ' animate-in' : ''}" style="${delay}"
        data-model="${(vehicle.model || '').toLowerCase()}"
        data-plate="${(vehicle.plate || '').toLowerCase()}">
        <div class="vcard-orb"></div>
        <div class="vcard-header">
          <div>
            <span class="vcard-kicker">ari_garage</span>
            <h3 class="vcard-model">${vehicle.model || 'Unknown'}</h3>
          </div>
          <span class="vcard-plate">${vehicle.plate || '—'}</span>
        </div>
        <div class="vcard-meta">${buildMetaPills(vehicle, condition)}</div>
        <div class="vcard-condition">
          <div class="metric-row">
            <span>${loc.veh_condition || 'Condition'}</span>
            <strong>${condition}%</strong>
          </div>
          <div class="condition-bar">
            <div class="condition-fill ${conditionState}" style="width:${condition}%"></div>
          </div>
        </div>
        ${fuelBlock}
        <div class="vcard-actions">${buildActionButton(type, vehicle)}</div>
      </article>`;
  }

  function renderGrid() {
    const query = searchInput.value.trim().toLowerCase();
    const list = state.tab === 'impounded' ? state.impoundedVehicles : state.garageVehicles;
    const type = state.tab === 'impounded' ? 'impounded' : 'garage';
    const loc = state.locales;

    const filtered = list.filter((vehicle) => {
      if (!query) return true;
      return (vehicle.model || '').toLowerCase().includes(query)
        || (vehicle.plate || '').toLowerCase().includes(query);
    });

    vehicleGrid.innerHTML = filtered.map((vehicle, index) => buildCard(vehicle, type, index)).join('');

    const isEmpty = filtered.length === 0;
    emptyState.classList.toggle('hidden', !isEmpty);

    if (!isEmpty) {
      return;
    }

    if (list.length === 0) {
      emptyMsg.textContent = state.tab === 'impounded'
        ? (loc.no_veh_impounded || 'No impounded vehicles.')
        : (loc.no_veh_parking || 'No vehicles stored here.');
      return;
    }

    emptyMsg.textContent = query
      ? `${loc.no_results || 'No results.'} "${query}"`
      : (loc.no_results || 'No results.');
  }

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.nav-btn').forEach((button) => {
      button.classList.toggle('active', button.dataset.tab === tab);
    });
    contentTitle.textContent = getTabTitle(tab);
    searchInput.value = '';
    renderGrid();
  }

  function applyAccentColor(color) {
    const hex = (color || DEFAULT_ACCENT).replace('#', '');
    if (hex.length !== 6) {
      return;
    }

    const red = parseInt(hex.slice(0, 2), 16);
    const green = parseInt(hex.slice(2, 4), 16);
    const blue = parseInt(hex.slice(4, 6), 16);

    document.documentElement.style.setProperty('--accent', `#${hex}`);
    document.documentElement.style.setProperty('--accent-dim', `rgba(${red},${green},${blue},0.18)`);
    document.documentElement.style.setProperty('--accent-soft', `rgba(${red},${green},${blue},0.10)`);
    document.documentElement.style.setProperty('--accent-glow', `rgba(${red},${green},${blue},0.42)`);
  }

  function showMenu(data) {
    state.locales = data.locales || {};
    state.spawnPoint = data.spawnPoint || null;
    state.poundName = data.poundName || null;
    state.poundSpawnPoint = data.poundSpawnPoint || null;
    state.menuType = data.menuType || 'garage';
    state.animateCards = data.animateCards !== false;
    state.showFuel = data.showFuel === true;
    state.defaultPoundCost = data.poundCost || 0;
    state.freeRelease = data.freeRelease === true;

    applyAccentColor(data.accentColor);
    garageLabel.textContent = data.garageLabel || '';

    state.garageVehicles = data.vehiclesList ? JSON.parse(data.vehiclesList) : [];
    state.impoundedVehicles = data.vehiclesImpoundedList ? JSON.parse(data.vehiclesImpoundedList) : [];

    badgeGarage.textContent = state.garageVehicles.length;
    badgeImpounded.textContent = state.impoundedVehicles.length;
    tabImpounded.style.display = state.menuType === 'impound' ? 'none' : '';

    switchTab('garage');
    overlay.classList.remove('hidden');
    searchInput.focus();
  }

  function bootPreviewMode() {
    const isPreview = window.location.protocol === 'file:' && window.location.search.includes('preview=1');
    if (!isPreview) {
      return;
    }

    showMenu({
      action: 'show',
      menuType: 'garage',
      garageLabel: 'Preview Garage',
      accentColor: DEFAULT_ACCENT,
      animateCards: true,
      showFuel: true,
      poundName: 'LosSantos',
      poundSpawnPoint: { x: 400.7, y: -1630.5 },
      spawnPoint: { x: 0, y: 0, z: 0, heading: 0 },
      locales: {
        action: 'Retrieve Vehicle',
        pay_impound: 'Pay & Release',
        locate_impound: 'Mark impound',
        veh_condition: 'Condition',
        no_veh_impounded: 'No impounded vehicles.',
        no_veh_parking: 'No vehicles stored here.',
        fuel: 'Fuel',
        state_label: 'State',
        state_garage: 'Stored',
        state_impound: 'Impounded',
        state_out: 'Out',
        release_cost: 'Release cost',
        free_release: 'Free release',
        no_results: 'No results.',
        out_action: 'Outside',
      },
      vehiclesList: JSON.stringify([
        {
          model: 'Comet S2',
          plate: 'ARI 001',
          state: 'stored',
          props: { bodyHealth: 900, engineHealth: 820, tankHealth: 1000, fuelLevel: 76 },
        },
        {
          model: 'Bati 801',
          plate: 'NEON 88',
          state: 'stored',
          props: { bodyHealth: 780, engineHealth: 640, tankHealth: 1000, fuelLevel: 48 },
        },
      ]),
      vehiclesImpoundedList: JSON.stringify([
        {
          model: 'Sultan RS',
          plate: 'POUND 7',
          state: 'impounded',
          releaseCost: 4200,
          props: { bodyHealth: 700, engineHealth: 420, tankHealth: 1000, fuelLevel: 31 },
        },
      ]),
    });
  }

  function hideVisual() {
    overlay.classList.add('hidden');
  }

  function hideMenu() {
    overlay.classList.add('hidden');
    post('escape', {});
  }

  btnClose.addEventListener('click', hideMenu);

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      hideMenu();
    }
  });

  searchInput.addEventListener('input', renderGrid);

  document.querySelectorAll('.nav-btn').forEach((button) => {
    button.addEventListener('click', () => switchTab(button.dataset.tab));
  });

  vehicleGrid.addEventListener('click', (event) => {
    const spawnButton = event.target.closest('.vcard-spawn-btn');
    if (spawnButton) {
      post('spawnVehicle', {
        vehicleProps: JSON.parse(spawnButton.dataset.props),
        spawnPoint: state.spawnPoint,
        exitVehicleCost: Number(spawnButton.dataset.releaseCost || state.defaultPoundCost || 0),
        poundName: state.poundName,
      });
      hideVisual();
      return;
    }

    const impoundButton = event.target.closest('.vcard-impound-btn');
    if (impoundButton) {
      post('impound', {
        mode: impoundButton.dataset.mode,
        vehicleProps: JSON.parse(impoundButton.dataset.props),
        poundName: state.poundName,
        poundSpawnPoint: state.poundSpawnPoint,
      });
      hideVisual();
    }
  });

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) {
      return;
    }

    if (data.action === 'show') {
      showMenu(data);
    } else if (data.action === 'hide') {
      overlay.classList.add('hidden');
    }
  });

  bootPreviewMode();
})();
