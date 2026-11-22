-- test-consumables-third.lua: enabling Medallions bar 3 clears the occupied consumables grid at every owner size.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Scene = dofile("Tools/render/scene.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = AB.New({ width = screen[1], height = screen[2] })
	AB.Enable(env, K)
	env.C_Container = {
		GetContainerNumSlots = function(bag) return bag == 0 and 12 or 0 end,
		GetContainerItemInfo = function(_, slot) return { itemID = ns.Consumables.kinds[slot].ids[1], stackCount = 1, iconFileID = 134829 } end,
	}
	env.FireEvent("BAG_UPDATE_DELAYED")
	for _, arrangement in ipairs({ "centred", "spread" }) do
		K.Options.Write("Layout", "arrangement", arrangement)
		K.Options.Write("ActionBars", "bar3.enabled", true)
		env.RunTimers()
		assert(#ns.Consumables.selected == 12 and ns.Consumables.header:IsShown(), "exercise occupied consumables")
		local a, b = { Scene.Rect(env, ns.Consumables.header) }, { Scene.Rect(env, ns.bars.bar3.holder) }
		assert(a[1] >= b[1] + b[3] or b[1] >= a[1] + a[3] or a[2] >= b[2] + b[4] or b[2] >= a[2] + a[4], screen[1] .. " " .. arrangement .. ": bar 3 must clear occupied consumables")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end
print("consumables third bar ok: occupied grid clears Medallions bar 3 at four sizes and both arrangements")
