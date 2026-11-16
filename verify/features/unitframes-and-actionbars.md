# Unit frames and action bars

These are the **Clean bars**, **Cast bars**, **Wide target bar**, **Action bars and the shared action slot** and **Medallions action slab and crest hub** rows in [the feature map](../../docs/feature-map.md).

## Sub-features

- Player, target, target of target, focus, focus target, pet and boss bars.
- Health and power fills, the held loss band, and low-health warning.
- Player and target cast bars.
- The wide target bar under the Orbs style.
- Action bars and the shared action slot, with keybind text.
- The Medallions action slab: recessed sockets, the crest hub, the experience strip along its lower edge, and the pet and stance slabs beside it.

## How to get to it (user POV)

The frames and bars are the centre of the HUD in play. The player tunes them under `/kstyle`, on the Unit Frames and Action Bars pages, and binds keys with `/kstyle bind`. In combat the player watches health, power, the cast bars and the cooldown state of the action slots. Under Medallions, the slab shows one row of twelve sockets a side on a 21:9 or wider screen, and two rows of six at 16:9.

## Driving it with the render and regression harnesses

The owner's-case render already frames the centre cluster. Its PNG must show the player slab with health and mana, a running Shadow Bolt cast bar, the pet slab under it, the target slab with its own cast, and the action slab with icons and keybinds around the crest:

```bash
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_HUD_STYLE=Medallions RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_warlock_mac --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_warlock_medallions_5120x1440.png"
echo "exit=$?"
```

`RENDER_LOSS=1` on `hud_reference` shows the held loss band. The scenes `gallery_unitframes` and `gallery_actionbars` isolate one area each. `RENDER_CLASS` swaps the class, so each class resource and pet can be rendered:

```bash
bash Tools/render/shoot.sh hud_dps_mac --class WARLOCK --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_dps_warlock.png"
echo "exit=$?"
```

Prove behaviour without pixels. The feature map rows name the full set. Start with:

```bash
lua5.1 Tools/regression/test-actionbars-medallions-slab.lua
echo "exit=$?"
lua5.1 Tools/regression/test-unitframes-medallions.lua
echo "exit=$?"
```

Each prints its own ok line and exits 0. The slab file proves rows, socket size, gaps and the pet slab at every crew screen size. `test-actionbars*` covers the bars and buttons, and `test-unitframes-castbar*` covers the cast bars.

## Gotchas

- The pet portrait in a render is the summoning spell's icon. The game draws the pet's model. The render log says so.
- Engine aura buttons keep their state hidden from the stub the same way the client hides it. Judge a render by what the scene drove, not by state read back from the buttons.
- A cast or fade in a render is sampled at the scene's clock. It reads mid-way, not at a precise frame. Use the regression files for timing claims.
