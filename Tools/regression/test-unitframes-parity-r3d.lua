-- test-unitframes-parity-r3d.lua: parity round 3d keeps v0.2.8 frames, then turns on, probes after events and turns off the buff lanes, duration, lockout, hidden and tracked spell filters, row spacing, precise timers, full spell names, spell rank, latency text and craft batches, and checks the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {} },
	setup = function(e)
		e.UnitCanAssist = function(_, token) return e._units[token] ~= nil and e._units[token].assist == true end
		e._lag, e._subtext, e._recasts = 42, "Rank 3", 2
		e.GetNetStats = function() return 0, 0, 20, e._lag end
		e.C_Spell.GetSpellSubtext = function() return e._subtext end
		e.C_TradeSkillUI = { GetRemainingRecasts = function() return e._recasts end }
		e._textWidth = function(text, _, size) return #text * size * 0.6 end
		local cast = e.UnitCastingInfo
		e.UnitCastingInfo = function(token)
			local r = { cast(token) }
			if e._trade and r[1] ~= nil then r[6] = true end
			return unpack(r, 1, 11)
		end
	end,
})
local Settings = ns.Settings

local function clean()
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
	assert(K.Options.Read("UnitFrames", key) == value, key .. " must round-trip")
end

-- A v0.2.8-shaped profile keeps today's settings and never touches the candidate filters.
local AURA_DEFAULTS = { buffStealable = "", buffDefensive = "", buffDispellable = "", auraHidden = "", auraTracked = "",
	auraTimed = false, auraHideLockout = false, auraTrackedOnly = false, auraRowGap = 0, auraPrecise = 0 }
