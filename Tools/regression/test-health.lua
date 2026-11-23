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

local GUID = "Player-1-0000001"

local function Install(env, enabled)
	local function entry(folder)
		return FOLDERS[folder:match("^KstyleUI_(.+)$") or ""] or {}
	end
	env.ADDON_INTERFACE_VERSION = "Out of date"
	env.UnitGUID = function(unit) return unit == "player" and GUID or nil end
	env.C_AddOns = {
		DoesAddOnExist = function(folder) return entry(folder).exists ~= false end,
		IsAddOnLoaded = function(folder) local loaded = entry(folder).loaded == true; return loaded, loaded end,
		GetAddOnMetadata = function(folder, field) assert(field == "Version"); return entry(folder).version or "@project-version@" end,
		DoesAddOnHaveLoadError = function(folder) return entry(folder).loadError == true end,
		GetAddOnInfo = function(folder) local e = entry(folder); return folder, folder, "", e.loadable == true, e.reason, "INSECURE" end,
		IsAddOnLoadOnDemand = function(folder) return folder == "KstyleUI_Options" or folder == "KstyleUI_Routes" end,
		EnableAddOn = function(folder, character) enabled[#enabled + 1] = folder .. "@" .. tostring(character) end,
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
		spec.handle = popup(spec)
		return spec.handle
	end
	for name, folder in pairs(FOLDERS) do
		if folder.module then
			K.Modules.Register(CoreEnv.Module(name, { onEnable = function() if folder.fails then error("Valerin-Silvermoon Player-123-456", 0) end end }))
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

local function About(env)
	local ns, items = { Changed = function() end, Window = { State = function() return {} end } }, {}
	local load = assert(loadfile("KstyleUI_Options/About.lua"))
	setfenv(load, env)
	load("KstyleUI_Options", ns)
	ns.StatusItems(function(item) items[#items + 1] = item end)
	return items
end

local function States(K)
	local out = {}
	for _, row in ipairs(K.Health.Modules()) do out[row.name] = row end
	return out
end

do
	local env, K, popups, enabled = Boot()
	local host = K.Widgets.DialogHost()
	local rows = States(K)
	local want = { ActionBars = "disabled", Bags = "failed", Chat = "outdated", Meters = "error", UnitFrames = "error", Nameplates = "error",
		Minimap = "reload", QoL = "off", Options = "ondemand", Routes = "missing", Skins = "running", Auras = "running" }
	for name, state in pairs(want) do
		assert(rows[name] and rows[name].state == state, name .. " must read " .. state .. ", got " .. tostring(rows[name] and rows[name].state))
	end
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
	assert(notice.buttons[1].label == "Later" and fix.reload and fix.label == "Turn on and reload", "Later, then Turn on and reload")
	env.SetCombat(true)
	host.editBox:GetScript("OnEnterPressed")(host.editBox)
	env.SetCombat(false)
	assert(#enabled == 0 and notice.handle:IsShown(), "Enter in the link box neither turns anything on nor closes the notice: " .. tostring(enabled[1]))
	fix.onClick()
	assert(#enabled == 1 and enabled[1] == "KstyleUI_ActionBars@" .. GUID, "the fix turns on only the folders the AddOn list turned off, for this character only: " .. tostring(enabled[1]))
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
	assert(host.body:GetText():find("Action bars", 1, true), "the first notice stays up while the later one waits")
	notice.handle:Close()
	assert(host.body:GetText():find("Quality of life: Hit an error while loading", 1, true), "closing the first notice shows the later one:\n" .. host.body:GetText())
	local about = About(env)
	about[2].set(false)
	assert(not popups[2].handle:IsShown(), "switching Load check off closes its notice")
	about[2].set(true)
	assert(#popups == 2, "switching it back on names nothing already named")

	local report = K.Health.Report()
	for _, part in ipairs({ "ActionBars disabled", "Bags failed INTERFACE_VERSION", "Chat outdated", "UnitFrames error", "Routes missing",
		"Options ondemand", "Cooldowns off", "QoL error", "skins absent", "hud medallions", "profile default", "errors " }) do
		assert(report:find(part, 1, true), "the report holds " .. part .. ":\n" .. report)
	end
	for _, private in ipairs({ "Valerin", "Silvermoon", "Player-", "0.2.14" }) do
		assert(not report:find(private, 1, true), "the report carries codes only, never an error's or a TOC's text such as " .. private .. ":\n" .. report)
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
	FOLDERS = { Routes = { reason = "DEMAND_LOADED", version = "0.0.1" }, Options = { reason = "DEMAND_LOADED", loadError = true } }
	local rows = States(select(2, Boot()))
	assert(rows.Routes.state == "outdated" and rows.Options.state == "error", "a part that loads when opened still reads its version and load error: " .. rows.Routes.state .. ", " .. rows.Options.state)
end

do
	FOLDERS = { Options = { reason = "DEMAND_LOADED" } }
	local env, _, popups = Boot()
	assert(#popups == 0, "a part that loads when opened is fine")
	FOLDERS.Options = { loaded = true, loadError = true }
	env.FireEvent("ADDON_LOADED", "KstyleUI_Options")
	env.RunTimers()
	assert(#popups == 1 and popups[1].text:find("Settings window: Hit an error while loading", 1, true), "a part that breaks when it loads on demand gets a notice")
end

do
	FOLDERS = { Routes = { reason = "DEP_DISABLED" } }
	local _, _, popups, enabled = Boot()
	local notice = assert(popups[1], "a part whose KstyleUI is turned off gets a notice")
	assert(not notice.editBox and notice.text:find("Turn them back on", 1, true), "turning KstyleUI back on is the fix, not an update:\n" .. notice.text)
	notice.buttons[2].onClick()
	assert(enabled[1] == "KstyleUI@" .. GUID, "the fix turns KstyleUI itself on for this character: " .. tostring(enabled[1]))
end

do
	local env, K = CoreEnv.New()
	K.Modules.Register(CoreEnv.Module("Skins", { onEnable = function() error("example", 0) end }))
	K.Setup.Integrations.RegisterSkins(function() return { { key = "zygor", label = "Zygor", addon = "ZygorGuidesViewerForever" } } end)
	env.C_AddOns = { IsAddOnLoaded = function() return true, true end }
	CoreEnv.LoadSaved(env)
	K.Store.Module("Skins").enabled = true
	CoreEnv.Login(env)
	assert(K.Health.Report():find("zygor off", 1, true), "a skin reads off when the Skins module failed:\n" .. K.Health.Report())
end

do
	local env, K = CoreEnv.New()
	CoreEnv.LoadSaved(env)
	K.Store.Account().healthChecks = false
	local after, scheduled = env.C_Timer.After, 0
	env.C_Timer.After = function(delay, fn)
		if fn == K.Health.Check then scheduled = scheduled + 1 end
		return after(delay, fn)
	end
	CoreEnv.Login(env)
	assert(scheduled == 0, "Load check off schedules nothing at login")
	local bare = CoreEnv.New()
	CoreEnv.LoadSaved(bare)
	bare.C_Timer.After = nil
	CoreEnv.Login(bare)
	for _, err in ipairs(bare._errors) do
		assert(not tostring(err):find("Health", 1, true), "a client without C_Timer.After skips the check: " .. tostring(err))
	end
end

do
	local env, K, ns = O.New()
	local exist, asked = env.C_AddOns.DoesAddOnExist, 0
	env.C_AddOns.DoesAddOnExist = function(...)
		asked = asked + 1
		if exist then return exist(...) end
	end
	K.Options.Open()
	local search = ns.Window.Parts().search
	search:SetText("font")
	search:GetScript("OnTextChanged")(search, true)
	assert(asked == 0, "a settings search reads no part's state, got " .. asked)
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
	for _, item in ipairs(Items()) do
		assert(item.kind ~= "note" or not tostring(item.label):find("\n", 1, true), "each status line is its own row:\n" .. tostring(item.label))
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
