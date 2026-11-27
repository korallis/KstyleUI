-- test-gamepad.lua: controller glyphs on action bar keybinds while a gamepad is active, and the Keyboard and Gamepad bar sets.
local AB = dofile("Tools/regression/actionbars_env.lua")
local O = dofile("Tools/regression/options_env.lua")

-- Forever's abbreviated binding text for a pad key is the game's own atlas markup (SetGamepadBindingStrings in Blizzard_SharedXML/SharedConstants.lua).
local NATIVE = { PAD1 = "Gen_1", PADDUP = "Gen_Up", PADPADDLE1 = "Gen_Paddle1", PADLSTICKUP = "Gen_LStickUp" }

local function Pad(e, style, active)
	e._game.bindings.ACTIONBUTTON1 = { "1", "PAD1" }
	e._game.bindings.ACTIONBUTTON2 = { "SHIFT-PADDUP" }
	e._game.bindings.ACTIONBUTTON3 = { "2", "PADPADDLE1" }
	e._game.bindings.ACTIONBUTTON4 = { "Q" }
	e._game.bindings.ACTIONBUTTON5 = { "PADLSTICKUP" }
	e._game.bindings.ACTIONBUTTON6 = { "3", "ALT-PAD2" }
	e._padActive, e._padStyle, e._mapped = active, style, 0
	e.IsBindingForGamePad = function(key) return key:match("PAD") ~= nil and key:match("NUMPAD") == nil end
	e.IsUsingGamepad = function() return e._padActive end
	e.GetBindingText = function(key) return NATIVE[key] and ("|A:Gamepad_%s_32:14:14|a"):format(NATIVE[key]) or "text:" .. key end
	e.C_GamePad = {
		IsEnabled = function() return true end,
		GetActiveDeviceID = function() return 1 end,
		GetDeviceMappedState = function(id)
			e._mapped = e._mapped + 1
			return id == 1 and e._padStyle and { labelStyle = e._padStyle } or nil
		end,
	}
	e.C_Texture = e.C_Texture or {}
	e.C_Texture.GetAtlasInfo = function(atlas) return atlas:match("^gamepad%-") and atlas ~= "gamepad-switch-128x-dpad-up-normal" and { width = 76, height = 75 } or nil end
end

local function Text(ns, i)
	return AB.Button(ns, "bar1", i).hotkey:GetText()
end

local function Width(text)
	local total = 0
	for width in text:gmatch("|A:[^:|]+:%d+:(%d+)|a") do total = total + tonumber(width) end
	return total
end

-- Active at login: the pad key shows as the active pad's glyph (modifiers as its triggers), a pad key outside the table as the game's own glyph, and keyboard-only keys keep their text.
for _, case in ipairs({ { "Letters", "gamepad-xbox1-buttona-normal", "gamepad-xbox1-trigger-lt-normal" }, { "Shapes", "gamepad-ps-buttoncrox-normal", "gamepad-ps-triggerl2-normal" }, { "Reverse", "gamepad-switch-128x-face-b-normal", "gamepad-switch-128x-zl-normal" } }) do
	local env, K, ns = AB.New({ setup = function(e) Pad(e, case[1], true) end })
	AB.Slot(env, 1, { texture = 135489, type = "spell", id = 100 })
	AB.Enable(env, K)
	local size = math.floor(select(2, AB.Button(ns, "bar1", 1).hotkey:GetFont()) * 1.5 + 0.5)
	local mark = "|A:%s:" .. size .. ":" .. size .. "|a"
	assert(Text(ns, 1) == mark:format(case[2]), case[1] .. ": the pad key wins over the keyboard key as its glyph: " .. tostring(Text(ns, 1)))
	assert(Text(ns, 2):find(case[3], 1, true) == 4 and Text(ns, 2):find("dpad", 1, true), case[1] .. ": Shift is the left trigger before the d-pad glyph")
	assert(case[1] ~= "Reverse" or Text(ns, 2):find("gamepad-xbox1-dpadup-normal", 1, true), "a glyph the client lacks falls back to the Xbox glyph")
	assert(Text(ns, 3) == mark:format("Gamepad_Gen_Paddle1_32"), case[1] .. ": a paddle shows the game's own glyph, not the keyboard key: " .. tostring(Text(ns, 3)))
	assert(Text(ns, 5) == mark:format("Gamepad_Gen_LStickUp_32"), case[1] .. ": a stick direction shows the game's own glyph: " .. tostring(Text(ns, 5)))
	assert(Text(ns, 6) == "APAD2", case[1] .. ": a pad key with no glyph shows its own key name: " .. tostring(Text(ns, 6)))
	assert(Text(ns, 4) == "Q", case[1] .. ": a keyboard-only binding keeps its key name")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Gamepad support on but the keyboard in use, then active, then the setting off: keyboard players and the switched-off setting see today's text, and an off setting does no pad work.
