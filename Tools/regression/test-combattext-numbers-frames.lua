-- test-combattext-numbers-frames.lua: under the Frames HUD style, KstyleUI_CombatText turns UNIT_COMBAT into animated numbers in the player's field, never touching a secret amount.
assert(loadfile("Tools/regression/test-combattext-numbers.lua"))("frames")
