-- FP_Icons.lua
-- Marker icons. Shapes are our own white TGA files (Tools/make_icons.py), tinted per
-- group. Raid markers and class icons are textures that ship with every game version.
FP_Icons = {}

local Icons = FP_Icons

local ICON_DIR = "Interface\\AddOns\\FriendPlates\\Icons\\"
local RAID_MARKER = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- kind "shape": tinted by the group color
-- kind "marker": raid target icon, own colors
-- kind "class": the unit's class icon
Icons.LIST = {
    { key = "chevron",  kind = "shape" },
    { key = "triangle", kind = "shape" },
    { key = "circle",   kind = "shape" },
    { key = "ring",     kind = "shape" },
    { key = "diamond",  kind = "shape" },
    { key = "square",   kind = "shape" },
    { key = "star",     kind = "shape" },
    { key = "heart",    kind = "shape" },
    { key = "shield",   kind = "shape" },
    { key = "plus",     kind = "shape" },
    { key = "class",    kind = "class" },
}
for i = 1, 8 do
    Icons.LIST[#Icons.LIST + 1] = { key = "marker" .. i, kind = "marker", index = i }
end

Icons.BY_KEY = {}
for _, icon in ipairs(Icons.LIST) do
    Icons.BY_KEY[icon.key] = icon
end

Icons.DEFAULT = "circle"

local function Get(key)
    return Icons.BY_KEY[key] or Icons.BY_KEY[Icons.DEFAULT]
end

local function ClassCoords(classFile)
    local coords = CLASS_ICON_TCOORDS and classFile and CLASS_ICON_TCOORDS[classFile]
    return coords
end

-- Only shapes are tinted.
function Icons.IsTinted(key)
    return Get(key).kind == "shape"
end

---------------------------------------------------------
-- Apply to a texture. color: { r, g, b } used for shapes.

function Icons.Apply(tex, key, classFile, r, g, b)
    local icon = Get(key)
    if icon.kind == "class" then
        local coords = ClassCoords(classFile)
        if coords then
            tex:SetTexture(CLASS_ICONS)
            tex:SetTexCoord(unpack(coords))
            tex:SetVertexColor(1, 1, 1)
            return
        end
        icon = Get(Icons.DEFAULT) -- unknown class: plain shape
    end
    if icon.kind == "marker" then
        tex:SetTexture(RAID_MARKER .. icon.index)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(1, 1, 1)
        return
    end
    tex:SetTexture(ICON_DIR .. icon.key)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(r or 1, g or 1, b or 1)
end

---------------------------------------------------------
-- Inline text markup for the options.

function Icons.Markup(key, size, r, g, b)
    local icon = Get(key)
    size = size or 16
    if icon.kind == "class" then
        local _, classFile = UnitClass("player")
        local c = ClassCoords(classFile)
        if c then
            return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", CLASS_ICONS, size, size,
                c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
        end
        icon = Get(Icons.DEFAULT)
    end
    if icon.kind == "marker" then
        return "|T" .. RAID_MARKER .. icon.index .. ":" .. size .. ":" .. size .. "|t"
    end
    return string.format("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t", ICON_DIR .. icon.key, size, size,
        (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end
