# CurseForge page

Paste the blocks below into the authors console. The research, the proposed TOC lines, and the owner's steps are in [RESEARCH.md](RESEARCH.md) and [CHECKLIST.md](CHECKLIST.md).

The Medallions pictures and the clip are in-game. The Frames, Orbs, ultrawide, setup and detail pictures are test renders of this addon, the same ones the README shows. Say that in the gallery captions. CurseForge asks for a visible note when a showcase picture could be read as something the addon does not do. These renders are the addon. The captions say which are which.

## Project name

KstyleUI

The [submission guide](https://support.curseforge.com/en/support/solutions/articles/9000199552-project-submission-guide-and-tips) asks for a distinct name, with no version number and no word such as "addon".

## Summary

Paste this one sentence. It is the README's pitch. The authors console rejects a summary longer than 256 characters (`summary.maxLength` 256 in the console). This one is 125.

```
A complete, pixel-perfect interface for World of Warcraft: Forever — one dark forged style, three HUDs, set up in one window.
```

The [moderation policies](https://support.curseforge.com/en/support/solutions/articles/9000197279-project-and-modpack-moderation-policies) call the summary a one-sentence tldr of what the project does.

## Moderation policy

The page follows CurseForge's [moderation policies](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies), checked on 2026-11-17:

- The summary is a one-sentence tl;dr and is not repeated as the description's first line.
- The description has no external download links: the optional icon pack, which is not an addon, is offered only on GitHub and is not linked here. Links to the source code and the issue tracker sit at the bottom of the page.
- A Credits section credits the bundled SIL Open Font License fonts and says the art is original to KstyleUI, with the AI-made pieces named.
- The name has no game name or version, the avatar is the 400x400 logo, the gallery has in-game pictures and labels the test renders, and every file carries the changelog.

## Description

On the Description step, switch the editor to Markdown, then paste this.

```markdown
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

1. Install this download with the CurseForge app on your Forever installation. By hand, unzip it into `World of Warcraft/_forever_/Interface/AddOns`, so that `KstyleUI` and the `KstyleUI_*` folders sit there.
2. Start the game. If the addons are not ticked on the character screen, tick them.
3. Log in. The setup opens. Pick your HUD, layout and modules, then click **Apply** and **Reload**.

## Links

- Source code: https://github.com/korallis/KstyleUI
- Issues: https://github.com/korallis/KstyleUI/issues

## Credits

- Fonts, all under the SIL Open Font License 1.1, with their licence files in the addon's `Media/Fonts` folder: Cinzel, Alegreya Sans, Barlow Semi Condensed, Source Sans 3, Inter, PT Serif, EB Garamond and IM Fell (the last three in KstyleUI's Folio faces). Some are adapted for the game's renderer and renamed, as the licence allows.
- All art is original to KstyleUI. The painted portraits, crests and some textures were made for this addon with AI image tools; the rest is drawn by KstyleUI's own code. No game art is extracted or traced.
- By korallis. All rights reserved.
```

## Class, categories, game version

- Game: World of Warcraft.
- Class: Addons.
- Game version: Forever. On the public addon list that flavor is [gameVersionTypeId 88568](https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568), and the patch is [1.60.1](https://www.curseforge.com/wow/search?class=addons&version=1.60.1). Do not tick Retail or Classic.
- Main category: Unit Frames. If the form offers the HUDs subcategory as the main choice, pick HUDs.
- Additional categories, up to four ([submission guide](https://support.curseforge.com/en/support/solutions/articles/9000199552-project-submission-guide-and-tips)): Action Bars, Map & Minimap, Bags & Inventory, Quests & Leveling.

## Licence

The TOC says `## X-License: All Rights Reserved`, and [LICENSE.md](../../LICENSE.md) says "Copyright 2026 the KstyleUI authors. All rights reserved." Pick **All Rights Reserved** if it is in the list. If it is not, pick **Custom** and paste that sentence. Do not pick a permissive licence. The bundled fonts keep their own SIL Open Font Licence. That stays in the repository. It is not the project licence.

## Links to set on the project

- Source: https://github.com/korallis/KstyleUI
- Issues: https://github.com/korallis/KstyleUI/issues

## Logo

`logo/curseforge-avatar.png`

400×400 PNG, the chamfered diamond, transparent outside the diamond. The console asks for a minimum of 400×400 at 1:1 ([submission guide](https://support.curseforge.com/en/support/solutions/articles/9000199552-project-submission-guide-and-tips): "at least minimum 400*400 px (1:1 scale) .png"; the console's own line is "Upload a minimum of 400px by 400px with 1:1 ratio image") and rejects an avatar over 102400 bytes. WebP avatars are warned off. This file is PNG and under that cap. It is not a filled square: the diamond is the mark, and the page behind it is dark.

## Gallery

CurseForge's submission guide tells you to add in-game screenshots on the Images tab, and moderation requires at least one gallery image. Neither that guide nor the authors console publishes a gallery pixel size. These files keep each README picture's own pixels. The hero is half of `docs/media/readme/game_medallions_hero.jpg` (5120×1440 down to 2560×720) so the page is not handed a 5K file. Stills are JPEG, as the README already stores them. The clip is a GIF. The console's image file control accepts `.png`, `.jpg`, `.jpeg`, `.gif` and `.webp`.

Upload in this order. Title, then caption.

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
