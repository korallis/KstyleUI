-- test-unitframes-r3d-review.lua: the PR #628 review probes: tracked buffs follow UNIT_FLAGS and stop refreshing once idle, the crest takes the debuff filters and precise timer, unchanged applies skip the engine, precise timers fit their pitch, fitted names keep the readable floor, late ranks land, a secret batch tick holds, latency reads once, and the preview shows the filters and live timer.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	setup = function(e)
		e.UnitCanAssist = function(_, token) return e._units[token] ~= nil and e._units[token].assist == true end
		e._textWidth = function(text, _, size) return #text * size * 0.6 end
		e.C_Spell.GetSpellSubtext = function() return e._rank end
		e.Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
		e.Enum.SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
		e.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
		e.C_StringUtil = { CreateSecondsFormatter = function()
			return setmetatable({ calls = {} }, { __index = function(_, method) return function(self, ...) self.calls[method] = { ... } end end })
		end }
	end,
	before = function(_, core)
		core.Store.Module("UnitFrames").auraLayout = "fan"
		core.Store.Module("HudStyle").style = "medallions"
		core.Callbacks.Fire("SettingChanged", "HudStyle", "style")
	end,
})

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local target = ns.Frames.Get("target").views[1]
write("target.auras", true)
write("target.auraFilter", "both")
U.SetUnit(env, "target", { name = "Fixture", health = 100, healthMax = 100, reaction = 5, assist = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
write("target.auraTracked", "1459")
write("target.auraTrackedOnly", true)
local groups = target.auras.container._groups
assert(groups.buffs.candidates.includeSpellIDs[1459], "a friendly target keeps only tracked buffs")

-- UNIT_FLAGS alone turns a friend hostile, as the engine's own containers listen for it.
env._units.target.assist = false
env.FireEvent("UNIT_FLAGS", "target")
env.RunTimers()
assert(groups.buffs.candidates == nil, "UNIT_FLAGS drops the allowlist on a hostile target")

-- With buffs off nothing is tracked, so faction events apply nothing.
env._units.target.assist = true
env.FireEvent("UNIT_FACTION", "target")
write("target.auraFilter", "debuffs")
env._units.target.assist = false
local applies, apply = 0, ns.Auras.Apply
ns.Auras.Apply = function(v)
	if v == target then applies = applies + 1 end
	return apply(v)
end
env.FireEvent("UNIT_FACTION", "target")
env.FireEvent("UNIT_FACTION", "target")
ns.Auras.Apply = apply
assert(applies == 0, "an inactive tracker refreshes nothing: " .. applies)

-- The crest takes the same hidden IDs and duration filter as the row, and so does its +N count.
write("target.auraFilter", "both")
write("target.auraHidden", "1234")
write("target.auraTimed", true)
local fan = target.auras.fan
assert(fan and fan.enabled, "the crest is on")
for rank, container in ipairs(fan.containers) do
	local c = container._groups.debuffs.candidates
	assert(c and c.excludeSpellIDs[1234] and c.maxDuration, "crest " .. rank .. " hides ID 1234 and permanent debuffs")
end

-- An unchanged apply leaves the engine's candidate filters alone.
local container = target.auras.container
local calls = container._candidateCalls
ns.Auras.Apply(target)
assert(container._candidateCalls == calls, "unchanged candidates are not set again: " .. container._candidateCalls - calls)
local crest = fan.containers[1]._candidateCalls
ns.Auras.Apply(target)
assert(fan.containers[1]._candidateCalls == crest, "nor on the crest")

-- Precise timers: the crest shares the formatter, and adjacent labels fit the pitch.
write("target.auraTimer", true)
write("target.auraSize", 22)
write("target.auraSpacing", 2)
local spacing = groups.buffs.layout.elementSpacing
write("target.auraPrecise", 5)
local formatter = target.auras.formatter
assert(formatter, "a precise formatter")
for _, entry in ipairs(fan.buttons) do
	assert(entry.button._aura.SetDurationText[2].textFormatter == formatter, "crest timers are precise too")
end
local entry = target.auras.buttons[1]
local _, size = entry.timer:GetFont()
local label = env._textWidth("4m 59s", nil, size)
local layout = groups.buffs.layout
assert(layout.elementWidth + layout.elementSpacing >= label, "a precise label fits its pitch: " .. layout.elementWidth + layout.elementSpacing .. " < " .. label)
write("target.auraPrecise", 0)
assert(groups.buffs.layout.elementSpacing == spacing, "off restores the spacing")

-- The preview drops the samples a lane rejects.
write("edit", "target")
local pane = ns.Preview.Build(env.UIParent)
write("target.auraTrackedOnly", false)
pane:Refresh()
local function icons()
	local list = {}
	for _, tile in ipairs(pane.auraTiles.target) do
		if tile.skin:IsShown() then list[#list + 1] = tostring(W.LastCall(tile.icon, "SetTexture")[1]) end
	end
	return table.concat(list, ",")
end
local before = icons()
write("target.buffDefensive", "only")
pane:Refresh()
assert(icons() ~= before, "only big defensives changes the preview: " .. icons())
write("target.buffDefensive", "")
pane:Refresh()
assert(icons() == before, "show all restores it")

-- Cast bars.
write("player.castbarFit", true)
write("player.castbarRank", true)
local cb = ns.CastBars.Get("player")[1]
local function cast(name)
	env._units.player.cast = { name = name, texture = 135846, start = 1000, finish = 4000, spellID = 116 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end

-- A rank that loads after the cast starts lands on SPELL_TEXT_UPDATE.
env._rank = ""
cast("Frostbolt")
env._rank = "Rank 3"
env.FireEvent("SPELL_TEXT_UPDATE", 116)
env.RunTimers()
assert(U.Shown(env, cb.text):lower():find("rank 3", 1, true), "the late rank appears: " .. U.Shown(env, cb.text))

-- A fitted name stops at the readable floor.
cast(string.rep("Arcane ", 24))
local _, fitted = cb.text:GetFont()
local px = fitted * K.Widgets.ScaleFactor(cb.text) / K.Scale.Pixel(1)
assert(px >= K.Scale.TextFloor() - 1e-6, "a fitted name keeps the readable floor: " .. px)

-- Fit off reads no widths.
write("player.castbarFit", false)
local getWidth, reads = cb.text.GetWidth, 0
cb.text.GetWidth = function(self) reads = reads + 1; return getWidth(self) end
cast("Frostbolt")
cb.text.GetWidth = getWidth
assert(reads == 0, "fit off measures nothing: " .. reads)

-- Both latency options read the latency once per cast.
local stats = 0
env.GetNetStats = function() stats = stats + 1; return 0, 0, 20, 42 end
write("player.castbarLatency", true)
write("player.castbarLagText", true)
stats = 0
cast("Frostbolt")
assert(stats == 1, "one GetNetStats per cast: " .. stats)

-- A batch keeps ticking when the duration object turns secret.
env._trade = true
local info = env.UnitCastingInfo
env.UnitCastingInfo = function(token)
	local r = { info(token) }
	if r[1] then r[6] = true end
	return unpack(r, 1, 11)
end
env.C_TradeSkillUI = { GetRemainingRecasts = function() return 2 end }
write("player.castbarCraft", true)
cast("Craft")
local d = assert(cb.duration, "a duration object")
d.GetRemainingDuration = function() return env.Secret(3) end
d.GetTotalDuration = function() return env.Secret(3) end
d.GetElapsedDuration = function() return env.Secret(0) end
local ok, err = pcall(cb.frame:GetScript("OnUpdate"), cb.frame, 1)
assert(ok, "a secret duration tick holds: " .. tostring(err))
assert(U.Shown(env, cb.timer):find("9.0", 1, true), "the batch timer runs on the plain cast times: " .. U.Shown(env, cb.timer))
env.UnitCastingInfo = info
write("player.castbarCraft", false)

-- The preview timer uses the live format: elapsed / total with latency.
write("player.castbarTotal", true)
write("edit", "player")
write("player.style", "plate")
pane:Refresh()
local shown = U.Shown(env, pane.casts.player.timer)
assert(shown:find(" / ", 1, true) and shown:find("(42ms)", 1, true), "the preview timer matches the live one: " .. shown)

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-unitframes-r3d-review: ok")
