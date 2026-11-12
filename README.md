# FriendPlates

A World of Warcraft addon that makes friendly player nameplates easy to read: each friendly player gets a **marker icon** that tells you who they are to you (party, raid, friend, guild or just another player), an optional **simple health bar**, and the clutter of the default nameplate (name, health bar, cast bar) can be hidden.

Built for **WoW Forever** (`FriendPlates_Camelot.toc`), also works on **Retail** (`FriendPlates.toc`).

It is a standalone addon. The icon and health bar attach to the game's own nameplate frames, so they show with Platynator, Plater, other nameplate addons and the default nameplates alike.

## Groups

Every friendly player falls into the **first enabled group** they belong to, in this order:

| Group | Who | Default icon | Default health |
|---|---|---|---|
| Party | Your party (and, by default, your own raid subgroup) | Green arrow | Always, bar |
| Raid | The rest of your raid | Orange arrow | Always, bar |
| Friends | Your friend list, plus Battle.net friends (optional) | Pink heart | Off (bar) |
| Guild | Your guild | Blue shield | Off (bar) |
| Other players | Every other friendly player (group disabled by default) | Small grey circle | Off (sphere) |

Disabling a group makes its players fall to the next group. **Other players** is disabled by default, so strangers' nameplates are left untouched. Enable it to mark them too.

Each group has its own settings:

- **Marker icon:** on/off, which icon, scale, and color (group color or class color).
- **Health:** show it Off, Always, or When not full (only while the player is missing health), as a **Bar** or a **Sphere** (a round orb that fills from bottom to top).
- **Default nameplate:** hide the name, the health bar and/or the cast bar. By default the name and health bar are hidden for every group, so only the icon (and the simple health bar, where enabled) remain.

## Layout

The **Layout** tab is shared by all groups. It has separate sections:

- **Marker icon:** anchor, offset and base size.
- **Health bar** (used by groups set to Bar): anchor, offset, width, height, texture, fill color (class, group or custom), background style (dark fill color, black or custom), background opacity and border.
- **Health sphere** (used by groups set to Sphere): the same settings, with a size instead of width and height.
- **Layer:** strata, frame level and opacity.

## Icons

| Kind | Icons |
|---|---|
| Shapes (colored per group) | Arrow, triangle, circle, ring, diamond, square, star, heart, shield, plus |
| Class icon | The player's class icon |
| Raid markers | Star, circle, diamond, triangle, moon, square, cross, skull |

The shapes are 64x64 white TGA files made by `Tools/make_icons.py` (plain Python, no dependencies). To change or add a shape, edit the script and run it again. Raid markers and class icons are textures that ship with the game.

The health bar texture can be Smooth (the default, also made by the script), Blizzard, Flat, Raid frame or Skills bar. If another addon loads LibSharedMedia, its status bar textures are listed too. The sphere uses the same texture, cut to a circle, with shading, an optional shine and a ring (`sphere_mask`, `sphere_shade`, `sphere_shine`, `sphere_ring`, also made by the script).

## Limitations

- Friendly player nameplates must be enabled. There is a toggle in the General tab.
- Friendly nameplates inside dungeons and raids are locked by the game, so addons cannot change them there.
- Hiding the name, health bar or cast bar only works with the default nameplates. With another nameplate addon, use its own settings for that; the FriendPlates icon and bar still show.
- On Retail the game can hide health values from addons in combat. Then "When not full" cannot tell, and the bar shows.
- Friends are matched by character. Battle.net friends only count while they are online on a character.

## Usage

`/fp` or `/friendplates` opens the options. They are also in the game's AddOns settings.

`/fp debug` prints one line per visible friendly player: its group, health setting, how "When not full" reads its health, and whether the bar is shown.
