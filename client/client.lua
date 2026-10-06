local RSGCore = exports['rsg-core']:GetCoreObject()
local hasMalaria = false
local lastSpreadAttempt = 0
local spreadCooldown = 60000 -- 1 minute cooldown on spread attempts
local isBusy = false
local isAnimationPlaying = false

-- Seed Lua's PRNG so location / spread / ragdoll rolls aren't deterministic.
-- Without this the first few math.random() calls return the same sequence every
-- time the resource starts, which can make it look like "nothing happens".
math.randomseed(GetGameTimer() + GetPlayerServerId(PlayerId()) * 1000)
for _ = 1, 5 do math.random() end -- discard first few, they're often biased

-- --------------------------------------------------------------------
-- Locale loader (JSON based, falls back to English)
-- --------------------------------------------------------------------
local fallbackLocaleKey = 'en'
local currentLocale = {}
local fallbackLocale = {}

local function LoadLocaleFile(lang)
    if not lang then return nil end
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if not raw then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

fallbackLocale = LoadLocaleFile(fallbackLocaleKey) or {}
if Config.Locale and Config.Locale ~= fallbackLocaleKey then
    currentLocale = LoadLocaleFile(Config.Locale) or {}
    if not next(currentLocale) then
        print(('^3[mack-malaria] Locale "%s" not found, falling back to "%s".^0')
            :format(tostring(Config.Locale), fallbackLocaleKey))
    end
else
    currentLocale = fallbackLocale
end

local function L(key)
    return currentLocale[key] or fallbackLocale[key] or key
end

-- --------------------------------------------------------------------
-- Notification wrapper (rNotify | bln_notify)
-- --------------------------------------------------------------------
-- kind:     'info' | 'success' | 'error' | 'warning'
-- extra:    optional table { icon = 'name', placement = 'top-right' }
local function Notify(kind, title, message, duration, extra)
    duration = duration or 4000
    extra    = extra or {}

    local system = Config.NotifySystem or 'rNotify'

    -- Auto fallback: if selected system isn't running, drop back to rNotify
    if GetResourceState(system) ~= 'started' and system ~= 'rNotify' then
        if Config.Debug then
            print(('^3[mack-malaria] Notify system "%s" not started, falling back to rNotify.^0'):format(system))
        end
        system = 'rNotify'
    end

    if system == 'bln_notify' then
        local templateMap = {
            info    = 'INFO',
            success = 'SUCCESS',
            error   = 'ERROR',
            warning = 'INFO',
        }
        local bln = Config.BlnNotify or {}
        local options = {
            title       = title,
            description = message,
            duration    = duration,
            placement   = extra.placement or bln.placement or 'top-right',
            icon        = extra.icon or bln.defaultIcon,
        }
        -- Templates are opt-in. They ship with hard-coded styled titles that
        -- clash with our per-event titles and, in testing, caused the
        -- description to disappear. Only attach one when explicitly enabled.
        local template = (bln.useTemplate == true) and templateMap[kind] or nil
        TriggerEvent('bln_notify:send', options, template)
    else
        -- Default / legacy: rNotify
        TriggerEvent('rNotify:ShowTopNotification', title, message, duration)
    end
end


-- Enhanced state sync
local function SyncMalariaState(state)
    local oldState = hasMalaria
    hasMalaria = state
    
    -- If we're curing malaria, ensure thorough cleanup
    if oldState == true and state == false then
        isAnimationPlaying = false
        Wait(100) -- Small delay to ensure cleanup completes
    end
    
    TriggerServerEvent('mack-malaria:server:syncMalaria', state)
    if Config.Debug then
        print('Malaria state synced:', state)
    end
end

-- Enhanced animation dictionary loading
local function loadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end
    end
    return HasAnimDictLoaded(dict)
end

local function PlayBoxOpeningAnimation()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local prop = nil

    -- Calculate box placement coordinates
    local boxCoords = {
        x = coords.x + 0.8 * math.sin(-math.rad(heading)),
        y = coords.y + 0.8 * math.cos(-math.rad(heading)),
        z = coords.z - 1.0
    }

    -- Ensure player is not moving
    ClearPedTasks(ped)

    -- Create and place the box
    local propName = "s_moneybox_loot"
    local propHash = GetHashKey(propName)
    
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do
        Wait(10)
    end

    -- Create box on ground
    prop = CreateObject(propHash, boxCoords.x, boxCoords.y, boxCoords.z, true, true, true)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)

    -- Play crouch inspection animation
    local inspectAnim = `WORLD_HUMAN_CROUCH_INSPECT`
    TaskStartScenarioInPlace(ped, inspectAnim, 0, true)
    Wait(2000)

    -- Add sound effect for opening the box
    PlaySoundFrontend(-1, "BACK", "HUD_SHOP_SOUNDSET", true)
    Wait(1000)
    
    -- Clean up
    if DoesEntityExist(prop) then
        DeleteObject(prop)
    end

    -- Clean up animations
    ClearPedTasks(ped)
    SetModelAsNoLongerNeeded(propHash)
