-- test-meters-card-fit.lua: meter glass fits its rows with a three-row minimum instead of keeping an empty reserved slot.
local M = dofile("Tools/regression/meters_env.lua")
local env, K, ns = M.New()
M.Enable(env, K)
local list = ns.Damage.list
list.holder:SetHeight(800)
for _, count in ipairs({ 1, 3, 5, 20 }) do
	for i = 1, count do list:SetRow(i, "Player " .. i, "MAGE", "friendly", i, 20, tostring(i), "5%") end
	list:Finish(count)
	local rows = math.max(3, count)
	local expected = K.Widgets.Snap(list.panel, list:Top()) + rows * (list.rowHeight + list.spacing) - list.spacing + list.pad
	assert(math.abs(list.panel:GetHeight() - expected) <= K.Scale.Pixel(1), "fit the meter card to its rows plus padding, with at least three rows")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("meter card fit ok")
