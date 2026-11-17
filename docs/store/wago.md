# Wago Addons page

Paste the blocks below on [the create-project page](https://addons.wago.io/developers/projects/create). The research, the proposed TOC lines, and the owner's steps are in [RESEARCH.md](RESEARCH.md) and [CHECKLIST.md](CHECKLIST.md).

Wago's public project stores a display name, a summary, a markdown description, categories, a thumbnail, gallery images with a description each, and source, website and issues URLs. [docs.wago.io](https://docs.wago.io/) documents the version-upload API, not these page fields. The description format below is the markdown Wago already renders (see [BigWigs](https://addons.wago.io/addons/bigwigs)). There is no published character limit. A page the length of this description is inside what that site already shows.

The Medallions pictures and the clip are in-game. The Frames, Orbs, ultrawide, setup and detail pictures are test renders of this addon.

## Project name

KstyleUI

## Summary

```
A complete, pixel-perfect interface for World of Warcraft: Forever — one dark forged style, three HUDs, set up in one window.
```

## Description

The description field is markdown. Paste this.

```markdown
A complete, pixel-perfect interface for World of Warcraft: Forever — one dark forged style, three HUDs, set up in one window.

Pick your HUD. **Medallions** puts a painted portrait of your character and a crest for your race and class over a dark gunmetal action slab. **Frames** keeps classic cards, your target stacked over you. **Orbs** puts health and resource in two orbs round a forged tray. Everything else follows: clean bars, readable nameplates, a group damage meter, quest and guide cards, and a size that lands on whole screen pixels from a laptop to a 32:9 ultrawide.

## Three HUD styles

**Medallions** is dark gunmetal with rounded, bevelled edges. Your player and target frames are slabs with a round medallion on the outer end. Yours is a painted portrait of your race, class and sex. A creature, pet or boss shows the game's own portrait. Your first two action bars sit in one dark slab, with a crest painted for your race and class in the middle. At rest the crest breathes.

**Frames** keeps your health and resource on a player card above the action bars, with your target's card stacked over it.

**Orbs** puts your health and resource in two orbs either side of a forged tray, and moves your target to a wide bar at the top of the screen.

Switch any time in **Options, General, HUD style**. Out of combat the change applies at once. Picked in combat, it waits for the fight to end.

## The rest of the screen

Health and resource fill flat and clean. Nameplates are plain bars that stay a steady size. The damage meter is one card with a bar per player in their class colour. On the right, a square map card, a quest card and, when you use it, the RestedXP guide card. On a 21:9 or 32:9 monitor, **Centred** keeps the HUD in a band in the middle, and **Spread** moves the side columns out to the edges.

The first time you log in, a short setup walks you through the HUD, the layout and the modules. Run it again with `/kstyle setup`. Type `/kstyle` for the settings.

The Medallions pictures and the clip in the gallery are in-game. The Frames, Orbs, ultrawide, setup and detail pictures are test renders of this addon.

## Install

KstyleUI runs on the World of Warcraft: Forever client.

1. Install this download with the Wago app on your Forever installation. By hand, unzip it into `World of Warcraft/_forever_/Interface/AddOns`, so that `KstyleUI` and the `KstyleUI_*` folders sit there.
2. Start the game. If the addons are not ticked on the character screen, tick them.
3. Log in. The setup opens. Pick your HUD, layout and modules, then click **Apply** and **Reload**.

The optional icon pack, which repaints ability and item icons, is a separate zip on the [GitHub release](https://github.com/korallis/KstyleUI/releases/latest). It is not an addon, so this page's file does not include it. Quit the game, copy its `Interface` folder into `World of Warcraft/_forever_/`, and start the game again.

## Links

- Source and releases: https://github.com/korallis/KstyleUI
- Issues: https://github.com/korallis/KstyleUI/issues
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
- Issues (the support URL): https://github.com/korallis/KstyleUI/issues

## Logo

`logo/wago-icon.png`

64×64 PNG, the same diamond, transparent outside it. [docs.wago.io](https://docs.wago.io/) does not publish an icon size. The thumbnail Wago serves for a project, measured from Plater's `thumbnail_image` on 2026-11-17, is 64×64 PNG, and the listing draws it at 64×64 CSS on a dark card (`bg-background-700`). A transparent diamond sits on that dark card the way the in-game icon sits on the UI. If the form refuses a file this small, upload `logo/curseforge-avatar.png` (400×400, the same drawing) and let Wago scale it.

## Gallery

[docs.wago.io](https://docs.wago.io/) does not publish a gallery pixel size. A live gallery, [LearnItAll](https://addons.wago.io/addons/learnitall/gallery), stores PNG and GIF files and a description on each, ten to a page. Use the same files as CurseForge. They keep the README pictures' own pixels, with the 5120-wide hero halved to 2560×720.

Upload in this order. The gallery description is the caption.

| File | Pixels | Title | Caption |
| --- | --- | --- | --- |
| `gallery/01-medallions-hero.jpg` | 2560×720 | Medallions on an ultrawide screen | In-game: the Medallions HUD on a 5120 by 1440 screen, in Tirisfal Glades. Chat and distant player names are blurred. |
| `gallery/02-style-medallions.jpg` | 1280×720 | Medallions | In-game Medallions HUD in combat, cropped to 16:9 from the ultrawide screenshot. |
| `gallery/03-style-frames.jpg` | 1200×675 | Frames | Test render of the Frames HUD in combat on a 1920 by 1080 screen. |
| `gallery/04-style-orbs.jpg` | 1200×675 | Orbs | Test render of the Orbs HUD in combat on a 1920 by 1080 screen. |
| `gallery/05-ultrawide-spread.jpg` | 1600×450 | Ultrawide, Spread | Test render of the Healer layout on a 5120 by 1440 screen, in the Spread arrangement. The side columns sit at the edges. |
| `gallery/06-setup.jpg` | 720×523 | First-run setup | Test render of the first-run setup on its layout step: DPS, Tank and Healer, with a preview under the pointer. |
| `gallery/07-nameplates.jpg` | 800×466 | Nameplates | Test render of the nameplates in combat: a targeted beast, an elite, a rare, a world boss and a friendly player. |
| `gallery/08-meter.jpg` | 540×300 | Damage meter | Test render of the damage meter in a party of five, one class-coloured bar per player. |
| `gallery/09-quests.jpg` | 660×624 | Map, quests and guide | Test render of the right rail: the map card, the quest card and the guide card. |
| `gallery/10-medallion-closeup.gif` | 960×199 | Target medallion | In-game: selecting a target brings in the target medallion, and its red ring pulses at low health. |

The upload page for a project, once it exists, is `https://addons.wago.io/developers/projects/<slug>/gallery/create`.
