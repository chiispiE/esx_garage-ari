--[[
    ari_garage — Server
    Version: 1.14.0-ari
--]]

-- ─── Update / Park / Release ───────────────────────────────────────────────────

RegisterServerEvent('ari_garage:updateOwnedVehicle')
AddEventHandler('ari_garage:updateOwnedVehicle', function(stored, parking, impound, data, spawn)
    local source  = source
    local xPlayer = ESX.Player(source)
    if not xPlayer then return end

    MySQL.update(
        'UPDATE owned_vehicles SET `stored` = @stored, `parking` = @parking, `pound` = @impound, `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier',
        {
            ['@identifier'] = xPlayer.getIdentifier(),
            ['@vehicle']    = json.encode(data.vehicleProps),
            ['@plate']      = data.vehicleProps.plate,
            ['@stored']     = stored,
            ['@parking']    = parking,
            ['@impound']    = impound,
        }
    )

    if stored then
        xPlayer.showNotification(TranslateCap('veh_stored'))
    else
        ESX.OneSync.SpawnVehicle(data.vehicleProps.model, spawn, data.spawnPoint.heading, data.vehicleProps, function(netId)
            local veh = NetworkGetEntityFromNetworkId(netId)
            Wait(300)
            TaskWarpPedIntoVehicle(GetPlayerPed(source), veh, -1)
        end)
    end
end)

-- ─── Impound ───────────────────────────────────────────────────────────────────

RegisterServerEvent('ari_garage:setImpound')
AddEventHandler('ari_garage:setImpound', function(impoundName, vehicleProps)
    local source  = source
    local xPlayer = ESX.Player(source)
    if not xPlayer then return end

    MySQL.update(
        'UPDATE owned_vehicles SET `stored` = @stored, `pound` = @impound, `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier',
        {
            ['@identifier'] = xPlayer.getIdentifier(),
            ['@vehicle']    = json.encode(vehicleProps),
            ['@plate']      = vehicleProps.plate,
            ['@stored']     = 2,
            ['@impound']    = impoundName,
        }
    )

    xPlayer.showNotification(TranslateCap('veh_impounded'))

    -- Notify owner (if Config.NotifyOnImpound and another player owns it, handled here)
    if Config.NotifyOnImpound then
        MySQL.query('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
            ['@plate'] = vehicleProps.plate
        }, function(result)
            if result and result[1] then
                local ownerIdentifier = result[1].owner
                local targetPlayer = ESX.GetPlayerFromIdentifier(ownerIdentifier)
                if targetPlayer and targetPlayer.source ~= source then
                    targetPlayer.showNotification(TranslateCap('veh_impounded'))
                end
            end
        end)
    end
end)

-- ─── Callbacks ─────────────────────────────────────────────────────────────────

ESX.RegisterServerCallback('ari_garage:getVehiclesInParking', function(source, cb, parking)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return cb({}) end

    MySQL.query(
        'SELECT * FROM owned_vehicles WHERE owner = @identifier AND parking = @parking AND stored = 1',
        { ['@identifier'] = xPlayer.getIdentifier(), ['@parking'] = parking },
        function(result)
            local vehicles = {}
            for i = 1, #result do
                table.insert(vehicles, {
                    vehicle = json.decode(result[i].vehicle),
                    plate   = result[i].plate,
                })
            end
            cb(vehicles)
        end
    )
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesImpounded', function(source, cb)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return cb({}) end

    MySQL.query(
        'SELECT * FROM owned_vehicles WHERE owner = @identifier AND stored = 0',
        { ['@identifier'] = xPlayer.getIdentifier() },
        function(result)
            local vehicles = {}
            for i = 1, #result do
                table.insert(vehicles, {
                    vehicle = json.decode(result[i].vehicle),
                    plate   = result[i].plate,
                })
            end
            cb(vehicles)
        end
    )
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesInPound', function(source, cb, impound)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return cb({}) end

    MySQL.query(
        'SELECT * FROM owned_vehicles WHERE owner = @identifier AND pound = @impound AND stored = 2',
        { ['@identifier'] = xPlayer.getIdentifier(), ['@impound'] = impound },
        function(result)
            local vehicles = {}
            for i = 1, #result do
                table.insert(vehicles, {
                    vehicle = json.decode(result[i].vehicle),
                    plate   = result[i].plate,
                })
            end
            cb(vehicles)
        end
    )
end)

ESX.RegisterServerCallback('ari_garage:checkVehicleOwner', function(source, cb, plate)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return cb(false) end

    MySQL.query(
        'SELECT COUNT(*) as count FROM owned_vehicles WHERE owner = @identifier AND plate = @plate',
        { ['@identifier'] = xPlayer.getIdentifier(), ['@plate'] = plate },
        function(result)
            cb(result and tonumber(result[1].count) > 0)
        end
    )
end)

ESX.RegisterServerCallback('ari_garage:checkMoney', function(source, cb, amount)
    local xPlayer = ESX.Player(source)
    if not xPlayer then return cb(false) end

    if Config.PaymentMethod == 'bank' then
        cb(xPlayer.getAccount('bank').money >= amount)
    elseif Config.PaymentMethod == 'any' then
        cb((xPlayer.getMoney() + xPlayer.getAccount('bank').money) >= amount)
    else
        cb(xPlayer.getMoney() >= amount)
    end
end)

-- ─── Pay Impound ───────────────────────────────────────────────────────────────

RegisterServerEvent('ari_garage:payPound')
AddEventHandler('ari_garage:payPound', function(amount)
    local source  = source
    local xPlayer = ESX.Player(source)
    if not xPlayer then return end

    local function deductAndNotify()
        xPlayer.showNotification(TranslateCap('pay_Impound_bill', amount))
    end

    if Config.PaymentMethod == 'bank' then
        if xPlayer.getAccount('bank').money >= amount then
            xPlayer.removeAccountMoney('bank', amount, 'Impound Fee')
            deductAndNotify()
        else
            xPlayer.showNotification(TranslateCap('missing_money'))
        end
    elseif Config.PaymentMethod == 'any' then
        local cash = xPlayer.getMoney()
        if cash >= amount then
            xPlayer.removeMoney(amount, 'Impound Fee')
            deductAndNotify()
        elseif (cash + xPlayer.getAccount('bank').money) >= amount then
            local remainder = amount - cash
            xPlayer.removeMoney(cash, 'Impound Fee (cash)')
            xPlayer.removeAccountMoney('bank', remainder, 'Impound Fee (bank)')
            deductAndNotify()
        else
            xPlayer.showNotification(TranslateCap('missing_money'))
        end
    else
        if xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount, 'Impound Fee')
            deductAndNotify()
        else
            xPlayer.showNotification(TranslateCap('missing_money'))
        end
    end
end)
