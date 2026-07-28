local Framework = {
    name = nil,
    object = nil,
}

local function resourceReady(resourceName)
    local state = GetResourceState(resourceName)
    return state == 'started' or state == 'starting'
end

local OxLib = {
    loaded = false,
}

local function loadOxLib()
    local resourceName = Config.OxLibName or 'ox_lib'

    if OxLib.loaded and lib and lib.name == resourceName then
        return true
    end

    local state = GetResourceState(resourceName)
    if state == 'starting' then
        for _ = 1, 50 do
            Wait(100)
            state = GetResourceState(resourceName)
            if state ~= 'starting' then break end
        end
    end

    if state ~= 'started' then
        return false
    end

    if lib and lib.name == resourceName then
        OxLib.loaded = true
        return true
    end

    local source = LoadResourceFile(resourceName, 'init.lua')
    if not source then return false end

    local chunk = load(source, ('@@%s/init.lua'):format(resourceName), 't', _ENV)
    if not chunk then return false end

    local ok = pcall(chunk)
    OxLib.loaded = ok and lib and lib.name == resourceName or false
    return OxLib.loaded
end

local function normalizeSystem(value)
    return string.lower(tostring(value or 'auto'))
end

local function isOxSystem(value)
    return value == 'ox' or value == 'ox_lib' or value == 'oxlib'
        or value == 'ox_menu' or value == 'ox_notify'
end

local function getQBCoreObject()
    local ok, object = pcall(function()
        return exports[Config.CoreName or 'qb-core']:GetCoreObject()
    end)
    return ok and object or nil
end

local function getESXObject()
    local ok, object = pcall(function()
        return exports[Config.ESXName or 'es_extended']:getSharedObject()
    end)

    if ok and object then return object end

    local legacyObject = nil
    TriggerEvent('esx:getSharedObject', function(objectValue)
        legacyObject = objectValue
    end)
    return legacyObject
end

local function resolveFramework()
    local selected = string.lower(tostring(Config.Framework or 'auto'))
    local timeoutAt = GetGameTimer() + 30000

    while GetGameTimer() < timeoutAt do
        local qbReady = resourceReady(Config.CoreName or 'qb-core')
        local esxReady = resourceReady(Config.ESXName or 'es_extended')
        local target = selected

        if selected == 'auto' then
            if qbReady and esxReady then
                target = string.lower(tostring(Config.AutoFrameworkPriority or 'qb'))
            elseif qbReady then
                target = 'qb'
            elseif esxReady then
                target = 'esx'
            end
        end

        if target == 'qb' and qbReady then
            local object = getQBCoreObject()
            if object then
                Framework.name = 'qb'
                Framework.object = object
                return true
            end
        elseif target == 'esx' and esxReady then
            local object = getESXObject()
            if object then
                Framework.name = 'esx'
                Framework.object = object
                return true
            end
        end

        Wait(250)
    end

    return false
end

if not resolveFramework() then
    error(('[apex-npcmechanic] Unable to detect framework. Check Config.Framework, Config.CoreName and Config.ESXName.'))
end

local QBCore = Framework.name == 'qb' and Framework.object or nil
local ESX = Framework.name == 'esx' and Framework.object or nil
local OxAvailable = loadOxLib()

local function resolveCallbackSystem()
    local selected = normalizeSystem(Config.CallbackSystem)

    if isOxSystem(selected) then
        return OxAvailable and 'ox' or 'framework'
    end

    if selected == 'framework' then
        return 'framework'
    end

    return OxAvailable and 'ox' or 'framework'
end

local CallbackSystem = resolveCallbackSystem()

local function triggerFrameworkCallback(name, callback, ...)
    if CallbackSystem == 'ox' then
        lib.callback(name, false, callback, ...)
        return
    end

    if Framework.name == 'qb' then
        QBCore.Functions.TriggerCallback(name, callback, ...)
        return
    end

    ESX.TriggerServerCallback(name, callback, ...)
end

local ServiceInProgress = false
local RoadsideState = {
    active = false,
    serverPending = false,
    completed = false,
    vehicleNetId = 0,
    targetVehicle = 0,
    mechanic = 0,
    truck = 0,
    toolbox = 0,
    blip = 0,
}

CreateThread(function()
    Wait(0)
    print(('[apex-npcmechanic] Client version 1.2.0 loaded (%s)'):format(Framework.name))
end)

local function L(key, ...)
    local language = Locales[Config.Language] or Locales.en or {}
    local text = language[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

local function resolveNotifySystem()
    local selected = normalizeSystem(Config.NotifySystem)

    if selected == 'auto' then
        if Config.CustomNotifyEvent then return 'custom' end
        if OxAvailable then return 'ox' end
        return 'framework'
    end

    if isOxSystem(selected) then
        return OxAvailable and 'ox' or 'framework'
    end

    if selected == 'custom' then
        return Config.CustomNotifyEvent and 'custom' or 'framework'
    end

    if selected == 'gta' then return 'gta' end
    return 'framework'
end

local NotifySystem = resolveNotifySystem()

local function notify(message, notifyType, duration)
    local selectedType = notifyType or 'primary'
    local selectedDuration = duration or 5000

    if NotifySystem == 'ox' then
        local oxTypes = {
            primary = 'inform',
            info = 'inform',
            inform = 'inform',
            success = 'success',
            error = 'error',
            warning = 'warning',
        }

        lib.notify({
            title = (Config.OxLib and Config.OxLib.NotifyTitle) or L('roadside_dispatch_title'),
            description = tostring(message),
            type = oxTypes[selectedType] or 'inform',
            duration = selectedDuration,
            position = (Config.OxLib and Config.OxLib.NotifyPosition) or 'top-right',
            showDuration = not Config.OxLib or Config.OxLib.NotifyShowDuration ~= false,
        })
        return
    end

    if NotifySystem == 'custom' then
        TriggerEvent(Config.CustomNotifyEvent, message, selectedType, selectedDuration)
        return
    end

    if NotifySystem == 'framework' then
        if Framework.name == 'qb' and QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify(message, selectedType, selectedDuration)
            return
        end

        if Framework.name == 'esx' and ESX and ESX.ShowNotification then
            ESX.ShowNotification(message)
            return
        end
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message))
    EndTextCommandThefeedPostTicker(false, false)
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function ensureVehicleNetId(vehicle)
    if not DoesEntityExist(vehicle) then return 0 end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId ~= 0 then return netId end

    NetworkRegisterEntityAsNetworked(vehicle)
    local started = GetGameTimer()
    while NetworkGetNetworkIdFromEntity(vehicle) == 0 and GetGameTimer() - started < 3000 do
        Wait(50)
    end

    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function vectorLength(value)
    if not value then return 0.0 end
    local x = tonumber(value.x) or 0.0
    local y = tonumber(value.y) or 0.0
    local z = tonumber(value.z) or 0.0
    return math.sqrt((x * x) + (y * y) + (z * z))
