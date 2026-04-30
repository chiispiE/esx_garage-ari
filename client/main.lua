--[[
    ari_garage — Client
    Version: 1.14.0-ari
--]]

local LastMarker, LastPart         = nil, nil
local thisGarage, thisPound        = nil, nil
local nearMarker, menuIsShowed     = false, false
local HasAlreadyEnteredMarker      = false
local vehiclesList, vehiclesImpoundedList = {}, {}
local next = next

-- ─── Helper ────────────────────────────────────────────────────────────────────

local function PlayUISound()
    if Config.UI.Sound.Enabled then
        PlaySoundFrontend(-1, Config.UI.Sound.Name, Config.UI.Sound.Set, true)
    end
end

local function IsJobAllowed(allowedJobs, allowedGrades)
    if not allowedJobs then return true end
    local playerJob   = ESX.PlayerData.job
    local playerGrade = ESX.PlayerData.job.grade

    for _, job in ipairs(allowedJobs) do
        if playerJob.name == job then
            if allowedGrades and allowedGrades[job] then
                return playerGrade >= allowedGrades[job]
            end
            return true
        end
    end
    return false
end

-- ─── Close Menu ────────────────────────────────────────────────────────────────

RegisterNetEvent('ari_garage:closemenu')
AddEventHandler('ari_garage:closemenu', function()
    menuIsShowed = false
    vehiclesList, vehiclesImpoundedList = {}, {}

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    if not menuIsShowed and thisGarage then
        ESX.TextUI(TranslateCap('access_parking'))
    end
    if not menuIsShowed and thisPound then
        ESX.TextUI(TranslateCap('access_Impound'))
    end
end)

RegisterNUICallback('escape', function(data, cb)
    TriggerEvent('ari_garage:closemenu')
    cb('ok')
end)

-- ─── Spawn Vehicle ─────────────────────────────────────────────────────────────

RegisterNUICallback('spawnVehicle', function(data, cb)
    local spawnCoords = vector3(data.spawnPoint.x, data.spawnPoint.y, data.spawnPoint.z)

    if thisGarage then
        if ESX.Game.IsSpawnPointClear(spawnCoords, 2.5) then
            thisGarage = nil
            TriggerServerEvent('ari_garage:updateOwnedVehicle', false, nil, nil, data, spawnCoords)
            TriggerEvent('ari_garage:closemenu')
            ESX.ShowNotification(TranslateCap('veh_released'))
        else
            ESX.ShowNotification(TranslateCap('veh_block'), 'error')
        end

    elseif thisPound then
        ESX.TriggerServerCallback('ari_garage:checkMoney', function(hasMoney)
            if hasMoney then
                if ESX.Game.IsSpawnPointClear(spawnCoords, 2.5) then
                    TriggerServerEvent('ari_garage:payPound', data.exitVehicleCost)
                    thisPound = nil
                    TriggerServerEvent('ari_garage:updateOwnedVehicle', false, nil, nil, data, spawnCoords)
                    TriggerEvent('ari_garage:closemenu')
                else
                    ESX.ShowNotification(TranslateCap('veh_block'), 'error')
                end
            else
                ESX.ShowNotification(TranslateCap('missing_money'))
            end
        end, data.exitVehicleCost)
    end

    cb('ok')
end)

-- ─── Impound ───────────────────────────────────────────────────────────────────

RegisterNUICallback('impound', function(data, cb)
    TriggerServerEvent('ari_garage:setImpound', data.poundName, data.vehicleProps)
    TriggerEvent('ari_garage:closemenu')
    SetNewWaypoint(data.poundSpawnPoint.x, data.poundSpawnPoint.y)
    cb('ok')
end)

-- ─── Blips ─────────────────────────────────────────────────────────────────────

CreateThread(function()
    for k, v in pairs(Config.Garages) do
        local b = Config.GarageBlip
        local blip = AddBlipForCoord(v.EntryPoint.x, v.EntryPoint.y, v.EntryPoint.z)
        SetBlipSprite(blip, v.Sprite  or b.Sprite)
        SetBlipDisplay(blip, b.Display)
        SetBlipScale(blip, v.Scale  or b.Scale)
        SetBlipColour(blip, v.Colour or b.Colour)
        SetBlipAsShortRange(blip, b.ShortRange)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(v.Label or TranslateCap('parking_blip_name'))
        EndTextCommandSetBlipName(blip)
    end

    for k, v in pairs(Config.Impounds) do
        local b = Config.ImpoundBlip
        local blip = AddBlipForCoord(v.GetOutPoint.x, v.GetOutPoint.y, v.GetOutPoint.z)
        SetBlipSprite(blip, v.Sprite  or b.Sprite)
        SetBlipDisplay(blip, b.Display)
        SetBlipScale(blip, v.Scale  or b.Scale)
        SetBlipColour(blip, v.Colour or b.Colour)
        SetBlipAsShortRange(blip, b.ShortRange)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(v.Label or TranslateCap('Impound_blip_name'))
        EndTextCommandSetBlipName(blip)
    end
end)

