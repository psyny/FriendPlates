-- FP_Groups.lua
-- Which group a friendly player belongs to: party, raid, friend list, guild or other.
-- Rosters are cached by GUID (and friends also by name) and rebuilt on roster events.
FP_Groups = {}

local Groups = FP_Groups
local Utils = FP_Utils
local Safe = Utils.Safe

-- Priority order: a unit uses the first group it belongs to whose settings are enabled.
Groups.LIST = { "party", "raid", "friend", "guild", "others" }

local roster = {}       -- GUID -> "party" | "raid"
local friendGuids = {}  -- GUID -> true
local friendNames = {}  -- "Name-Realm" -> true

---------------------------------------------------------
-- Party / raid

-- subgroupIsParty: in a raid, players of your own subgroup count as party.
function Groups.UpdateRoster(subgroupIsParty)
    wipe(roster)
    if IsInRaid() then
        local count = GetNumGroupMembers() or 0
        local mySubgroup
        local subgroups = {}
        for i = 1, count do
            local unit = "raid" .. i
            local _, _, subgroup = GetRaidRosterInfo(i)
            subgroups[i] = subgroup
            if Safe(UnitIsUnit, unit, "player") then
                mySubgroup = subgroup
            end
        end
        for i = 1, count do
            local guid = Safe(UnitGUID, "raid" .. i)
            if guid then
                local same = subgroupIsParty and mySubgroup and subgroups[i] == mySubgroup
                roster[guid] = same and "party" or "raid"
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local guid = Safe(UnitGUID, "party" .. i)
            if guid then
                roster[guid] = "party"
            end
        end
    end
end

-- When the GUID is hidden from us, ask the game directly.
local function RosterFallback(unit, subgroupIsParty)
    if IsInRaid() then
        local theirs, mine
        for i = 1, GetNumGroupMembers() or 0 do
            local raidUnit = "raid" .. i
            local _, _, subgroup = GetRaidRosterInfo(i)
            if Safe(UnitIsUnit, raidUnit, unit) then
                theirs = subgroup
            end
            if Safe(UnitIsUnit, raidUnit, "player") then
                mine = subgroup
            end
        end
        if not theirs then
            return nil
        end
        return (subgroupIsParty and theirs == mine) and "party" or "raid"
    end
    if Safe(UnitInParty, unit) and not IsInRaid() then
        return "party"
    end
    return nil
end

---------------------------------------------------------
-- Friend list (character friends + Battle.net friends playing WoW)

function Groups.UpdateFriends(includeBnet)
    wipe(friendGuids)
    wipe(friendNames)

    local list = C_FriendList
    if list and list.GetNumFriends then
        for i = 1, Safe(list.GetNumFriends) or 0 do
            local info = Safe(list.GetFriendInfoByIndex, i)
            if info then
                if info.guid then
                    friendGuids[info.guid] = true
                end
                local full = Utils.FullName(info.name)
                if full then
                    friendNames[full] = true
                end
            end
        end
    end

    local bnet = C_BattleNet
    if includeBnet and bnet and bnet.GetFriendAccountInfo and BNGetNumFriends then
        local count = Safe(BNGetNumFriends) or 0
        for i = 1, count do
            local account = Safe(bnet.GetFriendAccountInfo, i)
            local game = account and account.gameAccountInfo
            if game and game.playerGuid then
                friendGuids[game.playerGuid] = true
            end
            if game and game.characterName and game.realmName then
                local full = Utils.FullName(game.characterName, game.realmName)
                if full then
                    friendNames[full] = true
                end
            end
        end
    end
end

---------------------------------------------------------
-- Classify

local MEMBERSHIP = {
    party = function(unit, guid, ctx)
        if guid then
            return roster[guid] == "party"
        end
        return RosterFallback(unit, ctx.subgroupIsParty) == "party"
    end,
    raid = function(unit, guid, ctx)
        if guid then
            return roster[guid] == "raid"
        end
        return RosterFallback(unit, ctx.subgroupIsParty) == "raid"
    end,
    friend = function(unit, guid)
        if guid and friendGuids[guid] then
            return true
        end
        local full = Utils.UnitFullName(unit)
        return full ~= nil and friendNames[full] == true
    end,
    guild = function(unit)
        return Safe(UnitIsInMyGuild, unit) and true or false
    end,
    others = function()
        return true
    end,
}

-- A friendly player other than you.
function Groups.IsFriendlyPlayer(unit)
    if not Safe(UnitIsPlayer, unit) or Safe(UnitIsUnit, unit, "player") then
        return false
    end
    return Safe(UnitIsFriend, "player", unit) and not Safe(UnitCanAttack, "player", unit)
end

-- settings: profile.groups; ctx: { subgroupIsParty = bool }
-- Returns the group key and its settings, or nil when FriendPlates leaves the plate alone.
function Groups.Classify(unit, settings, ctx)
    if not Groups.IsFriendlyPlayer(unit) then
        return nil
    end
    local guid = Safe(UnitGUID, unit)
    for _, key in ipairs(Groups.LIST) do
        local group = settings[key]
        if group and group.enabled and MEMBERSHIP[key](unit, guid, ctx) then
            return key, group
        end
    end
    return nil
end
