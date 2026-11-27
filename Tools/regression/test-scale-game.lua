-- test-scale-game.lua: Interface size can follow the game's UI scale, in settings and in setup, up to the size that fits; setup's Edit Mode places stay put when the game's UI scale changes.
-- Intent: the owner asked for an option to turn off the automatic pixel-perfect size for players who use the game's
-- UI scale, offered in the setup too; the accepted plan includes re-placing setup's Edit Mode windows on a scale change.
local W = dofile("Tools/regression/widget_env.lua")
local CoreEnv = W.CoreEnv
local F = dofile("Tools/regression/editmode_fake.lua")

local UI_HEIGHT = 768
local DEFAULT_GAME_SCALE = 768 / 1080

local function near(a, b)
	return math.abs(a - b) <= 1e-9
end

-- The stub's UIParent sizes itself once, at creation; a game scale change resizes it the way the client does.
local function SetGameScale(env, scale, width, height)
	env.UIParent._scale = scale
	env.UIParent._width, env.UIParent._height = UI_HEIGHT * width / height / scale, UI_HEIGHT / scale
	env.FireEvent("UI_SCALE_CHANGED")
	env.RunTimers()
end

-- At 2560x1440 a step is 1080 / (16 * 1440) = 0.046875. Following the game's scale s asks for s / (768 / 1080):
-- 0.64 asks 0.9, nearest step 19 (0.890625); 0.71 asks 1.0, nearest step 21 (0.984375), which is Auto's size;
-- 0.90 asks 1.2656 but the DPS layout fits only up to 0.9982, so it stays at step 21.
do
	local env, K = CoreEnv.New({
		width = 2560, height = 1440, uiScale = DEFAULT_GAME_SCALE, size = "auto", fit = true,
		setup = function(e)
			e.GetPhysicalScreenSize = function() return 2560, 1440 end
		end,
	})
	CoreEnv.Boot(env)
	env.RunTimers()
	local Scale = K.Scale
	assert(K.Appearance.Get("uiScaleGame") == false and not Scale.IsGame(), "a new profile does not follow the game's UI scale")
	assert(near(Scale.AppliedUserScale(), 0.984375), "Auto applies 0.984375 at 2560x1440, got " .. Scale.AppliedUserScale())
	K.Options.Write("Appearance", "uiScaleGame", true)
	assert(Scale.IsGame() and near(Scale.AppliedUserScale(), 0.984375), "at the game's default scale the size is Auto's, got " .. Scale.AppliedUserScale())
	SetGameScale(env, 0.64, 2560, 1440)
	assert(near(Scale.AppliedUserScale(), 0.890625), "a 0.64 game scale shrinks the HUD to 0.890625, got " .. Scale.AppliedUserScale())
	local perUnit = 1440 * Scale.Root():GetEffectiveScale() / UI_HEIGHT
	assert(near(perUnit * Scale.STEPS_PER_PIXEL, 19), "the followed size is 19 sixteenths of a pixel per unit, got " .. perUnit * 16)
	SetGameScale(env, 0.9, 2560, 1440)
	assert(near(Scale.AppliedUserScale(), 0.984375), "a 0.90 game scale stops at the largest size that fits, got " .. Scale.AppliedUserScale())
	SetGameScale(env, 0.64, 2560, 1440)
	env.SetCombat(true)
	local rootScale = Scale.Root():GetScale()
	SetGameScale(env, DEFAULT_GAME_SCALE, 2560, 1440)
	assert(Scale.Root():GetScale() == rootScale, "a game scale change in combat waits")
	env.SetCombat(false)
	env.RunTimers()
	assert(near(Scale.AppliedUserScale(), 0.984375), "leaving combat applies the followed size, got " .. Scale.AppliedUserScale())
	SetGameScale(env, 0.64, 2560, 1440)
	K.Options.Write("Appearance", "uiScaleGame", false)
	assert(not Scale.IsGame() and near(Scale.AppliedUserScale(), 0.984375), "switching it off returns to the pixel-perfect size, got " .. Scale.AppliedUserScale())
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Settings: while the switch is on, the Auto switch and the size slider hide.
do
	local env, K = CoreEnv.New({ size = "auto" })
	CoreEnv.Boot(env)
	local auto, slider = K.Options.Row("Appearance", "uiScaleAuto"), K.Options.Row("Appearance", "uiScale")
	assert(K.Options.Row("Appearance", "uiScaleGame"), "General > Size offers Follow the game's UI scale")
	assert(auto.showWhen({}) and not slider.showWhen({}), "a new profile shows the Auto switch and hides the slider")
	assert(slider.showWhen({ uiScaleAuto = false }), "Auto off shows the slider")
	assert(not auto.showWhen({ uiScaleGame = true }) and not slider.showWhen({ uiScaleGame = true, uiScaleAuto = false }), "following the game's UI scale hides the Auto switch and the slider")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Setup's HUD style step: the Interface size row waits for Apply, an untouched row changes nothing, and the slider shows Your own.
