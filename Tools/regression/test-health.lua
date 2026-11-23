-- test-health.lua: the load check names each broken KstyleUI part once per session with its one-click fix, stays silent when switched off or when nothing is wrong, and the About page's Status section and copied report carry no personal data.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local O = dofile("Tools/regression/options_env.lua")

local FOLDERS = {
	ActionBars = { reason = "DISABLED" },
	Bags = { reason = "INTERFACE_VERSION" },
	Chat = { loaded = true, version = "0.2.14", module = true },
	Meters = { loaded = true },
	UnitFrames = { loaded = true, module = true, fails = true },
	Nameplates = { loaded = true, module = true, loadError = true },
	Minimap = { loadable = true },
	QoL = { loaded = true, module = true, off = true },
	Options = { reason = "DEMAND_LOADED" },
	Routes = { exists = false },
}
for _, name in ipairs({ "Cooldowns", "GroupFrames", "Auras", "CombatText", "Tooltips", "DataBars", "Skins" }) do
	FOLDERS[name] = { loaded = true, module = true }
end

local function Install(env, enabled)
	local function entry(folder)
		return FOLDERS[folder:match("^KstyleUI_(.+)$") or ""] or {}
	end
	env.ADDON_INTERFACE_VERSION = "Out of date"
	env.C_AddOns = {
		DoesAddOnExist = function(folder) return entry(folder).exists ~= false end,
		IsAddOnLoaded = function(folder) local loaded = entry(folder).loaded == true; return loaded, loaded end,
		GetAddOnMetadata = function(folder, field) assert(field == "Version"); return entry(folder).version or "@project-version@" end,
		DoesAddOnHaveLoadError = function(folder) return entry(folder).loadError == true end,
		GetAddOnInfo = function(folder) local e = entry(folder); return folder, folder, "", e.loadable == true, e.reason, "INSECURE" end,
		IsAddOnLoadOnDemand = function(folder) return folder == "KstyleUI_Options" or folder == "KstyleUI_Routes" end,
		EnableAddOn = function(folder) enabled[#enabled + 1] = folder end,
	}
end

local function Boot(opts)
	opts = opts or {}
	local enabled, popups = {}, {}
	local env, K = CoreEnv.New({ saved = opts.saved, player = "Valerin", realm = "Silvermoon", setup = function(e)
		if opts.client ~= false then Install(e, enabled) end
	end })
	local popup = K.Widgets.Popup
	K.Widgets.Popup = function(spec)
		popups[#popups + 1] = spec
		return popup(spec)
	end
	for name, folder in pairs(FOLDERS) do
		if folder.module then
			K.Modules.Register(CoreEnv.Module(name, { onEnable = function() if folder.fails then error("boom in Enable") end end }))
		end
	end
	CoreEnv.LoadSaved(env)
	for name, folder in pairs(FOLDERS) do
		if folder.module then K.Store.Module(name).enabled = not folder.off end
	end
	if opts.before then opts.before(K) end
	CoreEnv.Login(env)
	env.RunTimers()
	return env, K, popups, enabled
end

local function States(K)
	local out = {}
	for _, row in ipairs(K.Health.Modules()) do out[row.name] = row end
	return out
end

do
	local env, K, popups, enabled = Boot()
	local rows = States(K)
	local want = { ActionBars = "disabled", Bags = "failed", Chat = "outdated", Meters = "error", UnitFrames = "error", Nameplates = "error",
		Minimap = "reload", QoL = "off", Options = "ondemand", Routes = "missing", Skins = "running", Auras = "running" }
	for name, state in pairs(want) do
		assert(rows[name] and rows[name].state == state, name .. " must read " .. state .. ", got " .. tostring(rows[name] and rows[name].state))
	end
	assert(tostring(rows.UnitFrames.detail):find("boom in Enable", 1, true), "an Enable error keeps its message for the report")
	assert(K.Health.Text(rows.Bags) == "Did not load: Out of date", "a load reason reads through the client's ADDON_ string")
	assert(#popups == 1, "one notice after login, got " .. #popups)
	local notice = popups[1]
	for _, line in ipairs({ "Action bars: Turned off in the AddOn list", "Bags: Did not load: Out of date", "Chat: Not the same version as KstyleUI",
		"Meters: Hit an error while loading", "Unit frames: Hit an error while loading", "Nameplates: Hit an error while loading",
		"Minimap: Waiting for a reload", "World map routes: Missing", "Turn them back on and reload to finish.", "A reload usually loads them again.",
		"Update KstyleUI from the link below so every part matches, then restart the game." }) do
		assert(notice.text:find(line, 1, true), "the notice names: " .. line .. "\n" .. notice.text)
	end
	for _, quiet in ipairs({ "Quality of life", "Settings window", "Window skins" }) do
		assert(not notice.text:find(quiet, 1, true), quiet .. " is fine and must stay out of the notice")
	end
	assert(notice.editBox and notice.editBox.text:find("curseforge", 1, true), "update problems carry the download link")
	local fix = notice.buttons[2]
	assert(notice.buttons[1].label == "Later" and fix.primary and fix.reload and fix.label == "Turn on and reload", "Later, then one primary Turn on and reload")
	fix.onClick()
	assert(#enabled == 1 and enabled[1] == "KstyleUI_ActionBars", "the fix enables only the folders the AddOn list turned off")
	K.Health.Check()
	assert(#popups == 1, "a problem already named stays quiet for the rest of the session")
	K.Modules.Disable("Cooldowns")
	env.RunTimers()
	assert(#popups == 1, "switching a module off is not a problem")
	FOLDERS.QoL.fails = true
	K.Modules.Enable("QoL")
	env.RunTimers()
	FOLDERS.QoL.fails = nil
	assert(#popups == 2 and popups[2].text:find("Quality of life: Hit an error while loading", 1, true), "a module that fails later gets its own notice")
	assert(not popups[2].text:find("Action bars", 1, true) and not popups[2].editBox, "the later notice names only the new problem")
	assert(popups[2].buttons[2].label == "Reload now", "an error offers a reload")

	local report = K.Health.Report()
	for _, part in ipairs({ "ActionBars disabled", "Bags failed INTERFACE_VERSION", "Chat outdated 0.2.14", "UnitFrames error", "boom in Enable",
		"Routes missing", "Options ondemand", "Cooldowns off", "QoL error", "hud medallions", "profile default", "errors " }) do
		assert(report:find(part, 1, true), "the report holds " .. part .. ":\n" .. report)
	end
	assert(not report:find("\n", 1, true), "the report is one line for the copy box")
	assert(#env._errors == 2, "only the two failing Enables raise")
end

do
	local _, K, popups = Boot({ before = function(K)
		K.Store.Account().healthChecks = false
	end })
	assert(#popups == 0, "Load check off shows no notice")
	assert(#K.Health.Modules() > 0, "the states still read with the notice off")
end

do
	local _, K, popups = Boot({ client = false })
	assert(#popups == 0, "a client without the C_AddOns answers shows no notice")
	assert(K.Health.Report():find("UnitFrames unknown", 1, true), "without answers a part reads unknown, never broken")
end

do
	local env, K, ns = O.New({ player = "Valerin", realm = "Silvermoon" })
	assert(K.Store.CreateProfile("Valerin") and K.Store.SetProfile("Valerin"), "a profile named after the character")
	local function Items()
		return ns.Pages.Find(ns.Pages.List(), "About").Items()
	end
	local labels = table.concat(O.Labels(Items()), "\n")
	for _, label in ipairs({ "Status", "Load check", "Modules", "Existing addons", "Copy report", "HUD style: Medallions", "Profile: Valerin", "Boss timer lane: On" }) do
		assert(labels:find(label, 1, true), "About > Status lists " .. label .. "\n" .. labels)
	end
	local copy = O.Find(Items(), function(item) return item.label == "Copy report" end)
	local shown
	local popup = K.Widgets.Popup
	K.Widgets.Popup = function(spec) shown = spec; return popup(spec) end
	copy.buttons[1].onClick()
	local report = assert(shown and shown.editBox and shown.editBox.text, "Copy report opens a copy box")
	for _, private in ipairs({ "Valerin", "Silvermoon", "Player-" }) do
		assert(not report:find(private, 1, true), "the report must not carry " .. private .. ":\n" .. report)
	end
	assert(report:find("profile custom", 1, true), "a named profile reads as custom in the report")
	O.Find(Items(), function(item) return item.label == "Load check" end).set(false)
	assert(K.Store.Account().healthChecks == false, "the switch is saved for the account")
	local off = table.concat(O.Labels(Items()), "\n")
	assert(not off:find("Copy report", 1, true) and not off:find("HUD style:", 1, true), "Load check off hides the status lines")
	assert(#env._errors == 0, "the About page raises nothing: " .. tostring(env._errors[1]))
end

print("health ok")
