-- test-actionbars-crest-heat.lua: Rising heat (SlabHeat.lua): each combo point or stack warms the crest a step, a halo above the hub and a faint corona under it, each step a one-point bar at its share of the full alpha: a rogue's combo points feed crest-owned bars (easing in when motion allows, Immediate at Off), a warrior's Sunder Armor and a shaman's Lightning Shield charges feed application bars on their own aura containers (the shield's falling as charges are spent), a lost aura clears them, and the switch hides every step, waiting while auras are secret for the ones under an aura button.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local Last = AB.W.LastCall

local function New(class, known, setup)
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			Slots.Install(e)
			e._points, e._powerType = 0, class == "ROGUE" and 3 or 1
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.GetComboPoints = function() return e._points end
			e.UnitPowerType = function() return e._powerType end
			e.UnitPower = function(_, kind) return kind == 0 and 1500 or e._points end
			e.UnitPowerMax = function(_, kind) return kind == 0 and 3000 or 5 end
			e.GetTotemInfo = function() return false, "", 0, 0, 0, 1, 0 end
			e.GetTotemDuration = function() return { start = 0, finish = 0 } end
			if setup then setup(e) end
		end,
	})
	env.C_SpellBook.IsSpellKnown = function(id) return known[id] == true end
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

local function Reveal(env, value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

local function Fill(env, bar)
	return Slots.Engine(env, function()
		local low, high = bar:GetMinMaxValues()
		local value = Reveal(env, Last(bar, "SetValue")[1])
		return bar:IsShown() and math.max(0, math.min(1, (value - low) / (high - low))) or 0
	end)
end

local function Steps(env, bars, n, what)
	for k, bar in ipairs(bars) do
		local lit = math.ceil(k / 2) <= n
		assert(Fill(env, bar) == (lit and 1 or 0), what .. ": step " .. math.ceil(k / 2) .. (lit and " lit" or " dark"))
	end
end

local function Fed(ns)
	local list = {}
	for _, bar in ipairs(ns.SlabHeat.bars) do
		if bar.fed then list[#list + 1] = bar end
	end
	return list
end

local function Alpha(env, bars)
	return Slots.Engine(env, function()
		local sum = 0
		for _, bar in ipairs(bars) do sum = sum + bar:GetAlpha() end
		return sum
	end)
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

-- A rogue's combo points.
do
	local env, K, ns = New("ROGUE", {})
	local heat, hub = ns.SlabCrown.state.pips.heat, ns.Slab.hub
	assert(heat and #heat == 10, "five steps of halo and corona")
	assert(heat[1]:GetFrameLevel() > hub:GetFrameLevel() and heat[2]:GetFrameLevel() < hub:GetFrameLevel(), "the halo draws over the band, the corona under the ring")
	assert(math.abs(heat[1]:GetAlpha() - 0.2) < 1e-6 and math.abs(heat[2]:GetAlpha() - 0.16) < 1e-6, "each step draws a fifth of the halo and of a corona worth 0.8 at the maximum")
	assert(Last(heat[1], "SetStatusBarColor") and not Last(heat[2], "SetStatusBarColor"), "the halo takes the class colour; the corona keeps the burst's own colours")
	assert(Last(heat[2]:GetStatusBarTexture(), "AddMaskTexture") and not Last(heat[1]:GetStatusBarTexture(), "AddMaskTexture"), "the corona is masked inside the crest's footprint")
	assert(not heat.holder:IsShown(), "no combo points: the steps draw nothing and stay hidden")
	env._points = 3
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	Steps(env, heat, 3, "three points")
	assert(heat.holder:IsShown(), "points show the steps")
	assert(Last(heat[5], "SetValue")[2] == 1, "a gain eases in")
	K.Options.Write("Medallions", "motion", "off")
	env._points = 5
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	Steps(env, heat, 5, "five points")
	assert(Last(heat[9], "SetValue")[2] == 0, "Off shows the end state at once")
	K.Options.Write("ActionBars", "crestHeat", false)
	assert(Alpha(env, heat) == 0, "the switch off hides every step")
	local writes = 0
	for _, bar in ipairs(heat) do writes = writes - #AB.W.Calls(bar, "SetValue") end
	env._points = 2
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	for _, bar in ipairs(heat) do writes = writes + #AB.W.Calls(bar, "SetValue") end
	assert(writes == 0, "switched off, a combo point change writes no step")
	K.Options.Write("ActionBars", "crestHeat", true)
	assert(math.abs(Alpha(env, heat) - 1.8) < 1e-6, "and on brings them back")
	Steps(env, heat, 2, "back on, the steps show the count reached while off")
	K.Store.Module("ActionBars").crestHeat = false
	K.Callbacks.Fire("ProfileChanged")
	assert(Alpha(env, heat) == 0, "a profile with the switch off hides the steps")
	K.Store.Module("ActionBars").crestHeat = true
	K.Callbacks.Fire("ProfileChanged")
	K.Theme.SetPalette({ ROGUE = { r = 0.1, g = 0.3, b = 0.8 } }, 0)
	local r, g, b = heat[1]:GetStatusBarColor()
	assert(math.abs(r - 0.1) < 1e-6 and math.abs(g - 0.3) < 1e-6 and math.abs(b - 0.8) < 1e-6, "a palette change retints the halo")
	Clean(env, K, "rogue")
end

-- A warrior's Sunder Armor on the target, and the switch while auras are secret.
do
	local env, K, ns = New("WARRIOR", { [7386] = true })
	local bars = Fed(ns)
	assert(#bars == 10, "five steps on the crown's aura container")
	for k, bar in ipairs(bars) do
		local o = bar:GetParent()._applicationBar[2]
		local step = math.ceil(k / 2)
		assert(o.minApplications == step - 1 and o.maxApplications == step and o.interpolation == 1, "step " .. step .. " is an eased application bar")
	end
	Slots.Set(env, "target", { { id = 7386, count = 2, harmful = true } })
	Steps(env, bars, 2, "two Sunders")
	env._slotAuras.target[1].count = 4
	Slots.Set(env, "target", env._slotAuras.target)
	Steps(env, bars, 4, "four Sunders")
	Slots.Set(env, "target", nil)
	Steps(env, bars, 0, "the aura going")
	env._aurasSecret = true
	env.SetCombat(true)
	Slots.Set(env, "target", { { id = 7386, count = 5, harmful = true } })
	Steps(env, bars, 5, "five Sunders in combat")
	K.Options.Write("ActionBars", "crestHeat", false)
	assert(math.abs(Alpha(env, bars) - 1.8) < 1e-6, "while auras are secret the switch waits")
	env._aurasSecret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	assert(math.abs(Alpha(env, bars) - 1.8) < 1e-6, "readable auras in combat still write nothing under an aura button")
	env.SetCombat(false)
	assert(Alpha(env, bars) == 0, "and the steps hide once combat ends")
	Clean(env, K, "warrior")
end

-- A shaman's Lightning Shield charges fall.
do
	local env, K, ns = New("SHAMAN", { [10432] = true })
	local bars = Fed(ns)
	assert(#bars == 6, "three steps on the storm's own container")
	Slots.Set(env, "player", { { id = 10432, count = 3 } })
	Steps(env, bars, 3, "a full shield")
	env._slotAuras.player[1].count = 1
	Slots.Set(env, "player", env._slotAuras.player)
	Steps(env, bars, 1, "spent charges")
	Clean(env, K, "shaman")
end

print("actionbars crest heat ok")
