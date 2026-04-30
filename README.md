<div align="center">

<br/>

```
 █████╗ ██████╗ ██╗      ██████╗  █████╗ ██████╗  █████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██║     ██╔════╝ ██╔══██╗██╔══██╗██╔══██╗██╔════╝ ██╔════╝
███████║██████╔╝██║     ██║  ███╗███████║██████╔╝███████║██║  ███╗█████╗  
██╔══██║██╔══██╗██║     ██║   ██║██╔══██║██╔══██╗██╔══██║██║   ██║██╔══╝  
██║  ██║██║  ██║███████╗╚██████╔╝██║  ██║██║  ██║██║  ██║╚██████╔╝███████╗
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
```

**Advanced Vehicle Garage & Impound System for ESX**

`v1.14.0-ari` · FiveM · ESX · oxmysql

[![FiveM](https://img.shields.io/badge/FiveM-ESX-orange?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0tMiAxNHYtNGgtNGw2LTZoMHY0aDRsLTYgNnoiLz48L3N2Zz4=)](https://fivem.net)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.14.0--ari-brightgreen?style=flat-square)]()

<br/>

![Preview](https://r2.fivemanage.com/GKrFpmeSPmAY7LG3ytD9M/Capturadepantalla2026-04-30060409.png)


</div>

---

## ✨ What's New in 1.14.0-ari

> A complete overhaul from `esx_garage_v2`. Every system has been rewritten, improved, and documented.

| Area | Change |
|------|--------|
| 🎨 **UI** | Entirely new NUI — dark glass design, animated cards, search, sidebar tabs |
| ⚙️ **Config** | 30+ new options: job restrictions, vehicle filters, payment methods, sound, target system |
| 🚔 **Impound** | Per-impound labels, `FreeRelease` for police jobs, `NotifyOnImpound` for vehicle owners |
| 💳 **Billing** | Choose `cash`, `bank`, or `any` (smart deduct both) for impound fees |
| 🗄️ **SQL** | Safe `IF NOT EXISTS` migration, optional performance indexes |
| 🌍 **Locales** | Spanish (`es`) added, all strings updated with color codes |
| 🔧 **Code** | Fully documented Lua, single-responsibility callbacks, safe `nil` guards |

---

## 📋 Requirements

- [ESX Framework](https://github.com/esx-framework/esx_core) (Legacy or newer)
- [oxmysql](https://github.com/overextended/oxmysql)
- FiveM server artifact **≥ 6116** (Lua 5.4)

---

## 🚀 Installation

### 1 · Database

Run the migration script against your server database:

```sql
-- From ari_garage.sql
ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `parking` VARCHAR(60) NULL AFTER `stored`;

ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `pound` VARCHAR(60) NULL AFTER `parking`;
```

> **Upgrading from `esx_garage_v2`?** The columns already exist — the `IF NOT EXISTS` guards make it safe to run again.

### 2 · Resource

Copy the `ari_garage` folder into your `resources` directory:

```
resources/
  └── [cars]/
        └── ari_garage/
              ├── client/
              ├── server/
              ├── nui/
              ├── locales/
              ├── config.lua
              ├── fxmanifest.lua
              └── ari_garage.sql
```

### 3 · server.cfg

```cfg
ensure ari_garage
```

> Make sure `es_extended` and `oxmysql` are started **before** `ari_garage`.

---

## ⚙️ Configuration

All configuration lives in **`config.lua`**. Every option is documented inline. Here's a quick overview:

### General

```lua
Config.DrawDistance   = 12.0   -- marker visibility range (metres)
Config.InteractDistance = 1.5  -- how close to trigger interaction
Config.UseTarget      = false  -- set true for ox_target / qtarget support
Config.Show3DText     = true   -- floating text above markers
```

### UI

```lua
Config.UI = {
    AccentColor    = '#F5A623',  -- hex colour for highlights
    AnimateCards   = true,       -- staggered card entrance animation
    ShowFuelGauge  = false,      -- requires fuel resource exporting GetFuel
    Sound = {
        Enabled = true,
        Name    = 'CONFIRM_BEEP',
        Set     = 'HUD_MINI_GAME_SOUNDSET',
    },
}
```

### Billing

```lua
Config.PaymentMethod = 'cash'
-- 'cash'  → deduct from player cash only
-- 'bank'  → deduct from bank account only
-- 'any'   → use cash first, then bank for the remainder
```

### Adding a Garage

```lua
Config.Garages = {
    MyGarage = {
        Label         = 'Downtown Garage',       -- shown in UI
        EntryPoint    = { x = 0.0, y = 0.0, z = 0.0 },
        SpawnPoint    = { x = 5.0, y = 0.0, z = 0.0, heading = 180.0 },
        ImpoundedName = 'LosSantos',             -- linked impound
        AllowedJobs   = nil,                     -- nil = everyone
        AllowedGrades = nil,                     -- nil = any grade
        VehicleFilter = 'all',                   -- 'all' | 'car' | 'bike' | 'boat' | 'air'
        Sprite = 357, Scale = 0.8, Colour = 3,
    },
}
```

#### Job-Restricted Garage Example

```lua
MechanicBay = {
    Label         = 'Mechanic Bay',
    EntryPoint    = { x = 100.0, y = 200.0, z = 30.0 },
    SpawnPoint    = { x = 105.0, y = 200.0, z = 30.0, heading = 90.0 },
    ImpoundedName = 'LosSantos',
    AllowedJobs   = { 'mechanic' },
    AllowedGrades = { mechanic = 1 },  -- grade 1+ only
    VehicleFilter = 'car',
},
```

### Adding an Impound

```lua
Config.Impounds = {
    MyCity = {
        Label       = 'City Impound',
        GetOutPoint = { x = 400.7, y = -1630.5, z = 29.3 },
        SpawnPoint  = { x = 401.9, y = -1647.4, z = 29.2, heading = 323.3 },
        Cost        = 2500,         -- fee in $
        AllowedJobs = { 'police' }, -- police can release free
        FreeRelease = true,         -- waive fee if player has allowed job
    },
}
```

---

## 🌍 Locales

Locale files are in `locales/`. Set your locale in `server.cfg`:

```cfg
setr esx:locale "en"
```

| Code | Language |
|------|----------|
| `en` | English |
| `es` | Spanish |
| `de` | German |
| `fr` | French |
| `nl` | Dutch |
| `tr` | Turkish |
| `hu` | Hungarian |
| `sr` | Serbian |
| `sl` | Slovenian |

To add a new language, copy `locales/en.lua`, rename it, change the key at the top, and translate the strings.

---

## 📡 Exports

Other resources can read garage and impound data:

```lua
-- Lua (server or client)
local garages  = exports['ari_garage']:getGarages()
local impounds = exports['ari_garage']:getImpounds()
local config   = exports['ari_garage']:getConfig()
```

---

## 🔌 Target System

Set `Config.UseTarget = true` to disable markers and use your preferred target resource. You will need to manually register target zones or objects pointing to the events below:

| Event | Side | Usage |
|-------|------|-------|
| `ari_garage:hasEnteredMarker` | Client | Triggered on entry — pass `(garageName, 'EntryPoint')` |
| `ari_garage:hasExitedMarker`  | Client | Triggered on exit |
| `ari_garage:closemenu`        | Client | Close the NUI |

---

## 🐛 Known Issues / FAQ

**"No vehicles stored here" but I have vehicles**  
→ Make sure the `parking` column was added correctly and vehicles were stored *after* installing this version.

**Impound fee doesn't deduct from bank**  
→ Set `Config.PaymentMethod = 'bank'` in `config.lua`.

**Marker shows but [E] does nothing**  
→ Check that `Config.InteractDistance` is large enough — default is `1.5` metres. Try increasing to `2.0`.

**UI doesn't open**  
→ Make sure the `ui_page` line in `fxmanifest.lua` points to `nui/ui.html` and the resource is restarted.

---

## 🤝 Credits

- Original `esx_garage_v2` by the ESX-Framework team
- Redesign & v1.14.0-ari by **Ari**

---

## 📄 License

MIT — free to use, modify, and distribute with attribution.

---

<div align="center">
<sub>Made with ♥ for the FiveM community</sub>
</div>
