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
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("scale game ok")