end

local function getVehicleVisualDamagePercent(vehicle)
    if not DoesEntityExist(vehicle) then return 0.0 end

    local minDimensions, maxDimensions = GetModelDimensions(GetEntityModel(vehicle))
    local halfWidth = math.max(0.6, math.max(math.abs(minDimensions.x), math.abs(maxDimensions.x)))
    local front = math.max(1.0, maxDimensions.y)
    local rear = math.min(-1.0, minDimensions.y)
    local height = math.max(0.35, maxDimensions.z * 0.45)

    local samples = {
        vector3(0.0, front * 0.90, height),
        vector3(-halfWidth * 0.72, front * 0.72, height),
        vector3(halfWidth * 0.72, front * 0.72, height),
        vector3(-halfWidth * 0.85, 0.0, height),
        vector3(halfWidth * 0.85, 0.0, height),
        vector3(0.0, rear * 0.90, height),
        vector3(-halfWidth * 0.72, rear * 0.72, height),
        vector3(halfWidth * 0.72, rear * 0.72, height),
    }

    local maximumDeformation = 0.0
    local totalDeformation = 0.0
    for _, sample in ipairs(samples) do
        local deformation = GetVehicleDeformationAtPos(vehicle, sample.x, sample.y, sample.z)
        local magnitude = vectorLength(deformation)
        maximumDeformation = math.max(maximumDeformation, magnitude)
        totalDeformation = totalDeformation + magnitude
    end

    local averageDeformation = totalDeformation / #samples
    local deformationPercent = clamp((maximumDeformation * 46.0) + (averageDeformation * 26.0), 0.0, 100.0)

    local brokenWindows = 0
    for window = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, window) then
            brokenWindows = brokenWindows + 1
        end
    end

    local damagedDoors = 0
    for door = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, door) then
            damagedDoors = damagedDoors + 1
        end
    end

    local burstTyres = 0
    for tyre = 0, 7 do
        if IsVehicleTyreBurst(vehicle, tyre, false) then
            burstTyres = burstTyres + 1
        end
    end

    local partsPercent = clamp((brokenWindows * 5.0) + (damagedDoors * 8.0) + (burstTyres * 9.0), 0.0, 100.0)
    local visualDamage = math.max(deformationPercent, partsPercent)


    if IsVehicleDamaged(vehicle) then
        visualDamage = math.max(visualDamage, 12.0)
    end

    if not IsVehicleDriveable(vehicle, false) then
        visualDamage = math.max(visualDamage, 65.0)
    end

    return clamp(visualDamage, 0.0, 100.0)
end

local function getVehicleHealthData(vehicle)
    return {
        engine = clamp(GetVehicleEngineHealth(vehicle), 0.0, 1000.0),
        body = clamp(GetVehicleBodyHealth(vehicle), 0.0, 1000.0),
        tank = clamp(GetVehiclePetrolTankHealth(vehicle), 0.0, 1000.0),
        visualDamage = getVehicleVisualDamagePercent(vehicle),
    }
end

local function calculateLocalDamagePercent(health)
    local average = (health.engine + health.body + health.tank) / 3.0
    local healthDamage = clamp((1.0 - average / 1000.0) * 100.0, 0.0, 100.0)
    return math.max(healthDamage, clamp(tonumber(health.visualDamage) or 0.0, 0.0, 100.0))
end

local function requestControl(entity, timeout)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    local started = GetGameTimer()
    NetworkRequestControlOfEntity(entity)

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() - started < (timeout or 5000) do
        NetworkRequestControlOfEntity(entity)
        Wait(100)
    end

    return NetworkHasControlOfEntity(entity)
end


local function safeDeleteEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    requestControl(entity, 1500)
    SetEntityAsMissionEntity(entity, true, true)

    local entityType = GetEntityType(entity)
    local deleted = pcall(function()
        if entityType == 2 then
            DeleteVehicle(entity)
        elseif entityType == 1 then
            DeletePed(entity)
        elseif entityType == 3 then
            DeleteObject(entity)
        else
            DeleteEntity(entity)
        end
    end)

    if not deleted or DoesEntityExist(entity) then
        SetEntityCollision(entity, false, false)
        SetEntityVisible(entity, false, false)
        FreezeEntityPosition(entity, false)
        local coords = GetEntityCoords(entity)
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z - 100.0, false, false, false)
    end
end

local function requestModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local started = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - started < (timeout or 10000) do
        Wait(50)
    end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function requestAnimDictionary(dict, timeout)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local started = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - started < (timeout or 5000) do
        Wait(50)
    end

    return HasAnimDictLoaded(dict)
end

local function headingToward(fromCoords, toCoords)
    return GetHeadingFromVector_2d(toCoords.x - fromCoords.x, toCoords.y - fromCoords.y)
end

local function getGroundZAtCoord(x, y, referenceZ)
    referenceZ = tonumber(referenceZ) or 0.0
    RequestCollisionAtCoord(x, y, referenceZ)

    local probeHeights = {
        referenceZ + 2.0,
        referenceZ + 10.0,
        referenceZ + 25.0,
        referenceZ + 50.0,
        referenceZ + 100.0,
    }

    for attempt = 1, 3 do
        for _, probeZ in ipairs(probeHeights) do
            local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)
            if foundGround then
                return tonumber(groundZ)
            end
        end
        Wait(0)
    end

    return nil
end

local function getFloorZFromVehicle(vehicle, coords)
    local vehicleCoords = GetEntityCoords(vehicle)
    local heightAboveGround = math.max(0.0, tonumber(GetEntityHeightAboveGround(vehicle)) or 0.0)
    local vehicleFloorZ = vehicleCoords.z - heightAboveGround
    local referenceZ = math.max(tonumber(coords.z) or vehicleCoords.z, vehicleCoords.z)
    local groundZ = getGroundZAtCoord(coords.x, coords.y, referenceZ)


    if groundZ and math.abs(groundZ - vehicleFloorZ) <= 4.0 then
        return vector3(coords.x, coords.y, groundZ)
    end

    return vector3(coords.x, coords.y, vehicleFloorZ)
end

local function placePedSafelyOnGround(ped, vehicle, heading)
    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return nil end

    local currentCoords = GetEntityCoords(ped)
    local surfaceCoords = getFloorZFromVehicle(vehicle, currentCoords)
    local cfg = Config.Roadside or {}
    local minimumRootHeight = tonumber(cfg.PedGroundMinimumRootHeight) or 0.35
    local maximumRootHeight = tonumber(cfg.PedGroundMaximumRootHeight) or 2.25
    local rootHeight = currentCoords.z - surfaceCoords.z

    RequestCollisionAtCoord(surfaceCoords.x, surfaceCoords.y, surfaceCoords.z)
    FreezeEntityPosition(ped, false)


    if rootHeight < minimumRootHeight or rootHeight > maximumRootHeight then
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityCoords(
            ped,
            currentCoords.x, currentCoords.y, surfaceCoords.z,
            false, false, false, false
        )
        Wait(100)
    end

    if heading then
        SetEntityHeading(ped, heading)
    end

    return GetEntityCoords(ped)
