-- test-unitframes-medallions-fx.lua: the Medallions unit-frame effects through the shared layer: the portrait sheen is ambient motion that yields while a flip-in holds the medallion and comes back after; a level-up blooms a class-motif burst behind the player's medallion (a 3D model at Full, the 2D still at Calm, nothing at Off); a cast that lands or stops washes the bar steel or red with a light streak clipped to the bar, Off keeps it still, and Frames keeps its gilt flash.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local E = K.Effects

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local player = env._units.player
player.class, player.race, player.sex = "SHAMAN", "Dwarf", 2
U.SetUnit(env, "target", { name = "Galestrider", level = 6, health = 1206, healthMax = 1698, reaction = 2, canAttack = true })
env.SetTarget(true)
local frames = {}
for _, kind in ipairs(ns.Settings.KINDS) do
	frames[kind] = ns.Frames.Get(kind)
end

local ended = {}
function ended:SetTimeSpan(startTime, endTime)
	self.span = { startTime, endTime }
end
env.C_DurationUtil = { CreateDuration = function()
	return ended
end }
env._time = 1

local cb
local function cast(id)
	player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116, barID = id }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-" .. id, 116, id)
	cb = ns.CastBars.Get("player")[1]
end
local function land(id)
	player.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-" .. id, 116, id)
end
local function near(name, alpha)
	local r, g, b, a = cb.flash.wash:GetVertexColor()
	local ok, er, eg, eb = pcall(K.Tokens.Color, name)
	if not ok then
		return false
	end
	return W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb) and W.Near(a, alpha)
end

cast(1)
land(1)
assert(cb.flash.group:IsPlaying() and near("giltLit", 0.6) and not cb.medStreak, "under Frames a landed cast keeps its gilt flash")
env.RunTimers()
W.Settle(env)

K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(K.HudStyle.Current() == "medallions", "the style switched")
noErrors("switch")

local view = frames.player.views[1]
local m = view.medallion
assert(m and m:IsShown(), "the player medallion shows")
assert(E.playerMedallion == m, "the effects layer knows the player's medallion")
assert(m.sheenAnim:IsPlaying(), "the player's portrait sheen runs as ambient motion")

local tm = frames.target.views[1].medallion
assert(tm.sheenAnim:IsPlaying(), "the target's sheen runs too")
tm:FlipIn()
assert(tm.flip:IsPlaying() and E.Holder(tm) == E.PRIORITY.target, "a flip-in holds the target medallion")
assert(not tm.sheenAnim:IsPlaying() and tm.sheenAnim:IsPaused(), "the sheen pauses while the flip holds the medallion")
env.RunTimers()
assert(E.Holder(tm) == nil and tm.sheenAnim:IsPlaying(), "the sheen picks up again after the flip")

env.FireEvent("PLAYER_LEVEL_UP", 12)
assert(E.Holder(m) == E.PRIORITY.burst, "a level-up bursts behind the player's medallion")
assert(E.LiveModels() >= 1 and not (m.burst and m.burst.anim:IsPlaying()), "at Full the burst is the class model")
assert(not m.sheenAnim:IsPlaying(), "the sheen yields to the burst")
tm:FlipIn()
assert(E.Holder(tm) == E.PRIORITY.target, "another medallion is another place")
E.StopModels()
env.RunTimers()
K.Options.Write("Medallions", "motion", "calm")
env.FireEvent("PLAYER_LEVEL_UP", 13)
assert(m.burst and m.burst.anim:IsPlaying() and E.LiveModels() == 0, "at Calm the burst is the 2D still")
assert(m.burst:GetWidth() > m:GetWidth(), "the burst blooms beyond the medallion")
assert(m.burst:GetTexture() ~= nil, "the burst has art, its own or the glow")
env.RunTimers()
K.Options.Write("Medallions", "motion", "off")
m.burst.anim:Stop()
env.FireEvent("PLAYER_LEVEL_UP", 14)
assert(not m.burst.anim:IsPlaying() and E.Holder(m) == nil, "Off plays no burst")
assert(not m.sheenAnim:IsPlaying(), "Off stops the sheen")
K.Options.Write("Medallions", "motion", "full")
assert(m.sheenAnim:IsPlaying(), "Full brings the sheen back")
noErrors("medallions")

