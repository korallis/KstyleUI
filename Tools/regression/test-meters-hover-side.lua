-- test-meters-hover-side.lua: a meter card's tooltips open toward the middle of the screen, so the spell split of a card on the right rail sits beside the card instead of past the screen's edge, where the game would clamp it back over the card's own rows.
local M = dofile("Tools/regression/meters_env.lua")

local env, K, ns = M.New({ game = function(e)
	e._group = { raid = false, size = 2 }
end })
env._session = {
	combatSources = {
		{ name = "Kragar", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = true, deathRecapID = 0, deathTimeSeconds = 0, sourceGUID = "Player-Kragar" },
	},
	maxAmount = 2840, totalAmount = 2840, durationSeconds = 30,
}
M.Enable(env, K)
M.Tick(env)
local list = ns.Damage.list
local row = list.rows[1].frame
local panel = list.panel
local root = K.Scale.Root()

local function Hover(where)
	panel:ClearAllPoints()
	panel:SetSize(318, 190)
	panel:SetPoint(where, root, where, where == "RIGHT" and -28 or 28, 0)
	row._scripts.OnEnter(row)
	env.RunTimers()
	local tip = K.Widgets.Tooltip()
	assert(tip:IsOwned(row), "the hovered row owns the tooltip")
	local anchor = tip.anchor
	row._scripts.OnLeave(row)
	env.RunTimers()
	return anchor
end

assert(Hover("RIGHT") == "LEFT", "a card on the right rail opens its tooltip to its left, toward the screen's middle")
assert(Hover("LEFT") == "RIGHT", "a card on the left opens it to its right")

local tip = K.Widgets.Tooltip()
panel:ClearAllPoints()
panel:SetSize(318, 190)
panel:SetPoint("RIGHT", root, "RIGHT", -28, 0)
list.panel._scripts.OnEnter(list.panel)
env.RunTimers()
if tip:IsOwned(list.panel) then
	assert(tip.anchor == "LEFT", "the card's own tooltip opens inward too")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("test-meters-hover-side: ok")
