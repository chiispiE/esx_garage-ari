--[[
    ari_garage — Menú admin (ox_lib) para borrar entradas de owned_vehicles
--]]

local function notifySuccess(key)
    lib.notify({
        title = t('admin_menu_title'),
        description = t(key),
        type = 'success',
    })
end

local function notifyError(key)
    lib.notify({
        title = t('admin_menu_title'),
        description = t(key),
        type = 'error',
    })
end

local function decodeVehicleProps(jsonStr)
    if not jsonStr or jsonStr == '' then
        return {}
    end
    local ok, data = pcall(json.decode, jsonStr)
    if ok and type(data) == 'table' then
        return data
    end
    return {}
end

local function t(key)
    local str = TranslateCap(key)
    if not str then
        return key or ''
    end
    return str
end

local function tf(key, ...)
    local str = t(key)
    if select('#', ...) > 0 then
        local ok, result = pcall(string.format, str, ...)
        if ok then
            return result
        end
    end
    return str
end

local function openDeleteByPlate()
    local input = lib.inputDialog(t('admin_menu_title'), {
        {
            type = 'input',
            label = t('admin_plate_label'),
            description = t('admin_plate_desc'),
            required = true,
            min = 1,
            max = 12,
        },
    })

    if not input or not input[1] then
        return
    end

    local plate = input[1]
    local confirm = lib.alertDialog({
        header = t('admin_confirm_header'),
        content = tf('admin_confirm_body', plate),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then
        return
    end

    local ok, reason = lib.callback.await('ari_garage:adminDeleteVehicle', false, plate)
    if ok then
        notifySuccess('admin_deleted')
    elseif reason == 'no_permission' then
        notifyError('admin_no_permission')
    elseif reason == 'invalid_plate' then
        notifyError('admin_invalid_plate')
    else
        notifyError('admin_not_found')
    end
end

local function openSearchFlow()
    local input = lib.inputDialog(t('admin_search_title'), {
        {
            type = 'input',
            label = t('admin_search_label'),
            description = t('admin_search_desc'),
            required = true,
            min = 2,
            max = 32,
        },
    })

    if not input or not input[1] then
        return
    end

    local rows = lib.callback.await('ari_garage:adminSearchVehicles', false, input[1])
    if not rows or #rows == 0 then
        notifyError('admin_search_empty')
        return
    end

    local options = {}
    for i = 1, #rows do
        local r = rows[i]
        local props = decodeVehicleProps(r.vehicle)
        local m = props.model
        if type(m) == 'string' then
            m = joaat(m)
        end
        local modelLabel = m and GetDisplayNameFromVehicleModel(m) or '?'
        local storedText = r.stored == 0 and 'Garaje' or (r.stored == 1 and 'Fuera' or (r.stored == 2 and 'Embargado' or tostring(r.stored)))
        options[#options + 1] = {
            title = r.plate or '?',
            description = ('Dueno: %s | stored: %s | parking: %s | modelo: %s'):format(
                r.owner or '?',
                storedText,
                r.parking or '—',
                modelLabel
            ),
            icon = 'car',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = t('admin_confirm_header'),
                    content = tf('admin_confirm_body', r.plate),
                    centered = true,
                    cancel = true,
                })
                if confirm ~= 'confirm' then
                    return
                end
                local ok, reason = lib.callback.await('ari_garage:adminDeleteVehicle', false, r.plate)
                if ok then
                    notifySuccess('admin_deleted')
                elseif reason == 'no_permission' then
                    notifyError('admin_no_permission')
                else
                    notifyError('admin_not_found')
                end
            end,
        }
    end

    lib.registerContext({
        id = 'ari_garage_admin_search',
        title = t('admin_search_results'),
        menu = 'ari_garage_admin_root',
        options = options,
    })

    lib.showContext('ari_garage_admin_search')
end

local function openAdminRoot()
    if not lib.callback.await('ari_garage:adminCanOpen', false) then
        notifyError('admin_no_permission')
        return
    end

    lib.registerContext({
        id = 'ari_garage_admin_root',
        title = t('admin_menu_title'),
        options = {
            {
                title = t('admin_opt_delete_plate'),
                description = t('admin_opt_delete_plate_desc'),
                icon = 'trash',
                onSelect = openDeleteByPlate,
            },
            {
                title = t('admin_opt_search'),
                description = t('admin_opt_search_desc'),
                icon = 'magnifying-glass',
                onSelect = openSearchFlow,
            },
        },
    })

    lib.showContext('ari_garage_admin_root')
end

RegisterCommand(Config.AdminGarage.Command, function()
    openAdminRoot()
end, false)

if Config.AdminGarage.KeyRegister then
    RegisterKeyMapping(
        Config.AdminGarage.Command,
        t('admin_keymapping'),
        'keyboard',
        ''
    )
end
