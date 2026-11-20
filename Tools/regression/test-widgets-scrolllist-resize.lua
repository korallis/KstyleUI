-- test-widgets-scrolllist-resize.lua: pending size changes cannot refresh partially measured rows, and the binary search tolerates incomplete row tops.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local measuring, reenter = false, false
local list = K.Widgets.ScrollList(nil, {
	width = 200, height = 120, rowHeight = 24,
	heightOf = function(_, index, self)
		if reenter and index == 2 then
			measuring = true
			env.QueueSizeChanged(self)
			self:GetHeight()
			measuring = false
		end
		return index % 2 == 0 and 48 or 24
	end,
})
local items = {}
for i = 1, 117 do items[i] = "Item " .. i end
list:SetData(items)
local refresh = list.Refresh
list.Refresh = function(self, force)
	assert(not measuring, "OnSizeChanged must wait until Measure finishes, including during Restyle")
	return refresh(self, force)
end
reenter = true
list:Restyle()
reenter = false
assert(#list.tops == 118 and list.rows[2]:GetHeight() == 48, "variable row heights survive the deferred resize")
for i = #list.tops, 8, -1 do list.tops[i] = nil end
list:Refresh(true)
assert(#env._errors == 0, tostring(env._errors[1]))
print("widgets scrolllist pending resize ok")
