-- test-actionbars-medallions-crown.lua: the Medallions crest's crown: five ClassPip daggers fanned out of the top of the rune ring for a rogue, claws for a cat-form druid (its mana stays on the unit frames' druid bar), none for other classes, on by default and with Unit Frames not loaded, off when the unit frames' Class resource, Combo points or Class-themed pips setting is off, and it tells the unit frames whether it shows; each piece's art is drawn at its own angle, every lit layer is a one-point status bar fed the raw combo points now, before or at the maximum, a power event plays the fades only when motion allows, a target change and Off show the end states, the glints return on one common period only at a known maximum at Full, a changed maximum reuses the pieces built for it, nothing runs OnUpdate, and it listens only while it shows.
local AB = dofile("Tools/regression/actionbars_env.lua")

local ANGLES = { 130, 110, 90, 70, 50 }
local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local TRANSIENT = { "haloWas", "rise", "flare", "ember", "slash", "shine" }

local function New(class, size, setup)
	size = size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._points, e._max, e._powerType = 0, 5, 3
			e.GetComboPoints = function() return e._restricted and e.Secret(e._points) or e._points end
			e.UnitPowerType = function() return e._powerType end
			e.UnitPower = function(_, kind) return kind == 0 and 1500 or e._points end
			e.UnitPowerMax = function(_, kind) return kind == 0 and 3000 or e._max end
			if setup then setup(e) end
		end,
	})
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

