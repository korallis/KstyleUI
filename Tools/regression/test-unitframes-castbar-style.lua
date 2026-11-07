-- test-unitframes-castbar-style.lua: cast bars pick a fill direction and a class, reaction or custom colour, and a cast start restyles nothing and makes no new colour objects.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local CastBars = ns.CastBars

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function sameColor(call, r, g, b)
	return call ~= nil and near(call[1], r) and near(call[2], g) and near(call[3], b)
end

local player = CastBars.Get("player")[1]
local bar = player.bar

-- Fill direction: left to right by default; each of the four directions sets the engine's orientation
-- and fill, and the spark rides the fill's leading edge.
assert(W.LastCall(bar, "SetOrientation")[1] == "HORIZONTAL" and W.LastCall(bar, "SetReverseFill")[1] == false, "cast bars fill left to right by default")
local DIRECTIONS = {
	LEFT = { "HORIZONTAL", true, "LEFT" },
	UP = { "VERTICAL", false, "TOP" },
	DOWN = { "VERTICAL", true, "BOTTOM" },
	RIGHT = { "HORIZONTAL", false, "RIGHT" },
}
for _, direction in ipairs({ "LEFT", "UP", "DOWN", "RIGHT" }) do
	local want = DIRECTIONS[direction]
	K.Options.Write("UnitFrames", "player.castbarOrientation", direction)
	assert(W.LastCall(bar, "SetOrientation")[1] == want[1], direction .. ": orientation " .. want[1])
	assert(W.LastCall(bar, "SetReverseFill")[1] == want[2], direction .. ": reverse fill " .. tostring(want[2]))
	local _, rel, relPoint = bar.spark:GetPoint(1)
	assert(rel == bar:GetStatusBarTexture() and relPoint == want[3], direction .. ": the spark sits on the fill's " .. want[3] .. " edge, got " .. tostring(relPoint))
end
local focusBar = CastBars.Get("focus")[1]
K.Options.Write("UnitFrames", "focus.castbarOrientation", "UP")
assert(W.LastCall(focusBar.bar, "SetOrientation")[1] == "VERTICAL", "a cast bar inside its frame takes the fill direction too")
K.Options.Write("UnitFrames", "focus.castbarOrientation", "RIGHT")
noErrors("orientation")

-- A tall cast bar stacks its icon above the bar, so a vertical bar can stand on its own.
assert(K.Layout.Set("unitframes.castbar.player", "width", 20), "the player cast bar can be 20 units wide")
assert(K.Layout.Set("unitframes.castbar.player", "height", 200), "and 200 units tall")
local iw, ih = player.iconFrame:GetSize()
assert(near(iw, 20) and near(ih, 20), "the icon is as wide as the bar: " .. tostring(iw) .. "x" .. tostring(ih))
local _, _, _, px, py = player.panel:GetPoint(1)
local pw, ph = player.panel:GetSize()
assert(near(px, 0) and py <= -20, "the glass starts under the icon")
assert(near(pw, 20) and ph > 150 and -py + ph <= 200 + 1e-6, "the glass fills the rest of the height: " .. tostring(pw) .. "x" .. tostring(ph))
local _, _, _, bx, by = bar:GetPoint(1)
local bw, bh = bar:GetSize()
assert(bx >= px and bx + bw <= px + pw + 1e-6 and by <= py and -by + bh <= -py + ph + 1e-6, "the bar sits inside the glass's lines")
assert(bh > 150, "and fills its height: " .. tostring(bw) .. "x" .. tostring(bh))
K.Layout.Reset("unitframes.castbar.player")
local _, _, _, wx = bar:GetPoint(1)
assert(wx > 0, "a wide cast bar puts the icon back on the left")
noErrors("tall layout")

-- Colour source: reaction colours the bar by the caster's reaction to you.
K.Options.Write("UnitFrames", "target.castbarColor", "reaction")
local target = CastBars.Get("target")[1]
local function targetCasting(reaction, extra)
	local unit = { name = "Wolf", level = 10, health = 1, healthMax = 2, reaction = reaction,
		cast = { name = "Howl", texture = 135808, start = 1000, finish = 3800, spellID = 999 } }
	for k, v in pairs(extra or {}) do
		unit[k] = v
	end
	U.SetUnit(env, "target", unit)
	env.SetTarget(true)
	assert(target.frame:IsShown(), "the target's cast shows")
end
targetCasting(2)
assert(sameColor(W.LastCall(target.bar, "SetStatusBarColor"), K.Theme.ReactionColor(2)), "a hostile caster's bar takes the hostile colour")
targetCasting(5)
assert(sameColor(W.LastCall(target.bar, "SetStatusBarColor"), K.Theme.ReactionColor(5)), "a friendly caster's bar takes the friendly colour")
targetCasting(2, { secretReaction = true })
assert(sameColor(W.LastCall(target.bar, "SetStatusBarColor"), K.Theme.Accent()), "a secret reaction falls back to the class accent")
K.Options.Write("UnitFrames", "target.castbarColor", "class")
targetCasting(2)
assert(sameColor(W.LastCall(target.bar, "SetStatusBarColor"), K.Theme.Accent()), "class follows the class accent")
U.SetUnit(env, "target", nil)
env.SetTarget(false)
settle()
noErrors("reaction")