do
	local env, K = W.New({ boot = false, size = "auto" })
	for _, entry in ipairs(K.Setup.PICKER) do K.Modules.Register(CoreEnv.Module(entry.name)) end
	CoreEnv.Boot(env)
	local function settle() env.RunTimers(); W.Settle(env); env.RunTimers() end
	assert(K.Setup.Open())
	K.Setup.Go(2)
	settle()
	local panel = K.Setup.window
	assert(panel.sizeTabs:IsShown() and panel.sizeTabs:GetValue() == "Pixel", "the HUD style step offers Interface size, on Pixel perfect")
	assert(K.Setup.Apply(K.Setup.Choice()) and K.Appearance.Get("uiScaleGame") == false and K.Appearance.Get("uiScaleAuto") == true, "an untouched row changes nothing")
	K.Setup.Go(2)
	settle()
	panel.sizeTabs:Select("Game")
	assert(K.Setup.Choice().uiScale == "Game" and K.Appearance.Get("uiScaleGame") == false, "picking Game's UI scale waits for Apply")
	assert(K.Setup.Apply(K.Setup.Choice()) and K.Appearance.Get("uiScaleGame") == true and K.Scale.IsGame(), "Apply turns on Follow the game's UI scale")
	K.Setup.Go(2)
	settle()
	assert(panel.sizeTabs:GetValue() == "Game", "setup shows Game's UI scale while it is on")
	panel.sizeTabs:Select("Pixel")
	assert(K.Setup.Apply(K.Setup.Choice()) and K.Appearance.Get("uiScaleGame") == false and K.Appearance.Get("uiScaleAuto") == true, "Pixel perfect turns it off and Auto on")
	K.Options.Write("Appearance", "uiScaleAuto", false)
	assert(K.Setup.Open())
	K.Setup.Go(2)
	settle()
	assert(panel.sizeTabs:GetValue() == "Custom", "a size from the slider shows Your own")
	assert(K.Setup.Apply(K.Setup.Choice()) and K.Appearance.Get("uiScaleAuto") == false, "Apply keeps your own size")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Edit Mode: setup places the quest tracker at (1347, 811) and the damage meter at (1653, 175) screen pixels on
