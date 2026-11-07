-- Presets.lua: the presets spike records the Forever experience preset, the active Edit Mode layout and which default frames are shown.
local _, ns = ...

local FRAMES = {
	"PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PlayerCastingBarFrame", "TotemFrame",
	"MainActionBar", "MainMenuBarEndCaps", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
	"StanceBar", "PetActionBar", "BuffFrame", "DebuffFrame", "MinimapCluster", "MicroMenuContainer", "BagsBar",
	"StatusTrackingBarManager", "PartyFrame", "CompactRaidFrameContainer", "EssentialCooldownViewer",
	"UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer", "ChatFrame1", "ObjectiveTrackerFrame",
	"DamageMeter",
}
local CVARS = { "cooldownViewerEnabled", "combinedBags", "questPOI", "showToastWindow", "ActionButtonUseKeyDown" }

local function Frames()
	local frames = {}
	for _, name in ipairs(FRAMES) do
		local frame = _G[name]
		if type(frame) ~= "table" then
			frames[name] = { exists = false }
		else
			frames[name] = {
				exists = true,
				shown = ns.Try(function() return frame:IsShown() end),
				visible = ns.Try(function() return frame:IsVisible() end),
			}
		end
	end
	return frames
end

local function EditMode()
	local edit = {}
	if C_EditMode and type(C_EditMode.GetLayouts) == "function" then
		local ok, info = pcall(C_EditMode.GetLayouts)
		if ok and type(info) == "table" then
			edit.activeLayout = ns.Describe(info.activeLayout)
			edit.savedLayouts = type(info.layouts) == "table" and #info.layouts or nil
		end
	end
	local presets = type(EditModePresetLayoutManager) == "table" and EditModePresetLayoutManager.presetLayoutInfo
	edit.presetCount = type(presets) == "table" and #presets or nil
	if type(edit.activeLayout) == "number" and edit.presetCount then
		edit.activeIsPreset = edit.activeLayout <= edit.presetCount
	end
	local manager = EditModeManagerFrame
	if type(manager) == "table" and type(manager.GetActiveLayoutInfo) == "function" then
		local ok, layout = pcall(manager.GetActiveLayoutInfo, manager)
		if ok and type(layout) == "table" then
			edit.layoutName = ns.Describe(layout.layoutName)
			edit.layoutType = ns.EnumName(Enum and Enum.EditModeLayoutType, layout.layoutType) or ns.Describe(layout.layoutType)
			edit.layoutIndex = ns.Describe(layout.layoutIndex)
		end
	end
	return edit
end

ns.Register("presets", {
	group = "basic",
	summary = "records the experience preset, the Edit Mode layout and which default frames are shown.",
	Run = function(run)
		if C_GameRules and type(C_GameRules.GetForeverExperiencePreset) == "function" then
			local preset = ns.Try(C_GameRules.GetForeverExperiencePreset)
			run:Set("presetRaw", preset)
			run:Set("preset", ns.EnumName(Enum and Enum.ForeverExperiencePreset, preset) or preset)
		else
			run:Set("preset", "unavailable")
		end
		run:Set("editMode", EditMode())
		run:Set("frames", Frames())
		local cvars = {}
		if C_CVar and type(C_CVar.GetCVar) == "function" then
			for _, name in ipairs(CVARS) do
				cvars[name] = ns.Try(C_CVar.GetCVar, name)
			end
		end
		run:Set("cvars", cvars)
		run:Note("preset " .. tostring(run.data.results.preset) .. ".")
	end,
})
