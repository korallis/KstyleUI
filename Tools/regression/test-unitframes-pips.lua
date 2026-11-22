-- test-unitframes-pips.lua: the class-themed combo point row (on by default) draws Widgets.ClassPip daggers for a rogue and claws for a cat-form druid over the plain pips' places; every lit layer is a one-point status bar fed the raw count now, before, or at the maximum; a power event plays the gain, spend and maximum fades only when motion allows, a target change and Off show the end states, transient layers are hidden rather than alpha 0, nothing runs OnUpdate or loops, under Medallions the row gives way to the crest's crown only while it shows and a cat-form druid's bar sits above it, and switching the pips off restores the plain ones; a paladin or warlock shows nothing, as before.
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
	return n
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
local gr, gg, gb = K.Tokens.Color("jewelCombo")
local glow = W.LastCall(P.pips[1].halo, "SetStatusBarColor")
assert(glow[1] == gr and glow[2] == gg and glow[3] == gb, "the rogue's glow is the combo jewels' jewelCombo")
assert(W.LastCall(P.pips[1].flare, "SetStatusBarColor")[1] == K.Tokens.Color("jewelComboCore"), "the flare is jewelComboCore")

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

-- Turning motion Off settles a row that is still playing at once (review 678 #4).
Points(env, 2)
assert(P.pips[2].flare.anim:IsPlaying() and P.row.was.anim:IsPlaying(), "a spend is playing")
K.Options.Write("Medallions", "motion", "off")
assert(Moving(P) == 0 and not P.row.was.anim:IsPlaying() and not P.row.was:IsShown(), "Off settles the playing row at once")
K.Options.Write("Medallions", "motion", "full")

-- An unchanged readable count plays nothing again; a secret one is never compared, so it replays (review 678 #5).
local calls = 0
for _, bar in ipairs(Bars(P)) do
	for _, method in ipairs({ "Play", "Stop" }) do
		local native = bar.anim[method]
		bar.anim[method] = function(...) calls = calls + 1 return native(...) end
	end
end
Points(env, 2)
assert(calls == 0, "an unchanged count touches no animation, got " .. calls .. " calls")
env._restricted = true
Points(env, 2)
assert(calls > 0, "a secret count is never compared with the one before")
env._restricted = false
noErrors(env, K, "settle")

-- A secret count never meets a truth test: choose the fed value with an explicit if (review 678 #1).
for path, pattern in pairs({ ["Core/Widgets/ClassPip.lua"] = "and was or now", ["KstyleUI_UnitFrames/Pips.lua"] = "and state.points or", ["KstyleUI_ActionBars/SlabCrown.lua"] = "and state.points or" }) do
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a")
	file:close()
	assert(not source:find(pattern, 1, true), path .. ": '" .. pattern .. "' tests a secret count; pick it with if on the public flag")
end

-- Under Medallions the row stays until the crest's crown shows the points (Action Bars off, the slab off or unpaired:
-- no crown, review 678 #2); while it does, a rogue's row hides and has no mover; off brings the plain row back.
local crest = env.CreateFrame("Frame", nil, env.UIParent)
K.Widgets.SetClassCrown(crest)
assert(not R.showCombo and not R.content:IsShown(), "the crown takes a rogue's points")
assert(not K.Layout.Live("unitframes.resource"), "and the empty element has no mover")
K.Widgets.SetClassCrown(nil)
assert(R.showCombo and R.content:IsShown(), "the row comes back when the crown goes")
K.Widgets.SetClassCrown(crest)
K.Options.Write("UnitFrames", "resource.classPips", false)
assert(R.showCombo and not R.themed and R.pips[1]:IsShown(), "Class-themed pips off: the plain pips come back under Medallions")
for i, pip in ipairs(R.pips) do
	assert(pip:IsShown() and not P.pips[i].frame:IsShown(), "off: plain pip " .. i .. " shows")
end
Points(env, 2)
assert(Reveal(W.LastCall(R.pips[1], "SetValue")[1]) == 2, "off: the plain pips take the count")
K.Widgets.SetClassCrown(nil)
K.Options.Write("UnitFrames", "resource.classPips", true)
assert(R.themed and P.pips[1].frame:IsShown() and not R.pips[1]:IsShown(), "on again: the daggers")
noErrors(env, K, "switch")

-- Frames keeps the daggers' row and its mover; off brings the plain row back there too.
K.Options.Write("HudStyle", "style", "frames")
assert(R.showCombo and R.themed and P.pips[1].frame:IsShown() and not R.pips[1]:IsShown() and K.Layout.Live("unitframes.resource"), "Frames keeps the daggers' row and its mover")
K.Options.Write("UnitFrames", "resource.classPips", false)
for i, pip in ipairs(R.pips) do
	assert(pip:IsShown() and not P.pips[i].frame:IsShown(), "Frames off: plain pip " .. i .. " shows")
end
K.Options.Write("UnitFrames", "resource.classPips", true)
K.Options.Write("HudStyle", "style", "medallions")
noErrors(env, K, "frames")

-- The combo colour paints the plain pips only, so it shows while Class-themed pips is off (review 678 #3).
for _, key in ipairs({ "resource.comboColor", "resource.comboCustom" }) do
	local row = K.Options.Row("UnitFrames", key)
	local function shows(classPips)
		return row.showWhen({ edit = "player", resource = { enabled = true, classPips = classPips, comboColor = "custom" } })
	end
	assert(not shows(true) and shows(false), key .. " shows only for the plain pips")
end

-- A druid: claws in cat form, nothing in caster form; under Medallions the crest's crown takes the claws, and the
-- druid bar keeps its own settings in every form (review 678 #2, #3), seated just above the crown's tips in cat form so
-- the two never overlap.
local denv, DK, dns = U.New({ setup = function(e)
	e._units.player.class = "DRUID"
	e._units.player.powerType, e._units.player.powerToken = 3, "ENERGY"
	e._units.player.powers, e._units.player.powerMaxes = { [0] = 1500 }, { [0] = 3000 }
end })
local DP, DR = dns.Pips.state, dns.Resource.state
assert(DR.themed and DR.showMana and DP.pips[1].frame:IsShown(), "a cat-form druid's combo points are themed, beside its mana")
assert(File(DP.pips[1].blade, "SetStatusBarTexture"):find("PipClaw90.png", 1, true), "as claws")
assert(File(DP.pips[1].steel, "SetTexture"):find("PipClawSteel90.png", 1, true), "dormant when empty")
assert(W.LastCall(DP.pips[1].halo, "SetStatusBarColor")[1] == DK.Tokens.Color("pipDruidGlow"), "glowing pipDruidGlow")
Points(denv, 5)
assert(Loops(DP) == 0, "the row loops nothing, even at the maximum")
local dcrest = denv.CreateFrame("Frame", nil, denv.UIParent)
DK.Widgets.SetClassCrown(dcrest)
assert(not DR.showCombo and DR.showMana and DR.content:IsShown(), "under Medallions the crown takes the claws and the druid bar stays")
local _, seat = DR.content:GetPoint(1)
assert(seat == dcrest and not DK.Layout.Live("unitframes.resource"), "seated on the crown's anchor, so the element's own place is empty and has no mover")
DK.Options.Write("UnitFrames", "player.powerMana", true)
assert(DR.flipped == 3, "Mana in forms still swaps the druid bar to the form's power")
DK.Options.Write("UnitFrames", "player.powerMana", false)
denv._units.player.powerType, denv._units.player.powerToken = 1, "RAGE"
DK.Widgets.SetClassCrown(nil)
denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(DR.showMana and not DR.showCombo and select(2, DR.content:GetPoint(1)) == DR.holder, "bear form has no crown, so its mana bar is back in its own place")
denv._units.player.powerType, denv._units.player.powerToken = 0, "MANA"
denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
assert(not DR.themed and not DP.pips[1].frame:IsShown(), "caster form: no pips")
noErrors(denv, DK, "druid")

-- A paladin or warlock has no pip resource on Forever and shows nothing, themed or not.
for _, class in ipairs({ "PALADIN", "WARLOCK" }) do
	local cenv, CK, cns = U.New({ setup = function(e) e._units.player.class = class end })
	assert(not cns.Resource.state.showCombo and not cns.Resource.state.themed, class .. ": no pips")
	noErrors(cenv, CK, class)
end

print("unitframes pips ok")
