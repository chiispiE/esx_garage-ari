--[[
    ari_garage — Admin (ox_lib callbacks)
    Eliminación de filas en owned_vehicles; permisos vía Config.AdminGarage.Groups
--]]

local function trim(s)
    s = tostring(s or '')
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function normalizePlate(p)
    return trim(p):upper():gsub('%s+', '')
end

local function isAdminSource(src)
    if type(src) ~= 'number' then
        return false
    end

    if IsPlayerAceAllowed(tostring(src), 'command') or GetConvar('sv_lan', '') == 'true' then
        return true
    end

    local xPlayer = ESX.Player(src)
    if not xPlayer then
        return false
    end

    local group = xPlayer.getGroup and xPlayer.getGroup() or xPlayer.group
    return group ~= nil and Config.AdminGarage and Config.AdminGarage.Groups and Config.AdminGarage.Groups[group] == true
end

lib.callback.register('ari_garage:adminCanOpen', function(source)
    return isAdminSource(source)
end)

lib.callback.register('ari_garage:adminSearchVehicles', function(source, query)
    if not isAdminSource(source) then
        return {}
    end

    query = trim(query):gsub('%%', ''):gsub('_', '')
    if #query < 2 then
        return {}
    end

    local pattern = '%' .. query .. '%'
    local rows = MySQL.query.await(
        [[
            SELECT `owner`, `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM `owned_vehicles`
            WHERE `plate` LIKE ?
            ORDER BY `plate` ASC
            LIMIT 25
        ]],
        { pattern }
    )

    return rows or {}
end)

lib.callback.register('ari_garage:adminDeleteVehicle', function(source, plateArg)
    if not isAdminSource(source) then
        return false, 'no_permission'
    end

    local raw = trim(tostring(plateArg or ''))
    local norm = normalizePlate(plateArg)
    if norm == '' then
        return false, 'invalid_plate'
    end

    local affected = MySQL.update.await(
        [[
            DELETE FROM `owned_vehicles`
            WHERE UPPER(REPLACE(REPLACE(`plate`, ' ', ''), '-', '')) = ?
        ]],
        { norm }
    )

    if (affected or 0) < 1 and raw ~= '' then
        affected = MySQL.update.await('DELETE FROM `owned_vehicles` WHERE `plate` = ? LIMIT 1', { raw })
    end

    if (affected or 0) < 1 then
        return false, 'not_found'
    end

    local name = GetPlayerName(source) or ('id:' .. tostring(source))
    print(('[^3ari_garage^7] Admin %s (%s) eliminó vehículo (raw=%s norm=%s)'):format(name, source, raw, norm))

    return true, 'ok'
end)
