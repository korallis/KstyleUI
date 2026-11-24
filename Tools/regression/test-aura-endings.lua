-- test-aura-endings.lua: aura timers retain a positive final second, the buff bar, plates, unit frames (player, target, focus, boss, pet) and party and raid frames on both HUD styles share one expiring colour (timerExpiring, 7:1 or more against the black outline), and swipe flashes can be restored.
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local bands = {}
local env, K = A.New({ setup = function(e)
	e.AuraContainerInbound.GetDefaultAuraDurationFormatter().GetMaxIntervalCurve = function() return bands end
end })
local D = K.Widgets.Duration
K.Modules.Enable("Auras")
env.RunTimers()
local _, group = A.Container(env, "HELPFUL")
local button = group.frames[1]
A.Remaining(env, button, env.Secret(0.4))
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "the live bound 0.4-second aura timer rounds up")
assert(env.issecretvalue(button._aura.timer:GetText()), "live duration text stays engine-managed")
assert(button._aura.timerOptions.textFormatter.settings.SetMaxIntervalCurve == bands, "rounding preserves Blizzard's short-timer interval bands")
assert(K.Options.Row("Auras", "timer.cleanEndings") == nil, "remove the separate preview-only toggle")
assert(K.Appearance.Get("auraEndings"), "shared aura endings default on")
K.Options.Write("Appearance", "auraEndings", false)
env.RunTimers()
assert(env.Reveal(button._aura.timer:GetText()) == "0s", "shared endings off restores the old live formatter")
K.Options.Write("Appearance", "auraEndings", true)
env.RunTimers()
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "reenabling endings updates the existing live binding")
for _, kind in ipairs({ "long", "short" }) do
	K.Options.Write("Auras", "timer.format", kind)
	assert(env.Reveal(button._aura.timer:GetText()) == "1s", "live " .. kind .. " timers keep the final second")
end
local binding = D.ExpiringColor(5)
assert(binding and binding.property == env.Enum.DurationTextBindingProperty.RemainingDuration, "bind expiring colour to the engine's remaining duration")
assert(D.ExpiringColor(0) == nil, "zero disables the existing colour warning")
local Tokens = K.Tokens
local function same(bound, where, base)
	local points = assert(bound and bound.curve.points, where .. " binds an expiring colour curve")
	local function at(i) local p = points[i]; return p.x or p[1], p.color or p[2] end
	local x, low = at(1)
	local _, high = at(2)
	local r, g, b = Tokens.Color("timerExpiring")
	assert(x == 0 and low.r == r and low.g == g and low.b == b, where .. " turns expiring timers the shared timerExpiring colour")
	if base then
		r, g, b = Tokens.Color(base)
		assert(high.r == r and high.g == g and high.b == b, where .. " keeps its " .. base .. " ink above the warning")
	end
end
same(binding, "Duration.ExpiringColor")
same(button._aura.timerOptions.textColor, "the live buff bar")
local function luminance(r, g, b)
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end
local er, eg, eb = Tokens.Color("timerExpiring")
local contrast = (luminance(er, eg, eb) + 0.05) / (luminance(Tokens.Color("black")) + 0.05)
assert(contrast >= 7, ("timerExpiring is %.2f:1 against the black outline; keep it at 7:1 or more so it reads over any scenery"):format(contrast))
assert(er > eg and er > eb, "timerExpiring still reads as a red warning")
env.C_CurveUtil = nil
assert(D.ExpiringColor(5) == nil, "missing curve APIs keep a single colour")
local ns
env, K, ns = N.New()
N.Add(env, "nameplate1")
local plate = ns.Plates.Get("nameplate1")
button = plate.auras:GetAuraGroupFrame("debuffs", 1)
A.Remaining(env, button, env.Secret(0.4))
assert(env.Reveal(button._aura.timer:GetText()) == "1s", "plates use the shared rounded formatter too")
same(button._aura.timerOptions.textColor, "the live plate debuffs")
local function bling()
	for _, object in ipairs(A.Descendants(button)) do
		if object:GetObjectType() == "Cooldown" then return N.Last(object, "SetDrawBling") end
	end
