-- test-unitframes-column-cast.lua: the picture's cast bars: the player's own bar above the cooldown row (caps spell over a 9-unit tan bar, elapsed over total), the target's under its power bar (caps spell under a 7-unit bar, the time left with no unit).
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local CastBars = ns.CastBars
local Tokens, Layouts = K.Tokens, K.Setup.Layouts

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local PLAYER_CAST = Layouts.Element("unitframes.castbar.player")
assert(PLAYER_CAST.width == 347 and PLAYER_CAST.height == 30, "the player's cast element is the picture's 347 by 30")

assert(CastBars.ElementLive("player") == true, "the player's own cast bar is live beside its column frame")
assert(CastBars.ElementLive("target") == false, "the target's cast bar is inside its column, not a second element")

local element = CastBars.Get("player")[1]
local inline = CastBars.Inline("player")[1]
env._time = 2.2
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
assert(element.frame:IsShown() and not inline.frame:IsShown(), "the cast shows in the element, not inside the frame")
assert(element.mode == "above" and element.geometry.caption == "above", "the label stands above the bar")
assert(U.Shown(env, element.text) == "LIGHTNING BOLT", "the spell is in capitals: " .. U.Shown(env, element.text))
assert(not tostring(W.LastCall(element.text, "SetText")[1]):find("\226\128\137"), "with no thin space, Cinzel has none")
assert(element.text:GetFont() == Tokens.Font("names"), "the cast uses the tighter world-space names face")
local shadowX, shadowY = element.text:GetShadowOffset()
assert(shadowX > 0 and shadowY == -shadowX, "world-space cast labels retain the kit's soft shadow")
local _, castSize, castFlags = ns.Settings.Font("player", "cast")
local ref = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
K.Widgets.ApplyFont(ref, Tokens.Font("names"), castSize, castFlags)
assert(W.LastCall(element.text, "SetFont")[2] == W.LastCall(ref, "SetFont")[2], "the caption's size goes through Widgets.ApplyFont, so it snaps to whole pixels like every other text")
W.Tick(env, 0.1)
assert(U.Shown(env, element.timer) == "1.2 / 2.5", "elapsed over total, no unit: " .. U.Shown(env, element.timer))
local timer = W.LastCall(element.timer, "SetFormattedText")
assert(timer and timer[1] == "%.1f / %.1f", "the times reach the font string through SetFormattedText")
assert(near(select(2, element.bar:GetSize()), 9, 0.6), "the bar is 9 units tall")
assert(element.bar.spark:IsShown(), "with a spark at the head")
assert(element.bar.lit:IsShown() == false and element.bar.shade:IsShown() == false, "and flat")
local gr, gg, gb = Tokens.Color("gilt")
local fill = W.LastCall(element.bar, "SetStatusBarColor")
assert(fill and near(fill[1], gr) and near(fill[2], gg) and near(fill[3], gb), "the fill is the gilt token's tan")
assert(not element.label:IsShown() and not element.lock:IsShown() and not element.iconFrame:IsShown(), "no Casting word, no icon")
local tp, _, _, _, ty = element.text:GetPoint(1)
assert(tp == "BOTTOMLEFT" and ty > 9, "the label sits above the bar's top")
local bp = element.bar:GetPoint(1)
assert(bp == "BOTTOMLEFT", "the bar is at the element's foot")
local tp2 = element.timer:GetPoint(1)
assert(tp2 == "BOTTOMRIGHT", "the time is at the right of the label's row")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 188196)
settle()
assert(not element.frame:IsShown(), "the bar fades when the cast ends")
noErrors("player cast")

local target = CastBars.Inline("target")[1]
local tframe = ns.Frames.Get("target").views[1]
U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true,
	cast = { name = "Shadow Bolt", texture = 136197, start = 1000, finish = 3800, spellID = 686 } })
env._time = 3
env.SetTarget(true)
assert(target.frame:IsShown() and target.mode == "below", "the target's cast is inside its column, its label under the bar")
assert(U.Shown(env, target.text) == "SHADOW BOLT", "in capitals: " .. U.Shown(env, target.text))
W.Tick(env, 0.1)
assert(U.Shown(env, target.timer) == "0.8", "the time left with no unit: " .. U.Shown(env, target.timer))
local left = W.LastCall(target.timer, "SetFormattedText")
assert(left and left[1] == "%.1f", "through SetFormattedText")
assert(near(select(2, target.bar:GetSize()), 7, 0.6), "the bar is 7 units tall")
local g = tframe.geometry.cast
local cw, ch = target.frame:GetSize()
assert(near(cw, 491) and near(ch, g.h, 0.6), "the cast frame is the full 491, as tall as the bar and its label")
local lp, _, _, _, ly = target.text:GetPoint(1)
assert(lp == "TOPLEFT" and ly < -7, "the label sits under the bar")
assert(target.bar:GetPoint(1) == "TOPLEFT", "the bar is at the cast frame's top")
assert(not target.iconFrame:IsShown(), "no icon")
assert(CastBars.Get("target")[1].frame:IsShown() == false, "the separate target element stays hidden")
noErrors("target cast")

