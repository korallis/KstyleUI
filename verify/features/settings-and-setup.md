# Settings and setup

These are the **First-run setup**, **Edit Mode layout written by Apply**, **Settings window with search and live preview** and **Profiles, export and import** rows in [the feature map](../../docs/feature-map.md). The statechart is [setup.md](../../docs/statecharts/setup.md).

## Sub-features

- The first-run setup: welcome, HUD style, role layout, modules, and the summary with Apply.
- Apply writing element positions, sizes and module settings, and the Edit Mode layout.
- The settings window: pages per module, search, and live preview of a change.
- Profiles: save, switch, export and import a profile string.

## How to get to it (user POV)

The setup opens on first login. `/kstyle setup` reopens it. `/kstyle` opens the settings window, also reachable through Esc > Options > AddOns. The player searches a setting by name, changes it, and sees the HUD respond. Profiles live on their own page and through `/kstyle profile ...`.

## Driving it with the render and regression harnesses

The gallery scenes draw both windows in a representative state. `RENDER_CLASS` sets the class accent, so the warlock journey renders in violet:

```bash
RENDER_CLASS=WARLOCK bash Tools/render/shoot.sh gallery_options --strict \
  --out "$HOME/.cache/kstyleui-verify/gallery_options_warlock.png"
echo "exit=$?"
bash Tools/render/shoot.sh gallery_setup --strict \
  --out "$HOME/.cache/kstyleui-verify/gallery_setup.png"
echo "exit=$?"
```

The observable end state: exit 0 under `--strict` for each. The options PNG shows the settings window with its pages and rows. The setup PNG shows the setup steps. `gallery_setup_tracked` covers the rest the feature map names.

Prove behaviour without pixels. The feature map rows name the full set. Start with:

```bash
lua5.1 Tools/regression/test-setup.lua
echo "exit=$?"
lua5.1 Tools/regression/test-options-hud-pictures.lua
echo "exit=$?"
```

Each prints its own ok line and exits 0. `test-setup` proves the style cards and Apply keeping the pick. `test-setup-editmode*` proves the written Edit Mode layout. `test-store*` covers profiles, export and import, which have no render scene.

## Gotchas

- Profiles have no render scene. A profile journey is regression-only. Do not claim picture evidence for it.
- The gallery scenes take the player's class from `RENDER_CLASS` and fall back to warrior when it is unset. An options render without it proves the warrior accent, not the class under test.
- Apply writes through the same path in the harness as in the game. A setup proof that never reaches Apply proves only the window, not the written layout.
