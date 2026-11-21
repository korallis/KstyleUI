-- test-unitframes-aura-both-scope.lua: the target's Debuffs and buffs room rules stay on the target: a centred focus keeps its timer lane and the player's Medallions rows keep two of each kind.
local _, K, ns = dofile("Tools/regression/unitframes_env.lua").New()
local function Write(key, value) K.Options.Write("UnitFrames", key, value) end

Write("focus.auraPosition", "CENTER")
local lane = ns.Auras.TimerRoom("focus")
Write("focus.auraFilter", "both")
assert(lane > 0 and ns.Auras.TimerRoom("focus") == lane, "a centred focus on Debuffs and buffs keeps its timer lane; limit the two-group badge rule in Auras.lua TimerBelow to the target")

K.Options.Write("HudStyle", "style", "medallions")
Write("player.medallionsAuraFilter", "both")
assert(ns.Settings.Value("player", "auraRows") == 2, "the player's Medallions rows on Debuffs and buffs keep two of each kind; limit the one-row default in Settings.lua Value to the target")
Write("target.auraFilter", "both")
assert(ns.Settings.Value("target", "auraRows") == 1, "the target's Medallions rows on Debuffs and buffs keep one of each kind")
print("ok: the Debuffs and buffs room rules change only the target")
