# Published picture inventory

Before: `de9665838ee35b384ad4730444b7dd6075eac145`. After: this branch.
All filenames below are relative to their group. The same master description generates README, CurseForge and Wago.

| Group / picture | Before | After / pipeline input |
| --- | --- | --- |
| readme / crop_meter.jpg | AI mockup scenery | Test render over real forest plate |
| readme / crop_nameplates.jpg | AI mockup scenery | Test render over real forest plate |
| readme / crop_orbs.jpg | AI mockup scenery | Test render over real town plate |
| readme / crop_rail.jpg | AI mockup scenery | Test render over real forest plate |
| readme / crop_unitframes.jpg | AI mockup scenery | Test render over real forest plate |
| readme / frame_raid.jpg | No backdrop (flat gallery render) | Test render over real forest-mac plate |
| readme / frame_setup.jpg | No backdrop (flat gallery render) | Test render over real forest-mac plate |
| readme / frame_skins.jpg | No backdrop (flat gallery render) | Test render over real forest-mac plate |
| readme / game_medallions_16x9.jpg | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / game_medallions_cast.gif | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / game_medallions_closeup.jpg | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / game_medallions_hero.jpg | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / game_medallions_interrupt.gif | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / game_medallions_target.gif | Real in-game capture (preserved) | Real in-game screenshot (preserved) |
| readme / hud_frames_1080.jpg | AI mockup scenery | Test render over real forest plate |
| readme / hud_frames_5120.jpg | AI mockup scenery | Test render over real forest plate |
| readme / hud_orbs_1080.jpg | AI mockup scenery | Test render over real town plate |
| readme / hud_orbs_5120.jpg | AI mockup scenery | Test render over real town plate |
| readme / ultrawide_centred.jpg | AI mockup scenery | Test render over real forest plate |
| readme / ultrawide_spread.jpg | AI mockup scenery | Test render over real forest plate |
| marketing / banner.jpg | Real Medallions capture, darkened and branded | Same real capture; source label added |
| marketing / header-three-huds.jpg | No backdrop; procedural logo, gradient and text | Same; no scene depicted |
| marketing / header-every-screen.jpg | No backdrop; procedural logo, gradient and text | Same; no scene depicted |
| marketing / header-set-up.jpg | No backdrop; procedural logo, gradient and text | Same; no scene depicted |
| marketing / header-rest-of-your-ui.jpg | No backdrop; procedural logo, gradient and text | Same; no scene depicted |
| marketing / card-three-huds.jpg | Real in-game capture (preserved) via game_medallions_closeup.jpg | Real in-game screenshot (preserved) via game_medallions_closeup.jpg |
| marketing / card-pixel-perfect.jpg | AI mockup scenery via hud_frames_1080.jpg | Test render over real forest plate via hud_frames_1080.jpg |
| marketing / card-ultrawide.jpg | AI mockup scenery via ultrawide_spread.jpg | Test render over real forest plate via ultrawide_spread.jpg |
| marketing / card-ready-in-minutes.jpg | No backdrop (flat gallery render) via frame_setup.jpg | Test render over real forest-mac plate via frame_setup.jpg |
| marketing / card-full-kit.jpg | AI mockup scenery via crop_meter.jpg | Test render over real forest plate via crop_meter.jpg |
| marketing / card-nothing-extra.jpg | No backdrop (flat gallery render) via frame_skins.jpg | Test render over real forest-mac plate via frame_skins.jpg |
| marketing / show_crop_unitframes.jpg | AI mockup scenery via crop_unitframes.jpg | Test render over real forest plate via crop_unitframes.jpg |
| marketing / show_frame_setup.jpg | No backdrop (flat gallery render) via frame_setup.jpg | Test render over real forest-mac plate via frame_setup.jpg |
| marketing / show_frame_raid.jpg | No backdrop (flat gallery render) via frame_raid.jpg | Test render over real forest-mac plate via frame_raid.jpg |
| marketing / show_crop_nameplates.jpg | AI mockup scenery via crop_nameplates.jpg | Test render over real forest plate via crop_nameplates.jpg |
| marketing / show_crop_meter.jpg | AI mockup scenery via crop_meter.jpg | Test render over real forest plate via crop_meter.jpg |
| marketing / show_crop_rail.jpg | AI mockup scenery via crop_rail.jpg | Test render over real forest plate via crop_rail.jpg |
| marketing / show_frame_skins.jpg | No backdrop (flat gallery render) via frame_skins.jpg | Test render over real forest-mac plate via frame_skins.jpg |
| store/gallery / 01-medallions-hero.jpg | Real in-game capture (preserved) via game_medallions_hero.jpg | Real in-game screenshot (preserved) via game_medallions_hero.jpg |
| store/gallery / 02-style-medallions.jpg | Real in-game capture (preserved) via game_medallions_16x9.jpg | Real in-game screenshot (preserved) via game_medallions_16x9.jpg |
| store/gallery / 03-style-frames.jpg | AI mockup scenery via hud_frames_1080.jpg | Test render over real forest plate via hud_frames_1080.jpg |
| store/gallery / 04-style-orbs.jpg | AI mockup scenery via hud_orbs_1080.jpg | Test render over real town plate via hud_orbs_1080.jpg |
| store/gallery / 05-ultrawide-spread.jpg | AI mockup scenery via ultrawide_spread.jpg | Test render over real forest plate via ultrawide_spread.jpg |
| store/gallery / 06-setup.jpg | No backdrop (flat gallery render) via frame_setup.jpg | Test render over real forest-mac plate via frame_setup.jpg |
| store/gallery / 07-nameplates.jpg | AI mockup scenery via crop_nameplates.jpg | Test render over real forest plate via crop_nameplates.jpg |
| store/gallery / 08-meter.jpg | AI mockup scenery via crop_meter.jpg | Test render over real forest plate via crop_meter.jpg |
| store/gallery / 09-quests.jpg | AI mockup scenery via crop_rail.jpg | Test render over real forest plate via crop_rail.jpg |
| store/gallery / 10-medallion-closeup.gif | Real in-game capture (preserved) via game_medallions_target.gif | Real in-game screenshot (preserved) via game_medallions_target.gif |

All derived images are rebuilt by `python Tools/render/readme.py && python Tools/media/marketing.py --pages`.
The three real Medallions stills and three clips remain real captures; the target GIF is recompressed below 1 MB without dropping frames or changing timing.
Pictures with repainted ability or item icons also disclose the optional AI-made icon pack in their captions; the setup diagram and procedural headers show none.
Source labels appear in alt text and captions, with an additional visible label on marketing cards and showcases.
Plate crops and the prioritized in-game capture wish list are in [PROVENANCE.md](plates/PROVENANCE.md).