-- A cast start restyles nothing: fonts, the bar texture and an unchanged colour stay as the settings left them.
local function count(object, method)
	return #W.Calls(object, method)
end
local fonts = count(player.text, "SetFont") + count(player.timer, "SetFont")
local textures = count(bar, "SetStatusBarTexture")
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(player.frame:IsShown(), "the cast shows")
assert(count(player.text, "SetFont") + count(player.timer, "SetFont") == fonts, "a cast start sets no font")
assert(count(bar, "SetStatusBarTexture") == textures, "a cast start sets no bar texture")
local colours = count(bar, "SetStatusBarColor")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116)
settle()
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 4000, finish = 6500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
assert(count(bar, "SetStatusBarColor") == colours, "a second cast in the same colour paints nothing")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", 116)
settle()
noErrors("no restyle")

-- A cast after an interrupt takes its normal colour back.
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 7000, finish = 9500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", 116)
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-3", 116)
assert(sameColor(W.LastCall(bar, "SetStatusBarColor"), K.Tokens.Color("hostile")), "the interrupt paints the hostile colour")
settle()
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 10000, finish = 12500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", 116)
assert(sameColor(W.LastCall(bar, "SetStatusBarColor"), K.Theme.Accent()), "the next cast is back in the class accent")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-4", 116)
settle()

-- A secret interruptible flag colours from two colour objects made once, not on every cast.
local made = 0
local createColor = env.CreateColor
env.CreateColor = function(...)
	made = made + 1
	return createColor(...)
end
local function secretCast(id)
	U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, secretCast = true,
		cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999, barID = id } })
	env.SetTarget(true)
	local call = W.LastCall(target.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
	assert(call and env.issecretvalue(call[1]), "a secret flag colours the bar from a boolean")
end
secretCast(1)
local first = made
assert(first <= 2, "at most two colour objects for the first secret cast: " .. first)
secretCast(2)
secretCast(3)
assert(made == first, "later casts in the same colours make no colour objects: " .. made)
K.Options.Write("UnitFrames", "target.castbarColor", "custom")
K.Options.Write("UnitFrames", "target.castbarCustom", { r = 0.5, g = 0.25, b = 1 })
secretCast(4)
assert(made > first, "a new colour makes new colour objects")
local call = W.LastCall(target.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(near(call[3].r, 0.5) and near(call[3].g, 0.25) and near(call[3].b, 1), "in the new colour")
env.CreateColor = createColor
K.Options.Write("UnitFrames", "target.castbarColor", "class")
U.SetUnit(env, "target", nil)
env.SetTarget(false)
settle()
noErrors("colour objects")

-- Failed and interrupted casts hold with one shared release, and a new cast during the hold keeps its bar.
local held = {}
local after = env.C_Timer.After
env.C_Timer.After = function(seconds, fn)
	held[#held + 1] = fn
	return after(seconds, fn)
end
local function interrupt(start)
	env._units.player.cast = { name = "Frostbolt", texture = 135846, start = start, finish = start + 2500, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-5", 116)
	env._units.player.cast = nil
	local before = #held
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-5", 116)
	assert(#held == before + 1, "the interrupt holds the bar for a moment")
	return held[#held]
end
local release1 = interrupt(13000)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 14000, finish = 16500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-6", 116)
env.RunTimers()
assert(player.frame:IsShown() and U.Shown(env, player.text) == "FROSTBOLT", "a new cast during the hold keeps its bar")
assert(player.frame:GetScript("OnUpdate") ~= nil, "and its countdown keeps running after the old hold ends")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-6", 116)
settle()
local release2 = interrupt(17000)
assert(release1 == release2, "every hold uses the bar's one release function")
settle()
assert(not player.frame:IsShown(), "the hold still ends in a fade")
-- Two failures inside one hold: the first failure's timer does not cut the second message short.
local queued = {}
env.C_Timer.After = function(_, fn)
	held[#held + 1] = fn
	queued[#queued + 1] = fn
end
interrupt(18000)
interrupt(19000)
assert(#queued == 2, "each interrupt holds the bar")
queued[1]()
settle()
assert(player.frame:IsShown() and U.Shown(env, player.text) == K.L["Interrupted"]:upper(), "the first hold ending keeps the second interrupt's message")
queued[2]()
settle()
assert(not player.frame:IsShown(), "the second hold ending fades the bar")
env.C_Timer.After = after
noErrors("hold")

print("unitframes castbar style ok")
