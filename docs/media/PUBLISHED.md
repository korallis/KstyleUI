# Published picture inventory

The same master description ([docs/store/description.md](../store/description.md)) generates the README, CurseForge and Wago pages. Every picture on them is listed here. Filenames are relative to `docs/media/`.

| Picture | What it is | Made by |
| --- | --- | --- |
| marketing/banner.jpg | Real in-game screenshot (readme/game_medallions_hero.jpg), darkened, with the logo and wordmark | `marketing.py` |
| marketing/classes.gif | Test render over the real forest plate: the Medallions HUD for nine classes | `marketing.py --clips` |
| marketing/crowns.gif | Test render over the real forest plate: rogue blades and cat druid claws with the ring's jewels, gain to spend | `marketing.py --clips` |
| marketing/crowns-more.gif | Test render over the real forest plate: warrior, priest, mage, hunter and bear crowns | `marketing.py --clips` |
| marketing/shaman.gif | Test render over the real forest plate: Spirit Poles, then Lightning Shield's storm orbs | `marketing.py --clips` |
| marketing/hawks.gif | Test render over the real forest plate: the hunter's hawk perches | `marketing.py --clips` |
| marketing/trackers.gif | Test render over the real forest plate: warrior, warlock and cat druid crests playing their stories | `marketing.py --clips` (`Tools/render/clip.lua`) |
| marketing/effects.gif | Test render over the real forest plate: cooldown fire (Unleashed), glyph tide, cast ring, kill window and target lock | `marketing.py --clips` (`Tools/render/clip.lua`) |
| marketing/rest.gif | Test render over the real forest plate: the bars fading back at rest, then back for a target | `marketing.py --clips` |
| marketing/casts.gif | Test render over the real forest plate: the target's cast bar naming its target, YOU, a shield and the interrupt mark | `marketing.py --clips` |
| marketing/map.gif | Test render over the real forest plate, with the client's own map art: a route by road and zeppelin, then the Nearest picker | `marketing.py --clips` (`RENDER_MAP_ART`) |
| marketing/show_hud_1080.jpg | Test render over the real forest plate (readme/hud_1080.jpg): the whole HUD at 1920 by 1080 | `readme.py`, `marketing.py` |
| marketing/show_hud_finish.jpg | Test render over the real forest plate (readme/hud_finish.jpg): the middle of the HUD at twice the size, bar end to bar end | `readme.py`, `marketing.py` |
| marketing/show_hud_frames_1080.jpg | Test render over the real forest plate (readme/hud_frames_1080.jpg): the Frames look at 1920 by 1080 | `readme.py`, `marketing.py` |
| marketing/show_frame_raid.jpg | Test render over the real forest-mac plate (readme/frame_raid.jpg): the raid frames | `readme.py`, `marketing.py` |
| marketing/show_frames_medals.jpg | Test render over the real forest plate (readme/frames_medals.jpg): a warrior's crest pieces above the Frames stance bar | `readme.py`, `marketing.py` |

The store gallery (`docs/store/gallery/`) holds copies of the hero, the clips and the HUD picture, in upload order.

Rebuild everything with `python Tools/render/readme.py && python Tools/media/marketing.py --clips --pages`. The clips need LuaJIT and Chrome (set `CHROME` to its binary); every run renders every frame fresh from the tree it runs in, so nothing stale is reused. `python Tools/media/marketing.py --clips trackers.gif effects.gif` retakes the two crest stories alone: `Tools/render/clip.lua` plays each segment in `marketing.DRIVEN` on one moving clock.
Every test render carries a visible source label inside the picture and in its alt text. The page's note above the clips and every gallery caption disclose the optional AI-made icon pack.
Plate crops and the in-game capture wish list are in [PROVENANCE.md](plates/PROVENANCE.md).
