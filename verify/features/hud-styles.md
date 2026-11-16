# HUD styles

The style switch is the **HUD style: Frames, Orbs and Medallions** row in [the feature map](../../docs/feature-map.md). The Medallion unit frames, the Orbs and the forged tray, the Medallions action slab and crest hub, and the Medallions effects rows belong to the same journey family. The map names their code paths and tests. The statechart is [hud-style.md](../../docs/statecharts/hud-style.md).

## Sub-features

- The three styles themselves: Frames, Orbs and Medallions.
- The pickers that offer all three: the General settings page and step 2 of the first-run setup.
- Medallion unit frames: slabs, medallions, portrait and crest.
- Orbs and the forged tray.
- Medallions effects: the action slab at calm, combat, proc and level-up, and the ready, cast and vignette effects.

## How to get to it (user POV)

The player picks a style under `/kstyle`, General > HUD style, or in step 2 of the first-run setup. The whole HUD redraws in that style: unit frames, action bars, the minimap, cards and number faces all follow. A saved Medallions profile loads as Medallions on the next login.

## Driving it with the render and regression harnesses

Render the owner's case first. The scene `hud_warlock_mac` pins the warlock class. `RENDER_HUD_STYLE` selects the style:

```bash
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_HUD_STYLE=Medallions RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_warlock_mac --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_warlock_medallions_5120x1440.png"
echo "exit=$?"
```

The observable end state: exit 0, and the PNG shows the Medallions HUD. Unit frames are slabs with round medallion portraits. One row of action sockets runs each side of the central class crest hub. The minimap is round in a steel ring. Cards wear dark steel. The render log carries `class: WARLOCK (Morveth, mana, casting Shadow Bolt)`.

Repeat with `RENDER_HUD_STYLE=Frames` and `RENDER_HUD_STYLE=Orbs` to prove the switch both ways. `RENDER_ORBS_HIT=1` shows the Orbs hit orb. `RENDER_MEDALLIONS_STATE=calm|combat|proc|levelup` and `RENDER_FX=ready|cap|levelup|cast|stopped|vignette|burst|rest` drive the effects states the feature map row names.

Prove the offer and the saved-style load without pixels:

```bash
lua5.1 Tools/regression/test-hud-style-gate.lua
echo "exit=$?"
```

The end state is `hud style gate ok`, exit 0. That file proves all three styles are offered with no dev flag, the General page shows the three cards, the setup shows the three cards, and a saved Medallions style loads as Medallions. The feature map row lists the wider test set, including `test-layout-medallions*` and `test-unitframes-orbs`.

## Gotchas

- The full-HUD scenes `hud_<class>_mac` pin their class in the scene file. Use `--class WARLOCK` on `hud_dps_mac` when a journey must vary the class.
- The scene `hud_reference` reproduces the owner's reference picture state. It does not take a class variable. Do not claim a class journey from it.
- On a machine with no handoff mockup, portraits and the minimap terrain are flat colours. The render log names them as stand-ins. Judge slab shape, sockets, rings and text, not portrait art.
