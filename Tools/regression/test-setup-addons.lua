-- test-setup-addons.lua: live addon discovery, skin defaults, shared Options choices, Apply, reopen and Keep at every owner screen.
local Suite = dofile("Tools/regression/suite_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Fake = dofile("Tools/regression/addons_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Boot(screen, list, profile)
	return Suite.New({ version = 42, profiles = { Default = profile or {} }, characters = {}, account = { setupSeen = true } }, screen[1], screen[2], function(env) Fake.Install(env, list) end)
end

local function Item(panel, name, path)
	return assert(assert(panel.addons.groups[name], name).items[path], path).control
end

do
	local _, K = Boot({1920, 1080}, { { name = "FishingBuddy", loaded = true, enabled = 2 } })
	assert(K.Setup.Open(true))
	assert(#K.Setup.window.steps.items == 4, "skip Your addons when only an unsupported addon is installed")
end

for _, screen in ipairs({ {1920, 1080}, {2560, 1440}, {5120, 1440}, {3840, 2160} }) do
	local env, K = Boot(screen)
	local registry = env._addons.KstyleUI_Skins.Skins
	assert(K.Store.Defaults("Skins").enabled and K.Modules.IsRunning("Skins"), "a fresh profile runs Skins")
	for _, def in ipairs(registry.List()) do
		assert(K.Store.Defaults("Skins")[def.key].enabled and registry.IsOn(def.key), "every skin defaults on: " .. def.key)
	end
	assert(K.Setup.Open(true))
	W.Settle(env)
	local panel = K.Setup.window
	assert(panel.pages[1].branded.list:GetText():find("your addons", 1, true), "the welcome includes the detected-addon choice")
	assert(#panel.steps.items == 5 and panel.steps.items[4].label == "Your addons", "detected addons insert a step after Modules")
	assert(#K.Setup.Choice().addons == 4, "include only enabled supported addons")
	assert(K.Setup.Choice().modules.Skins, "Questie must not disable the whole Skins module")
	assert(K.Setup.Go(4))
	W.Settle(env)
	assert(Item(panel, "RXPGuides", "Skins.restedXP.enabled"):GetValue(), "Skin it starts ticked")
	assert(Item(panel, "Questie", "Skins.questie.enabled"):GetValue(), "new registry addon skins appear automatically and start ticked")
	assert(not Item(panel, "Bartender4", "ActionBars.enabled"):GetValue(), "prefer the installed bars")
	assert(not Item(panel, "Bartender4", "DataBars.micro.enabled"):GetValue() and not Item(panel, "Bartender4", "DataBars.bags.enabled"):GetValue(), "yield menus only")
	assert(not Item(panel, "Details", "Meters.damage.shown"):GetValue() and K.Setup.Choice().modules.Meters, "yield damage only")
	local tracker = Item(panel, "Questie", "Integrations.questTracker")
	assert(tracker:GetValue() == "kstyleui", "recommend KstyleUI's quest card")
	local options = K.Options.Row("Integrations", "questTracker").options
	assert(tracker.options == options and #options == 4 and options[4].value == "both", "setup and Options share tracker choices, including the existing Automatic choice")
	for _, group in ipairs(panel.addons.active) do
		for _, item in ipairs(group.active) do
			assert(item.row.key == "enabled" or K.Options.Row(item.row.module, item.row.key), "each choice uses its existing Options setting")
			assert(item.note.Restyle == panel.toggles.Skins.note.Restyle, "addon notes must share the Modules NoteStyle")
			local _, size = item.note:GetFont()
			assert(math.abs(size - 11 * K.Theme.FontScale()) < 1, "readable addon notes must use the setup's 11-unit note size")
			local rect = assert(Geometry.Rect(item.control, panel.addons.body))
			local page = assert(Geometry.Rect(panel.addons.body, panel.addons.body))
			assert(rect.left >= page.left - 1 and rect.right <= page.right + 1, "addon controls stay inside their page at every screen")
		end
	end
	K.Options.Write("Setup", "readableNotes", false)
	local note = panel.addons.active[1].active[1].note
	local moduleNote = panel.toggles.Skins.note
	local face, size, flags = note:GetFont()
	local moduleFace, moduleSize, moduleFlags = moduleNote:GetFont()
	assert(face == moduleFace and size == moduleSize and flags == moduleFlags and not note:CanWordWrap(), "addon notes must follow Readable setup notes off like Modules")
	K.Options.Write("Setup", "readableNotes", true)
	local before, writes = K.Store.Export(), 0
	K.Callbacks.Register("SettingChanged", "test", function() writes = writes + 1 end)
	Item(panel, "RXPGuides", "Skins.restedXP.enabled"):SetValue(false)
	Item(panel, "Questie", "Skins.questie.enabled"):SetValue(false)
	Item(panel, "Bartender4", "ActionBars.enabled"):SetValue(true)
	Item(panel, "Bartender4", "DataBars.micro.enabled"):SetValue(true)
	Item(panel, "Details", "Meters.damage.shown"):SetValue(true)
	tracker:SetValue("both")
	assert(K.Store.Export() == before and writes == 0, "editing setup only changes its pending choices")
	assert(panel.toggles.ActionBars:GetValue(), "same-job edits also update Modules")
	assert(K.Setup.Go(5) and K.Setup.Apply(K.Setup.Choice()))
	assert(not K.Options.Read("Skins", "restedXP.enabled") and not K.Options.Read("Skins", "questie.enabled"), "apply every skin choice")
	assert(K.Options.Read("ActionBars", "enabled") and K.Options.Read("DataBars", "micro.enabled") and not K.Options.Read("DataBars", "bags.enabled"), "apply bars and each menu independently")
	assert(K.Options.Read("Meters", "damage.shown") and K.Options.Read("Integrations", "questTracker") == "both", "addon choices win over the layout preset")
	assert(K.Setup.Open())
	W.Settle(env)
	assert(not Item(panel, "RXPGuides", "Skins.restedXP.enabled"):GetValue() and Item(panel, "Bartender4", "ActionBars.enabled"):GetValue(), "rerunning setup keeps skin and module choices")
	assert(not Item(panel, "Questie", "Skins.questie.enabled"):GetValue(), "rerunning setup keeps the reversible Questie skin choice")
	assert(Item(panel, "Bartender4", "DataBars.micro.enabled"):GetValue() and Item(panel, "Details", "Meters.damage.shown"):GetValue() and tracker:GetValue() == "both", "rerunning keeps partial and tracker choices")
	before, writes = K.Store.Export(), 0
	Item(panel, "RXPGuides", "Skins.restedXP.enabled"):SetValue(true)
	W.Click(panel.skip)
	W.Settle(env)
	assert(K.Store.Export() == before and writes == 0, "Keep my UI leaves every pending addon choice untouched")
	Fake.Install(env, {})
	assert(K.Setup.Open())
	assert(#panel.steps.items == 4 and panel.pages[4] == panel.summaryPage, "reopening skips the addons step when the live list is empty")
	assert(not panel.pages[1].branded.list:GetText():find("your addons", 1, true), "the welcome updates when no addons remain")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	print("setup addons " .. screen[1] .. "x" .. screen[2] .. ": defaults, detection, choices, reopen, Keep")
end

do
	local _, K = Boot({1920, 1080}, { { name = "RXPGuides", loaded = true, enabled = 2 } }, { Skins = { enabled = false, restedXP = { enabled = false } } })
	K.Setup.Open()
	assert(not K.Setup.Choice().modules.Skins and not K.Setup.Choice().addonSettings["Skins.restedXP.enabled"], "reopening preserves explicit master and per-addon off choices without an overlap")
end

do
	local env, K = Boot({1920, 1080}, {
		{ name = "Dominos", loaded = false, enabled = 2 }, { name = "Plater", loaded = true, enabled = 2 },
		{ name = "Bagnon", loaded = true, enabled = 2 }, { name = "Grid2", loaded = true, enabled = 2 },
	})
	K.Setup.Open(true)
	for _, module in ipairs({ "ActionBars", "Nameplates", "Bags", "GroupFrames" }) do assert(not K.Setup.Choice().modules[module], "same-job choices yield " .. module) end
	assert(K.Setup.Choice().modules.Skins, "other addons do not turn off window skins")
	assert(#K.Setup.Choice().addons == 4, "enabled load-on-demand supported addons count as installed")
	env.C_AddOns.GetAddOnEnableState = nil
	assert(#K.Setup.Integrations.Addons() == 3, "without enable-state information, include only loaded addons")
	env.C_AddOns.GetNumAddOns = function() return env.Secret(10) end
	assert(#K.Setup.Integrations.Addons() == 0, "ignore a secret addon count")
	env.C_AddOns.GetNumAddOns = nil
	assert(#K.Setup.Integrations.Addons() == 0, "missing detection is safe")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local _, K = W.New({ setup = function(env) Fake.Install(env, { { name = "RXPGuides", loaded = true, enabled = 2 } }) end })
	assert(K.Setup.Open(true))
	assert(#K.Setup.window.steps.items == 4, "skip registry-only addons when Skins is not loaded")
end

print("setup addons ok")
