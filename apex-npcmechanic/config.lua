Config = {}

Config.Framework = 'auto' -- auto / qb / esx
Config.AutoFrameworkPriority = 'qb' 
Config.CoreName = 'qb-core'
Config.ESXName = 'es_extended'
Config.MenuName = 'qb-menu' -- qb-menu resource name
Config.OxLibName = 'ox_lib'
Config.Language = 'ar'

-- Integration systems: auto / ox / framework / qb / custom / gta / none
-- MenuSystem supports: auto / ox / ox_menu / qb / qb-menu / none
-- NotifySystem supports: auto / ox / ox_notify / framework / custom / gta
-- CallbackSystem supports: auto / ox / ox_lib / framework
Config.MenuSystem = 'auto'
Config.NotifySystem = 'auto'
Config.CallbackSystem = 'auto'

Config.OxLib = {
    MenuStyle = 'context', 
    MenuPosition = 'top-right',
    NotifyPosition = 'top-right',
    NotifyTitle = nil, 
    NotifyShowDuration = true,
}


Config.PaymentType = 'both'
Config.MinPrice = 20
Config.MaxPrice = 150
Config.UseConfirmMenu = true

Config.RepairHealthyVehicles = false
Config.MinimumDamagePercent = 1.0
Config.CleanVehicleAfterRepair = false
Config.FixBurstTyres = true
Config.RepairDuration = 15000
Config.UseToolboxProp = true

Config.WalkSpeed = 1.0
Config.WalkHeadingTolerance = 0.2
Config.StuckReissueTime = 3500
Config.HoodWorkOffset = 0.95
Config.HoodSideOffset = 0.0 
Config.UseStableRepairScenario = false

Config.ToolboxModel = 'prop_tool_box_04'
Config.ToolboxSideOffset = 1.15
Config.ToolboxFrontOffset = 0.25

Config.RepairAnimationDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
Config.RepairAnimationName = 'machinic_loop_mechandplayer'
Config.RepairAnimationFlag = 1
Config.RepairAnimationBlendIn = 3.0
Config.RepairAnimationBlendOut = -3.0
Config.RepairAnimationCheckInterval = 1000
Config.RepairScenario = 'WORLD_HUMAN_VEHICLE_MECHANIC' 

Config.CustomNotifyEvent = nil 

Config.Roadside = {
    Enabled = true,
    Command = 'npcmechanic',

    DispatchFee = 50,
    Cooldown = 300, 
    MaxActiveCalls = 3,

    PedModel = 'mp_m_waremech_01',
    TowTruckModel = 'flatbed',

    SpawnDistance = 75.0,
    ParkingDistance = 14.0,
    MinimumSpawnDistance = 40.0,
    VehicleSearchRadius = 15.0,

    DriveSpeed = 16.0,
    DrivingStyle = 786603,
    ArrivalDistance = 18.0,
    DriveTimeout = 90000,
    DriveStuckReissueTime = 9000,
    ServiceTimeout = 240000,

    ExitVehicleTimeout = 12000,
    ExitClearTimeout = 9000,
    ExitSideClearance = 1.15,
    ExitForwardOffset = 0.65,
    ExitWalkSpeed = 1.0,

    PlayerExitTimeout = 20000,
    WalkTimeout = 30000,
    BonnetApproachRange = 2.2,
    BonnetStoppingRange = 0.65,
    BonnetFallbackRange = 1.15,
    BonnetFrontClearance = 0.55,
    FinalApproachSpeed = 0.65,
    FinalApproachTimeout = 12000,
    BonnetSideOffset = 0.0,
    PedGroundMinimumRootHeight = 0.35, 
    PedGroundMaximumRootHeight = 2.25, 

    RepairDuration = 15000,
    FreezeVehicleDuringRepair = true,
    OpenBonnet = true,
    UseToolboxProp = true,

    ReturnToTruckTimeout = 35000,
    EnterTruckTimeout = 15000,
    LeaveDistance = 120.0,
    LeaveTimeout = 45000,
    DespawnDistance = 90.0,

    ShowBlip = true,
    BlipSprite = 446,
    BlipColour = 3,
    BlipScale = 0.75,
}
