# Card materials

Open **Options → General → Card material** to choose the surface of KstyleUI's cards, panels, rails and windows. The dropdown is separate from the **Panel appearance** section's opacity and shadow controls. Selection repaints existing cards immediately through the widget kit's normal setting handler; switching profiles uses its existing profile handler. Neither action needs a reload.

| Choice | Surface |
| --- | --- |
| Glass | The original smoked glass, with its existing bevel and gilt ticks. |
| Flat | A quiet, untextured dark fill with a restrained edge. |
| Slate | A dark mineral surface with subtle repeating grain. |
| Forged iron, gilt ticks | Dark forged metal with a textured frame and the kit's gilt corner ticks. |
| Forged iron, brackets (default) | The same forged metal and frame, with corner brackets instead of gilt ticks. |

The saved values are `Glass`, `Flat`, `Slate`, `ForgedTicks` and `ForgedBrackets`. `Core/Widgets/Base.lua` keeps the default in one local `DEFAULT_CARD_MATERIAL` constant. On 2026-11-10 the owner selected **Forged iron, brackets** (`ForgedBrackets`) as the default. New profiles and existing profiles without an explicit material choice inherit it. An explicit saved choice, including Glass, stays selected. Missing, invalid or secret saved values fall back to the default without rewriting the profile.

**Glass remains one dropdown choice away.** Choose Glass to restore the original smoked-glass surface, bevel and gilt ticks immediately; that explicit choice is saved with the profile.

## Opacity and scope

**Panel opacity** retains its existing default of **0.75** and range of **0.50–1.00**. For Glass, the value is the original smoked-glass fill alpha. For another material, 0.75 means its authored opacity; lowering or raising the slider scales that material's fill and grain relative to 0.75, with alpha capped at 1. A denser forged surface can therefore look more solid than Glass at the same slider value. Choosing a material does not change the stored opacity or shadow preference.

The choice applies to the shared card surface, not status bars, action-button tiles or nameplate bars. Custom-radius or proportional-radius chrome, including nameplate badges, and explicit `grain = false` opt-outs keep their authored surface. Explicit state colours and custom fills keep their own treatment. Forged frames and brackets follow the same relative opacity as their surface, including zero opacity. Geometry, text positions and layout remain unchanged.

Floating menus, tooltips and dialogs use an opaque surface under every non-Glass material so content beneath cannot read through them. Their settled opacity does not follow Panel opacity; Glass retains its original transparency. [Popup surfaces](popup-materials.md) lists the affected surfaces and intentional exceptions.

## Assets

The slate and forged grains use original generated style sources; the frame slices, brackets, diamond and rule are original pixel constructions. Nothing is extracted from or traced over a commercial game's art. Sources and attribution are recorded in [Media/PROVENANCE.md](../Media/PROVENANCE.md). `Tools/media/make_media.py` re-exports the prepared material sources retained in `Tools/media/materials/`.

## Native check

### Render evidence (LEE-122)

The story rail and damage cards do not opt out of the selected material. Earlier
ordinary `hud_reference` renders omitted their grain/frame because the stubs
could not report dimensions for their multi-anchor owners. The approved phase-2
720p bright sheet used the same reference scene, DPS and explicit ForgedBrackets,
but a private launcher supplied solver dimensions and repainted materials. That
launcher was not shipped, so it was not reproducible with the normal command.

The shared renderer now performs the missing size-dependent material paint
without changing addon code, layout, text, bars or Glass. Use the documented
`RENDER_CARD_MATERIAL`, `RENDER_SCREEN` and `RENDER_LAYOUT` controls in
`Tools/render/README.md`; do not use the old private repaint launcher as an
acceptance baseline. This corrects render fidelity, not an observed client bug.

The offline renderer cannot prove the client's texture loading and sampling. After the change is merged to staging and the owner's live copy is updated, fully quit and restart Forever so the client discovers the new texture files; `/reload` alone is not the first-install check. Then:

1. Confirm a new or previously unselected profile opens on Forged iron, brackets at opacity 0.75, while an existing opacity override is preserved. Confirm a profile with an explicit saved Glass choice still opens on Glass.
2. Open General → Card material and select all five choices. Check the open Options window and visible cards repaint immediately, with no missing textures or Lua errors.
3. Move Panel opacity down and back, then switch between profiles with different materials. Confirm the material, grain and corner treatment follow immediately without moving the content.
4. Inspect a small card and a large window at the native display size and at 1280×720 or 1366×768. Check the border stays outside the fill, the corners stay crisp, and switching back to Glass restores the original surface.