for kind in pairs(Settings.AURAS) do
	for key, value in pairs(AURA_DEFAULTS) do
		assert(Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
	for _, view in ipairs(ns.Frames.Get(kind).views) do
		local container = view.auras and view.auras.container
		assert(not (container and container._candidateCalls), kind .. " sets no candidate filters by default")
	end
end
for kind in pairs(Settings.CASTBAR) do
	assert(Settings.Value(kind, "castbarFit") == false, kind .. " keeps cut-off spell names")
end
for _, key in ipairs({ "castbarRank", "castbarLagText", "castbarCraft" }) do
	assert(Settings.Value("player", key) == false, "player." .. key .. " starts off")
end

-- Buff lanes reach the engine's filter string and candidate filters, on the target and on boss frames.
local target = ns.Frames.Get("target").views[1]
write("target.auraFilter", "both")
local groups = target.auras.container._groups
assert(groups.buffs.filter == "HELPFUL" and groups.buffs.candidates == nil, "both lanes start open")
write("target.buffDefensive", "only")
assert(groups.buffs.filter == "HELPFUL|BIG_DEFENSIVE", "only big defensives: " .. groups.buffs.filter)
write("target.buffDefensive", "hide")
write("target.buffDispellable", "only")
assert(groups.buffs.filter == "HELPFUL|!BIG_DEFENSIVE|DISPELLABLE", "hide big defensives, keep dispellable: " .. groups.buffs.filter)
assert(groups.debuffs.filter == "HARMFUL", "the lanes leave debuffs alone")
write("target.buffStealable", "only")
assert(groups.buffs.candidates.isStealable == true and groups.debuffs.candidates == nil, "only stealable buffs")
local chip = target.auras.overflow.buffs
assert(chip.ghost._groups.count.candidates.isStealable == true, "the +N count follows the stealable filter")
write("target.buffStealable", "hide")
assert(groups.buffs.candidates.isStealable == false, "hide stealable buffs")
for _, key in ipairs({ "buffStealable", "buffDefensive", "buffDispellable" }) do
	write("target." .. key, "")
end
assert(groups.buffs.filter == "HELPFUL" and groups.buffs.candidates == nil and chip.ghost._groups.count.candidates == nil, "turning the lanes off restores the open filter")
local boss = ns.Frames.Get("boss").views[1]
write("boss.auraFilter", "both")
write("boss.buffDispellable", "hide")
write("boss.buffStealable", "only")
assert(boss.auras.container._groups.buffs.filter == "HELPFUL|!DISPELLABLE" and boss.auras.container._groups.buffs.candidates.isStealable == true, "boss frames take the lanes")
write("boss.buffDispellable", "")
write("boss.buffStealable", "")

-- Duration, lockouts and hidden spell IDs.
write("target.auraTimed", true)
assert(groups.buffs.candidates.maxDuration == math.huge and groups.debuffs.candidates.maxDuration == math.huge, "only auras with a duration")
write("target.auraHideLockout", true)
assert(groups.debuffs.candidates.excludeSpellIDs[57724] and not groups.buffs.candidates.excludeSpellIDs, "lockouts hide among debuffs only")
write("target.auraHidden", "1459, 21562")
assert(groups.debuffs.candidates.excludeSpellIDs[1459] and groups.debuffs.candidates.excludeSpellIDs[57723], "hidden IDs join the lockouts")
assert(groups.buffs.candidates.excludeSpellIDs[21562], "hidden IDs reach the buffs")
write("target.auraTimed", false)
write("target.auraHideLockout", false)
write("target.auraHidden", "")
assert(groups.buffs.candidates == nil and groups.debuffs.candidates == nil, "turning the filters off clears the candidates")

-- Tracked buffs apply on friendly units only and follow target and faction changes.
U.SetUnit(env, "target", { name = "Elunara", level = 60, health = 3000, healthMax = 4000, reaction = 5, assist = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
write("target.auraTracked", "1459 21562")
write("target.auraTrackedOnly", true)
assert(groups.buffs.candidates.includeSpellIDs[1459] and groups.debuffs.candidates == nil, "a friend shows only the tracked buffs")
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(groups.buffs.candidates == nil, "an enemy's buffs show as usual")
env._units.target.assist = true
env.FireEvent("UNIT_FACTION", "target")
assert(groups.buffs.candidates.includeSpellIDs[21562], "a faction change re-checks the unit")
local calls = target.auras.container._candidateCalls
env.FireEvent("UNIT_FACTION", "target")
assert(target.auras.container._candidateCalls == calls, "an unchanged unit does no work")
write("target.auraTrackedOnly", false)
assert(groups.buffs.candidates == nil, "turning tracking off restores every buff")
calls = target.auras.container._candidateCalls
env._units.target.assist = false
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(target.auras.container._candidateCalls == calls, "tracking off ignores target changes")
write("player.medallionsAuras", true)
write("player.auras", true)
write("player.auraFilter", "buffs")
write("player.auraTracked", "1459")
write("player.auraTrackedOnly", true)
local player = ns.Frames.Get("player").views[1]
assert(player.auras.container._groups.buffs.candidates.includeSpellIDs[1459], "the player is always friendly")
write("player.auraTrackedOnly", false)
write("player.auras", false)

-- Extra row spacing reaches the engine's line spacing, the footprint and the +N cell.
write("target." .. Settings.AuraKey("target", "auraRows"), 2)
local line = groups.debuffs.layout.lineSpacing
local _, height = ns.Auras.Footprint("target")
local _, _, y = ns.Auras.LastCell("target", nil, true)
write("target.auraRowGap", 4)
assert(math.abs(groups.debuffs.layout.lineSpacing - line - 4) < 0.01, "the rows move apart")
local _, wider = ns.Auras.Footprint("target")
local _, _, lower = ns.Auras.LastCell("target", nil, true)
assert(wider == height + 3 * 4 and math.abs(lower - y) == 4, "the footprint (two rows each of debuffs and buffs) and +N cell follow: " .. wider - height .. " " .. lower - y)
write("target.auraRowGap", 0)
assert(groups.debuffs.layout.lineSpacing == line, "zero restores the spacing")

-- Precise timers: a missing formatter keeps the short form; one installed in combat waits for combat's end.
local entry = target.auras.buttons[1]
local function options() return entry.button._aura.SetDurationText[2] end
write("target.auraPrecise", 3)
assert(options() == nil and entry.precise == nil, "no seconds formatter keeps the default timer")
env.Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
env.Enum.SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
env.Enum.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
env.C_StringUtil = { CreateSecondsFormatter = function()
	return setmetatable({ calls = {} }, { __index = function(_, method) return function(self, ...) self.calls[method] = { ... } end end })
end }
env.SetCombat(true)
write("target.auraPrecise", 5)
assert(options() == nil, "aura buttons are not touched in combat")
env.SetCombat(false)
env.RunTimers()
local formatter = assert(options() and options().textFormatter, "the timer takes the precise formatter after combat")
assert(formatter.calls.SetDesiredUnitCountCurve and formatter.calls.SetMaxIntervalCurve, "two units below the threshold, the game's bands above")
for _, each in ipairs(target.auras.buttons) do
	assert(each.button._aura.SetDurationText[2].textFormatter == formatter, "every timer shares one formatter")
end
write("target.auraPrecise", 5)
assert(options().textFormatter == formatter, "an unchanged value keeps its formatter")
write("target.auraPrecise", 0)
assert(options() == nil, "zero restores the game's own timer")

-- Cast bars: full spell names, rank, latency text and craft batches.
local cb = ns.CastBars.Inline("player")[1]
local function cast(name, channel)
	env._units.player.cast, env._units.player.channel = nil, nil
	env._units.player[channel and "channel" or "cast"] = { name = name or "Frostbolt", texture = 135846, start = 1000, finish = 4000, spellID = 116 }
	env.FireEvent(channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", "player", "Cast-1", 116)
end
local function size()
	return W.LastCall(cb.text, "SetFont")[2]
end
local function tick()
	cb.frame:GetScript("OnUpdate")(cb.frame, 1)
	return U.Shown(env, cb.timer)
end
local LONG = string.rep("Arcane ", 12) .. "Missiles"
cast(LONG)
local base = size()
write("player.castbarFit", true)
cast(LONG)
assert(size() < base and size() >= base * 0.6 - 1, "a long name shrinks to fit")
cast("Frostbolt")
assert(size() == base, "a short name keeps its size")
cast(LONG)
env._units.player.secretCast = true
cast(LONG)
assert(size() == base, "a secret name is never measured")
env._units.player.secretCast = nil
write("player.castbarFit", false)
cast(LONG)
assert(size() == base, "turning it off cuts the name off again")

write("player.castbarRank", true)
cast()
assert(U.Shown(env, cb.text):lower():find("(rank 3)", 1, true), "the rank follows the name: " .. U.Shown(env, cb.text))
cast(nil, true)
assert(U.Shown(env, cb.text):lower():find("(rank 3)", 1, true), "channels show their rank too")
env._subtext = "Racial"
cast()
assert(not U.Shown(env, cb.text):find("(", 1, true), "a subtext without a rank adds nothing")
env._subtext = "Rank 3"
write("player.castbarRank", false)
cast()
assert(not U.Shown(env, cb.text):find("(", 1, true), "turning it off shows the plain name")

local column = W.LastCall(cb.timer, "SetWidth")[1]
assert(not tick():find("ms", 1, true), "no latency text by default")
write("player.castbarLagText", true)
cast()
assert(tick():find("(42ms)", 1, true), "latency joins the timer: " .. U.Shown(env, cb.timer))
assert(W.LastCall(cb.timer, "SetWidth")[1] > column, "the timer column widens")
assert(not Settings.Value("player", "castbarLatency") and not cb.latency, "latency text needs no latency zone")
env._lag = env.Secret(50)
cast()
assert(not tick():find("ms", 1, true), "a secret latency is left out")
env._lag = 42
write("player.castbarLagText", false)
cast()
assert(not tick():find("ms", 1, true) and W.LastCall(cb.timer, "SetWidth")[1] == column, "turning it off restores the timer")

env._trade = true
cast()
local one = tick()
write("player.castbarCraft", true)
cast()
assert(U.Shown(env, cb.text):find("(3)", 1, true), "the name counts the crafts left")
local batch = tick()
assert(tonumber(batch:match("^[%d.]+")) == 9, "the timer counts down this craft and the two left: " .. one .. " -> " .. batch)
env._recasts = 0
cast()
assert(not U.Shown(env, cb.text):find("(", 1, true) and tick() == one, "the last craft is a plain cast")
env._recasts = 2
env._trade = nil
cast()
assert(not U.Shown(env, cb.text):find("(", 1, true), "spells are not crafts")
env._trade = true
write("player.castbarCraft", false)
cast()
assert(tick() == one, "turning it off restores the single craft")
env._trade = nil

-- The preview shows each option.
write("edit", "target")
write("target.auraPrecise", 3)
write("target.auraRowGap", 6)
local pane = ns.Preview.Build(env.UIParent)
local tiles = pane.auraTiles.target
assert(U.Shown(env, tiles[6].timer) == "2m 48s", "the preview timer is precise: " .. U.Shown(env, tiles[6].timer))
local columns = Settings.Value("target", "auraColumns")
local first, second = W.LastCall(tiles[1].skin, "SetPoint"), W.LastCall(tiles[columns + 1].skin, "SetPoint")
local pitch = math.abs(second[5] - first[5])
write("target.auraRowGap", 0)
pane:Refresh()
second, first = W.LastCall(tiles[columns + 1].skin, "SetPoint"), W.LastCall(tiles[1].skin, "SetPoint")
assert(pitch - math.abs(second[5] - first[5]) > 5, "the preview rows move apart by about the gap")
write("target.auraPrecise", 0)
pane:Refresh()
assert(U.Shown(env, tiles[6].timer) == "3m", "the preview keeps the short timer by default")
write("edit", "player")
write("player.style", "plate")
for _, key in ipairs({ "castbarRank", "castbarLagText", "castbarCraft" }) do
	write("player." .. key, true)
end
pane:Refresh()
local sample = pane.casts.player
assert(U.Shown(env, sample.text):lower():find("(rank 3) (3)", 1, true), "the preview name shows rank and crafts: " .. U.Shown(env, sample.text))
assert(U.Shown(env, sample.timer):find("(42ms)", 1, true), "the preview timer shows latency")
for _, key in ipairs({ "castbarRank", "castbarLagText", "castbarCraft" }) do
	write("player." .. key, false)
end
pane:Refresh()
assert(not U.Shown(env, sample.text):find("(", 1, true) and not U.Shown(env, sample.timer):find("ms", 1, true), "the preview clears them")
clean()
print("test-unitframes-parity-r3d: ok")