end

local function horizontalDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt((dx * dx) + (dy * dy))
end

local function ignoreNearbyPedCollisions(mechanic)
    if not DoesEntityExist(mechanic) then return end

    local playerPed = PlayerPedId()
    local mechanicCoords = GetEntityCoords(mechanic)

    for _, otherPed in ipairs(GetGamePool('CPed')) do
        if otherPed ~= mechanic and otherPed ~= playerPed and DoesEntityExist(otherPed) then
            if #(GetEntityCoords(otherPed) - mechanicCoords) <= 20.0 then
                SetEntityNoCollisionEntity(mechanic, otherPed, false)
            end
        end
    end
end


local function walkStraightTo(ped, destination, finalHeading, timeout, speed, stopRange, fallbackRange)
    if not DoesEntityExist(ped) then return false end

    timeout = timeout or 45000
    speed = speed or 1.0
    stopRange = stopRange or 0.8
    fallbackRange = fallbackRange or math.max(stopRange + 0.9, 1.8)

    local function issueTask()
        if not DoesEntityExist(ped) then return end

        ClearPedTasks(ped)
        SetPedKeepTask(ped, true)
        SetPedDesiredMoveBlendRatio(ped, speed)
        TaskGoStraightToCoord(
            ped,
            destination.x, destination.y, destination.z,
            speed,
            -1,
            finalHeading,
            Config.WalkHeadingTolerance or 0.2
        )
    end

    ClearPedTasksImmediately(ped)
    issueTask()

    local started = GetGameTimer()
    local lastProgress = started
    local bestDistance = horizontalDistance(GetEntityCoords(ped), destination)

    while DoesEntityExist(ped) and GetGameTimer() - started < timeout do
        local pedCoords = GetEntityCoords(ped)
        local distance = horizontalDistance(pedCoords, destination)

        if distance <= stopRange then
            ClearPedTasks(ped)
            SetEntityHeading(ped, finalHeading)
            return true
        end

        local now = GetGameTimer()
        if distance < bestDistance - 0.06 then
            bestDistance = distance
            lastProgress = now
        end

 
        if now - lastProgress >= (Config.StuckReissueTime or 3500) then
            issueTask()
            lastProgress = now
            bestDistance = distance
        end

        Wait(100)
    end

    ClearPedTasks(ped)

    local finalDistance = horizontalDistance(GetEntityCoords(ped), destination)
    if finalDistance <= fallbackRange then
        SetEntityHeading(ped, finalHeading)
        return true
    end

    return false
end

local function getBonnetRoute(vehicle, ped, sideOffsetOverride)
    local model = GetEntityModel(vehicle)
    local minDimensions, maxDimensions = GetModelDimensions(model)
    local cfg = Config.Roadside or {}


    local frontClearance = tonumber(cfg.BonnetFrontClearance) or 0.55
    local frontDistance = math.max(1.4, (tonumber(maxDimensions.y) or 1.8) + frontClearance)
    local workCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, frontDistance, 0.0)
    workCoords = getFloorZFromVehicle(vehicle, workCoords)


    local lookDistance = math.max(0.65, (tonumber(maxDimensions.y) or 1.8) * 0.45)
    local bonnetCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, lookDistance, 0.0)
    local workHeading = headingToward(workCoords, bonnetCoords)

    return {
        work = workCoords,
        workHeading = workHeading,
        sideSign = 1.0,
        frontDistance = frontDistance,
    }
end

local function startMechanicRepairAnimation(ped, workCoords, workHeading)
    local dict = Config.RepairAnimationDict or 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
    local name = Config.RepairAnimationName or 'machinic_loop_mechandplayer'

    SetEntityHeading(ped, workHeading)
    ClearPedTasksImmediately(ped)


    if requestAnimDictionary(dict, 5000) then
        TaskPlayAnim(
            ped,
            dict,
            name,
            Config.RepairAnimationBlendIn or 3.0,
            Config.RepairAnimationBlendOut or -3.0,
            -1,
            Config.RepairAnimationFlag or 1,
            0.0,
            false, false, false
        )
        SetPedKeepTask(ped, true)
        Wait(300)

        if IsEntityPlayingAnim(ped, dict, name, 3) then
            return dict, name
        end
    end


    TaskStartScenarioInPlace(ped, Config.RepairScenario or 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)
    SetPedKeepTask(ped, true)
    return nil, nil
end