end
assert(bling() and bling()[1] == false, "plate aura swipes disable the finishing flash by default")
K.Options.Write("Appearance", "auraEndings", false)
env.RunTimers()
assert(bling()[1] == true, "off restores the original finishing flash")
assert(env.Reveal(button._aura.timer:GetText()) == "0s", "off restores the original plate timer")
assert(#env._errors == 0, tostring(env._errors[1]))

local U, Engine = dofile("Tools/regression/unitframes_env.lua"), dofile("Tools/regression/aura_fixture_engine.lua")
local KINDS = { player = "player", target = "target", focus = "focus", boss = "boss1", pet = "pet" }
for _, style in ipairs({ "medallions", "frames" }) do
	local uenv, UK, uns = U.New({ frames = style == "frames" })
	for kind, unit in pairs(KINDS) do
		U.SetUnit(uenv, unit, { name = unit, health = 1, healthMax = 2, reaction = 2, auras = {
			{ id = 1, icon = 135813, left = 3, harmful = true, mine = true }, { id = 2, icon = 136026, left = 3, harmful = false, mine = true } } })
		UK.Options.Write("UnitFrames", kind .. (style == "medallions" and kind == "player" and ".medallionsAuras" or ".auras"), true)
		UK.Options.Write("UnitFrames", kind .. ".auraTimer", true)
	end
	uenv.RunTimers()
	Engine.Install(uenv)
	for kind in pairs(KINDS) do
		local view = uns.Frames.Get(kind).views[1]
		local entry
		for _, each in ipairs(view.auras and view.auras.buttons or {}) do entry = entry or each.button:IsShown() and each end
		assert(entry, style .. " " .. kind .. " shows an aura tile")
		same((entry.button._aura.SetDurationText[2] or {}).textColor, style .. " " .. kind .. " frame", "textEmphasis")
		assert(entry.timer:GetTextColor() == er, style .. " " .. kind .. ": a 3-second timer draws in timerExpiring")
		UK.Options.Write("UnitFrames", kind .. ".auraExpiring", 0)
		uenv.RunTimers()
		local options = entry.button._aura.SetDurationText[2]
		assert(not (options and options.textColor), style .. " " .. kind .. ": zero keeps one colour")
	end
	assert(#uenv._errors == 0 and UK.ErrorCount() == 0, tostring(uenv._errors[1]))
end

local G = dofile("Tools/regression/group_env.lua")
for _, style in ipairs({ "medallions", "frames" }) do
	for _, kind in ipairs({ "party", "raid" }) do
		local genv, GK, gns = G.New({ setup = G.Secure })
		if style == "frames" then GK.Options.Write("HudStyle", "style", "frames") end
		G.SetRoster(genv, kind, G.Members(kind == "raid" and 10 or 2))
		GK.Modules.Enable("GroupFrames")
		GK.Options.Write("GroupFrames", "auras.timers", true)
		genv.RunTimers()
		local f
		gns.Unit.ForEach(function(each) if each.unit == kind .. "1" then f = each end end)
		A.Assign(genv, assert(f, kind .. "1 has a frame").auras, "debuffs", 1)
		genv.RunTimers()
		local debuff = f.auras._groups.debuffs.active[1]
		same(debuff._aura.timerOptions.textColor, style .. " " .. kind .. " frame", "white")
		GK.Options.Write("GroupFrames", "auras.expiring", 0)
		genv.RunTimers()
		assert(not debuff._aura.timerOptions.textColor, style .. " " .. kind .. ": zero keeps one colour")
		assert(#genv._errors == 0 and GK.ErrorCount() == 0, tostring(genv._errors[1]))
	end
end
print("aura endings ok")
