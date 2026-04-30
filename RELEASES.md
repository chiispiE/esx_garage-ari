# Releases

## v1.15.0-ari

### Resumen
- Refactor completo de garaje y depósito.
- NUI renovada con look morado neón.
- SQL más claro, con estados de vehículo consistentes e índices nuevos.
- Textos en español más cortos y con más personalidad.

### Novedades
- Estado formal del vehículo:
  - `0` = fuera
  - `1` = guardado
  - `2` = depositado
- El listado de impound ya no mezcla coches fuera con coches en depósito.
- `VehicleFilter` ya filtra los vehículos por tipo.
- `FreeRelease`, `AllowedJobs` y `AllowedGrades` ahora sí afectan la liberación del depósito.
- El coste de sacar un vehículo del depósito puede variar según daño con `Config.ImpoundDamageMult`.
- La UI muestra mejor el estado, la condición y el coste de liberación.
- Color por defecto actualizado a morado neón.

### UI
- Fondo limpio sin bloque negro detrás del panel.
- Sidebar y tarjetas rehechas para una lectura más clara.
- Botones y badges con mejor contraste.
- Preview local disponible en:
  - `file:///C:/Users/ari/Desktop/esx_garage-ari/nui/ui.html?preview=1`

### SQL
- Migración rehecha en `ari_garage.sql`.
- Normalización de `parking` y `pound`.
- Nuevos índices:
  - `idx_owned_vehicles_owner_stored_parking`
  - `idx_owned_vehicles_owner_stored_pound`
  - `idx_owned_vehicles_owner_plate`

### Archivos clave
- `server/main.lua`
- `client/main.lua`
- `nui/css/app.css`
- `nui/js/app.js`
- `locales/es.lua`
- `ari_garage.sql`

### Upgrade
1. Sustituye el recurso por esta versión.
2. Ejecuta `ari_garage.sql` en tu base de datos.
3. Reinicia el recurso:
   - `restart esx_garage-ari`

### Nota
- Se mantiene compatibilidad con los eventos, callbacks y exports ya existentes del recurso.