local function getVehicleDisplayName(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(displayName)

    if not label or label == 'NULL' then
        label = displayName
    end

    local plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s*(.-)%s*$', '%1')
    return ('%s | %s: %s'):format(label, L('plate'), plate)
end

local function createToolbox(coords, heading)
    if not Config.UseToolboxProp then return nil end

    local model = requestModel(Config.ToolboxModel, 5000)
    if not model then return nil end

    local toolbox = CreateObject(model, coords.x, coords.y, coords.z + 0.15, false, false, false)
    SetEntityHeading(toolbox, heading)
    PlaceObjectOnGroundProperly(toolbox)
    FreezeEntityPosition(toolbox, true)
    SetModelAsNoLongerNeeded(model)
    return toolbox
end


local function deleteRoadsideEntity(entity, isVehicle)
    safeDeleteEntity(entity)
end

local function removeRoadsideBlip()
    if RoadsideState.blip ~= 0 and DoesBlipExist(RoadsideState.blip) then
        RemoveBlip(RoadsideState.blip)
    end
    RoadsideState.blip = 0
end

local function cleanupRoadsideService()
    removeRoadsideBlip()

    if RoadsideState.toolbox ~= 0 then
        deleteRoadsideEntity(RoadsideState.toolbox, false)
    end

    if RoadsideState.mechanic ~= 0 then
        deleteRoadsideEntity(RoadsideState.mechanic, false)
    end

    if RoadsideState.truck ~= 0 then
        deleteRoadsideEntity(RoadsideState.truck, true)
    end

    RoadsideState.active = false
    RoadsideState.serverPending = false
    RoadsideState.completed = false
    RoadsideState.vehicleNetId = 0
    RoadsideState.targetVehicle = 0
    RoadsideState.mechanic = 0
    RoadsideState.truck = 0
    RoadsideState.toolbox = 0
    ServiceInProgress = false
end

local function cancelRoadsideService()
    local shouldNotify = RoadsideState.active

    if RoadsideState.serverPending then
        RoadsideState.serverPending = false
        TriggerServerEvent('apex-npcmechanic:server:cancelRoadsideService')
    end

    cleanupRoadsideService()

    if shouldNotify then
        notify(L('roadside_failed'), 'error', 6000)
    end
end

local function getClosestRoadsideVehicle()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local radius = (Config.Roadside and Config.Roadside.VehicleSearchRadius) or 15.0

    local currentVehicle = GetVehiclePedIsIn(playerPed, false)
    if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
        return currentVehicle
    end

    local lastVehicle = GetVehiclePedIsIn(playerPed, true)
    if lastVehicle ~= 0 and DoesEntityExist(lastVehicle) then
        if #(GetEntityCoords(lastVehicle) - playerCoords) <= radius then
            return lastVehicle
        end
    end

    local closestVehicle = 0
    local closestDistance = radius + 0.01

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local distance = #(GetEntityCoords(vehicle) - playerCoords)
            if distance < closestDistance then
                closestDistance = distance
                closestVehicle = vehicle
            end
        end
    end

    return closestVehicle
end

local function getRoadNode(coords)
    local found, nodeCoords, nodeHeading = GetClosestVehicleNodeWithHeading(
        coords.x, coords.y, coords.z,
        1,
        3.0,
        0
    )

    if found and nodeCoords then
        return true, vector3(nodeCoords.x, nodeCoords.y, nodeCoords.z), nodeHeading or 0.0
    end

    return false, coords, 0.0
end

local function getRoadsideSpawnAndParking(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    local cfg = Config.Roadside
    local vehicleCoords = GetEntityCoords(vehicle)
    local spawnDistance = cfg.SpawnDistance or 75.0
    local minimumDistance = cfg.MinimumSpawnDistance or 40.0
    local spawnCoords

 
    for _, multiplier in ipairs({ 1.0, 1.35, 1.7 }) do
        local probe = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, spawnDistance * multiplier, 0.0)
        local found, node = getRoadNode(probe)

        if found and horizontalDistance(node, vehicleCoords) >= minimumDistance
            and not IsAnyVehicleNearPoint(node.x, node.y, node.z, 5.0) then
            spawnCoords = node
            break
        end
    end

    if not spawnCoords then
        local probe = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, spawnDistance, 0.0)
        local found, node = getRoadNode(probe)
        if not found or horizontalDistance(node, vehicleCoords) < minimumDistance then
            return nil
        end
        spawnCoords = node
    end

    local parkingProbe = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, cfg.ParkingDistance or 14.0, 0.0)
    local parkingFound, parkingCoords = getRoadNode(parkingProbe)

    if not parkingFound or horizontalDistance(parkingCoords, vehicleCoords) > 32.0 then
        parkingCoords = getFloorZFromVehicle(vehicle, parkingProbe)
    end

    local spawnHeading = headingToward(spawnCoords, parkingCoords)
    local leaveProbe = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, cfg.LeaveDistance or 120.0, 0.0)
    local leaveFound, leaveCoords = getRoadNode(leaveProbe)
    if not leaveFound then leaveCoords = leaveProbe end

    return {
        spawn = spawnCoords,
        spawnHeading = spawnHeading,
        parking = parkingCoords,
        leave = leaveCoords,
    }
end

local function configureRoadsidePed(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanEvasiveDive(ped, false)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.05)
    SetPedKeepTask(ped, true)
end

