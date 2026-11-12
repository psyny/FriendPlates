-- FP_Display.lua
-- Marker icon and health bar attached to the Blizzard nameplate base frames, plus
-- hiding parts of the default nameplate (name, health bar, cast bar).
-- Other nameplate addons draw their own frames: only the icon and bar show over them.
FP_Display = {}

local Display = FP_Display
local Icons = FP_Icons
local Utils = FP_Utils
local BarTextures = FP_BarTextures

local ICON_DIR = "Interface\\AddOns\\FriendPlates\\Icons\\"

---------------------------------------------------------
-- Container (one per nameplate frame, reused with the plate)

local function GetContainer(plate)
    local container = plate.FP_Container
    if container then
        return container
    end
    container = CreateFrame("Frame", nil, plate)
    container:SetAllPoints(plate)

    container.icon = container:CreateTexture(nil, "OVERLAY", nil, 1)

    -- Health bar
    local bar = CreateFrame("StatusBar", nil, container)
    bar.border = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    bar.border:SetColorTexture(0, 0, 0, 1)
    bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.bg:SetAllPoints(bar)
    bar:Hide()
    container.bar = bar

    -- Health sphere: a vertical bar cut to a circle, with shading and a ring on top
    local sphere = CreateFrame("StatusBar", nil, container)
    sphere:SetOrientation("VERTICAL")
    sphere.mask = sphere:CreateMaskTexture()
    sphere.mask:SetTexture(ICON_DIR .. "sphere_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    sphere.mask:SetAllPoints(sphere)
    sphere.bg = sphere:CreateTexture(nil, "BACKGROUND", nil, 1)
    sphere.bg:SetAllPoints(sphere)
    sphere.bg:AddMaskTexture(sphere.mask)
    sphere.shade = sphere:CreateTexture(nil, "OVERLAY", nil, 1)
    sphere.shade:SetTexture(ICON_DIR .. "sphere_shade")
    sphere.shade:SetAllPoints(sphere)
    sphere.shine = sphere:CreateTexture(nil, "OVERLAY", nil, 2)
    sphere.shine:SetTexture(ICON_DIR .. "sphere_shine")
    sphere.shine:SetAllPoints(sphere)
    sphere.border = sphere:CreateTexture(nil, "OVERLAY", nil, 3)
    sphere.border:SetTexture(ICON_DIR .. "sphere_ring")
    sphere.border:SetAllPoints(sphere)
    sphere:Hide()
    container.sphere = sphere

    plate.FP_Container = container
    return container
end

---------------------------------------------------------
-- Default nameplate parts

-- Each part: candidate fields on plate.UnitFrame (they differ between game versions).
local PARTS = {
    name = { "name" },
    health = { "HealthBarsContainer", "healthBar" },
    cast = { "castBar", "CastBar" },
}

local function FindPart(unitFrame, part)
    for _, field in ipairs(PARTS[part]) do
        local region = unitFrame[field]
        if type(region) == "table" and region.SetAlpha then
            return region
        end
    end
    return nil
end

-- hide: { name = bool, health = bool, cast = bool } or nil to restore everything.
-- Uses alpha so the game can keep showing and hiding the parts as it likes.
function Display.SetDefaultParts(plate, hide)
    local unitFrame = plate and plate.UnitFrame
    if not unitFrame then
        return
    end
    plate.FP_hide = hide
    local hidden = plate.FP_hidden
    if not hidden then
        hidden = {}
        plate.FP_hidden = hidden
    end
    for part in pairs(PARTS) do
        local region = FindPart(unitFrame, part)
        if region then
            if hide and hide[part] then
                region:SetAlpha(0)
                hidden[part] = true
            elseif hidden[part] then
                region:SetAlpha(1) -- only restore what we hid
                hidden[part] = nil
            end
        end
    end
end

-- Called after the game redraws a default nameplate (it may reset alpha).
function Display.ReapplyDefaultParts(plate)
    if plate and plate.FP_hide then
        Display.SetDefaultParts(plate, plate.FP_hide)
    end
end

---------------------------------------------------------
-- Show / hide

local function ApplyLayer(frame, plate, layout)
    if layout.strata ~= "INHERIT" then
        frame:SetFrameStrata(layout.strata)
    else
        frame:SetFrameStrata(plate:GetFrameStrata())
    end
    frame:SetFrameLevel(plate:GetFrameLevel() + layout.frame_level)
    frame:SetAlpha(layout.alpha)
end

local function GroupColor(group)
    local c = group.icon_color
    return c.r, c.g, c.b
end

-- true when at full health, false when not, nil when the game hides the values (secret).
local function IsFull(unit)
    local ok, health, max = pcall(function()
        return UnitHealth(unit), UnitHealthMax(unit)
    end)
    if not ok or Utils.IsSecret(health) or Utils.IsSecret(max) or not health or not max then
        return nil
    end
    return health >= max
end

-- Opacity curve for secret health: 100% -> hidden, anything below -> shown.
-- The game evaluates it (UnitHealthPercent), so we never read the secret value.
local fullCurve
local function GetFullCurve()
    if fullCurve == nil then
        fullCurve = false
        if C_CurveUtil and C_CurveUtil.CreateCurve then
            local ok, curve = pcall(function()
                local c = C_CurveUtil.CreateCurve()
                c:AddPoint(0, 1)
                c:AddPoint(0.999, 1)
                c:AddPoint(1, 0)
                return c
            end)
            fullCurve = ok and curve or false
        end
    end
    return fullCurve or nil
end

-- Hides the widget at full health by opacity, for secret values. Returns false if unsupported.
local function SetAlphaFromSecretHealth(widget, unit)
    local curve = GetFullCurve()
    if not curve or not UnitHealthPercent then
        return false
    end
    local ok = pcall(function()
        widget:SetAlpha(UnitHealthPercent(unit, false, curve))
    end)
    return ok
end

-- How "When not full" decides, for /fp debug.
function Display.DescribeHealth(unit)
    local ok, health, max = pcall(function()
        return UnitHealth(unit), UnitHealthMax(unit)
    end)
    if not ok then
        return "error reading health"
    end
    local secret = Utils.IsSecret(health) or Utils.IsSecret(max)
    if secret then
        return "secret values; curve method " .. (GetFullCurve() and UnitHealthPercent and "available" or "NOT available")
    end
    return "health " .. tostring(health) .. " / " .. tostring(max) .. ", full: " .. tostring(IsFull(unit))
end

-- Health values may be secret (Midnight): pass them straight to the bar, never compare them.
-- In "missing" mode the bar only shows below full health. With secret values the game hides
-- it through an opacity curve; if that is not available either, the bar always shows.
function Display.UpdateHealth(plate, unit)
    local container = plate and plate.FP_Container
    local mode = container and container.healthMode
    if not mode then
        return
    end
    local widget = container.health
    pcall(widget.SetMinMaxValues, widget, 0, UnitHealthMax(unit))
    pcall(widget.SetValue, widget, UnitHealth(unit))
    if mode ~= "missing" then
        widget:SetAlpha(1)
        widget:Show()
        return
    end
    local full = IsFull(unit)
    if full ~= nil then
        widget:SetAlpha(1)
        widget:SetShown(not full)
        return
    end
    widget:Show()
    if not SetAlphaFromSecretHealth(widget, unit) then
        widget:SetAlpha(1)
    end
end

-- The group picks the style; the style's own settings come from the Layout tab
-- (profile fields "bar_..." or "sphere_...").
local function ShowBar(container, plate, unit, layout, group, classFile, mode)
    local isSphere = group.health_style == "sphere"
    local prefix = isSphere and "sphere_" or "bar_"
    local function S(name)
        return layout[prefix .. name]
    end
    local bar = isSphere and container.sphere or container.bar
    local other = isSphere and container.bar or container.sphere
    other:Hide()
    container.health = bar
    container.healthMode = mode

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", plate, S("anchor"), S("offset_x"), S("offset_y"))
    if isSphere then
        bar:SetSize(S("size"), S("size"))
    else
        bar:SetSize(S("width"), S("height"))
    end
    bar:SetStatusBarTexture(BarTextures.Path(S("texture")))
    if isSphere then
        -- mask the fill texture (once per texture object)
        local fill = bar:GetStatusBarTexture()
        if fill and fill ~= bar.maskedFill then
            fill:AddMaskTexture(bar.mask)
            bar.maskedFill = fill
        end
    end

    local r, g, b
    if S("color_mode") == "class" then
        r, g, b = Utils.ClassColor(classFile)
    elseif S("color_mode") == "group" then
        r, g, b = GroupColor(group)
    end
    if not r then
        local c = S("color")
        r, g, b = c.r, c.g, c.b
    end
    bar:SetStatusBarColor(r, g, b)
    local bgR, bgG, bgB
    if S("bg_mode") == "black" then
        bgR, bgG, bgB = 0, 0, 0
    elseif S("bg_mode") == "custom" then
        local c = S("bg_color")
        bgR, bgG, bgB = c.r, c.g, c.b
    else -- "tinted": a dark shade of the fill color
        bgR, bgG, bgB = r * 0.25, g * 0.25, b * 0.25
    end
    bar.bg:SetColorTexture(bgR, bgG, bgB, S("bg_alpha"))
    bar.border:SetShown(S("border"))
    if isSphere then
        bar.shine:SetShown(S("shine"))
    end
    Display.UpdateHealth(plate, unit)
end

local function HideHealth(container)
    container.healthMode = nil
    container.bar:Hide()
    container.sphere:Hide()
end

-- layout: the profile (shared layout); group: the group's settings.
function Display.Show(plate, unit, layout, group)
    local container = GetContainer(plate)
    ApplyLayer(container, plate, layout)
    local classFile = Utils.UnitClassFile(unit)

    local icon = container.icon
    if group.show_icon then
        local size = layout.icon_size * group.icon_scale
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", plate, layout.icon_anchor, layout.icon_offset_x, layout.icon_offset_y)
        icon:SetSize(size, size)
        local r, g, b
        if group.icon_color_mode == "class" then
            r, g, b = Utils.ClassColor(classFile)
        end
        if not r then
            r, g, b = GroupColor(group)
        end
        Icons.Apply(icon, group.icon, classFile, r, g, b)
        icon:Show()
    else
        icon:Hide()
    end

    local mode = group.health_mode
    if mode == "always" or mode == "missing" then
        ShowBar(container, plate, unit, layout, group, classFile, mode)
    else
        HideHealth(container)
    end

    container:Show()
    Display.SetDefaultParts(plate, {
        name = group.hide_name,
        health = group.hide_health,
        cast = group.hide_cast,
    })
end

function Display.Hide(plate)
    if not plate then
        return
    end
    if plate.FP_Container then
        plate.FP_Container:Hide()
        HideHealth(plate.FP_Container)
    end
    Display.SetDefaultParts(plate, nil)
end