-- ─── Marker Enter / Exit events ────────────────────────────────────────────────

AddEventHandler('ari_garage:hasEnteredMarker', function(name, part)
    if part == 'EntryPoint' then
        local isInVehicle = IsPedInAnyVehicle(ESX.PlayerData.ped, false)
        thisGarage = Config.Garages[name]
        ESX.TextUI(isInVehicle and TranslateCap('park_veh') or TranslateCap('access_parking'))
    elseif part == 'GetOutPoint' then
        thisPound = Config.Impounds[name]
        ESX.TextUI(TranslateCap('access_Impound'))
    end
end)

AddEventHandler('ari_garage:hasExitedMarker', function()
    thisGarage = nil
    thisPound  = nil
    ESX.HideUI()
    TriggerEvent('ari_garage:closemenu')
end)

-- ─── Draw Markers ──────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local sleep      = 500
        local playerPed  = ESX.PlayerData.ped
        local coords     = GetEntityCoords(playerPed)

        for _, v in pairs(Config.Garages) do
            local ep = v.EntryPoint
            if #(coords - vector3(ep.x, ep.y, ep.z)) < Config.DrawDistance then
                local m = Config.Markers.EntryPoint
                DrawMarker(m.Type, ep.x, ep.y, ep.z,
                    0.0, 0.0, 0.0, 0, 0.0, 0.0,
                    m.Size.x, m.Size.y, m.Size.z,
                    m.Color.r, m.Color.g, m.Color.b,
                    m.Alpha, false, true, 2, m.Bob, false, false, false)
                sleep = 0
                break
            end
        end

        for _, v in pairs(Config.Impounds) do
            local gp = v.GetOutPoint
            if #(coords - vector3(gp.x, gp.y, gp.z)) < Config.DrawDistance then
                local m = Config.Markers.GetOutPoint
                DrawMarker(m.Type, gp.x, gp.y, gp.z,
                    0.0, 0.0, 0.0, 0, 0.0, 0.0,
                    m.Size.x, m.Size.y, m.Size.z,
                    m.Color.r, m.Color.g, m.Color.b,
                    m.Alpha, false, true, 2, m.Bob, false, false, false)
                sleep = 0
                break
            end
        end

        nearMarker = (sleep == 0)
        Wait(sleep)
    end
end)

-- ─── Open Garage Menu ──────────────────────────────────────────────────────────

local function buildLocales()
    return {
        action         = TranslateCap('veh_exit'),
        veh_model      = TranslateCap('veh_model'),
        veh_plate      = TranslateCap('veh_plate'),
        veh_condition  = TranslateCap('veh_condition'),
        veh_action     = TranslateCap('veh_action'),
        impound_action = TranslateCap('impound_action'),
        no_veh_parking = TranslateCap('no_veh_parking'),
        no_veh_impounded = TranslateCap('no_veh_impounded'),
        pay_impound    = TranslateCap('pay_impound'),
        fuel           = TranslateCap('fuel') or 'Fuel',
    }
end

local function openGarageMenu(garageKey, garage)
    ESX.TriggerServerCallback('ari_garage:getVehiclesInParking', function(vehicles)
        menuIsShowed = true

        for i = 1, #vehicles do
            table.insert(vehiclesList, {
                model = GetDisplayNameFromVehicleModel(vehicles[i].vehicle.model),
                plate = vehicles[i].plate,
                props = vehicles[i].vehicle,
            })
        end

        local spawnPoint = {
            x = garage.SpawnPoint.x,
            y = garage.SpawnPoint.y,
            z = garage.SpawnPoint.z,
            heading = garage.SpawnPoint.heading,
        }

        ESX.TriggerServerCallback('ari_garage:getVehiclesImpounded', function(impVehicles)
            for i = 1, #impVehicles do
                table.insert(vehiclesImpoundedList, {
                    model = GetDisplayNameFromVehicleModel(impVehicles[i].vehicle.model),
                    plate = impVehicles[i].plate,
                    props = impVehicles[i].vehicle,
                })
            end

            local poundSpawnPoint = nil
            if garage.ImpoundedName and Config.Impounds[garage.ImpoundedName] then
                local imp = Config.Impounds[garage.ImpoundedName]
                poundSpawnPoint = { x = imp.GetOutPoint.x, y = imp.GetOutPoint.y }
            end

            PlayUISound()

            SendNUIMessage({
                action               = 'show',
                menuType             = 'garage',
                garageLabel          = garage.Label or garageKey,
                vehiclesList         = json.encode(vehiclesList),
                vehiclesImpoundedList = next(vehiclesImpoundedList) and json.encode(vehiclesImpoundedList) or nil,
                poundName            = garage.ImpoundedName,
                poundSpawnPoint      = poundSpawnPoint,
                spawnPoint           = spawnPoint,
                accentColor          = Config.UI.AccentColor,
                animateCards         = Config.UI.AnimateCards,
                showFuel             = Config.UI.ShowFuelGauge,
                locales              = buildLocales(),
            })

            SetNuiFocus(true, true)
            ESX.HideUI()
        end)

    end, garageKey)