U.SetUnit(env, "target", { name = "Summoner", level = 51, health = 50, healthMax = 100, reaction = 2, canAttack = true, secretCast = true,
	cast = { name = "Molten Pulse", texture = 135808, start = 1000, finish = 3800, notInterruptible = true, spellID = 999 } })
env.SetTarget(true)
assert(env.issecretvalue(W.LastCall(target.text, "SetText")[1]), "a secret spell name reaches SetText untouched")
W.Tick(env, 0.1)
local secret = W.LastCall(target.timer, "SetFormattedText")
assert(secret and env.issecretvalue(secret[2]), "a secret time reaches SetFormattedText untouched")
noErrors("secret cast")
U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 1, healthMax = 2, reaction = 2 })
env.SetTarget(true)
settle()

K.Options.Write("UnitFrames", "player.castbarCaps", false)
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 188196)
assert(U.Shown(env, element.text) == "Lightning Bolt", "with capitals off the spell reads as the game writes it")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", 188196)
settle()

K.Options.Write("UnitFrames", "player.style", "plate")
assert(CastBars.ElementLive("player") == true and element.mode == nil, "a plate player draws the classic bar in the element")
K.Options.Write("UnitFrames", "player.style", "lumen")
assert(CastBars.ElementLive("player") == false and CastBars.Inline("player")[1].mode == nil, "the older Lumen style keeps its cast line inside the frame")
noErrors("styles")

-- A column target keeps its inline cast whichever side its portrait is on; the separate element stays off.
K.Options.Write("UnitFrames", "player.style", "column")
settle()
do
	K.Options.Write("UnitFrames", "target.portraitSide", "LEFT")
	settle()
	local snapshot = ns.Settings.Snapshot("target")
	assert(snapshot.inlineCast == true and snapshot.form == "column", "the column target's snapshot carries the inline cast contract")
	assert(ns.Settings.Snapshot("player").inlineCast == false, "the player's cast bar is its own element")
	local size = Layouts.Element("unitframes.target")
	local frame = ns.Geometry.Frame(snapshot, size.width, size.height, 1)
	assert(not frame.mirror and frame.cast, "a target with its portrait on the left still has its inline cast")
	assert(CastBars.ElementLive("target") == false, "and no second element")
	U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true,
		cast = { name = "Shadow Bolt", texture = 136197, start = 1000, finish = 3800, spellID = 686 } })
	env._time = 3
	env.SetTarget(true)
	assert(target.frame:IsShown() and target.mode == "below", "the inline cast shows with the portrait on the left")
	U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 1, healthMax = 2, reaction = 2 })
	env.SetTarget(true)
	K.Options.Write("UnitFrames", "target.portraitSide", "RIGHT")
	settle()
	noErrors("left portrait")
end

-- The target's cast room follows its cast font; a cast line given less height than it needs drops its label before it overflows.
do
	local size = Layouts.Element("unitframes.target")
	local function room()
		return ns.Geometry.Frame(ns.Settings.Snapshot("target"), size.width, size.height, 1).cast.h
	end
	assert(near(room(), 7 + 4.5 + 12 + 3, 0.01), "the 12-unit cast font takes the picture's 26.5: " .. room())
	K.Options.Write("UnitFrames", "target.fonts.cast.size", 16)
	assert(near(room(), 7 + 4.5 + 16 + 3, 0.01), "a 16-unit cast font takes 30.5: " .. room())
	K.Options.Write("UnitFrames", "target.fonts.cast.size", 12)

	for _, fontSize in ipairs({ 10, 12, 20 }) do
		K.Options.Write("UnitFrames", "player.fonts.cast.size", fontSize)
		for _, height in ipairs({ 6, 9, 12, 18, 26.5, 30, 40 }) do
			for _, mode in ipairs({ "above", "below" }) do
				local cb = mode == "above" and element or target
				CastBars.Layout(cb, 347, height)
				local where = mode .. " font " .. fontSize .. " height " .. height
				local _, barH = cb.bar:GetSize()
				local extent = barH
				if cb.text:IsShown() then
					local _, _, _, _, offset = cb.text:GetPoint(1)
					local _, rowH = cb.text:GetSize()
					extent = math.abs(offset) + rowH
				end
				assert(extent <= height + 0.6, where .. ": the bar and its label stand inside the frame, reaching " .. extent)
				assert(barH >= math.min(3, height) - 0.01 and barH <= (mode == "above" and 9 or 7) + 0.6, where .. ": the bar keeps a sane height " .. barH)
				assert(cb.text:IsShown() == cb.timer:IsShown(), where .. ": the label and its time go together")
			end
		end
	end
	K.Options.Write("UnitFrames", "player.fonts.cast.size", 12)
	settle()
	noErrors("cast room")
end
