-- groupframes_r3a.lua: shared setup for the group frames parity round 3a tests: the buffs you know and members carry, per-spell aura secrecy, mana and your raid group.
local H = { G = dofile("Tools/regression/group_env.lua"), MODULE = "GroupFrames" }
H.FORTITUDE, H.INTELLECT, H.THORNS = "Power Word: Fortitude", "Arcane Intellect", "Thorns"
local NAMES = { [1243] = H.FORTITUDE, [21562] = "Prayer of Fortitude", [1459] = H.INTELLECT, [23028] = "Arcane Brilliance", [467] = H.THORNS,
	[1126] = "Mark of the Wild", [21849] = "Gift of the Wild", [14752] = "Divine Spirit", [27681] = "Prayer of Spirit",
	[1038] = "Blessing of Salvation", [25895] = "Greater Blessing of Salvation" }

function H.setup(env)
	env._buffs = {}
	env._known = { [1243] = true, [1459] = true, [467] = true }
	env.C_SpellBook = { IsSpellKnown = function(id) return env._known[id] == true end }
	env.C_Spell = env.C_Spell or {}
	env.C_Spell.GetSpellName = function(id) return NAMES[id] end
	env.C_Spell.GetSpellTexture = function(id) return 100000 + id end
	env.C_Secrets.ShouldSpellAuraBeSecret = function() return env._aurasSecret == true end
	env.C_UnitAuras = env.C_UnitAuras or {}
	env.C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter)
		assert(filter == "HELPFUL", "missing buffs read helpful auras")
		if env._aurasSecret then return env.Secret({}) end
		local own = env._buffs[unit]
		return own and own[name] and { name = name } or nil
	end
	env.UnitPowerType = function(unit)
		local m = env._member(unit)
		return m and m.rage and 1 or 0, m and m.rage and "RAGE" or "MANA"
	end
	env.UnitPowerPercent = function(unit, kind, _, curve)
		assert(kind == 0, "healer mana reads mana")
		local m = env._member(unit)
		local share = (m and m.power or 50) / (m and m.maxPower or 100)
		return env.Secret(curve and curve:Evaluate(share) or share)
	end
	env.UnitInRaid = function(unit)
		return env._roster.kind == "raid" and unit == "player" and 1 or nil
	end
end

function H.write(env, K, key, value)
	K.Options.Write(H.MODULE, key, value)
	env.RunTimers()
end

function H.reveal(env, value)
	return env.issecretvalue(value) and env.Reveal(value) or value
end

function H.text(env, region)
	return H.reveal(env, region:GetText())
end

function H.formatted(env, region)
	local args = region._state.FormattedText
	local out = {}
	for i = 1, args.n do out[i] = H.reveal(env, args[i]) end
	return string.format(unpack(out, 1, args.n))
end

function H.frame(ns, unit)
	local out
	ns.Unit.ForEach(function(f) if f.unit == unit then out = f end end)
	return assert(out, "no frame for " .. unit)
end

function H.noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

function H.party(env)
	H.G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", rage = true, health = 50, maxHealth = 100 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 90, maxHealth = 100 },
	})
end

function H.width(env, region)
	return H.reveal(env, region:GetWidth())
end

function H.shown(f)
	return f.reminder ~= nil and f.reminder:IsShown()
end

function H.icon(f)
	return f.reminder.tile.icon:GetTexture()
end

function H.point(region)
	local p, rel, relPoint, x, y = region:GetPoint(1)
	return table.concat({ tostring(p), tostring(rel), tostring(relPoint), tostring(x), tostring(y) }, " ")
end

function H.offset(region)
	local _, _, _, x, y = region:GetPoint(1)
	return x, y
end

function H.near(a, b)
	return math.abs(a - b) < 1e-3
end

-- boot(opts) -> a quiet environment with the module on and a party; opts.setup defaults to H.setup, and a screen given by
-- opts.width and opts.height is checked to be the one booted.
function H.boot(opts)
	opts = opts or {}
	opts.setup = opts.setup or H.setup
	local env, K, ns = H.G.New(opts)
	env.SetQuiet(true) -- The parity checks read frame state; they do not need the widget call history.
	if opts.width then
		local w, h = env.GetPhysicalScreenSize()
		assert(w == opts.width and h == opts.height, "booted " .. w .. "x" .. h .. " for " .. opts.width .. "x" .. opts.height)
	end
	H.party(env)
	K.Modules.Enable(H.MODULE)
	env.RunTimers()
	return env, K, ns
end

H.SCREENS = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

-- screen(size) -> H.boot options for one of H.SCREENS at the game's default UI scale and the automatic interface size.
function H.screen(size, opts)
	opts = opts or {}
	opts.width, opts.height, opts.uiScale, opts.size = size[1], size[2], 768 / 1080, "auto"
	return opts
end

-- overlap(env, a, b) -> how far two regions' rendered rects cross, across and down; either at 0 or below means apart.
local Scene
function H.overlap(env, a, b)
	Scene = Scene or dofile("Tools/render/scene.lua")
	local r, s = { Scene.Rect(env, a) }, { Scene.Rect(env, b) }
	return math.min(r[1] + r[3], s[1] + s[3]) - math.max(r[1], s[1]), math.min(r[2] + r[4], s[2] + s[4]) - math.max(r[2], s[2])
end

return H
