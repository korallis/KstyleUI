# Crest effects: break out of the sockets (owner decision, 2026-11-24)

The owner looked at the first effects pass (light-drawn symbols in the same small round sockets on the shoulders, hips and feet) and chose: **break out**. Each tracked thing becomes part of the crest itself, like the hunter's hawk perches, the shaman's storm orbs and the priest's Inner Fire candles, not a symbol in a circle.

Rules for all three families (melee, ranged, healers), so the crest stays one consistent style:
- **No round sockets** for these pieces on the Medallions crest. Remove the socket/medal frame and its backing; the effect itself sits on or around the crest.
- **Kinds of placement**, pick what fits each tracked thing:
  - *Overlay on the emblem or ring*: a colour flood (Shadowform turns the crest violet), a dome or ward over the emblem (Power Word: Shield, Ice Barrier), cracks of fire across the ring (Enrage), a reticle across the whole crest (Hunter's Mark), drips from the crown (poisons), frost creeping over the rim (chill).
  - *Perched objects* on the crest's edge like the hawks: a horn on the rim, blades standing in the crown, vials hanging from the ring, a demon's sigil hovering, wisps orbiting.
  - *Ring motion*: something that travels, fills or burns along the outer or inner ring for timers (a fuse, a creeping glow, an orbiting spark).
- **Readable at a glance at 1080**: big enough, lit (additive glow, bloom), animated states (apply, active loop, ending warning, fade), distinct from each other on the same crest. Steel or dark at rest, never a grey token.
- **Stay inside the crest's footprint and clear of the unit bars, the cast bar, the level badge and the action slots** at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.
- **Keep every tracked thing and its switch** (nothing dropped), the #799 combat rules (nothing written under an engine aura button in combat, size at build, replay on ADDON_RESTRICTION_STATE_CHANGED), and the #809 sigils for the cooldown row.
- **Frames**: no crest there, so the Frames tracker row shows the same objects free-standing in a row (no round medal frames), same light and motion, sized to the row.
- Reuse the art that exists where it fits (the effect art each of you generated, the crest's own fire/burst/glyph/ambient art) and generate new art with `Tools/media` where needed. No icon textures. No imitation of any WeakAuras author's art.

**Step 1 (now): design only.** For each class (and form/stance), make mockups with the render harness over the owner's backdrops: one still with everything lit, one at rest, and a short GIF of the main moments, at 1920x1080 and 5120x1440, plus a table (tracked thing, placement, effect, motion). Put them in `C:/Users/leeba/.cache/kstyleui-evidence/crest-breakout-<family>/` with a `REPORT.md`, report to the coordinator, and **wait for a go** before changing your PR. The owner will judge all three families side by side.
