-- test-gamepad.lua: controller glyphs on action bar keybinds while a gamepad is active, and the Keyboard and Gamepad bar sets.
local AB = dofile("Tools/regression/actionbars_env.lua")

local function Pad(e, style, active)
	e._game.bindings.ACTIONBUTTON1 = { "1", "PAD1" }
	e._game.bindings.ACTIONBUTTON2 = { "SHIFT-PADDUP" }
	e._game.bindings.ACTIONBUTTON3 = { "PADPADDLE1" }
	e._game.bindings.ACTIONBUTTON4 = { "Q" }
	e._padActive, e._padStyle = active, style
	e.IsBindingForGamePad = function(key) return key:match("PAD") ~= nil and key:match("NUMPAD") == nil end
	e.C_GamePad = {
		IsEnabled = function() return e._padActive end,
		GetActiveDeviceID = function() return 1 end,
		GetDeviceMappedState = function(id) return id == 1 and { labelStyle = e._padStyle } or nil end,
	}
	e.C_Texture = e.C_Texture or {}
	e.C_Texture.GetAtlasInfo = function(atlas) return atlas:match("^gamepad%-") and atlas ~= "gamepad-switch-128x-dpad-up-normal" and { width = 76, height = 75 } or nil end
end

local function Text(ns, i)
	return AB.Button(ns, "bar1", i).hotkey:GetText()
end

-- Active at login: the pad key shows as the active pad's glyph (modifiers as its triggers); keyboard-only and unknown keys keep their text.
for _, case in ipairs({ { "Letters", "gamepad-xbox1-buttona-normal", "gamepad-xbox1-trigger-lt-normal" }, { "Shapes", "gamepad-ps-buttoncrox-normal", "gamepad-ps-triggerl2-normal" }, { "Reverse", "gamepad-switch-128x-face-b-normal", "gamepad-switch-128x-zl-normal" } }) do
	local env, K, ns = AB.New({ setup = function(e) Pad(e, case[1], true) end })
	AB.Slot(env, 1, { texture = 135489, type = "spell", id = 100 })
	AB.Enable(env, K)
	local size = math.floor(select(2, AB.Button(ns, "bar1", 1).hotkey:GetFont()) * 1.5 + 0.5)
	assert(Text(ns, 1) == ("|A:%s:%d:%d|a"):format(case[2], size, size), case[1] .. ": the pad key wins over the keyboard key as its glyph: " .. tostring(Text(ns, 1)))
	assert(Text(ns, 2):find(case[3], 1, true) == 4 and Text(ns, 2):find("dpad", 1, true), case[1] .. ": Shift is the left trigger before the d-pad glyph")
	assert(case[1] ~= "Reverse" or Text(ns, 2):find("gamepad-xbox1-dpadup-normal", 1, true), "a glyph the client lacks falls back to the Xbox glyph")
	assert(Text(ns, 3) ~= nil and not Text(ns, 3):find("|A", 1, true), case[1] .. ": a pad key the game has no glyph for keeps its text")
	assert(Text(ns, 4) == "Q", case[1] .. ": a keyboard-only binding keeps its key name")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Inactive, then active, then the setting off: keyboard players and the switched-off setting see today's text.
do
	local env, K, ns = AB.New({ setup = function(e) Pad(e, "Letters", false) end })
	AB.Enable(env, K)
	assert(Text(ns, 1) == "1", "no glyph while no gamepad is active")
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
	assert(Text(ns, 1):find("gamepad-xbox1-buttona-normal", 1, true), "the glyph appears when the gamepad becomes active")
	K.Options.Write("ActionBars", "padGlyphs", false)
	assert(Text(ns, 1) == "1" and Text(ns, 2) == K.Widgets.ShortKey("SHIFT-PADDUP", function(key) return env.GetBindingText(key) end):upper(), "off restores the key names")
	K.Options.Write("ActionBars", "padGlyphs", true)
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", false)
	assert(Text(ns, 1) == "1", "the key name returns when the gamepad goes inactive")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A client without C_GamePad or IsBindingForGamePad keeps today's text.
do
	local env, K, ns = AB.New({ setup = function(e) e._game.bindings.ACTIONBUTTON1 = { "PAD1" } end })
	AB.Enable(env, K)
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
	assert(not Text(ns, 1):find("|A", 1, true), "no gamepad API: plain text")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- The Gamepad bar set writes existing settings only, reads back as current, and Keyboard restores the defaults exactly.
do
	local env, K = AB.New()
	AB.Enable(env, K)
	local Looks, cfg = K.Setup.Looks, K.Store.Module("ActionBars")
	assert(Looks.Controls() == "Keyboard", "a fresh profile is on Keyboard")
	local before = { cfg.bar1.buttons, cfg.bar2.buttons, cfg.bar1.split, cfg.bar2.split, cfg.useTray }
	assert(Looks.ApplyControls("Gamepad") and Looks.Controls() == "Gamepad", "Gamepad applies and reads back")
	assert(cfg.bar1.buttons == 8 and cfg.bar2.buttons == 8 and cfg.bar1.split == "on" and cfg.bar2.split == "on" and cfg.useTray == false, "the Gamepad set")
	assert(Looks.Current() == "Forged", "the controls leave the Look alone")
	assert(Looks.ApplyControls("Keyboard") and Looks.Controls() == "Keyboard", "Keyboard is the way back")
	local after = { cfg.bar1.buttons, cfg.bar2.buttons, cfg.bar1.split, cfg.bar2.split, cfg.useTray }
	for i = 1, #before do assert(before[i] == after[i], "Keyboard restores setting " .. i) end
	K.Options.Write("ActionBars", "bar1.buttons", 10)
	assert(Looks.Controls() == nil and not Looks.ApplyControls("Custom"), "a changed bar is your own; Custom changes nothing")
	assert(cfg.bar1.buttons == 10, "your own count stays")
	local choice = K.Setup.NewChoice()
	choice.controls = "Gamepad"
	assert(K.Setup.Apply(choice) and Looks.Controls() == "Gamepad", "setup Apply takes the Gamepad choice")
	K.Options.Write("Setup", "controls", false)
	choice.controls = "Keyboard"
	assert(K.Setup.Apply(choice) and Looks.Controls() == "Gamepad", "with the choice hidden, Apply leaves the bars alone")
	env.RunTimers()
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Setup step 2 grows by the Controls row while it shows, and keeps the base height with the row off or on any other step.
do
	local O = dofile("Tools/regression/options_env.lua")
	local env, K = O.New({})
	for _, name in ipairs(K.Setup.PICKER) do K.Modules.Register(O.W.CoreEnv.Module(name.name)) end
	assert(K.Setup.Open(true) and K.Setup.Go(2))
	local panel = K.Setup.window
	local grown = panel.opts.height
	assert(grown > 540 and panel.padTabs:IsShown(), "step 2 grows for the Controls row")
	K.Layout.Set("setup.window", "scale", 0.9)
	assert(panel.opts.height == grown, "a window restyle keeps the grown height")
	panel.padTabs:Select("Gamepad")
	assert(K.Setup.Choice().controls == "Gamepad", "a Controls tab sets the choice")
	assert(K.Setup.Go(3) and panel.opts.height == 540, "step 3 keeps the base height")
	K.Options.Write("Setup", "controls", false)
	assert(K.Setup.Go(2) and panel.opts.height == 540 and not panel.padTabs:IsShown(), "the row off: step 2 as before")
	assert(#env._errors == 0 and K.ErrorCount() == 0, table.concat(env._errors, "\n"))
end

print("ok gamepad glyphs and bar sets")
