-- FP_Options.lua
FP_Options = {}

local Options = FP_Options
local Utils = FP_Utils
local Icons = FP_Icons
local Groups = FP_Groups
local BarTextures = FP_BarTextures

local L = LibStub("AceLocale-3.0"):GetLocale("FriendPlates", false)

Options.APP_NAME = "FriendPlates"
Options.db = nil -- profile
Options.options = nil

---------------------------------------------------------
-- Defaults

local function Group(icon, r, g, b, healthMode, healthStyle, scale, enabled)
    return {
        enabled = enabled ~= false,
        show_icon = true,
        icon = icon,
        icon_color_mode = "custom",
        icon_color = { r = r, g = g, b = b },
        icon_scale = scale or 1,
        health_mode = healthMode, -- "off" | "always" | "missing"
        health_style = healthStyle, -- "bar" | "sphere"
        hide_name = true,
        hide_health = true,
        hide_cast = false,
    }
end

Options.defaults = {
    profile = {
        enabled = true,
        subgroup_is_party = true,
        bnet_friends = true,

        groups = {
            party  = Group("chevron", 0.3, 1, 0.4, "always", "bar"),
            raid   = Group("chevron", 1, 0.6, 0.15, "always", "bar"),
            friend = Group("heart", 1, 0.45, 0.75, "off", "bar"),
            guild  = Group("shield", 0.35, 0.85, 1, "off", "bar"),
            others = Group("circle", 0.75, 0.75, 0.75, "off", "sphere", 0.6, false),
        },

        -- Icon layout (shared by all groups)
        icon_anchor = "CENTER",
        icon_offset_x = 0,
        icon_offset_y = 8,
        icon_size = 15,

        -- Health bar layout (shared by the groups using the bar)
        bar_anchor = "CENTER",
        bar_offset_x = 0,
        bar_offset_y = -8,
        bar_width = 50,
        bar_height = 5,
        bar_color_mode = "class",
        bar_color = { r = 0.2, g = 0.85, b = 0.3 },
        bar_bg_mode = "tinted",
        bar_bg_color = { r = 0.1, g = 0.1, b = 0.1 },
        bar_bg_alpha = 0.7,
        bar_border = true,
        bar_texture = "smooth",

        -- Health sphere layout (shared by the groups using the sphere)
        sphere_anchor = "CENTER",
        sphere_offset_x = 0,
        sphere_offset_y = -8,
        sphere_size = 12,
        sphere_color_mode = "class",
        sphere_color = { r = 0.2, g = 0.85, b = 0.3 },
        sphere_bg_mode = "tinted",
        sphere_bg_color = { r = 0.1, g = 0.1, b = 0.1 },
        sphere_bg_alpha = 0.7,
        sphere_border = true,
        sphere_shine = true,
        sphere_texture = "smooth",

        -- Layer
        strata = "INHERIT",
        frame_level = 20,
        alpha = 1,
    },
}

-- Converts settings saved by older versions.
function Options.Migrate(profile)
    for _, key in ipairs(Groups.LIST) do
        local group = profile.groups[key]
        if group.show_health ~= nil then -- was an on/off toggle
            group.health_mode = group.show_health and "always" or "off"
            group.show_health = nil
        end
    end
    profile.bar_style = nil -- the style is now set per group
end

---------------------------------------------------------
-- Lists

local function GetAnchorOptions()
    local values = {}
    for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
                             "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
        values[point] = L["FP.list.anchor." .. point]
    end
    return values
end

local STRATA_SORTING = { "INHERIT", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }

local function GetStrataOptions()
    local values = {}
    for _, strata in ipairs(STRATA_SORTING) do
        values[strata] = L["FP.list.strata." .. strata]
    end
    return values
end

---------------------------------------------------------
-- Changes

local function OnChanged()
    FriendPlates:RefreshAll()
end

local function ColorGet(tbl)
    return tbl.r, tbl.g, tbl.b
end

local function ColorSet(tbl, r, g, b)
    tbl.r, tbl.g, tbl.b = r, g, b
end

---------------------------------------------------------
-- Group options

