Config = {

    -- ------------------------------------------------------------------
    -- Notification backend
    -- ------------------------------------------------------------------
    -- 'rNotify'    -> uses rNotify:ShowTopNotification (default / legacy)
    -- 'bln_notify' -> uses bln_notify:send (https://github.com/blnStudio/bln_notify)
    NotifySystem = 'bln_notify',

    -- Options only used when NotifySystem = 'bln_notify'
    -- Icon names refer to bln_notify/ui/assets/imgs/icons
    BlnNotify = {
        placement   = 'top-right',      -- top/middle/bottom - left/center/right
        -- Templates (INFO/SUCCESS/ERROR) in bln_notify ship with their own
        -- pre-styled title text. When we pass our own title the layout can
        -- hide the description, so templates are OFF by default. Set to true
        -- only if you are OK losing custom titles and want the template look.
        useTemplate = false,
        defaultIcon = 'warning',        -- fallback for notifications without an explicit icon

        -- Per-event icons
        cureIcon        = 'tick',               -- Cure succeeded
        boxIcon         = 'awards_set_a_014',   -- Opened the mysterious old box
        spreadInfectIcon= 'awards_set_h_006',   -- Infected via spread from another player
        boxInfectIcon   = 'awards_set_b_013',   -- Infected via opening the old box
        symptomsIcon    = 'awards_set_b_016',   -- Ongoing sickness tick (symptoms)
        areaInfectIcon  = 'awards_set_b_011',   -- Infected by standing in a dangerous location
    },

    -- ------------------------------------------------------------------
    -- Locale / language
    -- ------------------------------------------------------------------
    -- Available out of the box: 'en', 'fr', 'es', 'bg', 'ru'
    -- Missing keys fall back to English automatically.
    Locale = 'en',

    Healthtake = 50,
    MinHealthLimit = 0,
    MaxHealthDrain = 600,
    SicktickMin = 45000,
    SicktickMax = 60000,
    HealthTickRate = 1000,
    chanceToRagdoll = 70,
    MalariaSpread = true,
    SpreadDistance = 4.0,
    SpreadChance = 100,
    CureTime = 4000,
    CureHealthRestore = 600,
    Debug = false,

    -- How often (ms) the script checks if the player is in an infection zone.
    AreaCheckInterval = 10000,
    -- Use horizontal (XY) distance instead of full 3D, with a vertical tolerance.
    -- Prevents "I'm standing right on the spot but nothing happens" when the zone
    -- coords were captured at water level but the player is on the ground above.
    AreaUseFlatDistance = true,
    AreaZTolerance = 15.0,

    
    InfectionLocations = {
        {
            coords = vector3(-3625.15, -2570.49, -14.8),  
            radius = 10.0,  -- Radius around the coordinates where infection can occur
            chance = 50     -- Percentage chance of infection when in this area
        },
        {
            coords = vector3(-3584.39, -2605.97, -14.75),  
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(2412.05, -738.88, 41.72),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(-2429.55, -1340.63, 153.77),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(-2069.33, -1444.18, 128.48),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(2440.81, -674.88, 43.14),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(1462.47, 811.33, 100.94),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(-1579.32, -926.34, 84.58),     
            radius = 10.0,
            chance = 50
        },
        {
            coords = vector3(-947.26, 2170.74, 342.08),     
            radius = 10.0,
            chance = 50
        }
    }
}



