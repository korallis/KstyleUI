# Core visuals reference

The core's visual service files carry one comment each, their first line, so their contracts live here, as [`core-services.md`](core-services.md) does for the other services. The roadmap's [Core public API](superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page adds the details and the extra functions. Tests: `Tools/regression/test-appearance.lua`.

## Appearance

`Core/Appearance.lua` holds the player's look settings and hands them to `Theme`, `Scale` and `Motion`. It loads after `Options.lua`, registers its defaults with `Store.RegisterDefaults("Appearance", defaults)` and its settings page with `Options.Register("Appearance", schema)` at load.

| Setting | Default | Row | Drives |
| --- | --- | --- | --- |
| `accentSource` | `"class"` | dropdown: class colour or custom colour | `Theme.SetAccentSource` |
| `accentColor` | the kit's accent, from `Tokens.Color("accentDefault")` | colour, shown only for a custom accent | `Theme.SetCustomAccent` |
| `font` | `"SourceSans3Semibold"` | dropdown of the three bundled faces | `Theme.SetFontFace` |
| `uiScale` | `1` | slider from 0.75 to 1.5 in steps of 0.05 | `Scale.SetUserScale` |
| `reducedMotion` | `false` | toggle | `Motion.SetReducedMotion` |

The font is a dropdown, not a `font` row, because the value is a key of `Tokens.MediaList("font")`, not a file path.

| Function | Behaviour |
| --- | --- |
| `Get(key) -> value` | The active profile's value. A value the setting does not allow (an unknown accent source or face, a colour channel outside 0 to 1) gives the default and a devlog line. A size outside 0.75 to 1.5 is clamped. Before the saved data loads, the default. An unknown key raises an error. |
| `Apply()` | Hands every setting to its service. The custom colour goes before the accent source, so switching to a custom accent fires `ThemeChanged` once. |
| `defaults`, `schema` | The tables registered with `Store` and `Options`. |

When the settings apply:

1. `ADDON_LOADED` for `KstyleUI`, right after `Store` loads the saved data, so the size and the accent are right before `PLAYER_LOGIN` builds frames.
2. `PLAYER_LOGIN`, again, in case the saved data loaded late.
3. `SettingChanged` for the `Appearance` page: the one setting that changed. The settings window writes through `Options.Write`, which fires it.
4. `ProfileChanged`: every setting of the new profile.

The accent itself is never saved. A profile shared by characters of different classes stores only the accent source and the custom colour, so each character gets its own class colour at login.

### LibSharedMedia

At `PLAYER_LOGIN`, if `LibStub` is loaded and `LibStub("LibSharedMedia-3.0", true)` returns the library, `Appearance` registers the three fonts and the three status bar textures under `KstyleUI <label>`, for example `KstyleUI Source Sans 3 Semibold` and `KstyleUI Glass`. It does this once. KstyleUI never loads or embeds the library. A library that raises an error while registering is counted in a devlog line and never stops login.