local function GroupOptions(key, order)
    local function G()
        return Options.db.groups[key]
    end
    local function Get(info)
        return G()[info.arg]
    end
    local function Set(info, value)
        G()[info.arg] = value
        OnChanged()
    end
    local function Off()
        return not G().enabled
    end

    local function IconValues()
        local values = {}
        local c = G().icon_color
        for _, icon in ipairs(Icons.LIST) do
            values[icon.key] = Icons.Markup(icon.key, 16, c.r, c.g, c.b) .. " " .. L["FP.icon." .. icon.key]
        end
        return values
    end
    local iconSorting = {}
    for _, icon in ipairs(Icons.LIST) do
        iconSorting[#iconSorting + 1] = icon.key
    end

    return {
        type = "group",
        name = function()
            local g = G()
            local c = g.icon_color
            local text = Icons.Markup(g.icon, 16, c.r, c.g, c.b) .. " " .. L["FP.group." .. key]
            return g.enabled and text or ("|cff808080" .. L["FP.group." .. key] .. "|r")
        end,
        order = order,
        get = Get,
        set = Set,
        args = {
            help = {
                type = "description",
                name = L["FP.group." .. key .. ".desc"],
                order = 0,
                fontSize = "medium",
            },
            enabled = {
                type = "toggle",
                name = L["FP.options.group.enabled"],
                desc = L["FP.options.group.enabled.desc"],
                arg = "enabled",
                order = 1,
                width = "full",
            },
            header_icon = {
                type = "header",
                name = L["FP.options.group.icon_header"],
                order = 10,
            },
            show_icon = {
                type = "toggle",
                name = L["FP.options.group.show_icon"],
                arg = "show_icon",
                order = 11,
                disabled = Off,
            },
            icon = {
                type = "select",
                name = L["FP.options.group.icon"],
                values = IconValues,
                sorting = iconSorting,
                arg = "icon",
                order = 12,
                disabled = function() return Off() or not G().show_icon end,
            },
            icon_scale = {
                type = "range",
                name = L["FP.options.group.icon_scale"],
                desc = L["FP.options.group.icon_scale.desc"],
                min = 0.25, max = 3, step = 0.05, isPercent = true,
                arg = "icon_scale",
                order = 13,
                disabled = function() return Off() or not G().show_icon end,
            },
            icon_color_mode = {
                type = "select",
                name = L["FP.options.group.icon_color_mode"],
                desc = L["FP.options.group.icon_color_mode.desc"],
                values = {
                    custom = L["FP.list.color.custom"],
                    class = L["FP.list.color.class"],
                },
                sorting = { "custom", "class" },
                arg = "icon_color_mode",
                order = 14,
                disabled = function() return Off() or not G().show_icon or not Icons.IsTinted(G().icon) end,
            },
            icon_color = {
                type = "color",
                name = L["FP.options.group.icon_color"],
                desc = L["FP.options.group.icon_color.desc"],
                order = 15,
                get = function() return ColorGet(G().icon_color) end,
                set = function(_, r, g, b)
                    ColorSet(G().icon_color, r, g, b)
                    OnChanged()
                end,
                disabled = Off,
            },
            header_health = {
                type = "header",
                name = L["FP.options.group.health_header"],
                order = 20,
            },
            health_mode = {
                type = "select",
                name = L["FP.options.group.health_mode"],
                desc = L["FP.options.group.health_mode.desc"],
                values = {
                    off = L["FP.list.health.off"],
                    always = L["FP.list.health.always"],
                    missing = L["FP.list.health.missing"],
                },
                sorting = { "off", "always", "missing" },
                arg = "health_mode",
                order = 21,
                disabled = Off,
            },
            health_style = {
                type = "select",
                name = L["FP.options.group.health_style"],
                desc = L["FP.options.group.health_style.desc"],
                values = {
                    bar = L["FP.list.health_style.bar"],
                    sphere = L["FP.list.health_style.sphere"],
                },
                sorting = { "bar", "sphere" },
                arg = "health_style",
                order = 22,
                disabled = function() return Off() or G().health_mode == "off" end,
            },
            header_default = {
                type = "header",
                name = L["FP.options.group.default_header"],
                order = 30,
            },
            default_help = {
                type = "description",
                name = L["FP.options.group.default_help"],
                order = 31,
            },
            hide_name = {
                type = "toggle",
                name = L["FP.options.group.hide_name"],
                arg = "hide_name",
                order = 32,
                disabled = Off,
            },
            hide_health = {
                type = "toggle",
                name = L["FP.options.group.hide_health"],
                arg = "hide_health",
                order = 33,
                disabled = Off,
            },
            hide_cast = {
                type = "toggle",
                name = L["FP.options.group.hide_cast"],
                arg = "hide_cast",
                order = 34,
                disabled = Off,
            },
        },
    }
end

local function GroupsArgs()
    local args = {
        help = {
            type = "description",
            name = L["FP.options.groups.help"],
            order = 0,
            fontSize = "medium",
        },
    }
    for i, key in ipairs(Groups.LIST) do
        args["group_" .. key] = GroupOptions(key, i)
    end
    return args
end

---------------------------------------------------------
-- Options table

local function GeneralGet(info)
    return Options.db[info.arg]
end

local function GeneralSet(info, value)
    Options.db[info.arg] = value
    FriendPlates:ApplySettings()
end

-- Friendly player nameplates: the CVar name is the same in Retail and Classic, the
-- second one is a guess kept in case a patch renames it.
local FRIEND_CVARS = { "nameplateShowFriends", "nameplateShowFriendlyPlayers" }

local function FriendCVar()
    for _, name in ipairs(FRIEND_CVARS) do
        if C_CVar.GetCVar(name) ~= nil then
            return name
        end
    end
    return nil
end

local function ColorOption(field, name, order, disabled)
    return {
        type = "color",
        name = name,
        order = order,
        disabled = disabled,
        get = function() return ColorGet(Options.db[field]) end,
        set = function(_, r, g, b)
            ColorSet(Options.db[field], r, g, b)
            OnChanged()
        end,
    }
end

-- Layout options of one health style. prefix: "bar" or "sphere" (fields "<prefix>_...").
local function HealthLayoutArgs(prefix, order)
    local function F(name)
        return prefix .. "_" .. name
    end
    local args = {}
    local function Add(name, option)
        option.order = order + option.order
        args[F(name)] = option
    end
    local function Range(name, label, min, max, softMin, softMax, o)
        Add(name, {
            type = "range", name = label, arg = F(name), order = o,
            min = min, max = max, softMin = softMin, softMax = softMax, step = 1,
        })
    end

    Add("header", { type = "header", name = L["FP.options.layout." .. prefix], order = 0 })
    Add("anchor", {
        type = "select",
        name = L["FP.options.layout.anchor"],
        desc = L["FP.options.layout.anchor.desc"],
        values = GetAnchorOptions,
        arg = F("anchor"),
        order = 1,
    })
    Add("texture", {
        type = "select",
        name = L["FP.options.layout.bar_texture"],
        desc = L["FP.options.layout.bar_texture.desc"],
        values = function()
            return (BarTextures.Options(function(key) return L["FP.bar_texture." .. key] end))
        end,
        sorting = function()
            local _, sorting = BarTextures.Options(function(key) return key end)
            return sorting
        end,
        arg = F("texture"),
        order = 2,
    })
    Range("offset_x", L["FP.options.layout.offset_x"], -200, 200, -100, 100, 3)
    Range("offset_y", L["FP.options.layout.offset_y"], -200, 200, -100, 100, 4)
    if prefix == "sphere" then
        Range("size", L["FP.options.layout.sphere_size"], 4, 96, 6, 48, 5)
    else
        Range("width", L["FP.options.layout.bar_width"], 10, 300, 10, 200, 5)
        Range("height", L["FP.options.layout.bar_height"], 1, 40, 1, 20, 6)
    end
    Add("color_mode", {
        type = "select",
        name = L["FP.options.layout.bar_color_mode"],
        values = {
            class = L["FP.list.color.class"],
            group = L["FP.list.color.group"],
            custom = L["FP.list.color.fixed"],
        },
        sorting = { "class", "group", "custom" },
        arg = F("color_mode"),
        order = 7,
    })
    Add("color", ColorOption(F("color"), L["FP.options.layout.bar_color"], 8,
        function() return Options.db[F("color_mode")] ~= "custom" end))
    Add("bg_mode", {
        type = "select",
        name = L["FP.options.layout.bar_bg_mode"],
        desc = L["FP.options.layout.bar_bg_mode.desc"],
        values = {
            tinted = L["FP.list.bg.tinted"],
            black = L["FP.list.bg.black"],
            custom = L["FP.list.bg.custom"],
        },
        sorting = { "tinted", "black", "custom" },
        arg = F("bg_mode"),
        order = 9,
    })
    Add("bg_color", ColorOption(F("bg_color"), L["FP.options.layout.bar_bg_color"], 10,
        function() return Options.db[F("bg_mode")] ~= "custom" end))
    Add("bg_alpha", {
        type = "range",
        name = L["FP.options.layout.bar_bg_alpha"],
        min = 0, max = 1, step = 0.05, isPercent = true,
        arg = F("bg_alpha"),
        order = 11,
    })
    Add("border", {
        type = "toggle",
        name = L["FP.options.layout.bar_border"],
        arg = F("border"),
        order = 12,
    })
    if prefix == "sphere" then
        Add("shine", {
            type = "toggle",
            name = L["FP.options.layout.sphere_shine"],
            desc = L["FP.options.layout.sphere_shine.desc"],
            arg = F("shine"),
            order = 13,
        })
    end
    return args
end

Options.options = {
    type = "group",
    name = L["FP.title"],
    desc = L["FP.desc"],
    childGroups = "tab",
    args = {
        tab_general = {
            type = "group",
            name = L["FP.options.tab_general.title"],
            order = 1,
            get = GeneralGet,
            set = GeneralSet,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["FP.options.enabled"],
                    desc = L["FP.options.enabled.desc"],
                    arg = "enabled",
                    order = 1,
                    width = "full",
                },
                friendly_plates = {
                    type = "toggle",
                    name = L["FP.options.friendly_plates"],
                    desc = L["FP.options.friendly_plates.desc"],
                    order = 2,
                    width = "full",
                    disabled = function() return FriendCVar() == nil end,
                    get = function()
                        local cvar = FriendCVar()
                        return cvar and C_CVar.GetCVarBool(cvar)
                    end,
                    set = function(_, value)
                        if InCombatLockdown() then
                            Utils.Print(L["FP.msg.combat"])
                            return
                        end
                        local cvar = FriendCVar()
                        if cvar then
                            C_CVar.SetCVar(cvar, value and "1" or "0")
                        end
                    end,
                },
                subgroup_is_party = {
                    type = "toggle",
                    name = L["FP.options.subgroup_is_party"],
                    desc = L["FP.options.subgroup_is_party.desc"],
                    arg = "subgroup_is_party",
                    order = 3,
                    width = "full",
                },
                bnet_friends = {
                    type = "toggle",
                    name = L["FP.options.bnet_friends"],
                    desc = L["FP.options.bnet_friends.desc"],
                    arg = "bnet_friends",
                    order = 4,
                    width = "full",
                },
            },
        },
        tab_groups = {
            type = "group",
            name = L["FP.options.tab_groups.title"],
            order = 2,
            childGroups = "tree",
            args = GroupsArgs(),
        },
        tab_layout = {
            type = "group",
            name = L["FP.options.tab_layout.title"],
            order = 3,
            get = GeneralGet,
            set = GeneralSet,
            args = {
                header_icon = {
                    type = "header",
                    name = L["FP.options.layout.icon"],
                    order = 1,
                },
                icon_anchor = {
                    type = "select",
                    name = L["FP.options.layout.anchor"],
                    desc = L["FP.options.layout.anchor.desc"],
                    values = GetAnchorOptions,
                    arg = "icon_anchor",
                    order = 2,
                },
                icon_size = {
                    type = "range",
                    name = L["FP.options.layout.icon_size"],
                    desc = L["FP.options.layout.icon_size.desc"],
                    min = 6, max = 96, softMin = 8, softMax = 64, step = 1,
                    arg = "icon_size",
                    order = 3,
                },
                icon_offset_x = {
                    type = "range",
                    name = L["FP.options.layout.offset_x"],
                    min = -200, max = 200, softMin = -100, softMax = 100, step = 1,
                    arg = "icon_offset_x",
                    order = 4,
                },
                icon_offset_y = {
                    type = "range",
                    name = L["FP.options.layout.offset_y"],
                    min = -200, max = 200, softMin = -100, softMax = 100, step = 1,
                    arg = "icon_offset_y",
                    order = 5,
                },
                header_layer = {
                    type = "header",
                    name = L["FP.options.layout.layer"],
                    order = 50,
                },
                strata = {
                    type = "select",
                    name = L["FP.options.layout.strata"],
                    desc = L["FP.options.layout.strata.desc"],
                    values = GetStrataOptions,
                    sorting = STRATA_SORTING,
                    arg = "strata",
                    order = 51,
                },
                frame_level = {
                    type = "range",
                    name = L["FP.options.layout.frame_level"],
                    desc = L["FP.options.layout.frame_level.desc"],
                    min = 0, max = 500, softMax = 100, step = 1,
                    arg = "frame_level",
                    order = 52,
                },
                alpha = {
                    type = "range",
                    name = L["FP.options.layout.alpha"],
                    min = 0.05, max = 1, step = 0.05, isPercent = true,
                    arg = "alpha",
                    order = 53,
                },
            },
        },
    },
}

-- Layout tab: one section per health style
for _, prefix in ipairs({ "bar", "sphere" }) do
    local order = prefix == "bar" and 10 or 30
    for key, option in pairs(HealthLayoutArgs(prefix, order)) do
        Options.options.args.tab_layout.args[key] = option
    end
end