local function spawnRoadsideMechanic(route)
    local cfg = Config.Roadside
    local truckModel = requestModel(cfg.TowTruckModel or 'flatbed', 10000)
    local pedModel = requestModel(cfg.PedModel or 'mp_m_waremech_01', 10000)

    if not truckModel or not pedModel then
        if truckModel then SetModelAsNoLongerNeeded(truckModel) end
        if pedModel then SetModelAsNoLongerNeeded(pedModel) end
        return false
    end

    local truck = CreateVehicle(
        truckModel,
        route.spawn.x, route.spawn.y, route.spawn.z + 0.25,
        route.spawnHeading,
        true,
        true
    )

    if not DoesEntityExist(truck) then
        SetModelAsNoLongerNeeded(truckModel)
        SetModelAsNoLongerNeeded(pedModel)
        return false
    end

    SetEntityAsMissionEntity(truck, true, true)
    SetVehicleOnGroundProperly(truck)
    SetVehicleEngineOn(truck, true, true, false)
    SetVehicleDoorsLocked(truck, 1)
    SetVehicleNumberPlateText(truck, 'APEX MEC')

    local mechanic = CreatePedInsideVehicle(truck, 4, pedModel, -1, true, true)
    if not DoesEntityExist(mechanic) then
        deleteRoadsideEntity(truck, true)
        SetModelAsNoLongerNeeded(truckModel)
        SetModelAsNoLongerNeeded(pedModel)
        return false
    end

    configureRoadsidePed(mechanic)

    local truckNetId = NetworkGetNetworkIdFromEntity(truck)
    if truckNetId ~= 0 then
        SetNetworkIdCanMigrate(truckNetId, true)
    end

    local pedNetId = NetworkGetNetworkIdFromEntity(mechanic)
    if pedNetId ~= 0 then
        SetNetworkIdCanMigrate(pedNetId, true)
    end

    RoadsideState.truck = truck
    RoadsideState.mechanic = mechanic

    if cfg.ShowBlip then
        local blip = AddBlipForEntity(truck)
        SetBlipSprite(blip, cfg.BlipSprite or 446)
        SetBlipColour(blip, cfg.BlipColour or 3)
        SetBlipScale(blip, cfg.BlipScale or 0.75)
        SetBlipRoute(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(L('roadside_truck_blip'))
        EndTextCommandSetBlipName(blip)
        RoadsideState.blip = blip
    end

    SetModelAsNoLongerNeeded(truckModel)
    SetModelAsNoLongerNeeded(pedModel)
    return true
end

local function driveRoadsideTruck(route, targetVehicle)
    local cfg = Config.Roadside
    local truck = RoadsideState.truck
    local mechanic = RoadsideState.mechanic
    if not DoesEntityExist(truck) or not DoesEntityExist(mechanic) then return false end

    local function issueDriveTask()
        if not DoesEntityExist(truck) or not DoesEntityExist(mechanic) then return end
        SetVehicleHandbrake(truck, false)
        SetVehicleEngineOn(truck, true, true, false)
        TaskVehicleDriveToCoordLongrange(
            mechanic,
            truck,
            route.parking.x, route.parking.y, route.parking.z,
            cfg.DriveSpeed or 16.0,
            cfg.DrivingStyle or 786603,
            8.0
        )
        SetPedKeepTask(mechanic, true)
    end

    issueDriveTask()
    local started = GetGameTimer()
    local lastProgress = started
    local bestDistance = horizontalDistance(GetEntityCoords(truck), route.parking)

    while RoadsideState.active and DoesEntityExist(truck) and DoesEntityExist(targetVehicle)
        and GetGameTimer() - started < (cfg.DriveTimeout or 90000) do
        local truckCoords = GetEntityCoords(truck)
        local distanceToParking = horizontalDistance(truckCoords, route.parking)
        local distanceToTarget = horizontalDistance(truckCoords, GetEntityCoords(targetVehicle))

        if distanceToParking <= (cfg.ArrivalDistance or 18.0)
            or distanceToTarget <= (cfg.ArrivalDistance or 18.0) + 5.0 then
            TaskVehicleTempAction(mechanic, truck, 27, 1800)
            Wait(1200)
            SetVehicleHandbrake(truck, true)
            return true
        end

        local now = GetGameTimer()
        if distanceToParking < bestDistance - 1.0 then
            bestDistance = distanceToParking
            lastProgress = now
        elseif now - lastProgress >= (cfg.DriveStuckReissueTime or 9000) then

            issueDriveTask()
            lastProgress = now
            bestDistance = distanceToParking
        end

        Wait(250)
    end

    return false
end


local function getTruckDriverClearPoint(truck)
    local cfg = Config.Roadside or {}
    local model = GetEntityModel(truck)
    local minDimensions, maxDimensions = GetModelDimensions(model)
    local halfWidth = math.max(math.abs(minDimensions.x), math.abs(maxDimensions.x))
    local sideDistance = halfWidth + (cfg.ExitSideClearance or 1.15)
    local forwardOffset = cfg.ExitForwardOffset or 0.65
    local point = GetOffsetFromEntityInWorldCoords(truck, -sideDistance, forwardOffset, 0.0)
    return getFloorZFromVehicle(truck, point)
end

local function goPedToCoordAnyMeans(ped, destination, timeout, stopRange, speed, heading)
    if not DoesEntityExist(ped) then return false end

    timeout = timeout or 30000
    stopRange = stopRange or 1.0
    speed = speed or 1.0
    heading = heading or headingToward(GetEntityCoords(ped), destination)

    local function issueTask()
        if not DoesEntityExist(ped) then return end
        ClearPedTasks(ped)
        SetPedKeepTask(ped, true)
        TaskGoToCoordAnyMeans(
            ped,
            destination.x, destination.y, destination.z,
            speed,
            0,
            false,
            786603,
            0.0
        )
    end

    issueTask()
    local started = GetGameTimer()
    local lastProgress = started
    local bestDistance = horizontalDistance(GetEntityCoords(ped), destination)

    while RoadsideState.active and DoesEntityExist(ped) and GetGameTimer() - started < timeout do
        local pedCoords = GetEntityCoords(ped)
        local distance = horizontalDistance(pedCoords, destination)

        if distance <= stopRange then
            ClearPedTasks(ped)
            SetEntityHeading(ped, heading)
            return true
        end

        local now = GetGameTimer()
        if distance < bestDistance - 0.08 then
            bestDistance = distance
            lastProgress = now
        elseif now - lastProgress >= ((Config.Roadside and Config.Roadside.DriveStuckReissueTime) or 9000) then
            issueTask()
            bestDistance = distance
            lastProgress = now
        end

        Wait(200)
    end

    ClearPedTasks(ped)
    local finalDistance = horizontalDistance(GetEntityCoords(ped), destination)
    if finalDistance <= math.max(stopRange + 0.8, 1.8) then
        SetEntityHeading(ped, heading)
        return true
    end

    return false
end

local function makeRoadsideMechanicExitTruck()
    local cfg = Config.Roadside or {}
    local mechanic = RoadsideState.mechanic
    local truck = RoadsideState.truck
    if not DoesEntityExist(mechanic) or not DoesEntityExist(truck) then return false end

    requestControl(truck, 2500)
    requestControl(mechanic, 2500)

    SetVehicleHandbrake(truck, true)
    SetVehicleEngineOn(truck, false, true, true)
    SetVehicleDoorsLocked(truck, 1)

    ClearPedTasks(mechanic)
    TaskLeaveVehicle(mechanic, truck, 0)

    local started = GetGameTimer()
    while RoadsideState.active and IsPedInVehicle(mechanic, truck, false)
        and GetGameTimer() - started < (cfg.ExitVehicleTimeout or 12000) do
        Wait(100)
    end

    if IsPedInVehicle(mechanic, truck, false) then
        TaskLeaveVehicle(mechanic, truck, 16)
        started = GetGameTimer()
        while RoadsideState.active and IsPedInVehicle(mechanic, truck, false)
            and GetGameTimer() - started < 2500 do
            Wait(100)
        end
    end

    if IsPedInVehicle(mechanic, truck, false) then return false end

    Wait(500)

    local clearPoint = getTruckDriverClearPoint(truck)

    SetEntityNoCollisionEntity(mechanic, truck, true)
    SetEntityNoCollisionEntity(truck, mechanic, true)
    local reached = goPedToCoordAnyMeans(
        mechanic,
        clearPoint,
        cfg.ExitClearTimeout or 9000,
        1.0,
        cfg.ExitWalkSpeed or 1.0,
        headingToward(clearPoint, GetEntityCoords(truck))
    )
    SetEntityNoCollisionEntity(mechanic, truck, false)
    SetEntityNoCollisionEntity(truck, mechanic, false)

    return reached
end

local function waitForPlayerToExitTarget(vehicle)
    local playerPed = PlayerPedId()
    if not IsPedInVehicle(playerPed, vehicle, false) then return true end

    notify(L('roadside_leave_vehicle'), 'primary', 5000)
    local started = GetGameTimer()
    while RoadsideState.active and IsPedInVehicle(playerPed, vehicle, false)
        and GetGameTimer() - started < ((Config.Roadside and Config.Roadside.PlayerExitTimeout) or 20000) do
        Wait(200)
    end

    return not IsPedInVehicle(playerPed, vehicle, false)
end

local function getTruckAvoidanceWaypoints(truck, startCoords, targetCoords)

    return { targetCoords }
end

local function walkRoadsideMechanicToBonnet(mechanic, vehicle, bonnetRoute)
    local cfg = Config.Roadside or {}
    if not DoesEntityExist(mechanic) or not DoesEntityExist(vehicle) then return false end

    local target = bonnetRoute.work
    local heading = bonnetRoute.workHeading
    local approachRange = tonumber(cfg.BonnetApproachRange) or 2.2
    local stoppingRange = tonumber(cfg.BonnetStoppingRange) or 0.65
    local fallbackRange = tonumber(cfg.BonnetFallbackRange) or 1.15
    local walkTimeout = tonumber(cfg.WalkTimeout) or 30000

    SetEntityNoCollisionEntity(mechanic, vehicle, true)
    SetEntityNoCollisionEntity(vehicle, mechanic, true)


    ClearPedTasks(mechanic)
    TaskGoToCoordAnyMeans(
        mechanic,
        target.x, target.y, target.z,
        Config.WalkSpeed or 1.0,
        0,
        false,
        786603,
        0.0
    )
    SetPedKeepTask(mechanic, true)

    local started = GetGameTimer()
    while RoadsideState.active and DoesEntityExist(mechanic) and DoesEntityExist(vehicle)
        and GetGameTimer() - started < walkTimeout do
        if horizontalDistance(GetEntityCoords(mechanic), target) <= approachRange then
            break
        end
        Wait(150)
    end

    if not RoadsideState.active or not DoesEntityExist(mechanic) or not DoesEntityExist(vehicle) then
        SetEntityNoCollisionEntity(mechanic, vehicle, false)
        SetEntityNoCollisionEntity(vehicle, mechanic, false)
        return false
    end


    ClearPedTasks(mechanic)
    TaskGoStraightToCoord(
        mechanic,
        target.x, target.y, target.z,
        tonumber(cfg.FinalApproachSpeed) or 0.65,
        -1,
        heading,
        Config.WalkHeadingTolerance or 0.2
    )
    SetPedKeepTask(mechanic, true)

    local finalStarted = GetGameTimer()
    local finalTimeout = tonumber(cfg.FinalApproachTimeout) or 12000
    local reached = false

    while RoadsideState.active and DoesEntityExist(mechanic) and DoesEntityExist(vehicle)
        and GetGameTimer() - finalStarted < finalTimeout do
        local distance = horizontalDistance(GetEntityCoords(mechanic), target)
        if distance <= stoppingRange then
            reached = true
            break
        end
        Wait(100)
    end

    local finalDistance = horizontalDistance(GetEntityCoords(mechanic), target)
    if not reached and finalDistance <= fallbackRange then
        reached = true
    end

    ClearPedTasks(mechanic)

    if reached then
        placePedSafelyOnGround(mechanic, vehicle, heading)
    end

    SetEntityNoCollisionEntity(mechanic, vehicle, false)
    SetEntityNoCollisionEntity(vehicle, mechanic, false)

    return reached
end

local function fullyRepairVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    requestControl(vehicle, 3000)

    local success, repairError = pcall(function()
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, false, true, true)

        if Config.FixBurstTyres then
            for tyre = 0, 7 do
                SetVehicleTyreFixed(vehicle, tyre)
            end
        end

        if Config.CleanVehicleAfterRepair then
            SetVehicleDirtLevel(vehicle, 0.0)
            WashDecalsFromVehicle(vehicle, 1.0)
        end
    end)

    if not success then
        print(('[apex-npcmechanic] Vehicle repair failed: %s'):format(tostring(repairError)))
        return false
    end

    return true
