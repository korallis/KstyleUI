-- test-tooltips-minimap-anchor.lua: minimap owners, child buttons and native blip tooltips stay beside the map in every position mode.
local T = dofile("Tools/regression/tooltips_env.lua")

local env, K, ns = T.New({ width = 1920, height = 1080, setup = function(game)
	game.Minimap = game.CreateFrame("Frame", "Minimap", game.UIParent)
	game.Minimap:SetSize(200, 200)
	game.Minimap:SetPoint("TOPRIGHT", game.UIParent, "TOPRIGHT", -20, -20)
	game.MinimapCluster = game.CreateFrame("Frame", nil, game.UIParent)
	game.GameTooltip.SetAnchorType = function(self, anchor) self._anchor = { anchor } end
	game.GameTooltip.SetMinimapMouseover = function(self) self:AddLine("Innkeeper Pala") end
end })
assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), tostring(env._errors[1]))
local map, tip = env.Minimap, env.GameTooltip
local child = env.CreateFrame("Button", nil, env.CreateFrame("Frame", nil, map))
tip:SetSize(240, 180)

local function Beside(right, why)
	local point, relative, relativePoint, x = tip:GetPoint(1)
	assert(relative == map and point == (right and "TOPRIGHT" or "TOPLEFT") and relativePoint == (right and "TOPLEFT" or "TOPRIGHT"), why or "minimap tooltips open on the side facing the screen centre")
	assert(right and x < 0 or not right and x > 0, "the tooltip has a gap from the map")
	assert(tip._anchor[1] == "ANCHOR_NONE", "minimap tooltips stop following the cursor")
end

for _, mode in ipairs({ "fixed", "cursor", "cursorOutOfCombat" }) do
	K.Options.Write("Tooltips", "anchor", mode)
	for _, combat in ipairs({ false, true }) do
		env.SetCombat(combat)
		env.GameTooltip_SetDefaultAnchor(tip, child)
		Beside(true)
		tip:SetOwner(child, "ANCHOR_CURSOR_RIGHT")
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", child, "BOTTOMLEFT")
		tip:AddLine("Quest objectives")
		T.BlizzardShow(tip, true)
		Beside(true, "restore minimap placement on OnShow after an addon button replaces the tooltip's points")
		assert(tip:GetOwner() == child and tip:GetLeftLine(1):GetText() == "Quest objectives", "moving a shown tooltip preserves its owner and content")
		tip:SetOwner(env.UIParent, "ANCHOR_CURSOR")
		tip:SetMinimapMouseover()
		Beside(true)
		assert(tip:GetLeftLine(1):GetText() == "Innkeeper Pala", "the native blip path keeps its content even though Blizzard uses UIParent as owner")
	end
end
env.SetCombat(false)

map:ClearAllPoints()
map:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 20, -20)
env.GameTooltip_SetDefaultAnchor(tip, map)
Beside(false)

local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
K.Layout.Register(holder, "minimap.main", { anchor = "TOPLEFT", x = 20, y = -20 }, { label = "Minimap" })
for _, parent in ipairs({ holder, env.MinimapCluster }) do
	tip:SetOwner(env.CreateFrame("Button", nil, parent), "ANCHOR_NONE")
	T.BlizzardShow(tip, true)
	Beside(false)
end

K.Options.Write("Tooltips", "minimapAnchor", false)
for _, mode in ipairs({ "fixed", "cursor", "cursorOutOfCombat" }) do
	K.Options.Write("Tooltips", "anchor", mode)
	env.GameTooltip_SetDefaultAnchor(tip, child)
	if mode == "fixed" then
		assert(select(2, tip:GetPoint(1)) == ns.Anchor.Frame(), "turning off minimap placement restores the placed anchor")
	else
		assert(tip._anchor[1] == "ANCHOR_CURSOR_RIGHT", "turning off minimap placement restores the cursor choice")
	end
end
K.Options.Write("Tooltips", "minimapAnchor", true)
K.Modules.Disable("Tooltips")
tip:SetOwner(child, "ANCHOR_CURSOR")
T.BlizzardShow(tip, true)
assert(tip._anchor[1] == "ANCHOR_CURSOR", "disabled Tooltips leaves minimap tooltips alone")
assert(#env._errors == 0, tostring(env._errors[1]))
print("tooltips minimap anchor ok")