end


local function SpreadMalaria()
    if not Config.MalariaSpread or not hasMalaria then return end
    
    local currentTime = GetGameTimer()
    if currentTime - lastSpreadAttempt < spreadCooldown then return end
    
    lastSpreadAttempt = currentTime
    local playerCoords = GetEntityCoords(PlayerPedId())
    local players = GetActivePlayers()
    
    for _, player in ipairs(players) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= Config.SpreadDistance then
                if math.random(100) <= Config.SpreadChance then
                    TriggerServerEvent('mack-malaria:spreadPlayer', GetPlayerServerId(player))
                    if Config.Debug then
                        print('Attempting to spread malaria to player at distance: ' .. distance)
                    end
                end
            end
        end
    end
end


RegisterNetEvent('mack-malaria:client:usemedicine')
AddEventHandler('mack-malaria:client:usemedicine', function()
    if isBusy then return end
    
    local hasItem = RSGCore.Functions.HasItem('malaria_medicine', 1)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    
    if not PlayerData.metadata['isdead'] and not PlayerData.metadata['ishandcuffed'] then
        if hasItem then
            if not hasMalaria then
                Notify('warning', L('no_malaria_title'), L('no_malaria_desc'), 4000)
                return
            end
            
            isBusy = true
            LocalPlayer.state:set('inv_busy', true, true)
            SetCurrentPedWeapon(PlayerPedId(), GetHashKey('weapon_unarmed'))
            
            if loadAnimDict("mech_inventory@drinking@champagne") then
                lib.progressBar({
                    duration = Config.CureTime,
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = false,
                    disableControl = true,
                    disable = {
                        move = true,
                        mouse = true,
                    },
                    anim = {
                        dict = "mech_inventory@drinking@champagne",
                        clip = "action",
                        flag = 1,
                    },
                    label = L('using_medicine'),
                })
                
                
                StopAnimTask(PlayerPedId(), "mech_inventory@drinking@champagne", "action", 1.0)
                RemoveAnimDict("mech_inventory@drinking@champagne")
            end
            
            
            SetEntityHealth(PlayerPedId(), Config.CureHealthRestore)
            SyncMalariaState(false)
            
            
            
            TriggerServerEvent('mack-malaria:server:removeitem', 'malaria_medicine', 1)
            
            
            LocalPlayer.state:set('inv_busy', false, true)
            isBusy = false
            
            Notify('success', L('cured_title'), L('cured_desc'), 4000, { icon = (Config.BlnNotify or {}).cureIcon })
        else
            Notify('error', L('error_title'), L('no_medicine_desc'), 4000)
        end
    else
        Notify('error', L('error_title'), L('dead_cuffed_desc'), 4000)
    end
end)

-- Event handlers
RegisterNetEvent('mack-malaria:client:syncMalaria')
AddEventHandler('mack-malaria:client:syncMalaria', function(state)
    SyncMalariaState(state)
end)

RegisterNetEvent('mack-malaria:spread')
AddEventHandler('mack-malaria:spread', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.job.type == "leo" or PlayerData.job.name == "medic" then
            return
        end
        
        SyncMalariaState(true)
        Notify('error', L('infected_title'), L('infected_desc'), 4000, { icon = (Config.BlnNotify or {}).spreadInfectIcon })

        if Config.Debug then
            print('Received Malaria through spread')
        end
    end)
end)

RegisterNetEvent('mack-malaria:useOldbox')
AddEventHandler('mack-malaria:useOldbox', function()
    local ped = PlayerPedId()
    
    
    LocalPlayer.state:set('inv_busy', true, true)
    
    
    PlayBoxOpeningAnimation()
    
   
    LocalPlayer.state:set('inv_busy', false, true)
    
   
    SyncMalariaState(true)
    Notify('info', L('mystery_box_title'), L('mystery_box_desc'), 4000, { icon = (Config.BlnNotify or {}).boxIcon })
    Wait(1000)
    Notify('error', L('infected_title'), L('infected_desc'), 4000, { icon = (Config.BlnNotify or {}).boxInfectIcon })
end)