do
	local env, K, ns = AB.New({ setup = function(e) Pad(e, "Letters", false) end })
	AB.Enable(env, K)
	assert(Text(ns, 1) == "1" and Text(ns, 3) == "2", "no glyph at login while the keyboard is in use, though gamepad support is on: " .. Text(ns, 1))
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
	assert(Text(ns, 1):find("gamepad-xbox1-buttona-normal", 1, true), "the glyph appears when the gamepad becomes active")
	env._padStyle = nil
	env.FireEvent("GAME_PAD_CONNECTED")
	assert(Text(ns, 1) == "1", "no mapped pad: today's text, not a guessed Xbox glyph: " .. Text(ns, 1))
	env._padStyle = "Letters"
	for i = 7, 12 do env._game.bindings["ACTIONBUTTON" .. i] = { "PAD" .. (i - 6) } end
	env._mapped = 0
	env.FireEvent("GAME_PAD_CONNECTED")
	assert(env._mapped == 1, "one pad-style read per refresh, got " .. env._mapped)
	K.Options.Write("ActionBars", "padGlyphs", false)
	assert(Text(ns, 1) == "1" and Text(ns, 2) == K.Widgets.ShortKey("SHIFT-PADDUP", function(key) return env.GetBindingText(key) end):upper(), "off restores the key names")
	local reads, get = 0, env.GetBindingKey
	env.GetBindingKey = function(...) reads = reads + 1; return get(...) end
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", false)
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
	env.FireEvent("GAME_PAD_CONNECTED")
	assert(reads == 0 and env._mapped == 1, "pad events do no binding work while the setting is off: " .. reads .. " reads")
	K.Options.Write("ActionBars", "padGlyphs", true)
	assert(Text(ns, 1):find("gamepad-xbox1-buttona-normal", 1, true), "the pad state tracked while off shows on turning it back on")
	env.FireEvent("GAME_PAD_ACTIVE_CHANGED", false)
	assert(Text(ns, 1) == "1", "the key name returns when the gamepad goes inactive")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Glyphs fit their socket in both HUD styles and follow the keybind font as it changes.
do
	local env, K, ns = AB.New({ setup = function(e)
		Pad(e, "Shapes", true)
		e._game.bindings.ACTIONBUTTON1 = { "CTRL-SHIFT-PAD1" }
	end })
	AB.Enable(env, K)
	local b = AB.Button(ns, "bar1", 1)
	assert(Width(Text(ns, 1)) > 0 and Width(Text(ns, 1)) <= b:GetWidth(), "Medallions: a three-glyph chord stays in its socket: " .. Width(Text(ns, 1)) .. " in " .. b:GetWidth())
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	b = AB.Button(ns, "bar1", 1)
	assert(Width(Text(ns, 1)) > 0 and Width(Text(ns, 1)) <= b:GetWidth(), "Frames: a three-glyph chord stays in its button: " .. Width(Text(ns, 1)) .. " in " .. b:GetWidth())
	env._game.bindings.ACTIONBUTTON1 = { "PAD1" }
	env.FireEvent("UPDATE_BINDINGS")
	local before = Text(ns, 1)
	K.Options.Write("ActionBars", "text.hotkey.size", 20)
	local after = Text(ns, 1)
	env.FireEvent("UPDATE_BINDINGS")
	assert(after ~= before and after == Text(ns, 1), "Frames: the glyph follows the keybind font at once: " .. before .. " then " .. after .. ", " .. Text(ns, 1) .. " after a binding refresh")
	assert(Width(after) <= b:GetWidth(), "Frames: the bigger glyph stays in its button")
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- A secret device ID never reaches GetDeviceMappedState, whose arguments may not be secret.
do
	local env, K, ns = AB.New({ setup = function(e) Pad(e, "Letters", true) end })
	AB.Enable(env, K)
	env.C_GamePad.GetActiveDeviceID = function() return env.Secret(1) end
	env.C_GamePad.GetDeviceMappedState = function(id) assert(not env.issecretvalue(id), "a secret device ID reached GetDeviceMappedState") end
	local ok, err = pcall(ns.UpdateHotkey, AB.Button(ns, "bar1", 1))
	assert(ok, tostring(err))
	assert(Text(ns, 1) == "1", "an unreadable pad keeps today's text")
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

