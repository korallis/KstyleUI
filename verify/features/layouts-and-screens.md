# Layouts and screens

These are the **DPS, Tank and Healer layouts**, **Interface size: Auto**, **Ultrawide arrangement: Centred and Spread**, **HUD width** and **Layout Mode** rows in [the feature map](../../docs/feature-map.md). The statechart is [arrangement-layout-class.md](../../docs/statecharts/arrangement-layout-class.md).

## Sub-features

- The DPS, Tank and Healer layouts from setup step 3.
- Interface size Auto, the pixel-perfect size per screen.
- The ultrawide arrangements: the HUD in a centred band, or spread across the screen.
- HUD width: 21:9, 16:9 or full.
- Layout Mode, where the player moves elements by hand.

## How to get to it (user POV)

The player picks a role layout in the first-run setup, and changes it later with `/kstyle setup`. Size sits under `/kstyle`, General > Size. The arrangement and HUD width sit on the Elements page. On a 5120x1440 screen, Centred keeps the HUD in the middle band. Spread sends the rails to the screen edges. Tank adds a threat card to the combat cluster. Healer adds party frames beside the centre.

## Driving it with the render and regression harnesses

The scene `hud_reference` takes the layout and screen variables. Render each layout on the owner's ultrawide:

```bash
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_LAYOUT=DPS RENDER_ARRANGEMENT=centred \
  bash Tools/render/shoot.sh hud_reference --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_reference_dps_centred.png"
echo "exit=$?"
```

Swap `RENDER_LAYOUT` through `DPS`, `Tank` and `Healer`, and `RENDER_ARRANGEMENT` through `centred` and `spread`. The observable end state: exit 0 under `--strict` for each. The Tank PNG shows a visible threat card. The Healer PNG shows party frames beside the centre. The spread PNG puts chat, the map and the rails at the screen edges. The centred PNG keeps them in the middle band.

Prove placement and collisions without pixels. The feature map rows name the full set. Start with:

```bash
lua5.1 Tools/regression/test-setup-layouts.lua
echo "exit=$?"
lua5.1 Tools/regression/test-layout-ultrawide.lua
echo "exit=$?"
```

Each prints its own ok line and exits 0. `test-setup-collisions.lua` proves elements do not overlap. The `test-render-scenes-reference*` files rebuild the three presets and guard them without Chrome.

## Gotchas

- `--ppu` must match the screen: height over 1080. A wrong `--ppu` still renders, but the PNG no longer carries the screen's own pixels, and size claims from it are void.
- An unknown `RENDER_LAYOUT` value fails the scene on purpose. That failure is correct behaviour, not a broken harness.
- The Healer reference shows one chat line cut at the top of the chat viewport. That is the game's native scrolling behaviour, as [the render README](../../Tools/render/README.md) documents. It is not a layout defect.
