# Wago Addons page

Paste the blocks below on [the create-project page](https://addons.wago.io/developers/projects/create). The research, the proposed TOC lines, and the owner's steps are in [RESEARCH.md](RESEARCH.md) and [CHECKLIST.md](CHECKLIST.md).

Wago's public project stores a display name, a summary, a markdown description, categories, a thumbnail, gallery images with a description each, and source, website and issues URLs. [docs.wago.io](https://docs.wago.io/) documents the version-upload API, not these page fields. The description format below is the markdown Wago already renders (see [BigWigs](https://addons.wago.io/addons/bigwigs)). There is no published character limit. A page the length of this description is inside what that site already shows.

The hero picture is in-game. The clips and the HUD pictures are test renders of this addon over in-game screenshots.

## Project name

KstyleUI

## Summary

```
One dark forged UI for World of Warcraft: Forever. Pick Medallions or Frames for your HUD, get a class crest that lights up as you fight, and set it all up in one window.
```

## Description

The description field is markdown. Paste this. The block is [description.md](description.md) verbatim, regenerated with `python3 Tools/media/marketing.py --pages`; edit that file, not this block.

```markdown
![KstyleUI banner: the diamond logo and wordmark over a darkened in-game screenshot of the Medallions HUD](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/banner.jpg)

*In-game screenshot behind the wordmark. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon.*

**Come say hi on Discord: [discord.gg/A5qqGZEXyN](https://discord.gg/A5qqGZEXyN).** That's the place for help or a bug report, and new stuff shows up there before it ships.

KstyleUI swaps the default UI for one dark forged style, the same on your bars, frames, bags and windows. The HUD comes in two looks. Medallions puts you and your target in round medallions with your class crest between your action bars. Frames is the classic layout cleaned up, with your target stacked over you above the bars. It's made for World of Warcraft: Forever only, and setup is one window the first time you log in.

Every picture below is a test render of the addon over my own in-game screenshots. Icons in these pictures are the optional AI-made icon pack, not art shipped in the addon.

![KstyleUI test render over an in-game screenshot: a warrior's, a warlock's and a cat druid's crests coming alive as their buffs, debuffs and cooldowns land, with no icons on them](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/trackers.gif)

*No more little icons. Your buffs, procs, debuffs and cooldowns are part of the crest now: a war horn and perched weapons for warriors, Curses and Stings burning down the ring for warlocks and hunters, a dome of light for priests and rakes tearing across it for cats.*

![KstyleUI test render over an in-game screenshot: the crest effects in turn: fire on a big cooldown, the glyph tide, the cast ring, the kill window and the target lock](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/effects.gif)

*Ten new effects inspired by the old WeakAuras centre-piece UIs. A big cooldown sets the crest on fire, the glyphs fill with your power, your cast runs round the edge, the rim burns red in Execute range and claws close on a new target. Every piece has its own switch in `/kstyle`.*

![KstyleUI test render over an in-game screenshot of the Frames look: a warrior's crest pieces standing free above the stance bar](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/show_frames_medals.jpg)

*On Frames the same pieces stand free above your stance bar.*

![KstyleUI test render over an in-game screenshot: the Medallions HUD for nine classes in turn, each with its own crest](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/classes.gif)

*Every class gets its own crest, and most of them get a crown on top.*

![KstyleUI test render over an in-game screenshot: a rogue's crown of blades and a cat druid's claws filling with combo points, then a finisher slashing them out](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/crowns.gif)

*Rogues get a crown of blades and cat druids get claws. Each combo point lights one, and a finisher slashes them out.*

![KstyleUI test render over an in-game screenshot: warrior banners, priest candles, mage shards, hunter arrows and bear talons filling up on the crest](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/crowns-more.gif)

*Warriors get banners for Sunder, shadow priests candles, mages Arcane Blast shards, hunters arrows and bears talons for Lacerate.*

![KstyleUI test render over an in-game screenshot: a shaman's totem bar on the crest, then Lightning Shield's three storm orbs throwing bolts](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/shaman.gif)

*I put way too much effort into shamans. Your totem bar sits on the crest and Lightning Shield turns into storm orbs that throw a bolt as each charge goes.*

![KstyleUI test render over an in-game screenshot: a hunter's hawk perches lighting up with a timer for each hawk](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/hawks.gif)

*Hunters with Summon Hawk get a perch on the ring for each hawk, with a timer round it. Baine's idea.*

![KstyleUI test render over an in-game screenshot of the whole HUD on a 1920 by 1080 screen: the guide card top left, the quests on the right under the map](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/show_hud_1080.jpg)

*The whole thing in Medallions. Your RestedXP or Zygor guide sits top left and your quests sit on the right under the map.*

![KstyleUI test render over an in-game screenshot of the middle of the Medallions HUD: the player and target frames with lit glass bars, docked into the crest](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/show_hud_finish.jpg)

*Every bar has a lit glass finish, and the Medallions frames dock right into the crest.*

![KstyleUI test render over an in-game screenshot: the action bars and player frame fading back out of combat, then snapping back when a target is picked](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/rest.gif)

*Out of combat with nothing targeted, your bars fade back so you can see the game. Target something and they're straight back.*

![KstyleUI test render over an in-game screenshot: a target's cast bar naming who the spell is aimed at, then YOU, a shield on a cast you can't interrupt, and a dim bar with a gold mark while your interrupt recharges](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/casts.gif)

*Enemy cast bars say who the spell is aimed at, or YOU. A shield means you can't kick it, and a gold mark shows where your kick is back.*

![KstyleUI test render over an in-game screenshot of the Frames look on a 1920 by 1080 screen: the target's card stacked over the player's above the action bars](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/show_hud_frames_1080.jpg)

*If the crest isn't your thing, Frames is the other look: big plain cards for you and your target, same forged style. Switch any time in `/kstyle`.*

![KstyleUI test render over an in-game screenshot of the raid frames: twenty tiles with missing health, debuffs, a dead and an offline member](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/show_frame_raid.jpg)

*Party and raid frames get the same look, with the debuffs you can dispel up front.*

![KstyleUI test render over an in-game screenshot, with the game's own map art: a route to the Undercity by road and zeppelin, then the Nearest innkeeper, bank and trainer picker](https://raw.githubusercontent.com/korallis/KstyleUI/main/docs/media/marketing/map.gif)

*The map plans your route, zeppelins and the tram included, and finds the nearest innkeeper, bank or trainer you've been to. The map art is the game's own.*

There's a lot more: nameplates, a damage and threat meter, bags, tooltips, chat and skins for most of Blizzard's windows. Every bit of it can be switched off in `/kstyle`. Each module has a README on [GitHub](https://github.com/korallis/KstyleUI) with all its settings.

## Install

1. Install it with the CurseForge app, the Wago app or WowUp. By hand, unzip it into `World of Warcraft/_forever_/Interface/AddOns`.
2. Log in, pick Medallions or Frames and a Look, then DPS, Tank or Healer in the setup window, then click **Apply** and **Reload**.
3. `/kstyle` opens the settings, `/kstyle layout` lets you move stuff and `/kb` binds your keys.

The icon pack is optional and isn't an addon, so it's only on [GitHub](https://github.com/korallis/KstyleUI/releases/latest). The [icon pack guide](https://github.com/korallis/KstyleUI/blob/main/docs/icons.md) has the steps.

## Links

- Help, bug reports and news: [Discord](https://discord.gg/A5qqGZEXyN). For a bug, paste the report from About > Status in `/kstyle`.
- Source code: https://github.com/korallis/KstyleUI

## Credits

- Fonts, all under the SIL Open Font License 1.1, with their licence files in the addon's `Media/Fonts` folder: Cinzel, Alegreya Sans, Barlow Semi Condensed, Source Sans 3, Inter, PT Serif, EB Garamond and IM Fell. Some are adapted for the game's renderer and renamed, as the licence allows.
- The portraits, crests and textures are KstyleUI's own art. Some were made with AI image tools and the rest is drawn by the addon's code. Nothing is extracted or traced from the game. The scenery in the pictures is cropped from my own Forever screenshots, and none of it is AI-generated.
- Zygor support and the hawk perches idea: Baine.
- By the KstyleUI authors. All rights reserved.
```

## Game version

Forever, patch 1.60.1. That is the only Forever patch [the game-data API](https://addons.wago.io/api/data/game) lists (`patches.forever` and `live_patches.supported_forever_patches`). Do not tick Retail or Classic. The packager sets `supported_forever_patches` on each upload. You only pick the flavor when the project is created, if the form asks.

## Categories

Wago has no separate tag field on a public project. It has categories, from [the category API](https://addons.wago.io/api/data/categories). Pick these. Unit Frames is the one to lead with. The others are the same four CurseForge is given, and the project model stores a list, so more than one is allowed.

- Unit Frames
- Action Bars
- Map & Minimap
- Bags & Inventory
- Quests & Leveling

## Licence

Same as the TOC: All Rights Reserved. [Plater's Wago page](https://addons.wago.io/addons/plater-nameplates) stores that as the licence URL `https://en.wikipedia.org/wiki/All_rights_reserved`. Use that URL if the form wants a link, or leave the URL empty and keep the sentence in the description. The sentence in the repository is "Copyright 2026 the KstyleUI authors. All rights reserved." Do not pick a permissive licence.

## Links to set on the project

- Source: https://github.com/korallis/KstyleUI
- Website: https://github.com/korallis/KstyleUI
- Issues (the support URL): https://discord.gg/A5qqGZEXyN

## Logo

`logo/wago-icon.png`

64×64 PNG, the same diamond, transparent outside it. [docs.wago.io](https://docs.wago.io/) does not publish an icon size. The thumbnail Wago serves for a project, measured from Plater's `thumbnail_image` on 2026-11-17, is 64×64 PNG, and the listing draws it at 64×64 CSS on a dark card (`bg-background-700`). A transparent diamond sits on that dark card the way the in-game icon sits on the UI. If the form refuses a file this small, upload `logo/curseforge-avatar.png` (400×400, the same drawing) and let Wago scale it.

## Gallery

[docs.wago.io](https://docs.wago.io/) does not publish a gallery pixel size. A live gallery, [LearnItAll](https://addons.wago.io/addons/learnitall/gallery), stores PNG and GIF files and a description on each, ten to a page. Use the same files as CurseForge: the README's pictures and clips, with the 5120-wide hero halved to 2560×720.

Upload in this order. The gallery description is the caption.

| File | Pixels | Title | Caption |
| --- | --- | --- | --- |
| `gallery/01-medallions-hero.jpg` | 2560×720 | Medallions on an ultrawide screen | In-game screenshot: the Medallions HUD on a 5120 by 1440 screen, in Shen'dar Village. Other players' names and chat are blurred. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/02-classes.gif` | 800×258 | A crest for every class | KstyleUI test render over an in-game screenshot: the Medallions HUD for nine classes in turn, each with its own crest. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/03-crowns.gif` | 800×620 | Crown of blades and claws | KstyleUI test render over an in-game screenshot: a rogue's crown of blades and a cat druid's claws fill with combo points, then a finisher slashes them out. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/04-crowns-more.gif` | 800×620 | Class crowns | KstyleUI test render over an in-game screenshot: warrior banners, priest candles, mage shards, hunter arrows and bear talons fill as their stacks build. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/05-shaman.gif` | 800×620 | Totems and Lightning Shield | KstyleUI test render over an in-game screenshot: the shaman's totem bar on the crest, then Lightning Shield's storm orbs, each throwing a bolt as its charge is spent. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/06-hawks.gif` | 800×620 | Hawk perches | KstyleUI test render over an in-game screenshot: a hunter's hawk perches on the crest ring, each with a timer for its hawk. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/07-hud.jpg` | 1920×1080 | The whole HUD | KstyleUI test render over an in-game screenshot of the whole HUD on a 1920 by 1080 screen: the guide card top left, the quests on the right under the map. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/08-frames.jpg` | 1200×675 | The Frames look | KstyleUI test render over an in-game screenshot of the Frames look on a 1920 by 1080 screen: the target's card stacked over the player's above the action bars. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/09-rest.gif` | 800×261 | Clean screen at rest | KstyleUI test render over an in-game screenshot: out of combat with no target, the bars and player frame fade back, then a target brings them straight back. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/10-casts.gif` | 800×264 | Who a cast is aimed at | KstyleUI test render over an in-game screenshot: a target's cast bar names who the spell is aimed at, says YOU, shields a cast you can't interrupt, then dims with a gold mark while your interrupt recharges. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/11-map.gif` | 800×634 | Routes and nearest services | KstyleUI test render over an in-game screenshot, with the game's own map art: a route to the Undercity by road and zeppelin, then the Nearest picker for innkeepers, banks and trainers. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/12-trackers.gif` | 800×620 | The crest comes alive | KstyleUI test render over an in-game screenshot: warrior, warlock and cat druid crests come alive as buffs, debuffs and cooldowns land on the crest itself. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/13-frames-medals.jpg` | 1600×468 | Crest pieces on Frames | KstyleUI test render over an in-game screenshot of the Frames look: a warrior's crest pieces standing free above the stance bar. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |
| `gallery/14-effects.gif` | 800×620 | Crest effects | KstyleUI test render over an in-game screenshot: the crest catching fire on a big cooldown, then the glyph tide, the cast ring, the kill window and the target lock. Icons in this picture are the optional AI-made icon pack, not art shipped in the addon. |

The upload page for a project, once it exists, is `https://addons.wago.io/developers/projects/<slug>/gallery/create`.