end

local function openImpoundMenu(poundKey, pound)
    ESX.TriggerServerCallback('ari_garage:getVehiclesInPound', function(vehicles)
        if next(vehicles) then
            menuIsShowed = true

            for i = 1, #vehicles do
                table.insert(vehiclesList, {
                    model = GetDisplayNameFromVehicleModel(vehicles[i].vehicle.model),
                    plate = vehicles[i].plate,
                    props = vehicles[i].vehicle,
                })
            end

            PlayUISound()

            SendNUIMessage({
                action       = 'show',
                menuType     = 'impound',
                garageLabel  = pound.Label or poundKey,
                vehiclesList = json.encode(vehiclesList),
                spawnPoint   = { x = pound.SpawnPoint.x, y = pound.SpawnPoint.y, z = pound.SpawnPoint.z, heading = pound.SpawnPoint.heading },
                poundCost    = pound.Cost,
                accentColor  = Config.UI.AccentColor,
                animateCards = Config.UI.AnimateCards,
                showFuel     = Config.UI.ShowFuelGauge,
                locales      = buildLocales(),
            })

            SetNuiFocus(true, true)
            ESX.HideUI()
        else
            ESX.ShowNotification(TranslateCap('no_veh_Impound'))
        end
    end, poundKey)
end

-- ─── Interaction Loop ──────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        if nearMarker then
            local playerPed     = ESX.PlayerData.ped
            local coords        = GetEntityCoords(playerPed)
            local isInMarker    = false
            local currentMarker = nil
            local currentPart   = nil

            -- Garage entry points
            for k, v in pairs(Config.Garages) do
                local ep = v.EntryPoint
                if #(coords - vector3(ep.x, ep.y, ep.z)) < Config.Markers.EntryPoint.Size.x then
                    isInMarker    = true
                    currentMarker = k
                    currentPart   = 'EntryPoint'

                    local isInVehicle = IsPedInAnyVehicle(playerPed, false)

                    if not isInVehicle then
                        if IsControlJustReleased(0, 38) and not menuIsShowed then
                            if not IsJobAllowed(v.AllowedJobs, v.AllowedGrades) then
                                ESX.ShowNotification(TranslateCap('not_allowed'), 'error')
                            else
                                openGarageMenu(k, v)
                            end
                        end
                    else
                        if IsControlJustReleased(0, 38) then
                            local vehicle     = GetVehiclePedIsIn(playerPed, false)
                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                            ESX.TriggerServerCallback('ari_garage:checkVehicleOwner', function(owner)
                                if owner then
                                    ESX.Game.DeleteVehicle(vehicle)
                                    TriggerServerEvent('ari_garage:updateOwnedVehicle', true, k, nil, { vehicleProps = vehicleProps })
                                    ESX.ShowNotification(TranslateCap('veh_stored'))
                                else
                                    ESX.ShowNotification(TranslateCap('not_owning_veh'), 'error')
                                end
                            end, vehicleProps.plate)
                        end
                    end
                    break
                end
            end

            -- Impound get-out points
            for k, v in pairs(Config.Impounds) do
                local gp = v.GetOutPoint
                if #(coords - vector3(gp.x, gp.y, gp.z)) < 2.0 then
                    isInMarker    = true
                    currentMarker = k
                    currentPart   = 'GetOutPoint'

                    if IsControlJustReleased(0, 38) and not menuIsShowed then
                        openImpoundMenu(k, v)
                    end
                    break
                end
            end

            -- Enter / exit events
            if isInMarker and (not HasAlreadyEnteredMarker or LastMarker ~= currentMarker or LastPart ~= currentPart) then
                if LastMarker ~= currentMarker or LastPart ~= currentPart then
                    TriggerEvent('ari_garage:hasExitedMarker')
                end
                HasAlreadyEnteredMarker = true
                LastMarker = currentMarker
                LastPart   = currentPart
                TriggerEvent('ari_garage:hasEnteredMarker', currentMarker, currentPart)
            end

            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false
                TriggerEvent('ari_garage:hasExitedMarker')
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
