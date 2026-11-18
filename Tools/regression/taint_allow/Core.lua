-- Core.lua: reviewed taint-scan exceptions for Core/. Tools/regression/README.md has the format.
return {
	["Core/Vignette.lua"] = {
		why = "Layout moves only the private vignette frame created in this file without a secure template. UIParent and WorldFrame are its possible parents; neither Blizzard frame is moved or modified. The private frame is unprotected, so changing its parent is allowed in combat and during Edit Mode; the option restores the previous WorldFrame visibility or follows UIParent.",
		calls = {
			["frame:SetParent"] = 1,
		},
	},
	["Core/EffectModels.lua"] = {
		why = "Model moves one of KstyleUI's own pooled ModelScenes under the frame its 3D effect belongs to (the crest hub or a medallion), so the scene takes that frame's strata, alpha and visibility. The scene is KstyleUI's, created without a template, never protected and never a Blizzard frame, so the move is allowed in combat and no Blizzard code runs.",
		calls = {
			["scene:SetParent"] = 1,
		},
	},
}
