-- KstyleUI_ActionBars.lua: the action bars' combat paths, with their time budgets in microseconds per call, for test-perf.lua.
local Perf = ...
local AB = dofile("Tools/regression/actionbars_env.lua")
local FX = dofile("Tools/regression/effects_env.lua")

local SLOTS = 12

return {
	{
		name = "ActionBars paired SPELL_UPDATE_COOLDOWN and ACTIONBAR_UPDATE_COOLDOWN, 48 buttons",
		budget = 600,
		setup = function()
			local env, K, ns = AB.New()
			AB.Enable(env, K)
			for n = 1, SLOTS do
				AB.Slot(env, n, { texture = 135000 + n, type = "spell", id = 100 + n, cooldown = { name = "cd" .. n } })
			end
			AB.Slot(env, 2, {
				texture = 135002, type = "spell", id = 102, cooldown = { name = "cd2" },
				charges = { maxCharges = 2, currentCharges = 1, isActive = true }, chargeDuration = { name = "charge2" },
			})
			assert(#ns.actionButtons == 48, "the fixture walks 48 action buttons")
			local info = { isOnGCD = true }
			env.C_ActionBar.GetActionCooldown = function() return info end
			local spell = Perf.Event(env, "SPELL_UPDATE_COOLDOWN")
			local action = Perf.Event(env, "ACTIONBAR_UPDATE_COOLDOWN")
			return env, function()
				env._now = env._now + 1 / 60
				spell()
				action()
			end
		end,
	},
	{
		name = "ActionBars ACTIONBAR_UPDATE_COOLDOWN",
		budget = 125,
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
		name = "ActionBars PET_BAR_UPDATE_COOLDOWN with a pet",
		budget = 215,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			env._game.petExists = true
			env._game.pet[1] = { name = "Bite", texture = 132278, spellID = 17253 }
			env.FireEvent("UNIT_PET", "player")
			env.SetCombat(true)
			env.RunTimers()
			return env, Perf.Event(env, "PET_BAR_UPDATE_COOLDOWN")
		end,
	},
	{
		name = "ActionBars pet appears and leaves in combat",
		budget = 750,
		calls = 50,
		setup = function()
			local env, K = AB.New()
			AB.Enable(env, K)
			env.RunTimers()
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
			assert(b.medPushed:IsShown(), "the fixture's press shows the slot's Medallions pushed frame")
			click(b, "LeftButton", false)
			return env, function()
				click(b, "LeftButton", true)
				click(b, "LeftButton", false)
			end
		end,
	},
	{
		name = "ActionBars SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and HIDE on a slot",
		budget = 445,
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
	{
		name = "ActionBars Medallions ready flash on a slot",
		budget = 120,
		setup = function()
			local env, K, ns = AB.New()
			AB.Enable(env, K)
			env.RunTimers()
			AB.Slot(env, 1, { texture = 135001, type = "spell", id = 101 })
			local b = AB.Button(ns, "bar1", 1)
			b.realCooldown = true
			b:FlashReady()
			assert(b.medReady and b.medReady.anim:IsPlaying(), "the fixture plays the Medallions flash")
			return env, function()
				b:FlashReady()
			end
		end,
	},
	{
		name = "ActionBars Medallions hub ring UNIT_POWER_UPDATE",
		budget = 20,
		setup = function()
			local env, K = AB.New({ setup = FX.Install })
			AB.Enable(env, K)
			env.RunTimers()
			return env, Perf.Event(env, "UNIT_POWER_UPDATE", "player", "RAGE")
		end,
	},
}
