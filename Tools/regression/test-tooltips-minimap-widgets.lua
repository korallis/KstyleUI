-- test-tooltips-minimap-widgets.lua: the real minimap column and secure overlay use the same map-clear placement as GameTooltip.
local M = dofile("Tools/regression/minimap_env.lua")
local T = dofile("Tools/regression/tooltips_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local env, K, mapNS = M.New({ enabled = true, width = 1920, height = 1080, setup = function(game)
	T.Blizzard(game)
	game._mail.new = true
	game.QueueStatusButton:Show()
end })
M.Settle(env)
M.Holder(K)._mouseOver = true
M.W.Enter(env.Minimap)
M.Settle(env)
local tip = K.Widgets.Tooltip()
Load(T.Files(), env)
assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), tostring(env._errors[1]))
local map, buttons = env.Minimap, mapNS.Map.column.buttons

local function Beside(right)
	local point, relative, relativePoint, x = tip:GetPoint(1)
	assert(relative == map and point == (right and "TOPRIGHT" or "TOPLEFT") and relativePoint == (right and "TOPLEFT" or "TOPRIGHT"), "custom minimap tooltips must use the shared map-clear placement")
	assert(right and x < 0 or not right and x > 0, "the custom tooltip keeps a gap from the map")
	local ts, ms = tip:GetEffectiveScale(), map:GetEffectiveScale()
	assert(right and tip:GetRight() * ts < map:GetLeft() * ms or not right and tip:GetLeft() * ts > map:GetRight() * ms, "the tooltip sits entirely outside the minimap")
	assert(tip:IsShown() and #tip.used > 0, "the real widget content stays visible")
end

for _, mode in ipairs({ "fixed", "cursor", "cursorOutOfCombat" }) do
	K.Options.Write("Tooltips", "anchor", mode)
	for _, combat in ipairs({ false, true }) do
		env.SetCombat(combat)
		for _, name in ipairs({ "tracking", "mail", "calendar", "queue", "drawer" }) do
			local button = buttons[name]
			assert(button:IsVisible(), "the fixture must show " .. name .. " before hovering it")
			M.W.Enter(button)
			M.Settle(env)
			assert(tip:IsOwned(button), "placement preserves the real column tooltip owner")
			Beside(true)
			M.W.Leave(button)
			M.Settle(env)
		end
	end
end
env.SetCombat(false)
local other = env.CreateFrame("Button", nil, K.Scale.Root())
other:SetPoint("CENTER")
tip:SetOwner(other, "ANCHOR_RIGHT")
tip:AddLine("Another control")
tip:Show()
assert(select(2, tip:GetPoint(1)) == other, "unrelated kit tooltips keep their original placement")
M.W.Enter(buttons.tracking)
M.W.Enter(mapNS.SecureClick.overlay)
M.Settle(env)
Beside(true)
M.W.Leave(mapNS.SecureClick.overlay)
M.Settle(env)

assert(K.Layout.Set("minimap.main", "anchor", "TOPLEFT"))
assert(K.Layout.Set("minimap.main", "x", 20))
M.W.Enter(buttons.calendar)
M.Settle(env)
Beside(false)
M.W.Leave(buttons.calendar)
M.Settle(env)

local function PreviousPlacement()
	M.W.Enter(buttons.tracking)
	M.Settle(env)
	assert(select(2, tip:GetPoint(1)) == buttons.tracking, "turning the fix off restores the column's original anchor")
	M.W.Leave(buttons.tracking)
	M.Settle(env)
end
K.Options.Write("Tooltips", "minimapAnchor", false)
PreviousPlacement()
K.Options.Write("Tooltips", "minimapAnchor", true)
K.Modules.Disable("Tooltips")
PreviousPlacement()
assert(K.Modules.Enable("Tooltips"))
M.W.Enter(buttons.tracking)
M.Settle(env)
Beside(false)
assert(#env._errors == 0, tostring(env._errors[1]))
print("tooltips minimap widgets ok")
