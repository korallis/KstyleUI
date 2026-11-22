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
	["Core/Skin.lua"] = {
		why = "Blizzard skin refreshes set texture alpha when windows open, select rows or animate fades; third-party skins may do so too. Rehush only restores zero under a recursion guard, so each fade tick costs one guarded setter.",
		calls = {
			["texture:SetAlpha"] = 1,
		},
	},
	["Core/Widgets/Base.lua"] = {
		why = "KstyleUI controls show, hide or SetShown on their own card header nodes on settings and state changes. These three hooks update the header ornament only when visibility changes; Blizzard and other addons do not drive these private nodes.",
		calls = {
			["node:Show"] = 1,
			["node:Hide"] = 1,
			["node:SetShown"] = 1,
		},
	},
}