Citizen.CreateThread(function()
    while true do
        Wait(100)
        
        if hasMalaria and not isAnimationPlaying then
            Wait(math.random(Config.SicktickMin, Config.SicktickMax))
            
            local ped = PlayerPedId()
            
            if loadAnimDict('amb_misc@world_human_vomit@male_a@idle_b') then
                if not hasMalaria then
                    goto continue
                end
                
                isAnimationPlaying = true
                TaskPlayAnim(ped, "amb_misc@world_human_vomit@male_a@idle_b", "idle_f", 8.0, -8.0, -1, 31, 0, true, 0, false, 0, false)
                
                SpreadMalaria()
                
                
                for i = 1, 8 do
                    if not hasMalaria then
                        goto continue
                    end
                    Wait(1000)
                end
                
                if not hasMalaria then
                    goto continue
                end
                
                RemoveAnimDict('amb_misc@world_human_vomit@male_a@idle_b')
                
                
                local currentHealth = GetEntityHealth(ped)
                local newHealth = math.max(Config.MinHealthLimit, currentHealth - Config.Healthtake)
                SetEntityHealth(ped, newHealth)
                
                
                ClearPedSecondaryTask(ped)
                isAnimationPlaying = false
                
               
                if math.random(100) <= Config.chanceToRagdoll and hasMalaria then
                    SetPedToRagdoll(ped, 6000, 6000, 0, 0, 0, 0)
                end
                
                if hasMalaria then
                    Notify('error', L('symptoms_title'), L('symptoms_desc'), 4000, { icon = (Config.BlnNotify or {}).symptomsIcon })
                end
            end
        
        end
        
        ::continue::
    end
end)

-- Returns distance and whether the player is inside the zone, honouring the
-- AreaUseFlatDistance + AreaZTolerance config options.
local function GetZoneProximity(playerCoords, location)
    if Config.AreaUseFlatDistance then
        local dx = playerCoords.x - location.coords.x
        local dy = playerCoords.y - location.coords.y
        local dz = math.abs(playerCoords.z - location.coords.z)
        local flat = math.sqrt(dx * dx + dy * dy)
        local inside = flat <= location.radius and dz <= (Config.AreaZTolerance or 15.0)
        return flat, dz, inside
    else
        local d = #(playerCoords - location.coords)
        return d, 0.0, d <= location.radius
    end
end

local function CheckMalariaInfectionLocations()
    if hasMalaria then return end

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    local nearestIdx, nearestDist = nil, math.huge

    for i, location in ipairs(Config.InfectionLocations) do
        local flat, dz, inside = GetZoneProximity(playerCoords, location)

        if flat < nearestDist then
            nearestIdx, nearestDist = i, flat
        end

        if inside then
            local roll = math.random(100)
            if Config.Debug then
                print(('[mack-malaria] Zone #%d HIT flat=%.2f dz=%.2f radius=%.2f roll=%d need<=%d')
                    :format(i, flat, dz, location.radius, roll, location.chance))
            end
            if roll <= location.chance then
                SyncMalariaState(true)
                Notify('error', L('infected_title'), L('infected_area_desc'), 4000, { icon = (Config.BlnNotify or {}).areaInfectIcon })
                return
            end
        end
    end

    if Config.Debug and nearestIdx then
        local loc = Config.InfectionLocations[nearestIdx]
        print(('[mack-malaria] Not inside any zone. Nearest: #%d at flat=%.2f (radius=%.2f) player=%.2f,%.2f,%.2f')
            :format(nearestIdx, nearestDist, loc.radius,
                    playerCoords.x, playerCoords.y, playerCoords.z))
    end
end

-- Single thread for location-based infection checking
Citizen.CreateThread(function()
    while true do
        Wait(Config.AreaCheckInterval or 10000)
        if not hasMalaria then
            CheckMalariaInfectionLocations()
        end
    end
end)

-- Debug command: force an immediate area check from wherever you're standing.
-- Only registered when Config.Debug is true.
if Config.Debug then
    RegisterCommand('malariacheck', function()
        print('[mack-malaria] Manual area check triggered')
        CheckMalariaInfectionLocations()
    end, false)
end
