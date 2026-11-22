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
| marketing/show_hud_1080.jpg | Test render over the real forest plate (readme/hud_1080.jpg): the whole HUD at 1920 by 1080 | `readme.py`, `marketing.py` |
| marketing/show_hud_frames_1080.jpg | Test render over the real forest plate (readme/hud_frames_1080.jpg): the Frames look at 1920 by 1080. Until the Frames restore lands, this is the last Frames render, from `37c066152` (2026-11-20); `readme.py --only hud_frames_1080` retakes it after | `readme.py`, `marketing.py` |
| marketing/show_frame_raid.jpg | Test render over the real forest-mac plate (readme/frame_raid.jpg): the raid frames | `readme.py`, `marketing.py` |

The store gallery (`docs/store/gallery/`) holds copies of the hero, the clips and the HUD picture, in upload order.

Rebuild everything with `python Tools/render/readme.py && python Tools/media/marketing.py --clips --pages`. The clips need LuaJIT and Chrome; every run renders every frame fresh from the tree it runs in, so nothing stale is reused.
Every test render carries a visible source label inside the picture and in its alt text. The page's note above the clips and every gallery caption disclose the optional AI-made icon pack.
Plate crops and the in-game capture wish list are in [PROVENANCE.md](plates/PROVENANCE.md).
