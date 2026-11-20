-- test-cooldowns-bar-layout.lua: item acquisition leaves the native grid's one layout intact; addon refresh and viewer scale each reflow once.
local C = dofile("Tools/regression/cooldowns_env.lua")

for _, count in ipairs({ 2, 4, 12 }) do
	local env, K, ns = C.New({ setup = C.Game })
	local viewer = env._viewers.BuffBarCooldownViewer
	for id = 3, count do C.Item(env, viewer, id) end
	C.Enable(env, K)
	local layouts, layout = 0, viewer.Layout
	viewer.Layout = function(self)
		layouts = layouts + 1
		return layout(self)
	end
	for _, item in ipairs(viewer._items) do
		item:SetScale(0.7)
		viewer:OnAcquireItemFrame(item)
		assert(item:GetHeight() < 30, "the cost test must resize every acquired tracked bar")
	end
	viewer:Layout()
	assert(layouts == 1, "leave acquisition relayout to Blizzard's RefreshLayout; never run a grid layout per tracked item")
	layouts = 0
	ns.Reskin.Refresh()
	assert(layouts == 1, "batch the tracked-bar grid layout once per Reskin.Refresh")
	layouts = 0
	viewer:SetScale(1.3)
	assert(layouts == 1, "batch the tracked-bar grid layout once per viewer scale change")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "layout cost must exercise successful restyling")
end
print("cooldowns bar layout cost ok")
