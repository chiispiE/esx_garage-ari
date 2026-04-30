--[[
    ari_garage — Server
    Version: 1.15.0-ari
--]]

local VEHICLE_STATE = {
    OUT = 0,
    STORED = 1,
    IMPOUNDED = 2,
}

CreateThread(function()
    local resourceName = GetCurrentResourceName()
    local version = GetResourceMetadata(resourceName, 'version', 0) or '1.15.0-ari'
    local author = GetResourceMetadata(resourceName, 'author', 0) or 'Ari'

    Wait(500)
    print('^5╔══════════════════════════════════════════════════╗^0')
    print('^5║               ^4🚗  ARI GARAGE  🚗               ^5║^0')
    print('^5╠══════════════════════════════════════════════════╣^0')
    print('^5║  ^2> Recurso:   ^0' .. string.format('%-31s', resourceName) .. '^5║^0')
    print('^5║  ^2> Versión:   ^0' .. string.format('%-31s', version) .. '^5║^0')
    print('^5║  ^2> Autora:    ^0' .. string.format('%-31s', author) .. '^5║^0')
    print('^5║  ^2> Sistema:   ^5GARAGE + IMPOUND LISTO         ^5║^0')
    print('^5╠══════════════════════════════════════════════════╣^0')
    print('^5║         ^3Todo en orden, Ari. A rodar.          ^5║^0')
    print('^5╚══════════════════════════════════════════════════╝^0')
end)

local function getPlayerFromSource(source)
    local xPlayer = ESX.Player(source)
    if not xPlayer then
        return nil
    end

    return xPlayer, xPlayer.getIdentifier()
end

local function getPlayerJobData(xPlayer)
    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
    if not job then
        return nil, -1
    end

    local grade = job.grade
    if type(grade) ~= 'number' then
        grade = tonumber(job.grade_level or job.grade_name or 0) or 0
    end

    return job.name, grade
end

local function isJobAllowedForImpound(xPlayer, impound)
    if not impound or not impound.AllowedJobs then
        return true
    end

    local playerJob, playerGrade = getPlayerJobData(xPlayer)
    if not playerJob then
        return false
    end

    for i = 1, #impound.AllowedJobs do
        local allowedJob = impound.AllowedJobs[i]
        if playerJob == allowedJob then
            if impound.AllowedGrades and impound.AllowedGrades[allowedJob] then
                return playerGrade >= impound.AllowedGrades[allowedJob]
            end

            return true
        end
    end

    return false
end

local function decodeVehicleRows(rows, impound)
    local vehicles = {}

    for i = 1, #rows do
        local props = rows[i].vehicle and json.decode(rows[i].vehicle) or nil
        if props then
            local releaseCost = 0
            if impound then
                releaseCost = math.floor((impound.Cost or 0) * (1.0 + math.max(0.0, (1.0 - math.min(props.engineHealth or 1000, 1000) / 1000)) * math.max(Config.ImpoundDamageMult - 1.0, 0.0)))
                releaseCost = math.max(releaseCost, impound.Cost or 0)
            end

            vehicles[#vehicles + 1] = {
                vehicle = props,
                plate = rows[i].plate,
                releaseCost = releaseCost,
                pound = rows[i].pound,
                parking = rows[i].parking,
                stored = rows[i].stored,
            }
        end
    end

    return vehicles
end

local function computeReleaseData(xPlayer, impound, props)
    local baseCost = impound and impound.Cost or 0
    local finalCost = baseCost

    if impound and Config.ImpoundDamageMult > 1.0 then
        local engineHealth = math.min(props and props.engineHealth or 1000, 1000)
        local damageRatio = 1.0 - (engineHealth / 1000)
        finalCost = math.floor(baseCost * (1.0 + (damageRatio * (Config.ImpoundDamageMult - 1.0))))
    end

    local canUseFreeRelease = impound and impound.FreeRelease and isJobAllowedForImpound(xPlayer, impound)
    if canUseFreeRelease then
        finalCost = 0
    end

    local allowed = isJobAllowedForImpound(xPlayer, impound)
    local reason = nil

    if not allowed then
        reason = 'not_allowed'
    end

    return {
        allowed = allowed,
        amount = math.max(0, finalCost),
        isFree = finalCost <= 0,
        reason = reason,
    }
