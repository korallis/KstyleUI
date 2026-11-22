# The Medallions HUD

KstyleUI has one HUD, Medallions. Its rows in [the feature map](../../docs/feature-map.md) are the Medallion unit frames, the Medallions action slab and crest hub, and the Medallions effects. The map names their code paths and tests.

## Sub-features

- Medallion unit frames: slabs, medallions, portrait and crest.
- The action slab and crest hub: one row of sockets each side of the class crest.
- Medallions effects: the action slab at calm, combat, proc and level-up, and the ready, cast and vignette effects.
- Migration: a profile saved on the removed Frames or Orbs styles loads on Medallions and says so once.

## How to get to it (user POV)

The HUD is Medallions from the first login; the setup has no style step. Unit frames, action bars, the minimap, cards and number faces all draw in the Medallions look.

## Driving it with the render and regression harnesses

Render the owner's case first. The scene `hud_warlock_mac` pins the warlock class:

```bash
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_warlock_mac --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_warlock_medallions_5120x1440.png"
echo "exit=$?"
```

The observable end state: exit 0, and the PNG shows the Medallions HUD. Unit frames are slabs with round medallion portraits. One row of action sockets runs each side of the central class crest hub. The minimap is round in a steel ring. Cards wear dark steel. The render log carries `class: WARLOCK (Morveth, mana, casting Shadow Bolt)`.

`RENDER_MEDALLIONS_STATE=calm|combat|proc|levelup` and `RENDER_FX=ready|cap|levelup|cast|stopped|vignette|burst|rest` drive the effects states the feature map rows name.

Prove the move from the removed styles without pixels:

```bash
lua5.1 Tools/regression/test-store-medallions-only.lua
echo "exit=$?"
```

The end state is `store medallions only ok`, exit 0. That file proves a Frames or Orbs profile moves to Medallions with one chat line, keeps its other settings and drops the keys only those styles read, and that a Medallions profile moves nowhere.

## Gotchas

- The full-HUD scenes `hud_<class>_mac` pin their class in the scene file. Use `--class WARLOCK` on `hud_dps_mac` when a journey must vary the class.
- The scene `hud_reference` reproduces the owner's reference picture state. It does not take a class variable. Do not claim a class journey from it.
- On a machine with no handoff mockup, portraits and the minimap terrain are flat colours. The render log names them as stand-ins. Judge slab shape, sockets, rings and text, not portrait art.
