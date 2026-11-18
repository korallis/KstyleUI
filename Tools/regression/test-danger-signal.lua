-- test-danger-signal.lua: the aspect-correct danger edge and player-only annulus share an engine breath, keep health secret, and restore the previous art and behaviour through Options.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
local function near(a, b) return math.abs(a - b) < 0.001 end
local function alpha(region)
	local value = U.W.LastCall(region, "SetAlpha")[1]
	return env.issecretvalue(value) and env.Reveal(value) or value
end
K.Options.Write("HudStyle", "style", "medallions")
U.SetUnit(env, "target", { name = "Enemy", health = 8, healthMax = 100, reaction = 2, canAttack = true })
env.SetTarget(true)
local player = env._units.player
local m = ns.Frames.Get("player").views[1].medallion
local enemy = ns.Frames.Get("target").views[1].medallion
local V = K.Effects.Vignette
assert(K.Store.Module("UnitFrames").dangerEdge == true, "default ON: add dangerEdge to UnitFrames defaults")
assert(K.Store.Module("UnitFrames").cleanLowRing == true, "default ON: add cleanLowRing to UnitFrames defaults")
assert(V.frame:GetParent() == env.UIParent, "parent the danger edge to UIParent so hiding the UI hides it")
assert(#V.frame.body == 8 and #V.frame.ember == 8, "use aspect-correct edge slices for both layers")
assert(U.W.LastCall(V.frame.body[1], "SetBlendMode")[1] == "BLEND", "the body darkens the world with BLEND")
assert(U.W.LastCall(V.frame.ember[1], "SetBlendMode")[1] == "ADD", "only the small ember adds light")
assert(near(alpha(V.frame.body[1]), 0.6) and near(alpha(V.frame.ember[1]), 0.22), "cap body and ember at 0.6 and 0.22")
local width, height = env.UIParent:GetWidth(), env.UIParent:GetHeight()
env.UIParent:SetSize(height * 32 / 9, height)
K.Callbacks.Fire("ScaleChanged")
assert(near(V.frame.body[1]:GetWidth(), height * 0.18) and near(V.frame.ember[1]:GetWidth(), height * 0.08), "ultrawide corners keep 18% and 8% short-side depth after a scale change")
env.UIParent:SetSize(width, height)
K.Callbacks.Fire("ScaleChanged")
for _, point in ipairs({ { 0, 0.7 }, { 0.15, 0.7 }, { 0.275, 0.35 }, { 0.4, 0 }, { 1, 0 } }) do
	player.health = player.healthMax * point[1]
	env.FireEvent("UNIT_HEALTH", "player")
	assert(near(alpha(m.low), point[2]), "use the linear 15%-40% annulus curve, never compare health in Lua")
end
assert(not m.pulse:IsPlaying(), "the clean ring uses the shared breath, not the old fast pulse")
assert(m.dangerPulse and U.W.LastCall(m.dangerPulse, "SetTarget")[1] == m.lowFrame, "target the player ring from the vignette's engine group")
assert(m.dangerPulse._parent == V.frame.breath, "one AnimationGroup starts the ring and vignette together")
assert(near(U.W.LastCall(m.dangerPulse, "SetDuration")[1], K.Tokens.Duration("dangerBreath")), "share dangerBreath 0.8 seconds per leg")
assert(near(U.W.LastCall(m.dangerPulse, "SetToAlpha")[1], 0.6), "both signals breathe from 1 to 0.6")
assert(m.lowFrame:GetFrameLevel() < m:GetFrameLevel(), "draw the clean annulus below the bezel's frame level")
assert(near(m.lowFrame:GetWidth(), K.Widgets.Snap(m, m.size * 1.12)), "use LOW_SPREAD 1.12")
assert(enemy.lowFrame:IsShown() and not enemy.pulse:IsPlaying() and alpha(enemy.low) == 1, "enemies get a static rim, never a low-health pulse")
assert(enemy.low:GetTexture() == K.Tokens.Texture("dangerRim"), "the enemy rim is a clean 2-unit ring")
env._units.target.canAttack, env._units.target.reaction = false, 5
env.FireEvent("UNIT_HEALTH", "target")
assert(not enemy.lowFrame:IsShown(), "friendly units never get the danger rim")
env._units.target.canAttack, env._units.target.reaction = true, 2
K.Options.Write("UnitFrames", "cleanLowRing", false)
assert(m.low:GetTexture() == K.Tokens.Texture("medLowHealthRing"), "off restores the smoke art")
assert(m.lowFrame:GetFrameLevel() == m:GetFrameLevel() + 1, "off restores the old overlay layer")
assert(near(m.lowFrame:GetWidth(), K.Widgets.Snap(m, m.size * 1.3)), "off restores the old spread")
assert(enemy.pulse:IsPlaying(), "off restores the enemy pulse")
assert(near(U.W.LastCall(enemy.pulse._anims[1], "SetDuration")[1], 0.4), "off restores the 1.25 Hz pulse")
K.Options.Write("UnitFrames", "dangerEdge", false)
assert(V.frame:GetParent() == (env.WorldFrame or env.UIParent), "off restores the previous world parent")
assert(V.frame.art[1]:IsShown() and not V.frame.body[1]:IsShown(), "off restores the old full-screen additive art")
assert(V.frame.art[1]:GetTexture() == K.Tokens.Texture("medVignette"), "keep the original vignette asset")
K.Options.Write("UnitFrames", "dangerEdge", true)
K.Options.Write("UnitFrames", "cleanLowRing", true)
env.UIParent:Hide()
-- The stub does not dispatch OnHide to descendants; the client does.
V.frame:GetScript("OnHide")(V.frame)
assert(not V.frame:IsVisible() and not V.frame.breath:IsPlaying(), "hidden UI stops the shared loop")
env.UIParent:Show()
assert(V.frame.breath:IsPlaying(), "showing the UI restarts the shared loop")
K.Options.Write("Medallions", "motion", "calm")
assert(not V.frame.breath:IsPlaying() and not m.pulse:IsPlaying(), "Calm holds both danger signals still")
K.Options.Write("Medallions", "motion", "off")
assert(not V.frame.breath:IsPlaying(), "Off holds danger still too")
player.dead = true
env.FireEvent("PLAYER_DEAD")
env.FireEvent("UNIT_HEALTH", "player")
assert(not V.frame:IsShown() and not m.lowFrame:IsShown(), "death clears both signals")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok danger signal")
