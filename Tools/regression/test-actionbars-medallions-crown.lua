-- test-actionbars-medallions-crown.lua: the Medallions crest's crown: five ClassPip daggers fanned out of the top of the rune ring for a rogue, claws for a cat-form druid with its mana as a thin line above them, sun-spears for a paladin and soul shards for a warlock, as many as UnitPowerMax gives (none at 0), on by default and with Unit Frames not loaded, off when the unit frames' Class-themed pips setting is off; each piece's art is drawn at its own angle, every lit layer is a one-point status bar fed the raw combo points now, before or at the maximum, a power event plays the fades only when motion allows, a target change and Off show the end states, the glint repeats only at a known maximum at Full, nothing runs OnUpdate, and it listens only while it shows.
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
	K.Options.Write("HudStyle", "style", "medallions")
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

local function Last(region, method)
	local calls = region._calls
	for i = #calls, 1, -1 do
		if calls[i].method == method then return calls[i].args end
	end
end

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

-- At a known maximum at Full each glint repeats; below it, or at a secret count, nothing loops.
K.Options.Write("Medallions", "motion", "full")
Points(env, 5, "PLAYER_TARGET_CHANGED")
loops = select(3, Moving(C))
assert(loops == 5, "at the maximum at Full each blade's glint repeats, got " .. loops)
Points(env, 4)
assert(select(3, Moving(C)) == 0, "below the maximum nothing loops")
env._restricted = true
Points(env, 5, "PLAYER_TARGET_CHANGED")
assert(select(3, Moving(C)) == 0, "a secret count never starts the loop")
env._restricted = false

-- The unit frames' Class-themed pips setting turns it off and on, even with Unit Frames not loaded.
K.Store.Profile().UnitFrames = K.Store.Profile().UnitFrames or {}
K.Store.Profile().UnitFrames.resource = { classPips = false }
K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", false)
assert(not C.shown and not C.pips[1].frame:IsShown() and Listeners(env) == listening - 1, "off: no crown and no listening for it")
K.Store.Profile().UnitFrames.resource.classPips = true
K.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.classPips", true)
assert(C.shown and C.pips[1].frame:IsShown(), "on again: the crown")

-- Frames hides it with the hub.
K.Options.Write("HudStyle", "style", "frames")
assert(not C.shown and not C.pips[1].frame:IsShown(), "Frames has no crown")
assert(#env._errors == 0 and K.ErrorCount() == 0, "rogue: " .. tostring(env._errors[1]))

-- A paladin's holy power and a warlock's soul shards: as many pieces as UnitPowerMax gives, in a fan centred on the top,
-- fed that power; none at 0.
for _, case in ipairs({ { "PALADIN", "HOLY_POWER", "PipSpear" }, { "WARLOCK", "SOUL_SHARDS", "PipShard" } }) do
	local class, token, art = case[1], case[2], case[3]
	local cenv, CK, cns = New(class, nil, function(e) e._max, e._powerType = 3, 0 end)
	local state = cns.SlabCrown.state
	assert(state.shown and #state.pips == 3, class .. ": three pieces for a maximum of three")
	for i, angle in ipairs({ 110, 90, 70 }) do
		assert(tostring(Last(state.pips[i].blade, "SetStatusBarTexture")[1]):find(art .. angle .. ".png", 1, true), class .. ": piece " .. i .. " at " .. angle .. " degrees")
	end
	local low, high = state.pips[1].shine:GetMinMaxValues()
	assert(low == 2 and high == 3, class .. ": the glint lights at its maximum of three")
	cenv._points = 2
	cenv.FireEvent("UNIT_POWER_FREQUENT", "player", token)
	assert(Last(state.pips[2].blade, "SetValue")[1] == 2 and select(2, Moving(state)) == 6 * 3, class .. ": its power event lights and moves the crown")
	cenv._max = 0
	cenv.FireEvent("UNIT_MAXPOWER", "player", token)
	assert(not state.shown and not state.pips[1].frame:IsShown(), class .. ": a client without the power draws nothing")
	assert(#cenv._errors == 0 and CK.ErrorCount() == 0, class .. ": " .. tostring(cenv._errors[1]))
end

-- A druid: claws in cat form with its mana as a thin line above them (off with the unit frames' Druid mana), nothing in
-- caster form.
do
	local denv, DK, dns = New("DRUID")
	local state = dns.SlabCrown.state
	assert(state.shown and #state.pips == 5 and tostring(Last(state.pips[3].blade, "SetStatusBarTexture")[1]):find("PipClaw90.png", 1, true), "a cat-form druid wears a crown of claws")
	local line = state.mana
	assert(line and line:IsShown(), "with its mana as a line above them")
	local _, _, _, _, y = line:GetPoint(1)
	assert(y > 76 + 44, "the mana line sits above the claws' tips")
	assert(Last(line, "SetValue")[1] == 1500 and select(2, line:GetMinMaxValues()) == 3000, "fed the druid's mana")
	DK.Store.Profile().UnitFrames = DK.Store.Profile().UnitFrames or {}
	DK.Store.Profile().UnitFrames.resource = { druidMana = false }
	DK.Callbacks.Fire("SettingChanged", "UnitFrames", "resource.druidMana", false)
	assert(state.shown and not line:IsShown(), "Druid mana off hides the line and keeps the claws")
	denv._powerType = 0
	denv.FireEvent("UPDATE_SHAPESHIFT_FORM")
	assert(not state.shown and not state.pips[1].frame:IsShown(), "caster form: no crown")
	assert(#denv._errors == 0 and DK.ErrorCount() == 0, "druid: " .. tostring(denv._errors[1]))
end

do
	local wenv, WK, wns = New("WARRIOR")
	assert(not wns.SlabCrown.state.shown and #wns.SlabCrown.state.pips == 0, "a warrior has no crown")
	assert(#wenv._errors == 0 and WK.ErrorCount() == 0, "warrior: " .. tostring(wenv._errors[1]))
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
