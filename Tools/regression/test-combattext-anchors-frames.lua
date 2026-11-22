-- test-combattext-anchors-frames.lua: under the Frames HUD style, KstyleUI_CombatText puts numbers on KstyleUI unit, group and nameplate frames, found by their unit attribute and kept current as the group changes.
assert(loadfile("Tools/regression/test-combattext-anchors.lua"))("frames")
