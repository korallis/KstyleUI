-- test-meters-card-frames.lua: under the Frames HUD style, the damage card as the owner's picture draws it (LEE-20, "let the picture win"): the cap names the meter with the rate at its right, five bars as tall as the row coloured by the spell's school, no icons, and "412 · 46%" at the right of each.
assert(loadfile("Tools/regression/test-meters-card.lua"))("frames")
