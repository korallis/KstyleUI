local W = dofile("Tools/regression/widget_env.lua")
do
	local env, K = W.New()
	K.Options.Write("Setup", "closeBehaviour", "later")
	K.Setup.Open(true)
	for _, branded in ipairs({ false, true }) do
		K.Options.Write("Widgets", "general.brandedWelcome", branded)
		W.Settle(env)
		assert(K.Setup.window.welcomeNote:GetText():find("Only Apply", 1, true), "both welcome styles explain the Later choice")
	end
	K.Options.Write("Setup", "closeBehaviour", "apply")
	assert(K.Setup.window.welcomeNote:GetText():find("applies the DPS", 1, true), "changing the close choice updates an open setup")
	K.Options.Write("Setup", "closeBehaviour", "later")
	K.Options.Write("ProfileTools", "backups", false)
	assert(not K.Setup.window.welcomeNote:GetText():find("backup", 1, true), "the open welcome does not promise a disabled backup")
	K.Setup.window:Close()
	assert(#env._errors == 0, tostring(env._errors[1]))
end
for _, close in ipairs({ "close", "escape", "later" }) do
	local env, K = W.New({ boot = false })
	K.Modules.Register(W.CoreEnv.Module("ActionBars"))
	W.CoreEnv.Boot(env)
	env.RunTimers()
	W.Settle(env)
	K.Options.Write("Setup", "closeBehaviour", "later")
	local before, writes = K.Store.Export(), 0
	K.Callbacks.Register("SettingChanged", "test", function() writes = writes + 1 end)
	K.Setup.Go(3)
	W.Click(K.Setup.window.cards.Healer)
	if close == "escape" then W.Key(K.Setup.window, "ESCAPE")
	elseif close == "later" then W.Click(K.Setup.window.skip)
	else K.Setup.window:Close() end
	W.Settle(env)
	assert(K.Store.Export() == before and writes == 0, close .. ": closing setup must mean Later; only Apply changes the UI")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
do
	local Fake = dofile("Tools/regression/editmode_fake.lua")
	local env, K = W.New()
	local saved = {}
	for i = 1, 5 do saved[i] = { layoutName = "Mine " .. i, layoutType = Fake.ACCOUNT, systems = Fake.Modern().systems } end
	local state = { saved = saved, active = 3, max = 5 }
	Fake.Install(env, state)
	assert(K.Setup.Apply({ layout = "DPS", modules = {}, replaceLayout = "Mine 2" }))
	assert(state.saves == 1 and Fake.Named(state, "KstyleUI DPS"), "Apply replaces only the layout the player chose")
	assert(Fake.Named(state, "Mine 1") and Fake.Named(state, "Mine 3") and not Fake.Named(state, "Mine 2"))
	local backup = K.Store.Account().editModeBackup
	assert(backup and backup.name == "Before setup" and #backup.layouts == 7, "the named backup includes Edit Mode's five layouts and two presets")
	assert(K.Profiles.Restore())
	assert(Fake.Named(state, "Mine 2") and not Fake.Named(state, "KstyleUI DPS"), "restore brings back the replaced Edit Mode layout")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = W.New({ boot = false })
	K.Modules.Register(W.CoreEnv.Module("ActionBars"))
	W.CoreEnv.Boot(env)
	assert(K.Options.Read("Setup", "closeBehaviour") == "apply", "the owner keeps the previous Close behaviour as the default")
	K.Options.Write("ProfileTools", "backups", false)
	K.Setup.Open(true)
	K.Setup.window:Close()
	assert(K.Options.Read("ActionBars", "enabled") and K.Store.Account().setupSeen, "Apply the default setup restores the previous first-run Close behaviour")
	assert(#K.Store.ListProfiles() == 1, "Setup backups can be switched off")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
do
	local Fake = dofile("Tools/regression/editmode_fake.lua")
	local env, K = W.New()
	local saved = {}
	for i = 1, 5 do saved[i] = { layoutName = "Mine " .. i, layoutType = Fake.ACCOUNT, systems = Fake.Modern().systems } end
	local state = { saved = saved, active = 3, max = 5 }
	Fake.Install(env, state)
	K.Options.Write("Setup", "replaceLayout", false)
	assert(not K.Setup.EditMode.Write("DPS", nil, "Mine 2"), "Edit Mode replacement off restores the previous refusal at five full slots")
	assert(not state.saves and Fake.Named(state, "Mine 2"))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("setup later ok")
