-- test-combattext-power.lua: power gains and the field's travel distance. Both keep v0.2.8's defaults; switched on, power gains show "+amount" from COMBAT_TEXT_UPDATE in their colour only while the game's combat text watches the player, never set the game's unit, combine only within one resource, refuse secret amounts, show only in your own place and stop when switched off; each HUD style's travel slider is the distance its field uses, capped by the field, in both directions and in the preview.
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

-- The game's combat text unit is the only proof a gain is yours: with none, a vehicle or a secret, nothing shows,
-- and the module never sets the unit, so switching off or disabling leaves the game's state as it was.
K.Options.Write("CombatText", "power", true)
assert(cfg.power and Gain("ENERGIZE", 25, "ENERGY") == nil, "a gain is refused while the game watches no unit")
K.Options.Write("CombatText", "power", false)
K.Modules.Disable("CombatText")
assert(#setActive == 0 and active == nil, "power gains never set the game's combat text unit: " .. tostring(active))
CT.Enable(env, K)
K.Options.Write("CombatText", "power", true)
active = "vehicle"
assert(Gain("ENERGIZE", 18, "ENERGY") == nil, "a vehicle's gain never shows as yours")
active = env.Secret("player")
assert(Gain("ENERGIZE", 18, "ENERGY") == nil, "a secret combat text unit is refused")
active = "player"

-- Watching you: gains show in their colour.
local number = Gain("ENERGIZE", 25, "ENERGY")
assert(number and CT.Text(env, number) == "+short(25)", "a gain reads +amount: " .. tostring(number and CT.Text(env, number)))
assert(number.emitter == ns.Module.fieldEmitter, "power gains show in your field")
local r, g, b = CT.LastCall(number.text, "SetTextColor")
local tr, tg, tb = K.Tokens.Color("rare")
assert(r == tr and g == tg and b == tb, "power gains take their default colour")
Clear()
K.Options.Write("CombatText", "powerColor", { r = 0.2, g = 0.4, b = 0.6 })
r, g, b = CT.LastCall(Gain("ENERGIZE", 5, "ENERGY").text, "SetTextColor")
assert(r == 0.2 and g == 0.4 and b == 0.6, "the power colour applies")
Clear()

-- Gains combine only within one resource; a secret resource never combines.
assert(CT.Text(env, Gain("PERIODIC_ENERGIZE", "30", "MANA")) == "+short(30)", "periodic gains and string amounts show")
assert(CT.Text(env, Gain("ENERGIZE", 12, "MANA")) == "+short(42)" and #CT.Shown(ns) == 1, "gains of one resource close together combine")
Clear()
Gain("ENERGIZE", 10, "MANA")
Gain("ENERGIZE", 1, "HOLY_POWER")
local shown = CT.Shown(ns)
assert(#shown == 2 and CT.Text(env, shown[1]) == "+short(10)" and CT.Text(env, shown[2]) == "+short(1)", "gains of different resources stay apart: " .. #shown)
Clear()
Gain("ENERGIZE", 5, env.Secret("MANA"))
Gain("ENERGIZE", 5, env.Secret("MANA"))
assert(#CT.Shown(ns) == 2, "gains of a secret resource stay apart")
Clear()

-- Nothing shows for no gain, no resource, other kinds, secret kinds or a failed read.
for _, case in ipairs({ { "ENERGIZE", 0 }, { "ENERGIZE", -4 }, { "ENERGIZE", nil }, { "DAMAGE", 40 }, { env.Secret("ENERGIZE"), 40 } }) do
	assert(Gain(case[1], case[2], "ENERGY") == nil, "no number for " .. tostring(case[1]) .. " " .. tostring(case[2]))
end
assert(Gain("ENERGIZE", 40, nil) == nil, "a gain with no resource is refused")
info.fail = true
assert(Gain("ENERGIZE", 10, "ENERGY") == nil, "a failed event read shows nothing")
info.fail = nil

-- A secret amount is refused: telling a gain from zero or a loss would mean comparing it.
for _, value in ipairs({ 12345, -4, 0 }) do
	assert(Gain("ENERGIZE", env.Secret(value), "MANA") == nil, "a secret gain of " .. value .. " is refused")
end
K.Options.Write("CombatText", "maxPerFrame", 1)
CT.Hit(env, "player", "WOUND", "", 120, 1)
local hit = CT.Shown(ns)[1]
Gain("ENERGIZE", env.Secret(0), "MANA")
assert(hit.live and not hit.retiring and CT.Shown(ns)[1] == hit, "a secret gain never displaces a real hit")
Clear()
K.Options.Write("CombatText", "maxPerFrame", 4)

-- Without the game's number formatters a gain keeps its plus sign.
local short, full = env.AbbreviateNumbers, env.BreakUpLargeNumbers
env.AbbreviateNumbers, env.BreakUpLargeNumbers = nil, nil
K.Options.Write("CombatText", "format", "full")
assert(CT.Text(env, Gain("ENERGIZE", 25, "MANA")) == "+25", "an unformatted gain reads +amount")
Clear()
env.AbbreviateNumbers, env.BreakUpLargeNumbers = short, full
K.Options.Write("CombatText", "format", "short")

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

-- Each HUD style keeps its own travel: the slider shown is the distance the field uses, so 48 can be chosen under Medallions.
local function Travel()
	for _, row in ipairs(ns.Settings.Schema()) do
		if row.label == K.L["Travel above you"] and (not row.showWhen or row.showWhen(ns.Settings.Values())) then
			return row.key
		end
	end
end
env.RunTimers()
local key = Travel()
assert(ns.Module.cfg.rise == 40 and K.Options.Read("CombatText", key) == 40, "Medallions keeps its 40-unit rise and its slider says so: " .. tostring(key))
K.Options.Write("CombatText", key, 48)
assert(ns.Module.cfg.rise == 48, "48 can be chosen under Medallions")
K.Options.Write("CombatText", key, 24)
assert(ns.Module.cfg.rise == 24, "a chosen travel distance stays under Medallions")
assert(ns.Settings.Snapshot({ [key] = env.Secret(80) }).rise == 40, "a secret saved distance falls back to Medallions' default")
env.RunTimers()
key = Travel()
assert(ns.Module.cfg.rise == 48 and K.Options.Read("CombatText", key) == 48, "Frames' slider is the distance its field uses")
assert(ns.Settings.Snapshot({ [key] = env.Secret(80) }).rise == 48, "a secret saved distance falls back to the default")

-- Power gains show only in your own place: never on a party button that shows you, with You on or off.
local buttons
K.Modules.Register(CT.CoreEnv.Module("GroupFrames", { onEnable = function()
	local _
	_, buttons = CT.UnitHolder(env, K, "groupframes.party", "GroupFrames", { "player", "party1" }, true)
end }))
K.Modules.Enable("GroupFrames")
env.RunTimers()
Gain("ENERGIZE", 7, "MANA")
assert(#CT.On(ns, buttons[1]) == 0 and #CT.On(ns, field) == 1, "a gain shows in your field, not on your party button")
Clear()
K.Options.Write("CombatText", "units.player", false)
Gain("ENERGIZE", 7, "MANA")
assert(#CT.Shown(ns) == 0, "power gains follow the You toggle")
K.Options.Write("CombatText", "units.player", true)
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

-- The preview shows power gains only while they and You are on, and travels the chosen distance.
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
	PK.Options.Write("CombatText", "units.player", false)
	preview:Refresh()
	assert(Power() == nil, "the preview shows no power gains while You is off")
	assert(#penv._errors == 0, tostring(penv._errors[1]))
end
print("ok - test-combattext-power")