end

local function canAffordImpound(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if Config.PaymentMethod == 'bank' then
        return xPlayer.getAccount('bank').money >= amount
    elseif Config.PaymentMethod == 'any' then
        return (xPlayer.getMoney() + xPlayer.getAccount('bank').money) >= amount
    end

    return xPlayer.getMoney() >= amount
end

local function deductImpoundPayment(xPlayer, amount)
    if amount <= 0 then
        return true
    end

    if Config.PaymentMethod == 'bank' then
        if xPlayer.getAccount('bank').money < amount then
            return false
        end

        xPlayer.removeAccountMoney('bank', amount, 'Impound Fee')
        return true
    elseif Config.PaymentMethod == 'any' then
        local cash = xPlayer.getMoney()
        local bank = xPlayer.getAccount('bank').money

        if cash >= amount then
            xPlayer.removeMoney(amount, 'Impound Fee')
            return true
        end

        if (cash + bank) < amount then
            return false
        end

        if cash > 0 then
            xPlayer.removeMoney(cash, 'Impound Fee (cash)')
        end

        xPlayer.removeAccountMoney('bank', amount - cash, 'Impound Fee (bank)')
        return true
    end

    if xPlayer.getMoney() < amount then
        return false
    end

    xPlayer.removeMoney(amount, 'Impound Fee')
    return true
end

local function updateVehicleState(identifier, plate, state, parking, impound, vehicleProps)
    return MySQL.update.await(
        [[
            UPDATE owned_vehicles
            SET `stored` = ?, `parking` = ?, `pound` = ?, `vehicle` = ?
            WHERE `plate` = ? AND `owner` = ?
        ]],
        {
            state,
            parking,
            impound,
            json.encode(vehicleProps),
            plate,
            identifier,
        }
    )
end

local function getOwnedVehicleByPlate(identifier, plate)
    return MySQL.single.await(
        'SELECT `plate`, `vehicle`, `stored`, `parking`, `pound` FROM owned_vehicles WHERE `owner` = ? AND `plate` = ? LIMIT 1',
        { identifier, plate }
    )
end

local function getOwnedVehicleByPlateAnyOwner(plate)
    return MySQL.single.await(
        'SELECT `owner`, `plate`, `vehicle`, `stored`, `parking`, `pound` FROM owned_vehicles WHERE `plate` = ? LIMIT 1',
        { plate }
    )
end

local function spawnOwnedVehicle(source, spawn, data)
    ESX.OneSync.SpawnVehicle(data.vehicleProps.model, spawn, data.spawnPoint.heading, data.vehicleProps, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        Wait(300)

        if vehicle and vehicle ~= 0 then
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
        end
    end)
end

RegisterServerEvent('ari_garage:updateOwnedVehicle')
AddEventHandler('ari_garage:updateOwnedVehicle', function(stored, parking, impound, data, spawn)
    local source = source
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer or not data or not data.vehicleProps or not data.vehicleProps.plate then
        return
    end

    local ownedVehicle = getOwnedVehicleByPlate(identifier, data.vehicleProps.plate)
    if not ownedVehicle then
        xPlayer.showNotification(TranslateCap('not_owning_veh'))
        return
    end

    local state = stored and VEHICLE_STATE.STORED or VEHICLE_STATE.OUT
    local updated = updateVehicleState(identifier, data.vehicleProps.plate, state, parking, impound, data.vehicleProps)
    if updated < 1 then
        return
    end

    if state == VEHICLE_STATE.STORED then
        xPlayer.showNotification(TranslateCap('veh_stored'))
        return
    end

    spawnOwnedVehicle(source, spawn, data)
end)

RegisterServerEvent('ari_garage:setImpound')
AddEventHandler('ari_garage:setImpound', function(impoundName, vehicleProps)
    local source = source
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate then
        return
    end

    local impound = Config.Impounds[impoundName]
    if not impound then
        return
    end

    local ownedVehicle = getOwnedVehicleByPlateAnyOwner(vehicleProps.plate)
    if not ownedVehicle then
        xPlayer.showNotification(TranslateCap('not_owning_veh'))
        return
    end

    local updated = updateVehicleState(ownedVehicle.owner, vehicleProps.plate, VEHICLE_STATE.IMPOUNDED, nil, impoundName, vehicleProps)
    if updated < 1 then
        return
    end

    xPlayer.showNotification(TranslateCap('veh_impounded'))

    if not Config.NotifyOnImpound then
        return
    end

    local result = MySQL.single.await('SELECT `owner` FROM owned_vehicles WHERE `plate` = ? LIMIT 1', { vehicleProps.plate })
    if not result or result.owner == identifier then
        return
    end

    local targetPlayer = ESX.GetPlayerFromIdentifier(result.owner)
    if targetPlayer and targetPlayer.source ~= source then
        targetPlayer.showNotification(TranslateCap('veh_impounded'))
    end
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesInParking', function(source, cb, parking)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({})
    end

    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` = ? AND `parking` = ?
            ORDER BY `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.STORED, parking }
    )

    cb(decodeVehicleRows(result))
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesImpounded', function(source, cb)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({})
    end

    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` IN (?, ?)
            ORDER BY `stored` DESC, `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.OUT, VEHICLE_STATE.IMPOUNDED }
    )

    cb(decodeVehicleRows(result))
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesInPound', function(source, cb, impoundName)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({})
    end

    local impound = Config.Impounds[impoundName]
    if not impound then
        return cb({})
    end

    local releaseMeta = computeReleaseData(xPlayer, impound, {})
    if not releaseMeta.allowed then
        return cb({
            allowed = false,
            vehicles = {},
            reason = releaseMeta.reason,
        })
    end

    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` = ? AND `pound` = ?
            ORDER BY `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.IMPOUNDED, impoundName }
    )

    local vehicles = decodeVehicleRows(result)
    for i = 1, #vehicles do
        local releaseData = computeReleaseData(xPlayer, impound, vehicles[i].vehicle)
        vehicles[i].releaseCost = releaseData.amount
        vehicles[i].releaseFree = releaseData.isFree
    end

    cb({
        allowed = true,
        vehicles = vehicles,
        cost = impound.Cost or 0,
        freeRelease = impound.FreeRelease == true and isJobAllowedForImpound(xPlayer, impound),
    })
