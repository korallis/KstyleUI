-- KstyleUI_ActionBars.lua: the action bars' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local AB = dofile("Tools/regression/actionbars_env.lua")

local SLOTS = 12

return {
	{
		name = "ActionBars ACTIONBAR_UPDATE_COOLDOWN",
		budget = 100,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			for n = 1, SLOTS do
				AB.Slot(env, n, { texture = 135000 + n, type = "spell", id = 100 + n, cooldown = { name = "cd" .. n } })
			end
			AB.Slot(env, 2, {
				texture = 135002, type = "spell", id = 102, cooldown = { name = "cd2" }, count = "2",
				charges = { maxCharges = 2, currentCharges = 1, isActive = true }, chargeDuration = { name = "charge2" },
			})
			return env, Perf.Event(env, "ACTIONBAR_UPDATE_COOLDOWN")
		end,
	},
	{
		name = "ActionBars PET_BAR_UPDATE_COOLDOWN at Full with a pet, tray unchanged",
		budget = 160,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			env._game.petExists = true
			env.FireEvent("UNIT_PET", "player")
			env.SetCombat(true)
			env.RunTimers()
			return env, Perf.Event(env, "PET_BAR_UPDATE_COOLDOWN")
		end,
	},
	{
		name = "ActionBars pet appears and leaves in combat at Full, covered finials hide, re-place queued",
		budget = 750,
		calls = 50,
		setup = function()
			local env, K, ns = AB.New()
			AB.Enable(env, K)
			K.Options.Write("Widgets", "ornaments", "Full")
			env.RunTimers()
			local tray, shown = ns.bars.bar1.ornament, 0
			for i = 1, tray.used do
				if tray.textures[i]:IsShown() then shown = shown + 1 end
			end
			assert(shown == 3, "the tray fixture draws both finials and the keystone before the pet arrives, not " .. shown .. " pieces")
			local pet = Perf.Event(env, "UNIT_PET", "player")
			return env, function()
				env._game.petExists = not env._game.petExists
				pet()
			end
		end,
	},
	{
		name = "ActionBars key press flashes a slot",
		budget = 20,
		setup = function()
			local env, K, ns = AB.New()
			AB.Enable(env, K)
			AB.Slot(env, 1, { texture = 135001, type = "spell", id = 101 })
			local b = AB.Button(ns, "bar1", 1)
			local click = b:GetScript("OnClick")
			click(b, "LeftButton", true)
			assert(b.press:IsPlaying(), "the fixture's press plays the slot's flash")
			click(b, "LeftButton", false)
			return env, function()
				click(b, "LeftButton", true)
				click(b, "LeftButton", false)
			end
		end,
	},
	{
		name = "ActionBars SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and HIDE on a slot",
		budget = 400,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			AB.Slot(env, 1, { texture = 135001, type = "spell", id = 101 })
			local show = Perf.Event(env, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 101)
			local hide = Perf.Event(env, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 101)
			return env, function()
				show()
				hide()
			end
		end,
	},
}
