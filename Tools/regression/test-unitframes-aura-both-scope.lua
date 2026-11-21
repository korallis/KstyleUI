-- test-unitframes-aura-both-scope.lua: the target's Debuffs and buffs room rules stay on the target: a centred focus keeps its timer lane and the player's Medallions rows keep two of each kind; the settings preview shows the target's rows of both kinds.
local env, K, ns = dofile("Tools/regression/unitframes_env.lua").New()
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

Write("edit", "target")
env.RunTimers()
local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
pane:SetSize(280, 560)
pane:SetPoint("CENTER")
local preview = K.Options.Preview("UnitFrames")(pane)
preview:Refresh()
local tops, rows = {}, 0
for _, tile in ipairs(preview.auraIcons.target) do
	if tile:IsShown() and not tops[tile:GetTop()] then tops[tile:GetTop()], rows = true, rows + 1 end
end
assert(preview.auraCount == 12 and rows == 2, string.format("the preview shows %d tiles on %d rows, not a row of six debuffs and a row of six buffs; count both groups in Preview.lua PaintAuras", preview.auraCount, rows))
print("ok: the Debuffs and buffs room rules change only the target, and the preview shows both rows")