end)

ESX.RegisterServerCallback('ari_garage:checkVehicleOwner', function(source, cb, plate)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb(false)
    end

    local ownedVehicle = getOwnedVehicleByPlate(identifier, plate)
    cb(ownedVehicle ~= nil)
end)

ESX.RegisterServerCallback('ari_garage:checkMoney', function(source, cb, amount, impoundName, vehicleProps)
    local xPlayer = ESX.Player(source)
    if not xPlayer then
        return cb({ allowed = false, amount = amount or 0, isFree = false })
    end

    if impoundName and Config.Impounds[impoundName] then
        local releaseData = computeReleaseData(xPlayer, Config.Impounds[impoundName], vehicleProps or {})
        if not releaseData.allowed then
            return cb(releaseData)
        end

        releaseData.hasMoney = canAffordImpound(xPlayer, releaseData.amount)
        return cb(releaseData)
    end

    cb({
        allowed = true,
        amount = amount or 0,
        isFree = (amount or 0) <= 0,
        hasMoney = canAffordImpound(xPlayer, amount or 0),
    })
end)

RegisterServerEvent('ari_garage:payPound')
AddEventHandler('ari_garage:payPound', function(amount, impoundName, vehicleProps)
    local source = source
    local xPlayer = ESX.Player(source)
    if not xPlayer then
        return
    end

    local finalAmount = amount or 0
    if impoundName and Config.Impounds[impoundName] then
        local releaseData = computeReleaseData(xPlayer, Config.Impounds[impoundName], vehicleProps or {})
        if not releaseData.allowed then
            xPlayer.showNotification(TranslateCap('not_allowed'))
            return
        end

        finalAmount = releaseData.amount
    end

    if not deductImpoundPayment(xPlayer, finalAmount) then
        xPlayer.showNotification(TranslateCap('missing_money'))
        return
    end

    if finalAmount > 0 then
        xPlayer.showNotification(TranslateCap('pay_Impound_bill', finalAmount))
    else
        xPlayer.showNotification(TranslateCap('veh_Impound_released'))
    end
end)