end

local function repairVehicleAtRoadside(vehicle)
    local cfg = Config.Roadside or {}
    local mechanic = RoadsideState.mechanic
    if not DoesEntityExist(vehicle) or not DoesEntityExist(mechanic) then return false end

    notify(L('roadside_arrived'), 'primary', 4000)
    ignoreNearbyPedCollisions(mechanic)

    local route = getBonnetRoute(vehicle, mechanic, cfg.BonnetSideOffset or 0.0)
    local reachedBonnet = walkRoadsideMechanicToBonnet(mechanic, vehicle, route)
    if not reachedBonnet or not RoadsideState.active then return false end


    requestControl(mechanic, 1500)
    SetEntityNoCollisionEntity(mechanic, vehicle, true)
    SetEntityNoCollisionEntity(vehicle, mechanic, true)


    local groundedCoords = placePedSafelyOnGround(mechanic, vehicle, route.workHeading)
    if groundedCoords then
        route.work = groundedCoords
    end

    SetEntityNoCollisionEntity(mechanic, vehicle, false)
    SetEntityNoCollisionEntity(vehicle, mechanic, false)

    TaskTurnPedToFaceEntity(mechanic, vehicle, 350)
    Wait(350)
    groundedCoords = placePedSafelyOnGround(mechanic, vehicle, route.workHeading)
    if groundedCoords then
        route.work = groundedCoords
    end

    FreezeEntityPosition(mechanic, true)

    if cfg.FreezeVehicleDuringRepair then
        requestControl(vehicle, 3000)
        FreezeEntityPosition(vehicle, true)
    end

    SetVehicleEngineOn(vehicle, false, true, true)

    if cfg.OpenBonnet then
        SetVehicleDoorOpen(vehicle, 4, false, false)
        Wait(700)
    end

    local toolboxCoords = GetOffsetFromEntityInWorldCoords(
        vehicle,
        route.sideSign * (Config.ToolboxSideOffset or 1.15),
        route.frontDistance + (Config.ToolboxFrontOffset or 0.25),
        0.0
    )
    toolboxCoords = getFloorZFromVehicle(vehicle, toolboxCoords)

    if cfg.UseToolboxProp then
        RoadsideState.toolbox = createToolbox(toolboxCoords, GetEntityHeading(vehicle)) or 0
    end

    local repairAnimDict, repairAnimName = startMechanicRepairAnimation(mechanic, route.work, route.workHeading)

    notify(L('roadside_repairing'), 'primary', 4000)
    local repairStarted = GetGameTimer()
    local lastAnimationCheck = repairStarted
    local repairDuration = cfg.RepairDuration or Config.RepairDuration or 15000

    while RoadsideState.active and DoesEntityExist(vehicle) and DoesEntityExist(mechanic)
        and GetGameTimer() - repairStarted < repairDuration do
        if repairAnimDict and repairAnimName
            and GetGameTimer() - lastAnimationCheck >= (Config.RepairAnimationCheckInterval or 1000) then
            lastAnimationCheck = GetGameTimer()
            if not IsEntityPlayingAnim(mechanic, repairAnimDict, repairAnimName, 3) then
                SetEntityHeading(mechanic, route.workHeading)
                TaskPlayAnim(
                    mechanic,
                    repairAnimDict,
                    repairAnimName,
                    Config.RepairAnimationBlendIn or 3.0,
                    Config.RepairAnimationBlendOut or -3.0,
                    -1,
                    Config.RepairAnimationFlag or 1,
                    0.0,
                    false, false, false
                )
            end
        end
        Wait(100)
    end

    if not RoadsideState.active or not DoesEntityExist(vehicle) then
        if DoesEntityExist(mechanic) then
            FreezeEntityPosition(mechanic, false)
            ClearPedTasksImmediately(mechanic)
        end
        if cfg.FreezeVehicleDuringRepair and DoesEntityExist(vehicle) then
            FreezeEntityPosition(vehicle, false)
        end
        return false
    end

    ClearPedTasksImmediately(mechanic)
    FreezeEntityPosition(mechanic, false)
    if repairAnimDict then RemoveAnimDict(repairAnimDict) end

    local repaired = fullyRepairVehicle(vehicle)
    if not repaired then
        if cfg.OpenBonnet then
            SetVehicleDoorShut(vehicle, 4, false)
        end

        if RoadsideState.toolbox ~= 0 then
            deleteRoadsideEntity(RoadsideState.toolbox, false)
            RoadsideState.toolbox = 0
        end

        if cfg.FreezeVehicleDuringRepair then
            FreezeEntityPosition(vehicle, false)
        end

        return false
    end

    if cfg.OpenBonnet then
        SetVehicleDoorShut(vehicle, 4, false)
    end

    if RoadsideState.toolbox ~= 0 then
        deleteRoadsideEntity(RoadsideState.toolbox, false)
        RoadsideState.toolbox = 0
    end

    if cfg.FreezeVehicleDuringRepair then
        FreezeEntityPosition(vehicle, false)
    end

    return true
