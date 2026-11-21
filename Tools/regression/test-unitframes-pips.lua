-- test-unitframes-pips.lua: the class-themed combo point row (on by default) draws Widgets.ClassPip daggers for a rogue and claw marks for a cat-form druid over the plain pips' places; every lit layer is a one-point status bar fed the raw count now, before, or at the maximum; a power event plays the gain, spend and maximum fades only when motion allows, a target change and Off show the end states, transient layers are hidden rather than alpha 0, nothing runs OnUpdate, the idle glint and breath run only at a known maximum under Medallions at Full, a rogue's row gives way to the crest's crown under Medallions, and switching the pips off restores the plain ones.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function rogue(env)
	env._units.player.class = "ROGUE"
	env._units.player.powerType, env._units.player.powerToken = 3, "ENERGY"
end

local env, K, ns = U.New({ setup = rogue })
local R, P = ns.Resource.state, ns.Pips.state
local FEED = { halo = "now", haloWas = "was", rise = "now", flare = "now", ember = "was", slash = "was", blade = "now", shine = "max" }
local TRANSIENT = { haloWas = true, rise = true, flare = true, ember = true, slash = true, shine = true }

local function noErrors(e, k, where)
	assert(#e._errors == 0, where .. ": " .. tostring(e._errors[1]))
	assert(k.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function Points(e, n, event)
	e._comboPoints = n
	e.FireEvent(event or "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
end

local function Reveal(value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

local function File(region, method)
	return tostring(W.LastCall(region, method)[1])
end

local function Bars(state)
	local out = {}
	for _, p in ipairs(state.pips) do
		for key in pairs(FEED) do
			out[#out + 1] = p[key]
		end
	end
	out[#out + 1], out[#out + 2] = state.row.now, state.row.was
	return out
end

local function Loops(state)
	local n = 0
	for _, bar in ipairs(Bars(state)) do
		local group = bar.anim
		if group and group:IsPlaying() and (group:GetLooping() or "NONE") ~= "NONE" then n = n + 1 end
	end
	return n + (state.row.breath:IsPlaying() and 1 or 0)
end

local function Moving(state)
	local shown, playing = 0, 0
	for _, p in ipairs(state.pips) do
		for key in pairs(TRANSIENT) do
			if p[key]:IsShown() then shown = shown + 1 end
			if p[key].anim:IsPlaying() then playing = playing + 1 end
		end
	end
	return shown, playing
end

-- On by default under Frames: upright daggers over the plain pips' places, which hide.
assert(R.showCombo and R.themed, "a rogue's combo points are themed by default")
for i, pip in ipairs(R.pips) do
	local p = P.pips[i]
	assert(not pip:IsShown() and p.frame:IsShown(), "pip " .. i .. " shows the dagger over the hidden plain pip")
	assert(W.LastCall(p.frame, "SetPoint")[2] == pip, "pip " .. i .. "'s art is centred on its plain pip")
	assert(File(p.steel, "SetTexture"):find("PipBladeSteel90.png", 1, true), "an empty pip is the dormant upright dagger")
	assert(File(p.blade, "SetStatusBarTexture"):find("PipBlade90.png", 1, true), "a lit pip is the upright dagger")
	assert(File(p.mask, "SetTexture"):find("PipBladeShape90.png", 1, true), "the slide-in and slash are cut to the dagger")
	for _, key in ipairs({ "rise", "slash" }) do
		assert(p[key]:GetStatusBarTexture()._masks[1] == p.mask, "pip " .. i .. "'s " .. key .. " is masked to the dagger")
	end
	assert(File(p.halo, "SetStatusBarTexture"):find("PipBladeGlow90.png", 1, true), "the halo hugs the dagger")
end
local gr, gg, gb = K.Tokens.Color("pipRogueGlow")
local glow = W.LastCall(P.pips[1].halo, "SetStatusBarColor")
assert(glow[1] == gr and glow[2] == gg and glow[3] == gb, "the rogue's glow is pipRogueGlow")
assert(W.LastCall(P.pips[1].flare, "SetStatusBarColor")[1] == K.Tokens.Color("pipRogueCore"), "the flare is pipRogueCore")

-- The art centres on whole pixels: its overhang past the plain pip is a whole number of pixels on each side.
for _, p in ipairs(P.pips) do
	local px = K.Widgets.Border(p.frame)
	local over = (p.frame:GetWidth() - R.pips[p.i]:GetWidth()) / 2 / px
	assert(math.abs(over - math.floor(over + 0.5)) < 1e-6 and over > 0, "the art overhangs its pip by whole pixels, got " .. over)
end

-- Each layer is a one-point status bar: now and before light pip i from i - 1 to i, the glint and the row's glow the maximum.
for _, p in ipairs(P.pips) do
	for key, feed in pairs(FEED) do
		local _, low, high = U.Bar(env, p[key])
		local want = feed == "max" and 4 or p.i - 1
		assert(low == want and high == want + 1, "pip " .. p.i .. "'s " .. key .. " spans one point from " .. want)
	end
end
assert(select(2, U.Bar(env, P.row.now)) == 4 and select(2, U.Bar(env, P.row.was)) == 4, "the row's glow lights at the maximum")

-- At rest nothing moves, every transient layer is hidden and no layer is alpha 0.
local shown, playing = Moving(P)
assert(shown == 0 and playing == 0, "at login every transient layer is hidden and still")
for _, bar in ipairs(Bars(P)) do
	local alpha = W.LastCall(bar, "SetAlpha")
	assert(not alpha or alpha[1] > 0, "no layer waits at alpha 0; transient ones hide")
	assert(not bar._scripts.OnUpdate, "no layer runs OnUpdate")
end

-- A gain under restriction: the layers get the secret count, and the fades play.
env._restricted = true
Points(env, 2)
for _, p in ipairs(P.pips) do
	for key, feed in pairs(FEED) do
		local value = W.LastCall(p[key], "SetValue")[1]
		assert(feed == "was" or env.issecretvalue(value), "pip " .. p.i .. "'s " .. key .. " gets the secret count itself")
		assert(Reveal(value) == (feed == "was" and 0 or 2), "pip " .. p.i .. "'s " .. key .. " gets the count " .. feed)
	end
end
shown, playing = Moving(P)
assert(shown == 6 * 5 and playing == 6 * 5, "a gain shows and plays every transient layer, got " .. shown .. " and " .. playing)
assert(P.pips[3].blade.anim:IsPlaying() and P.pips[3].halo.anim:IsPlaying(), "the lit layers hold and fade in")
assert(Loops(P) == 0, "nothing loops below the maximum")
Points(env, 0)
local was = W.LastCall(P.pips[2].ember, "SetValue")[1]
assert(env.issecretvalue(was) and Reveal(was) == 2, "a spend drains the pips lit before with the secret count before, kept unread")
env._restricted = false
noErrors(env, K, "secret gain")

-- A finished fade hides its layer.
local flare = P.pips[1].flare
flare.anim._scripts.OnFinished(flare.anim)
assert(not flare:IsShown(), "a transient layer hides when its fade ends")

-- A target change shows the count at once, as the game's own bar does; Off shows end states; Calm plays the fades.
Points(env, 3, "PLAYER_TARGET_CHANGED")
shown, playing = Moving(P)
assert(shown == 0 and playing == 0, "a target change moves nothing")
assert(Reveal(W.LastCall(P.pips[3].blade, "SetValue")[1]) == 3, "and lights the new count")
K.Options.Write("Medallions", "motion", "off")
Points(env, 4)
shown, playing = Moving(P)
assert(shown == 0 and playing == 0 and not P.pips[4].blade.anim:IsPlaying(), "Off plays nothing")
K.Options.Write("Medallions", "motion", "calm")
Points(env, 5)
assert(Moving(P) == 6 * 5, "Calm plays the fades")
K.Options.Write("Medallions", "motion", "full")
Points(env, 5)
assert(Loops(P) == 0, "Frames loops nothing, even at the maximum at Full")
noErrors(env, K, "motion")

-- Under Medallions a rogue's points are the crest's crown of blades: the row hides and has no mover; off brings the plain row back.
K.Options.Write("HudStyle", "style", "medallions")
assert(K.HudStyle.Current() == "medallions" and not R.showCombo and not R.content:IsShown(), "under Medallions a rogue's row gives way to the crown")
assert(not K.Layout.Live("unitframes.resource"), "and the empty element has no mover")
K.Options.Write("UnitFrames", "resource.classPips", false)
assert(R.showCombo and not R.themed and R.pips[1]:IsShown(), "Class-themed pips off: the plain pips come back under Medallions")
K.Options.Write("HudStyle", "style", "frames")
for i, pip in ipairs(R.pips) do
	assert(pip:IsShown() and not P.pips[i].frame:IsShown(), "off: plain pip " .. i .. " shows")
end
Points(env, 2)
assert(Reveal(W.LastCall(R.pips[1], "SetValue")[1]) == 2, "off: the plain pips take the count")
K.Options.Write("UnitFrames", "resource.classPips", true)
assert(R.themed and P.pips[1].frame:IsShown() and not R.pips[1]:IsShown(), "on again: the daggers")
noErrors(env, K, "switch")

-- A druid: claw marks in cat form, nothing in caster form; under Medallions the row stays, and at a known maximum at Full
-- its glow breathes and each glint repeats, while below it or at a secret count nothing loops.
local denv, DK, dns = U.New({ setup = function(e)
	e._units.player.class = "DRUID"
	e._units.player.powerType, e._units.player.powerToken = 3, "ENERGY"
end })
local DP, DR = dns.Pips.state, dns.Resource.state
assert(DR.themed and DP.pips[1].frame:IsShown(), "a cat-form druid's combo points are themed")
assert(File(DP.pips[1].blade, "SetStatusBarTexture"):find("PipDruid.png", 1, true), "as claw marks")
assert(File(DP.pips[1].steel, "SetTexture"):find("PipDruidSocket.png", 1, true), "in claw sockets")
assert(W.LastCall(DP.pips[1].halo, "SetStatusBarColor")[1] == DK.Tokens.Color("pipDruidGlow"), "glowing pipDruidGlow")
DK.Options.Write("HudStyle", "style", "medallions")
Points(denv, 5, "PLAYER_TARGET_CHANGED")
assert(DR.themed and DP.row.breath:IsPlaying() and Loops(DP) == 5 + 1, "at the maximum under Medallions the row breathes and each glint repeats")
Points(denv, 5)
assert(DP.pips[2].shine.anim:GetLooping() == "NONE", "a change at the maximum runs one glint first")
DP.pips[2].shine.anim._scripts.OnFinished(DP.pips[2].shine.anim)
assert(DP.pips[2].shine.anim:GetLooping() == "REPEAT" and DP.pips[2].shine:IsShown(), "after the glint that reaches the maximum, it repeats")
Points(denv, 4)
assert(Loops(DP) == 0 and not DP.row.breath:IsPlaying(), "below the maximum nothing loops")
DP.pips[2].shine.anim._scripts.OnFinished(DP.pips[2].shine.anim)
assert(not DP.pips[2].shine:IsShown(), "below the maximum the glint hides when it ends")
DK.Options.Write("Medallions", "motion", "calm")
Points(denv, 5)
assert(Loops(DP) == 0, "Calm does not breathe")
DK.Options.Write("Medallions", "motion", "full")
denv._restricted = true
Points(denv, 5)
assert(Loops(DP) == 0, "a secret count never starts the idle loops")
denv._restricted = false
denv._units.player.powerType, denv._units.player.powerToken = 0, "MANA"
denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(not DR.themed and not DP.pips[1].frame:IsShown(), "caster form: no pips")
noErrors(denv, DK, "druid")

print("unitframes pips ok")
