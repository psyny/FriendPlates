-- FP_Utils.lua
FP_Utils = {}

local Utils = FP_Utils

---------------------------------------------------------
-- Secret-safe API calls.
-- Since Midnight, some unit APIs return "secret" values (in combat, in instances)
-- that addons cannot compare. Those are treated as unknown (nil).

local issecretvalue = issecretvalue

function Utils.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) or false
end

function Utils.Safe(fn, ...)
    if not fn then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok or Utils.IsSecret(value) then
        return nil
    end
    return value
end

---------------------------------------------------------
-- Units

function Utils.IsNameplateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d") ~= nil
end

local function MyRealm()
    local realm = GetNormalizedRealmName and Utils.Safe(GetNormalizedRealmName)
    if not realm or realm == "" then
        realm = (Utils.Safe(GetRealmName) or ""):gsub("[%s%-]", "")
    end
    return realm
end

-- "Name-Realm" for any name, with or without a realm.
function Utils.FullName(name, realm)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if name:find("-", 1, true) then
        return name
    end
    if not realm or realm == "" then
        realm = MyRealm()
    end
    return name .. "-" .. realm:gsub("[%s%-]", "")
end

function Utils.UnitFullName(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or Utils.IsSecret(name) or Utils.IsSecret(realm) then
        return nil
    end
    return Utils.FullName(name, realm)
end

function Utils.UnitClassFile(unit)
    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok or Utils.IsSecret(classFile) then
        return nil
    end
    return classFile
end

function Utils.ClassColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b
    end
    return nil
end

---------------------------------------------------------
-- Tables

function Utils.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

function Utils.Print(msg)
    print("|cff66ff88FriendPlates|r: " .. tostring(msg))
end
