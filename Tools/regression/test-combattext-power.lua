-- test-combattext-power.lua: power gains and the field's travel distance. Both keep v0.2.8's defaults; switched on, power gains show "+amount" from COMBAT_TEXT_UPDATE in their colour, combine like other public amounts, never compare a secret gain, refuse without the string helpers, and stop when switched off; the travel distance moves your numbers further, capped by the field, in both directions and in the preview.
local CT = dofile("Tools/regression/combattext_env.lua")
local W = CT.W

local info, active, setActive = { n = 0 }, nil, {}
local function Game(e)
	e.C_CombatText = {
		GetCurrentEventInfo = function()
			if info.fail then error("no event info") end
			return info[1], info[2]
		end,
		GetActiveUnit = function() return active end,
		SetActiveUnit = function(unit) setActive[#setActive + 1] = unit; active = unit end,
	}
	e.C_StringUtil = {
		TruncateWhenZero = function(n)
			local v = e.Reveal(n)
			return e.Secret(v == 0 and "" or tostring(math.floor(v)))
		end,
		WrapString = function(infix, prefix, suffix)
			local v = e.Reveal(infix)
			return e.Secret(v == "" and "" or (prefix or "") .. v .. (suffix or ""))
		end,
	}
end

local env, K, ns = CT.New({ setup = Game })
CT.Enable(env, K)
local cfg = ns.Module.cfg
local stats = ns.Module.stats

local function Gain(kind, amount, token)
	info[1], info[2] = amount, token
	env.FireEvent("COMBAT_TEXT_UPDATE", kind)
	return CT.Shown(ns)[1]
end

local function Clear()
	for _, number in ipairs(CT.Shown(ns)) do CT.Finish(number) end
	assert(#CT.Shown(ns) == 0, "the numbers finish")
end

-- Defaults are v0.2.8's: no power gains, no COMBAT_TEXT_UPDATE work, and a 48-unit rise in Frames.
assert(cfg.power == false and cfg.rise == 48, "power gains start off and the field keeps its 48-unit rise")
assert(Gain("ENERGIZE", 25, "ENERGY") == nil and stats.combatText == 0, "power gains off registers no COMBAT_TEXT_UPDATE")
assert(#setActive == 0, "power gains off never sets the combat text unit")

-- Switched on: the event registers, the unit is set only while the game has none, and gains show in their colour.
K.Options.Write("CombatText", "power", true)
assert(cfg.power and #setActive == 1 and setActive[1] == "player", "power gains on set the player as the combat text unit")
local number = Gain("ENERGIZE", 25, "ENERGY")
assert(number and CT.Text(env, number) == "+short(25)", "a gain reads +amount: " .. tostring(number and CT.Text(env, number)))
assert(number.emitter == ns.Module.fieldEmitter, "power gains show in your field")
local r, g, b = CT.LastCall(number.text, "SetTextColor")
local tr, tg, tb = K.Tokens.Color("rare")
assert(r == tr and g == tg and b == tb, "power gains take their default colour")
Clear()
assert(CT.Text(env, Gain("PERIODIC_ENERGIZE", "30", "MANA")) == "+short(30)", "periodic gains and string amounts show")
assert(CT.Text(env, Gain("ENERGIZE", 12, "RAGE")) == "+short(42)" and #CT.Shown(ns) == 1, "gains close together combine")
Clear()
K.Options.Write("CombatText", "powerColor", { r = 0.2, g = 0.4, b = 0.6 })
r, g, b = CT.LastCall(Gain("ENERGIZE", 5, "ENERGY").text, "SetTextColor")
assert(r == 0.2 and g == 0.4 and b == 0.6, "the power colour applies")
Clear()

-- Nothing shows for no gain, other kinds, secret kinds or a failed read.
for _, case in ipairs({ { "ENERGIZE", 0 }, { "ENERGIZE", -4 }, { "ENERGIZE", nil }, { "DAMAGE", 40 }, { env.Secret("ENERGIZE"), 40 } }) do
	assert(Gain(case[1], case[2], "ENERGY") == nil, "no number for " .. tostring(case[1]) .. " " .. tostring(case[2]))
end
info.fail = true
assert(Gain("ENERGIZE", 10, "ENERGY") == nil, "a failed event read shows nothing")
info.fail = nil

-- Secret gains are formatted by the game, and zero comes back empty.
assert(CT.Text(env, Gain("ENERGIZE", env.Secret(40), "ENERGY")) == "secret:+40", "a secret gain shows through the string helpers")
Clear()
assert(CT.Text(env, Gain("ENERGIZE", env.Secret(0), "ENERGY")) == "secret:", "a secret zero gain shows no text")
Clear()
local util = env.C_StringUtil
env.C_StringUtil = nil
assert(Gain("ENERGIZE", env.Secret(40), "ENERGY") == nil, "without the string helpers a secret gain is refused")
env.C_StringUtil = util

-- Power gains follow your place: none while You is off.
K.Options.Write("CombatText", "units.player", false)
assert(Gain("ENERGIZE", 25, "ENERGY") == nil, "power gains follow the You toggle")
K.Options.Write("CombatText", "units.player", true)

-- A unit the game already set is left alone.
setActive = {}
active = "vehicle"
K.Options.Write("CombatText", "power", false)
K.Options.Write("CombatText", "power", true)
assert(#setActive == 0, "an active combat text unit is never overwritten")

-- Switched off: no more event work, and damage keeps working.
K.Options.Write("CombatText", "power", false)
local seen = stats.combatText
assert(Gain("ENERGIZE", 25, "ENERGY") == nil and stats.combatText == seen, "power gains off unregisters COMBAT_TEXT_UPDATE")
CT.Hit(env, "player", "WOUND", "", 120, 1)
assert(CT.Text(env, CT.Shown(ns)[1]) == "short(120)", "damage still shows")
Clear()

-- Disable and enable keep the saved choice.
K.Options.Write("CombatText", "power", true)
K.Modules.Disable("CombatText")
assert(Gain("ENERGIZE", 25, "ENERGY") == nil, "a disabled module shows no power gains")
CT.Enable(env, K)
assert(Gain("ENERGIZE", 25, "ENERGY"), "re-enabling restores power gains")
Clear()

-- The field's travel distance: further when raised, capped by the field, and downward too.
local field = ns.Module.field
local room = field:GetHeight() - cfg.size * 1.8
local function Rise()
	CT.Hit(env, "player", "WOUND", "", 100, 1)
	local move = CT.Anim(CT.Shown(ns)[1], "move")
	Clear()
	return move.offsetY
end
assert(math.abs(Rise() - math.min(48, room)) < 1e-6, "the default rise is unchanged")
K.Options.Write("CombatText", "fieldDistance", 80)
assert(math.abs(Rise() - math.min(80, room)) < 1e-6 and math.min(80, room) > 48, "a longer travel distance moves numbers further")
K.Options.Write("CombatText", "fieldDistance", 120)
assert(math.abs(Rise() - room) < 1e-6, "the field's height caps the travel distance")
K.Options.Write("CombatText", "fieldDistance", 16)
assert(math.abs(Rise() - 16) < 1e-6, "a shorter travel distance applies")
K.Options.Write("CombatText", "direction", "down")
assert(math.abs(Rise() + 16) < 1e-6, "the travel distance applies downward")
K.Options.Write("CombatText", "direction", "up")
K.Options.Write("CombatText", "fieldDistance", 48)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(ns.Module.cfg.rise == 40, "Medallions keeps its 40-unit rise")
K.Options.Write("CombatText", "fieldDistance", 24)
assert(ns.Module.cfg.rise == 24, "a chosen travel distance stays under Medallions")
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
assert(ns.Settings.Snapshot({ fieldDistance = env.Secret(80) }).rise == 48, "a secret saved distance falls back to the default")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

-- The preview shows power gains only while they are on, and travels the chosen distance.
do
	local penv, PK = CT.New({ setup = Game })
	local holder = penv.CreateFrame("Frame", nil, PK.Scale.Root())
	local preview = PK.Options.Preview("CombatText")(holder)
	local function Power()
		local found
		for _ = 1, 80 do
			W.Tick(penv, 0.05)
			for _, n in ipairs(preview.pool.active) do
				if n.kind == "power" then found = CT.Text(penv, n) end
			end
		end
		return found
	end
	assert(Power() == nil, "the preview shows no power gains while they are off")
	PK.Options.Write("CombatText", "power", true)
	PK.Options.Write("CombatText", "fieldDistance", 24)
	preview:Refresh()
	assert(Power() == "+short(25)", "the preview shows a power gain while they are on")
	assert(preview.cfg.rise == 24, "the preview travels the chosen distance")
	assert(#penv._errors == 0, tostring(penv._errors[1]))
end
print("ok - test-combattext-power")