-- Setup and General with the Action Bars settings registered (`bars`) or absent.
local BARS = { bar1 = { buttons = 12, split = "off" }, bar2 = { buttons = 12, split = "off" }, useTray = true }
local function Options(size, bars)
	local env, K, ns = O.New({ width = size[1], height = size[2] })
	for _, name in ipairs(K.Setup.PICKER) do K.Modules.Register(O.W.CoreEnv.Module(name.name, bars and name.name == "ActionBars" and { defaults = BARS } or nil)) end
	return env, K, ns
end

-- Setup step 2 grows by the Controls row while it shows, and loses that row with the row off (at once, on the open step); every other step keeps the base height. The Interface size row (test-scale-game) always shows on step 2.
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = Options(size, true)
	local label = size[1] .. "x" .. size[2] .. ": "
	assert(K.Setup.Open(true) and K.Setup.Go(2))
	local panel = K.Setup.window
	local grown = panel.opts.height
	assert(grown > 540 and panel.padTabs:IsShown(), label .. "step 2 grows for the Controls row")
	K.Layout.Set("setup.window", "scale", 0.9)
	assert(panel.opts.height > 540 and math.abs(panel.opts.height - grown) < 4, label .. "a window resize keeps the grown height, refitted to the new scale's pixels")
	panel.padTabs:Select("Gamepad")
	assert(K.Setup.Choice().controls == "Gamepad", label .. "a Controls tab sets the choice")
	assert(K.Setup.Go(3) and panel.opts.height == 540, label .. "step 3 keeps the base height")
	assert(K.Setup.Go(2) and panel.opts.height > 540, label .. "back on step 2 the row grows the window again")
	K.Options.Write("Setup", "controls", false)
	local without = panel.opts.height
	assert(without > 540 and without < grown - 20 and not panel.padTabs:IsShown(), label .. "the row off on the open step: the window loses the Controls row at once, got " .. without)
	assert(K.Setup.Go(3) and K.Setup.Go(2) and panel.opts.height == without and not panel.padTabs:IsShown(), label .. "the row off: step 2 stays without it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, table.concat(env._errors, "\n"))
end

-- Without the Action Bars settings, the Controls choice claims nothing and shows nowhere.
do
	local env, K, ns = Options({ 1920, 1080 }, false)
	local Looks = K.Setup.Looks
	assert(Looks.Controls() == nil and not Looks.ApplyControls("Gamepad") and Looks.Controls() == nil, "no Action Bars settings: no current set and Apply refuses")
	assert(K.Setup.Open(true) and K.Setup.Go(2) and not K.Setup.window.padTabs:IsShown() and K.Setup.window.opts.height < 620, "setup hides the row: step 2 grows only by its one Interface size row, got " .. K.Setup.window.opts.height)
	for _, item in ipairs(ns.Pages.Find(ns.Pages.List(), "General").Items()) do
		assert(item.label ~= K.L["Controls"], "General hides the row")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, table.concat(env._errors, "\n"))
end

print("ok gamepad glyphs and bar sets")