end

local function getDriverDoorCoords(vehicle)
    return getTruckDriverClearPoint(vehicle)
end

local function sendRoadsideMechanicAway(route)
    local cfg = Config.Roadside or {}
    local mechanic = RoadsideState.mechanic
    local truck = RoadsideState.truck
    if not DoesEntityExist(mechanic) or not DoesEntityExist(truck) then
        cleanupRoadsideService()
        return
    end

    SetVehicleHandbrake(truck, true)
    ClearPedTasksImmediately(mechanic)

    local doorCoords = getDriverDoorCoords(truck)
    local reachedDoor = goPedToCoordAnyMeans(
        mechanic,
        doorCoords,
        cfg.ReturnToTruckTimeout or 35000,
        1.2,
        Config.WalkSpeed or 1.0,
        headingToward(doorCoords, GetEntityCoords(truck))
    )

    if not reachedDoor or not RoadsideState.active then
        cleanupRoadsideService()
        return
    end

    SetVehicleDoorsLocked(truck, 1)
    SetVehicleHandbrake(truck, false)
    TaskEnterVehicle(mechanic, truck, cfg.EnterTruckTimeout or 15000, -1, 1.0, 1, 0)
    local enterStarted = GetGameTimer()

    while RoadsideState.active and not IsPedInVehicle(mechanic, truck, false)
        and GetGameTimer() - enterStarted < (cfg.EnterTruckTimeout or 15000) do
        Wait(100)
    end

    if IsPedInVehicle(mechanic, truck, false) then
        SetVehicleEngineOn(truck, true, true, false)
        TaskVehicleDriveToCoordLongrange(
            mechanic,
            truck,
            route.leave.x, route.leave.y, route.leave.z,
            cfg.DriveSpeed or 16.0,
            cfg.DrivingStyle or 786603,
            8.0
        )

        local leaveStarted = GetGameTimer()
        local playerPed = PlayerPedId()
        while RoadsideState.active and DoesEntityExist(truck)
            and GetGameTimer() - leaveStarted < (cfg.LeaveTimeout or 45000) do
            if #(GetEntityCoords(truck) - GetEntityCoords(playerPed)) >= (cfg.DespawnDistance or 90.0) then
                break
            end
            Wait(500)
        end
    else
        TaskGoToCoordAnyMeans(mechanic, route.leave.x, route.leave.y, route.leave.z, Config.WalkSpeed or 1.0, 0, false, 786603, 0.0)
        local leaveStarted = GetGameTimer()
        local playerPed = PlayerPedId()
        while RoadsideState.active and DoesEntityExist(mechanic)
            and GetGameTimer() - leaveStarted < 20000 do
            if #(GetEntityCoords(mechanic) - GetEntityCoords(playerPed)) >= 45.0 then
                break
            end
            Wait(500)
        end
    end

    cleanupRoadsideService()
end

local function runRoadsideSequence(vehicleNetId, price)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    local waitStarted = GetGameTimer()

    while not DoesEntityExist(vehicle) and GetGameTimer() - waitStarted < 5000 do
        Wait(100)
        vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    end

    if not DoesEntityExist(vehicle) then
        cancelRoadsideService()
        return
    end

    RoadsideState.active = true
    RoadsideState.serverPending = true
    RoadsideState.completed = false
    RoadsideState.vehicleNetId = vehicleNetId
    RoadsideState.targetVehicle = vehicle
    ServiceInProgress = true

    local route = getRoadsideSpawnAndParking(vehicle)
    if not route then
        notify(L('roadside_spawn_failed'), 'error')
        cancelRoadsideService()
        return
    end

    if not spawnRoadsideMechanic(route) then
        notify(L('roadside_spawn_failed'), 'error')
        cancelRoadsideService()
        return
    end

    notify(L('roadside_dispatched'), 'success', 6000)

    if not driveRoadsideTruck(route, vehicle) then
        cancelRoadsideService()
        return
    end

    removeRoadsideBlip()

    if not makeRoadsideMechanicExitTruck() then
        cancelRoadsideService()
        return
    end

    if not waitForPlayerToExitTarget(vehicle) then
        cancelRoadsideService()
        return
    end

    if not repairVehicleAtRoadside(vehicle) then
        cancelRoadsideService()
        return
    end

    if RoadsideState.serverPending then
        RoadsideState.serverPending = false
        RoadsideState.completed = true
        TriggerServerEvent('apex-npcmechanic:server:completeRoadsideService')
    end

    sendRoadsideMechanicAway(route)
end

local function requestRoadsideRepair(vehicle)
    if not Config.Roadside or not Config.Roadside.Enabled then
        notify(L('roadside_command_disabled'), 'error')
        return
    end

    if ServiceInProgress or RoadsideState.active then
        notify(L('roadside_busy'), 'error')
        return
    end

    if not DoesEntityExist(vehicle) then
        notify(L('roadside_no_vehicle'), 'error')
        return
    end

    local health = getVehicleHealthData(vehicle)
    local netId = ensureVehicleNetId(vehicle)
    if netId == 0 then
        notify(L('invalid_request'), 'error')
        return
    end

    TriggerServerEvent('apex-npcmechanic:server:requestRoadsideService', netId, health)
end

local function resolveMenuSystem()
    if not Config.UseConfirmMenu then return 'none' end

    local selected = normalizeSystem(Config.MenuSystem)

    if selected == 'auto' then
        if OxAvailable then return 'ox' end
        if resourceReady(Config.MenuName or 'qb-menu') then return 'qb' end
        return 'none'
    end

    if isOxSystem(selected) then
        return OxAvailable and 'ox' or 'none'
    end

    if selected == 'qb' or selected == 'qb-menu' then
        return resourceReady(Config.MenuName or 'qb-menu') and 'qb' or 'none'
    end

    return 'none'
end