-- 1920x1080; a game scale change from 0.71 to 0.90 re-places both so they keep those pixels.
do
	local state = { saved = { { layoutName = "Mine", layoutType = F.ACCOUNT, systems = F.Modern().systems } }, active = 1 }
	local env, K = W.New({ boot = false, width = 1920, height = 1080, uiScale = DEFAULT_GAME_SCALE, size = "auto", setup = function(e) F.Install(e, state) end })
	CoreEnv.Boot(env)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	env.RunTimers()
	local function Pixels(system)
		local a = F.Find(F.Named(state, "KstyleUI DPS"), system).anchorInfo
		local s = env.UIParent:GetEffectiveScale() * 1080 / UI_HEIGHT
		return math.floor(a.offsetX * s + 0.5), math.floor(a.offsetY * s + 0.5)
	end
	local tx, ty = Pixels(F.TRACKER)
	local mx, my = Pixels(F.METER)
	assert(tx == 1347 and ty == 811 and mx == 1653 and my == 175, string.format("setup's places: tracker %d,%d meter %d,%d", tx, ty, mx, my))
	SetGameScale(env, 0.9, 1920, 1080)
	tx, ty = Pixels(F.TRACKER)
	mx, my = Pixels(F.METER)
	assert(tx == 1347 and ty == 811, string.format("the tracker keeps its pixels, got %d,%d", tx, ty))
	assert(mx == 1653 and my == 175, string.format("the damage meter keeps its pixels, got %d,%d", mx, my))
	-- A rescale that leaves every place where it is, as the size settings applied at each login do, saves nothing.
	local saves = state.saves
	K.Callbacks.Fire("HudStyleChanged")
	env.RunTimers()
	assert(state.saves == saves, "a restyle that moves nothing does not save the layouts again")
	-- Restyle compares the whole Edit Mode entry: a second anchor on the tracker, which Place clears, is a change it saves.
	F.Find(F.Named(state, "KstyleUI DPS"), F.TRACKER).anchorInfo2 = { point = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 1600, offsetY = 600 }
	K.Callbacks.Fire("HudStyleChanged")
	env.RunTimers()
	assert(state.saves == saves + 1 and F.Find(F.Named(state, "KstyleUI DPS"), F.TRACKER).anchorInfo2 == nil, "a restyle that clears the tracker's second anchor saves it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Follow mode: at 1920x1080 a game scale of 2/3 asks 0.9375, a whole step, so the root-to-game ratio stays 1 while
-- the root grows from 1920x1080 to 2048x1152 units. Setup re-places what it owns at the places a fresh Apply at 2/3
-- writes (tracker 1475,883, tracked buff icons 933,462.6), and a buff bar viewer the player moved by hand, with no
-- setup stamp, keeps its place.
do
	local state = { saved = { { layoutName = "Mine", layoutType = F.ACCOUNT, systems = F.Modern().systems } }, active = 1 }
	local env, K = W.New({ boot = false, width = 1920, height = 1080, uiScale = DEFAULT_GAME_SCALE, size = "auto", setup = function(e) F.Install(e, state) end })
	CoreEnv.Boot(env)
	K.Options.Write("Appearance", "uiScaleGame", true)
	env.RunTimers()
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	env.RunTimers()
	local layout = F.Named(state, "KstyleUI DPS")
	local icons = F.Find(layout, F.VIEWER, F.BUFF_ICON).anchorInfo
	assert(near(icons.offsetX, 869) and near(icons.offsetY, 462.6), string.format("setup places the tracked buff icons at 869,462.6, got %s,%s", icons.offsetX, icons.offsetY))
	K.Store.Account().editModeRows["KstyleUI DPS"][F.BUFF_BAR] = nil
	F.Find(layout, F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX = 100
	SetGameScale(env, 2 / 3, 1920, 1080)
	assert(near(K.Scale.AppliedUserScale(), 0.9375) and near(K.Setup.EditMode.Factor(), 1), "2/3 follows to 0.9375 with the ratio unchanged")
	-- SaveLayouts replaces the fake's saved tables, so read the layout again.
	layout = F.Named(state, "KstyleUI DPS")
	local tracker, bars = F.Find(layout, F.TRACKER).anchorInfo, F.Find(layout, F.VIEWER, F.BUFF_BAR).anchorInfo
	icons = F.Find(layout, F.VIEWER, F.BUFF_ICON).anchorInfo
	assert(near(tracker.offsetX, 1475) and near(tracker.offsetY, 883), string.format("the tracker follows the grown HUD to 1475,883, got %s,%s", tracker.offsetX, tracker.offsetY))
	assert(near(icons.offsetX, 933) and near(icons.offsetY, 462.6), string.format("setup's tracked buff icons follow to 933,462.6, got %s,%s", icons.offsetX, icons.offsetY))
	assert(near(bars.offsetX, 100), "a buff bar viewer moved by hand, with no setup stamp, keeps its place, got " .. tostring(bars.offsetX))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A resolution change keeps what v0.3.5.2 did, as the owner chose: only a new layout class, band or warning lane
-- restyles, and that restyle re-places an unstamped viewer too, so older layouts adapt to the new screen. Only game
-- UI Scale and Follow changes use the ratio and root-size triggers and leave a hand-moved viewer alone.
local function Resolution(width, height)
	local state = { saved = { { layoutName = "Mine", layoutType = F.ACCOUNT, systems = F.Modern().systems } }, active = 1 }
	local screen = { 1920, 1080 }
	local env, K = W.New({ boot = false, width = 1920, height = 1080, uiScale = DEFAULT_GAME_SCALE, size = "auto", setup = function(e)
		F.Install(e, state)
		e.GetPhysicalScreenSize = function() return screen[1], screen[2] end
	end })
	CoreEnv.Boot(env)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	env.RunTimers()
	K.Store.Account().editModeRows["KstyleUI DPS"][F.BUFF_BAR] = nil
	F.Find(F.Named(state, "KstyleUI DPS"), F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX = 100
	local saves = state.saves
	screen[1], screen[2] = width, height
	env.UIParent._width, env.UIParent._height = UI_HEIGHT * width / height / DEFAULT_GAME_SCALE, UI_HEIGHT / DEFAULT_GAME_SCALE
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
	assert(#env._errors == 0, tostring(env._errors[1]))
	local layout = F.Named(state, "KstyleUI DPS")
	return state.saves - saves, F.Find(layout, F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX, F.Find(layout, F.TRACKER).anchorInfo.offsetX
end

do
	-- 1920x1080 to 2560x1440 stays 16:9: the ratio moves (1 to 0.984375) but no earlier trigger fires, so nothing moves.
	local saves, bar, tracker = Resolution(2560, 1440)
	assert(saves == 0 and near(bar, 100) and near(tracker, 1347), string.format("a 16:9 resolution change restyles nothing, as before this hotfix: %d saves, bar %s, tracker %s", saves, bar, tracker))
	-- 1920x1080 to 3440x1440 changes the layout class to 21:9: the earlier rule re-places the unstamped viewer too.
	saves, bar = Resolution(3440, 1440)
	assert(saves == 1 and not near(bar, 100), string.format("a 21:9 resolution change re-places an unstamped viewer, as before this hotfix: %d saves, bar %s", saves, bar))
end

-- The size slider is a scale change too: with Auto off, a new Interface size re-places setup's tracker and leaves a
-- buff bar viewer moved by hand, with no setup stamp, where the player put it.
do
	local state = { saved = { { layoutName = "Mine", layoutType = F.ACCOUNT, systems = F.Modern().systems } }, active = 1 }
	local env, K = W.New({ boot = false, width = 1920, height = 1080, uiScale = DEFAULT_GAME_SCALE, size = "auto", setup = function(e) F.Install(e, state) end })
	CoreEnv.Boot(env)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	env.RunTimers()
	K.Options.Write("Appearance", "uiScaleAuto", false)
	env.RunTimers()
	K.Store.Account().editModeRows["KstyleUI DPS"][F.BUFF_BAR] = nil
	F.Find(F.Named(state, "KstyleUI DPS"), F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX = 100
	local tracker, saves = F.Find(F.Named(state, "KstyleUI DPS"), F.TRACKER).anchorInfo.offsetX, state.saves
	K.Options.Write("Appearance", "uiScale", 0.75)
	env.RunTimers()
	local layout = F.Named(state, "KstyleUI DPS")
	assert(state.saves == saves + 1 and not near(F.Find(layout, F.TRACKER).anchorInfo.offsetX, tracker), "a new Interface size re-places setup's tracker")
	assert(near(F.Find(layout, F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX, 100), "a new Interface size leaves a hand-moved, unstamped viewer in place, got " .. tostring(F.Find(layout, F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- An ultrawide arrangement or HUD width change at one screen size and one game UI Scale is not a scale change, as the
-- owner chose: it resizes the root, but its restyle keeps the earlier rule and re-places an unstamped viewer, so an
-- older layout follows the HUD as it did before this hotfix.
do
	local state = { saved = { { layoutName = "Mine", layoutType = F.ACCOUNT, systems = F.Modern().systems } }, active = 1 }
	local env, K = W.New({ boot = false, width = 5120, height = 1440, uiScale = DEFAULT_GAME_SCALE, size = "auto", setup = function(e)
		F.Install(e, state)
		e.GetPhysicalScreenSize = function() return 5120, 1440 end
	end })
	CoreEnv.Boot(env)
	assert(K.Setup.Apply({ layout = "DPS", modules = {} }))
	env.RunTimers()
	local function Change(key, value)
		K.Store.Account().editModeRows["KstyleUI DPS"][F.BUFF_BAR] = nil
		F.Find(F.Named(state, "KstyleUI DPS"), F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX = 100
		local saves, rw = state.saves, K.Setup.RootSize()
		K.Options.Write("Layout", key, value)
		env.RunTimers()
		assert(#env._errors == 0, tostring(env._errors[1]))
		assert(math.abs(K.Setup.RootSize() - rw) > 0.5, string.format("%s %s resizes the root, got %s to %s", key, value, rw, K.Setup.RootSize()))
		return state.saves - saves, F.Find(F.Named(state, "KstyleUI DPS"), F.VIEWER, F.BUFF_BAR).anchorInfo.offsetX
	end
	-- Setup learns the root's size from the first scale change after loading, so the later changes also pass the
	-- root-size compare that a game UI Scale change in Follow mode relies on.
	for _, change in ipairs({ { "arrangement", "spread" }, { "arrangement", "centred" }, { "canvas", "16:9" } }) do
		local saves, bar = Change(change[1], change[2])
		assert(saves == 1 and not near(bar, 100), string.format("%s %s re-places an unstamped viewer, as before this hotfix: %d saves, bar %s", change[1], change[2], saves, bar))
	end
end

print("scale game ok")
