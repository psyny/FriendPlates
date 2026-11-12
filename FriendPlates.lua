-- FriendPlates.lua
FriendPlates = LibStub("AceAddon-3.0"):NewAddon("FriendPlates", "AceConsole-3.0", "AceEvent-3.0")

local Addon = FriendPlates
local Utils = FP_Utils
local Groups = FP_Groups
local Display = FP_Display
local Options = FP_Options

local MAX_NAMEPLATES = 40
local dirtyUnits = {}
local dirtyAll = false
local flushQueued = false
local healthUnits = {} -- unit -> true while its plate shows our health bar
local ctx = { subgroupIsParty = true }

-- Events that can change which group a player is in.
local ROSTER_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED" }
local FRIEND_EVENTS = {
    "FRIENDLIST_UPDATE",
    "BN_FRIEND_INFO_CHANGED",
    "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE",
}
local REFRESH_ALL_EVENTS = { "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE" }

-- Unit events that can change one plate.
local UNIT_EVENTS = { "UNIT_FACTION", "UNIT_FLAGS", "UNIT_NAME_UPDATE" }
-- UNIT_HEALTH_FREQUENT only exists in some game versions.
local HEALTH_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEALTH_FREQUENT" }

---------------------------------------------------------
-- Addon events

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("FriendPlatesDB", Options.defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    Options.Migrate(self.db.profile)
    Options.db = self.db.profile

    local options = Options.options
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    options.args.profiles.order = 100

    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(Options.APP_NAME, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(Options.APP_NAME, Options.APP_NAME)

    self:RegisterChatCommand("fp", "SlashCommand")
    self:RegisterChatCommand("friendplates", "SlashCommand")
end

function Addon:OnEnable()
    self:SafeRegisterEvent("NAME_PLATE_UNIT_ADDED", "OnPlateAdded")
    self:SafeRegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnPlateRemoved")
    self:SafeRegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    for _, event in ipairs(ROSTER_EVENTS) do
        self:SafeRegisterEvent(event, "OnRosterChanged")
    end
    for _, event in ipairs(FRIEND_EVENTS) do
        self:SafeRegisterEvent(event, "OnFriendsChanged")
    end
    for _, event in ipairs(REFRESH_ALL_EVENTS) do
        self:SafeRegisterEvent(event, "RefreshAll")
    end
    for _, event in ipairs(UNIT_EVENTS) do
        self:SafeRegisterEvent(event, "OnUnitEvent")
    end
    for _, event in ipairs(HEALTH_EVENTS) do
        self:SafeRegisterEvent(event, "OnHealthEvent")
    end
    self:HookDefaultPlates()

    if C_FriendList and C_FriendList.ShowFriends then
        pcall(C_FriendList.ShowFriends) -- asks the server for the list; FRIENDLIST_UPDATE follows
    end
    self:ApplySettings()
end

-- Unknown events (renamed by a patch, or missing in this game version) are skipped.
function Addon:SafeRegisterEvent(event, handler)
    pcall(self.RegisterEvent, self, event, handler)
end

function Addon:OnProfileChanged()
    Options.Migrate(self.db.profile)
    Options.db = self.db.profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange(Options.APP_NAME)
    self:ApplySettings()
end

-- Applies every option. Called when a general option changes.
function Addon:ApplySettings()
    ctx.subgroupIsParty = Options.db.subgroup_is_party
    Groups.UpdateRoster(ctx.subgroupIsParty)
    Groups.UpdateFriends(Options.db.bnet_friends)
    self:RefreshAll()
end

function Addon:SlashCommand(input)
    if strtrim(input or ""):lower() == "debug" then
        self:PrintDebug()
        return
    end
    LibStub("AceConfigDialog-3.0"):Open(Options.APP_NAME)
end

-- /fp debug: one line per visible friendly player plate.
function Addon:PrintDebug()
    local count = 0
    for i = 1, MAX_NAMEPLATES do
        local unit = "nameplate" .. i
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and Utils.Safe(UnitExists, unit) and Groups.IsFriendlyPlayer(unit) then
            count = count + 1
            local key, group = Groups.Classify(unit, Options.db.groups, ctx)
            local container = plate.FP_Container
            local widget = container and container.health
            local shown = widget and container.healthMode and widget:IsShown()
            Utils.Print(format("%s: group %s, health %s/%s | %s | widget shown %s, alpha %s",
                Utils.UnitFullName(unit) or unit,
                tostring(key),
                group and group.health_mode or "-",
                group and group.health_style or "-",
                Display.DescribeHealth(unit),
                tostring(shown),
                widget and (Utils.Safe(widget.GetAlpha, widget) or "secret") or "-"))
        end
    end
    if count == 0 then
        Utils.Print("no friendly player nameplates visible")
    end
end

---------------------------------------------------------
-- The game may redraw parts of a default nameplate after we hid them: hide them again.

function Addon:HookDefaultPlates()
    local function Reapply(frame)
        local unit = frame and frame.unit
        if Utils.IsNameplateUnit(unit) then
            Display.ReapplyDefaultParts(C_NamePlate.GetNamePlateForUnit(unit))
        end
    end
    for _, name in ipairs({ "CompactUnitFrame_UpdateName", "CompactUnitFrame_UpdateAll" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, Reapply)
        end
    end
end

---------------------------------------------------------
-- Refresh (batched to the next frame)

local function Flush()
    flushQueued = false
    if dirtyAll then
        dirtyAll = false
        wipe(dirtyUnits)
        -- Walk the unit tokens rather than the plate frames: plates that were already
        -- shown before we loaded (e.g. after /reload) never send NAME_PLATE_UNIT_ADDED.
        for i = 1, MAX_NAMEPLATES do
            local unit = "nameplate" .. i
            if Utils.Safe(UnitExists, unit) then
                Addon:UpdateUnit(unit)
            end
        end
        return
    end
    for unit in pairs(dirtyUnits) do
        Addon:UpdateUnit(unit)
    end
    wipe(dirtyUnits)
end

local function QueueFlush()
    if not flushQueued then
        flushQueued = true
        C_Timer.After(0, Flush)
    end
end

function Addon:RefreshAll()
    dirtyAll = true
    QueueFlush()
end

function Addon:RefreshUnit(unit)
    dirtyUnits[unit] = true
    QueueFlush()
end

function Addon:UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        healthUnits[unit] = nil
        return -- gone, or a forbidden plate (friendly plates inside instances)
    end
    local db = Options.db
    local group
    if db.enabled and Utils.Safe(UnitExists, unit) then
        local _
        _, group = Groups.Classify(unit, db.groups, ctx)
    end
    if not group then
        healthUnits[unit] = nil
        Display.Hide(plate)
        return
    end
    Display.Show(plate, unit, db, group)
    healthUnits[unit] = (group.health_mode == "always" or group.health_mode == "missing") or nil
end

---------------------------------------------------------
-- Game events

function Addon:OnPlateAdded(_, unit)
    self:RefreshUnit(unit)
end

function Addon:OnPlateRemoved(_, unit)
    dirtyUnits[unit] = nil
    healthUnits[unit] = nil
    Display.Hide(C_NamePlate.GetNamePlateForUnit(unit))
end

function Addon:OnUnitEvent(_, unit)
    if Utils.IsNameplateUnit(unit) then
        self:RefreshUnit(unit)
    end
end

function Addon:OnHealthEvent(_, unit)
    if healthUnits[unit] then
        Display.UpdateHealth(C_NamePlate.GetNamePlateForUnit(unit), unit)
    end
end

function Addon:OnRosterChanged()
    Groups.UpdateRoster(ctx.subgroupIsParty)
    self:RefreshAll()
end

function Addon:OnFriendsChanged()
    Groups.UpdateFriends(Options.db.bnet_friends)
    self:RefreshAll()
end

function Addon:OnEnteringWorld()
    self:ApplySettings()
    -- Rosters and plates can still be settling right after a load screen or /reload.
    C_Timer.After(1, function()
        self:ApplySettings()
    end)
end