local function showOxConfirmationMenu(vehicle, vehicleNetId, price, damagePercent)
    if not OxAvailable or not lib then return false end

    local description = L(
        'roadside_dispatch_description',
        getVehicleDisplayName(vehicle),
        math.floor((damagePercent or 0) + 0.5),
        math.max(0, math.floor(Config.Roadside.DispatchFee or 0))
    )

    local menuStyle = normalizeSystem(Config.OxLib and Config.OxLib.MenuStyle or 'context')
    local menuId = 'apex_npcmechanic_roadside_confirmation'

    if menuStyle == 'menu' then
        lib.registerMenu({
            id = menuId,
            title = L('roadside_dispatch_title'),
            position = (Config.OxLib and Config.OxLib.MenuPosition) or 'top-right',
            options = {
                {
                    label = L('roadside_dispatch_header', price),
                    description = description,
                    icon = 'truck-pickup',
                    args = { vehicleNetId = vehicleNetId },
                },
                {
                    label = L('cancel'),
                    icon = 'xmark',
                    args = { cancel = true },
                },
            }
        }, function(selected, _, args)
            if selected == 1 and args and args.vehicleNetId then
                TriggerEvent('apex-npcmechanic:client:confirmRoadsideRepair', args)
            end
        end)

        lib.showMenu(menuId)
        return true
    end

    lib.registerContext({
        id = menuId,
        title = L('roadside_dispatch_title'),
        canClose = true,
        options = {
            {
                title = L('roadside_dispatch_header', price),
                description = description .. ('  \n%s'):format(L('roadside_confirm')),
                icon = 'truck-pickup',
                event = 'apex-npcmechanic:client:confirmRoadsideRepair',
                args = { vehicleNetId = vehicleNetId },
            },
            {
                title = L('cancel'),
                icon = 'xmark',
                event = 'apex-npcmechanic:client:closeOxConfirmation',
            },
        }
    })

    lib.showContext(menuId)
    return true
end

local function showQbConfirmationMenu(vehicle, vehicleNetId, price, damagePercent)
    local menuName = Config.MenuName or 'qb-menu'
    if not resourceReady(menuName) then return false end

    exports[menuName]:openMenu({
        {
            header = L('roadside_dispatch_title'),
            txt = L(
                'roadside_dispatch_description',
                getVehicleDisplayName(vehicle),
                math.floor((damagePercent or 0) + 0.5),
                math.max(0, math.floor(Config.Roadside.DispatchFee or 0))
            ),
            isMenuHeader = true,
        },
        {
            header = L('roadside_dispatch_header', price),
            txt = L('roadside_confirm'),
            icon = 'fas fa-truck-pickup',
            params = {
                event = 'apex-npcmechanic:client:confirmRoadsideRepair',
                args = { vehicleNetId = vehicleNetId }
            }
        },
        {
            header = L('cancel'),
            icon = 'fas fa-times',
            params = { event = 'qb-menu:closeMenu' }
        }
    })

    return true
end

local function showConfirmationMenu(vehicle, vehicleNetId, price, damagePercent)
    local menuSystem = resolveMenuSystem()

    if menuSystem == 'ox' then
        return showOxConfirmationMenu(vehicle, vehicleNetId, price, damagePercent)
    end

    if menuSystem == 'qb' then
        return showQbConfirmationMenu(vehicle, vehicleNetId, price, damagePercent)
    end

    return false
end

local function openRoadsideConfirmation()
    if not Config.Roadside or not Config.Roadside.Enabled then
        notify(L('roadside_command_disabled'), 'error')
        return
    end

    if ServiceInProgress or RoadsideState.active then
        notify(L('roadside_busy'), 'error')
        return
    end

    local vehicle = getClosestRoadsideVehicle()
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(L('roadside_no_vehicle'), 'error')
        return
    end

    local health = getVehicleHealthData(vehicle)
    local damagePercent = calculateLocalDamagePercent(health)
    if not Config.RepairHealthyVehicles and damagePercent < Config.MinimumDamagePercent then
        notify(L('vehicle_too_healthy'), 'error')
        return
    end

    local netId = ensureVehicleNetId(vehicle)
    if netId == 0 then
        notify(L('invalid_request'), 'error')
        return
    end

    triggerFrameworkCallback('apex-npcmechanic:server:getRoadsideQuote', function(success, price, verifiedDamage, reason, remaining)
        if not success then
            local messages = {
                disabled = L('roadside_command_disabled'),
                busy = L('roadside_busy'),
                global_busy = L('roadside_global_busy'),
                cooldown = L('roadside_cooldown', tonumber(remaining) or 0),
                invalid = L('invalid_request'),
            }
            notify(messages[reason] or L('invalid_request'), 'error')
            return
        end

        if not showConfirmationMenu(vehicle, netId, price, verifiedDamage or damagePercent) then
            requestRoadsideRepair(vehicle)
        end
    end, netId, health)
end

RegisterCommand((Config.Roadside and Config.Roadside.Command) or 'npcmechanic', function()
    openRoadsideConfirmation()
end, false)

RegisterNetEvent('apex-npcmechanic:client:closeOxConfirmation', function()
end)

RegisterNetEvent('apex-npcmechanic:client:confirmRoadsideRepair', function(data)
    if not data or not data.vehicleNetId then return end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(data.vehicleNetId))
    if not DoesEntityExist(vehicle) then
        notify(L('roadside_no_vehicle'), 'error')
        return
    end

    requestRoadsideRepair(vehicle)
end)

RegisterNetEvent('apex-npcmechanic:client:startRoadsideService', function(vehicleNetId, price)
    if RoadsideState.active or ServiceInProgress then
        TriggerServerEvent('apex-npcmechanic:server:cancelRoadsideService')
        return
    end

    RoadsideState.active = true
    RoadsideState.serverPending = true
    ServiceInProgress = true

    CreateThread(function()
        runRoadsideSequence(tonumber(vehicleNetId), tonumber(price) or 0)
    end)
end)

RegisterNetEvent('apex-npcmechanic:client:roadsideRejected', function(reason, remaining)
    local messages = {
        disabled = L('roadside_command_disabled'),
        busy = L('roadside_busy'),
        global_busy = L('roadside_global_busy'),
        cooldown = L('roadside_cooldown', tonumber(remaining) or 0),
        money = L('insufficient_money'),
        healthy = L('vehicle_too_healthy'),
        invalid = L('invalid_request'),
    }

    notify(messages[reason] or L('invalid_request'), 'error')
end)

RegisterNetEvent('apex-npcmechanic:client:roadsideServiceComplete', function(price)
    RoadsideState.completed = true
    RoadsideState.serverPending = false
    notify(L('roadside_complete', tonumber(price) or 0), 'success', 6000)
end)

RegisterNetEvent('apex-npcmechanic:client:roadsideServiceCancelled', function()
    local wasActive = RoadsideState.active
    cleanupRoadsideService()
    if wasActive then
        notify(L('roadside_failed'), 'error', 6000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanupRoadsideService()
end)
