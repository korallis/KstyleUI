-- Core.lua: reviewed taint-scan exceptions for Core/. Tools/regression/README.md has the format.
return {
	["Core/EffectModels.lua"] = {
		why = "Model moves one of KstyleUI's own pooled ModelScenes under the frame its 3D effect belongs to (the crest hub or a medallion), so the scene takes that frame's strata, alpha and visibility. The scene is KstyleUI's, created without a template, never protected and never a Blizzard frame, so the move is allowed in combat and no Blizzard code runs.",
		calls = {
			["scene:SetParent"] = 1,
		},
	},
}