local bar = ns.CastBars.NewBar(env.UIParent, "player", false)
bar.frame:SetSize(240, 20)
bar.bar:SetSize(220, 12)
bar.frame:Show()
local Fx = ns.CastEffects
assert(Fx.Flash(bar, "giltLit", 0.6) == true, "under Medallions the effects layer takes the cast flash")
cb = bar
assert(cb.medStreak and cb.medStreak.anim:IsPlaying() and cb.flash.group:IsPlaying(), "a landed cast washes the bar and runs a streak along it")
assert(near("steelLit", 0.6) or near("textEmphasis", 0.6), "the wash is steel, not gilt")
assert(W.LastCall(cb.flash, "SetClipsChildren")[1] == true, "the streak is clipped to the bar")
local length = cb.medStreak.streak:GetWidth()
assert(W.Near(length, 220 * 0.35) and W.Near(W.LastCall(cb.medStreak.move, "SetOffset")[1], 220 + length), "the streak crosses the whole bar")
assert(E.Holder(cb) == E.PRIORITY.cast, "the flash holds its cast bar")
Fx.Flash(cb, "hostile", 0.55)
assert(cb.flash.group:IsPlaying() and near("hostile", 0.55), "a stopped cast washes red")
env.RunTimers()
assert(E.Holder(cb) == nil, "the hold ends with the flash")
K.Options.Write("Medallions", "motion", "off")
cb.flash.group:Stop()
cb.medStreak.anim:Stop()
assert(Fx.Flash(cb, "giltLit", 0.6) == true and not cb.flash.group:IsPlaying() and not cb.medStreak.anim:IsPlaying(), "Off keeps the cast bar still")
for _, frame in ipairs(env._frames) do
	assert(not (frame == cb.flash or frame == cb.medStreak) or not frame:GetScript("OnUpdate"), "the flash runs no OnUpdate")
end
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
assert(Fx.Flash(cb, "giltLit", 0.6) == false, "Frames keeps CastBar's own flash")
noErrors("cast")

do
	local wenv, WK, wns = U.New()
	local me = wenv._units.player
	me.class, me.race, me.sex = "WARLOCK", "Scourge", 2
	U.SetUnit(wenv, "pet", { name = "Zabnik", level = 38, health = 100, healthMax = 100, reaction = 5 })
	local wframes = {}
	for _, kind in ipairs(wns.Settings.KINDS) do
		wframes[kind] = wns.Frames.Get(kind)
	end
	WK.Options.Write("HudStyle", "style", "medallions")
	wenv.RunTimers()
	local wm = wframes.player.views[1].medallion
	assert(wm and wm:IsShown() and WK.Effects.playerMedallion == wm, "Lee's undead warlock has a player medallion")
	assert(tostring(wm.portrait:GetTexture()):lower():find("scourge_warlock", 1, true), "it shows the undead warlock bust: " .. tostring(wm.portrait:GetTexture()))
	local pet = wframes.pet.views[1].medallion
	assert(pet and pet:IsShown(), "the imp has its medallion")
	wenv.FireEvent("PLAYER_LEVEL_UP", 39)
	assert(wm.burst and tostring(wm.burst:GetTexture()):find("BurstWarlock", 1, true), "the level-up burst is the fel burst: " .. tostring(wm.burst and wm.burst:GetTexture()))
	local fel
	for _, frame in ipairs(wenv._frames) do
		if frame:GetObjectType() == "ModelScene" and frame:IsShown() then
			fel = frame.actor._state.ModelByFileID and frame.actor._state.ModelByFileID[1]
		end
	end
	assert(fel == WK.Effects.MODELS.WARLOCK, "at Full the burst is the warlock's fel model: " .. tostring(fel))
	wenv.RunTimers()
	wenv.SetCombat(true)
	wenv.SetCombat(false)
	wenv.RunTimers()
	assert(WK.Layout.Rest.Resting() and WK.Layout.Rest.Level("unitframes.pet") == WK.Layout.Rest.ALPHA, "the imp's frame rests after combat")
	assert(WK.Layout.Rest.Level("unitframes.player") == 1, "the warlock's own frame never rests")
	assert(#wenv._errors == 0 and WK.ErrorCount() == 0, "warlock: " .. tostring(wenv._errors[1]))
end

print("ok unitframes medallions fx")
