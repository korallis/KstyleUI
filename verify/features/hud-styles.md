# HUD styles

The style switch is the **HUD style** row in [the feature map](../../docs/feature-map.md): Medallions, the default, or Frames. The Medallion unit frames, the Medallions action slab and crest hub, the Medallions effects, the Frames tray and the forged ornaments and card materials (Frames only) belong to the same journey family. The map names their code paths and tests. The statechart is [hud-style.md](../../docs/statecharts/hud-style.md).

## Sub-features

- The two styles themselves: Medallions and Frames.
- The pickers that offer both: the General settings page and step 2 of the first-run setup.
- Medallion unit frames: slabs, medallions, portrait and crest.
- The action slab and crest hub: one row of sockets each side of the class crest.
- Frames: the player and target cards, the tray behind bars 1 and 2, the square minimap, the card material and the forged ornaments.
- Medallions effects: the action slab at calm, combat, proc and level-up, and the ready, cast and vignette effects.
- Migration: store migration 45 moves every profile to Medallions except one explicitly saved on Frames; a player whose v0.2.12 or v0.2.13 update moved it picks Frames again and gets their saved Frames positions back.

## How to get to it (user POV)

The player picks a style under `/kstyle`, General > HUD style, or in step 2 of the first-run setup. The whole HUD redraws in that style: unit frames, action bars, the minimap, cards and number faces all follow. A change made in combat waits for combat to end. A saved Frames profile loads as Frames on the next login.

## Driving it with the render and regression harnesses

Render the owner's case first. The scene `hud_warlock_mac` pins the warlock class. `RENDER_HUD_STYLE` selects the style, Medallions when unset:

```bash
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_HUD_STYLE=Medallions RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_warlock_mac --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_warlock_medallions_5120x1440.png"
echo "exit=$?"
```

The observable end state: exit 0, and the PNG shows the Medallions HUD. Unit frames are slabs with round medallion portraits. One row of action sockets runs each side of the central class crest hub. The minimap is round in a steel ring. Cards wear dark steel. The render log carries `class: WARLOCK (Morveth, mana, casting Shadow Bolt)`.

Repeat with `RENDER_HUD_STYLE=Frames` to prove the switch both ways. The Frames PNG shows the player and target cards with round portraits in gilt rings, bars 1 and 2 stacked in the tray card, a square minimap in a forged card, and cards in the forged iron material with brackets. `RENDER_MEDALLIONS_STATE=calm|combat|proc|levelup` and `RENDER_FX=ready|cap|levelup|cast|stopped|vignette|burst|rest` drive the Medallions effects states the feature map rows name.

Prove the offer and the saved-style load without pixels:

```bash
lua5.1 Tools/regression/test-hud-style-gate.lua
echo "exit=$?"
```

The end state is `hud style gate ok`, exit 0. That file proves both styles are offered, the General page and the setup show both cards, and a saved Frames style loads as Frames.

Prove the migration that removed the saved styles:

```bash
lua5.1 Tools/regression/test-store-medallions-only.lua
echo "exit=$?"
```

The end state is `store medallions only ok`, exit 0. That file proves migration 45 moves Orbs and implicit Frames profiles to Medallions with one chat line, leaves a saved Frames choice with its keys and keeps the other settings.

## Gotchas

- The full-HUD scenes `hud_<class>_mac` pin their class in the scene file. Use `--class WARLOCK` on `hud_dps_mac` when a journey must vary the class.
- The scene `hud_reference` reproduces the owner's reference picture state. It does not take a class variable. Do not claim a class journey from it.
- On a machine with no handoff mockup, portraits and the minimap terrain are flat colours. The render log names them as stand-ins. Judge slab shape, sockets, rings and text, not portrait art.
- Ornaments and card materials draw only under Frames. A Medallions render shows neither, whatever `RENDER_ORNAMENTS` or `RENDER_CARD_MATERIAL` says.