local function Points(env, n, event)
	env._points = n
	env.FireEvent(event or "UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
end

local function Reveal(env, value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

local Last = AB.W.LastCall

local function Moving(state)
	local shown, playing, loops = 0, 0, 0
	for _, p in ipairs(state.pips) do
		for _, key in ipairs(TRANSIENT) do
			if p[key]:IsShown() then shown = shown + 1 end
			if p[key].anim:IsPlaying() then
				playing = playing + 1
				if (p[key].anim:GetLooping() or "NONE") ~= "NONE" then loops = loops + 1 end
			end
		end
	end
	return shown, playing, loops
end

local function Listeners(env)
	local n = 0
	for _, f in ipairs(env._frames) do
		if f._events.UNIT_POWER_FREQUENT then n = n + 1 end
	end
	return n
end

local env, K, ns = New("ROGUE")
local C = ns.SlabCrown.state
local hub = ns.Slab.hub
local saved = K.Store.Profile().UnitFrames
assert(not env._addons.KstyleUI_UnitFrames and not (saved and saved.resource), "the action bars run without Unit Frames or its resource settings")
assert(C.shown and #C.pips == 5, "a rogue's crest wears the crown by default, with Unit Frames not loaded")
local line = C.line
assert(line and K.Widgets.ClassCrown() == line, "and tells the unit frames it shows the points, with a seat for the druid bar")
local _, seatTo, _, seatX, seatY = line:GetPoint(1)
assert(seatTo == hub and seatX == 0 and seatY > 76 + 44, "the seat is just above the tips")
for i, p in ipairs(C.pips) do
	local angle = ANGLES[i]
	assert(p.frame:IsShown() and p.frame:GetParent() == hub.top, "blade " .. i .. " stands on the hub")
	assert(tostring(Last(p.steel, "SetTexture")[1]):find("PipBladeSteel" .. angle .. ".png", 1, true), "blade " .. i .. " is drawn at " .. angle .. " degrees")
	assert(tostring(Last(p.blade, "SetStatusBarTexture")[1]):find("PipBlade" .. angle .. ".png", 1, true), "its lit art at the same angle")
	local point, relative, relativePoint, x, y = p.frame:GetPoint(1)
	assert(point == "CENTER" and relative == hub and relativePoint == "CENTER", "blade " .. i .. " is placed from the hub's centre")
	local a = math.deg(math.atan2(y, x))
	assert(math.abs(a - angle) < 1 and y > 0, "blade " .. i .. " fans out at " .. angle .. " degrees above the hub, got " .. a)
	assert(not p.frame._scripts.OnUpdate, "no blade runs OnUpdate")
end
local listening = Listeners(env)
assert(listening >= 1, "the crown listens for combo points while it shows")

-- A gain under restriction: every layer gets the secret count, and only the fades play.
env._restricted = true
Points(env, 2)
for _, p in ipairs(C.pips) do
	for _, key in ipairs({ "halo", "rise", "flare", "blade" }) do
		local value = Last(p[key], "SetValue")[1]
		assert(env.issecretvalue(value) and Reveal(env, value) == 2, "blade " .. p.i .. "'s " .. key .. " gets the secret count itself")
	end
	local _, low, high = nil, p.shine:GetMinMaxValues()
	assert(low == 4 and high == 5, "the glint lights only at the maximum")
end
local shown, playing, loops = Moving(C)
assert(shown == 6 * 5 and playing == 6 * 5 and loops == 0, "a gain plays every transient layer once")
Points(env, 0)
assert(Reveal(env, Last(C.pips[2].ember, "SetValue")[1]) == 2, "a spend drains with the count before, kept unread")
env._restricted = false

-- A target change shows the count at once; Off plays nothing; Calm plays the fades but never loops.
Points(env, 3, "PLAYER_TARGET_CHANGED")
shown, playing = Moving(C)
assert(shown == 0 and playing == 0, "a target change moves nothing")
K.Options.Write("Medallions", "motion", "off")
Points(env, 5)
shown, playing = Moving(C)
assert(shown == 0 and playing == 0, "Off plays nothing")
K.Options.Write("Medallions", "motion", "calm")
Points(env, 4)
Points(env, 5)
shown, playing, loops = Moving(C)
assert(shown == 6 * 5 and playing == 6 * 5 and loops == 0, "Calm plays the fades and never loops")

-- At a known maximum at Full the glints sweep 0.05 s apart, then all return on one 3.5 s rest, so the wave keeps its
-- shape (review 678 #4); below it, or at a secret count, they stop.
local function Sweep()
	for _, p in ipairs(C.pips) do
		if p.shine.anim:IsPlaying() then p.shine.anim._scripts.OnFinished(p.shine.anim) end
	end
end
K.Options.Write("Medallions", "motion", "full")
Points(env, 5, "PLAYER_TARGET_CHANGED")
for i, p in ipairs(C.pips) do
	assert(p.shine.anim:IsPlaying() and math.abs(Last(p.shineWait, "SetDuration")[1] - (3.5 + (i - 1) * 0.05)) < 1e-9, "glint " .. i .. " starts 0.05 s after the one before")
end
Sweep()
for i, p in ipairs(C.pips) do
	assert(p.shine.anim:IsPlaying() and Last(p.shineWait, "SetDuration")[1] == 3.5, "glint " .. i .. " returns on the common 3.5 s rest")
end
assert(select(3, Moving(C)) == 0, "the return is no loop, so no group's period drifts")
local function Glints()
	local n = 0
	for _, p in ipairs(C.pips) do
		if p.shine.anim:IsPlaying() or p.shine:IsShown() then n = n + 1 end
	end
	return n
end
Points(env, 4)
Sweep()
assert(Glints() == 0, "below the maximum the glints stop")
env._restricted = true
Points(env, 5, "PLAYER_TARGET_CHANGED")
assert(Glints() == 0, "a secret count never starts them")
env._restricted = false

-- A changed maximum reuses the pieces built for that count; the client never frees a frame (review 678 #5).
local before = #env._frames
for _, most in ipairs({ 4, 5, 4, 5, 4, 5 }) do
	env._max = most
	env.FireEvent("UNIT_MAXPOWER", "player", "COMBO_POINTS")
	assert(#C.pips == most, "the crown has " .. most .. " pieces")
end
assert(#env._frames - before == 4 * 9, "only the four-piece crown is new, got " .. (#env._frames - before) .. " frames")

-- The unit frames' Class-themed pips setting turns it off and on, even with Unit Frames not loaded.
K.Store.Profile().UnitFrames = K.Store.Profile().UnitFrames or {}
K.Store.Profile().UnitFrames.resource = { classPips = false }
K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", false)
assert(not C.shown and not C.pips[1].frame:IsShown() and Listeners(env) == listening - 1, "off: no crown and no listening for it")
K.Store.Profile().UnitFrames.resource.classPips = true
K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", true)
assert(C.shown and C.pips[1].frame:IsShown(), "on again: the crown")

-- The unit frames' Class resource and Combo points switches turn it off too (review 678 #3).
for _, key in ipairs({ "enabled", "comboPoints" }) do
	K.Store.Profile().UnitFrames.resource = { [key] = false }
	K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource." .. key, false)
	assert(not C.shown and not K.Widgets.ClassCrown(), "resource." .. key .. " off: no crown, and the unit frames know")
	K.Store.Profile().UnitFrames.resource = {}
	K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource." .. key, true)
	assert(C.shown and K.Widgets.ClassCrown(), "resource." .. key .. " on: the crown")
end

-- Frames hides it with the hub.
assert(not C.shown and not C.pips[1].frame:IsShown() and not K.Widgets.ClassCrown(), "Frames has no crown")
assert(#env._errors == 0 and K.ErrorCount() == 0, "rogue: " .. tostring(env._errors[1]))

-- A druid: claws in cat form, its mana left to the unit frames' druid bar and its settings (review 678 #3), nothing in
-- caster form.
do
	local denv, DK, dns = New("DRUID")
	local state = dns.SlabCrown.state
	assert(state.shown and #state.pips == 5 and tostring(Last(state.pips[3].blade, "SetStatusBarTexture")[1]):find("PipClaw90.png", 1, true), "a cat-form druid wears a crown of claws")
	for _, f in ipairs(denv._frames) do
		assert(not (f:GetParent() == dns.Slab.hub.top and f._type == "StatusBar"), "the crown draws no mana line of its own")
	end
	denv._powerType = 0
	denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(not state.shown and not state.pips[1].frame:IsShown(), "caster form: no crown")
	assert(#denv._errors == 0 and DK.ErrorCount() == 0, "druid: " .. tostring(denv._errors[1]))
end

for _, class in ipairs({ "WARRIOR", "PALADIN", "WARLOCK" }) do
	local cenv, CK, cns = New(class)
	assert(not cns.SlabCrown.state.shown and #cns.SlabCrown.state.pips == 0, class .. " has no crown")
	assert(#cenv._errors == 0 and CK.ErrorCount() == 0, class .. ": " .. tostring(cenv._errors[1]))
end

-- The blades are whole pixels at every owner screen.
for _, size in ipairs(SIZES) do
	local senv, SK, sns = New("ROGUE", size)
	for _, p in ipairs(sns.SlabCrown.state.pips) do
		local px = SK.Widgets.Border(p.frame)
		local w = p.frame:GetWidth() / px
		assert(math.abs(w - math.floor(w + 0.5)) < 1e-6, size[1] .. "x" .. size[2] .. ": blade " .. p.i .. " is " .. w .. " pixels wide")
	end
	assert(#senv._errors == 0 and SK.ErrorCount() == 0, size[1] .. "x" .. size[2] .. ": " .. tostring(senv._errors[1]))
end

print("actionbars medallions crown ok")
