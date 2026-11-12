-- FP_BarTextures.lua
-- Health bar textures: a few that exist in every game version, our own Smooth texture,
-- and every status bar texture registered in LibSharedMedia (when another addon loads it).
FP_BarTextures = {}

local BarTextures = FP_BarTextures

local LSM_PREFIX = "lsm:"

BarTextures.DEFAULT = "smooth"

local BUILTIN = {
    { key = "blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "smooth",   path = "Interface\\AddOns\\FriendPlates\\Icons\\bar_smooth" },
    { key = "flat",     path = "Interface\\Buttons\\WHITE8X8" },
    { key = "raid",     path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "skills",   path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local BUILTIN_BY_KEY = {}
for _, entry in ipairs(BUILTIN) do
    BUILTIN_BY_KEY[entry.key] = entry
end

local function LSM()
    return LibStub("LibSharedMedia-3.0", true)
end

-- Texture path for a saved key. Missing LSM textures fall back to the default.
function BarTextures.Path(key)
    local builtin = BUILTIN_BY_KEY[key]
    if builtin then
        return builtin.path
    end
    if type(key) == "string" and key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
        local lsm = LSM()
        local path = lsm and lsm:Fetch("statusbar", key:sub(#LSM_PREFIX + 1), true)
        if path then
            return path
        end
    end
    return BUILTIN_BY_KEY[BarTextures.DEFAULT].path
end

-- values, sorting for an AceConfig select. label(key) gives the built-in names.
-- Each entry shows a small preview of the texture.
function BarTextures.Options(label)
    local values, sorting = {}, {}
    local function Add(key, name, path)
        values[key] = "|T" .. path .. ":12:60|t " .. name
        sorting[#sorting + 1] = key
    end
    for _, entry in ipairs(BUILTIN) do
        Add(entry.key, label(entry.key), entry.path)
    end
    local lsm = LSM()
    if lsm then
        local names = lsm:List("statusbar")
        for _, name in ipairs(names) do
            local path = lsm:Fetch("statusbar", name, true)
            if path then
                Add(LSM_PREFIX .. name, name, path)
            end
        end
    end
    return values, sorting
end
