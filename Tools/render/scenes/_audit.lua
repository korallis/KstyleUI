-- _audit.lua: optional previous-behaviour settings for the audit's base-equality fixtures.
local Audit = {}
function Audit.Apply(K)
	if os.getenv("RENDER_NEEDS_OFF") ~= "1" then return end
	if K.Setup.Layouts.ThirdBarFinished and not K.Options.Row("ActionBars", "bar3.finished") then
		local cfg = K.Store.Module("ActionBars")
		cfg.bar3 = cfg.bar3 or {}
		if cfg.bar3.finished ~= false then
			cfg.bar3.finished = false
			K.Callbacks.Fire("SettingChanged", "ActionBars", "bar3.finished", false)
		end
	end
	for module, values in pairs({
		ColorVision = { mode = "standard" }, Integrations = { notices = false, timerLane = false, announcementLane = false, weakAuras = false },
		Setup = { closeBehaviour = "apply", replaceLayout = false }, ProfileTools = { review = false, backups = false },
		OptionControls = { numericInput = false, changedSettings = false }, LayoutControls = { clearMovers = false, search = false },
		ActionBars = { bindingHints = false, ["bar3.finished"] = false }, UnitFrames = { ["target.rangeFade"] = false },
		GroupFrames = { ["icons.roleShapes"] = false, ["icons.statuses"] = false, ["threat.shapes"] = false, ["auras.typeLetters"] = false, ["blizzard.manager"] = true, ["blizzard.keepManager"] = false, ["presets.raid"] = "Compact" },
		Nameplates = { ["threat.shapes"] = false, ["cast.shieldBadge"] = false }, Meters = { ["threat.tankAlarm"] = false },
	}) do
		for key, value in pairs(values) do
			if K.Options.Row(module, key) and K.Options.Read(module, key) ~= value then K.Options.Write(module, key, value) end
		end
	end
	if K.Profiles and K.Store.Module("Readability").preset ~= "Standard" then K.Profiles.Readable("Standard") end
end
return Audit
