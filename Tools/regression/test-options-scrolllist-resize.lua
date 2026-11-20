-- test-options-scrolllist-resize.lua: pending client layout must not refresh a new Options page against the previous page's row tops.
local O = dofile("Tools/regression/options_env.lua")
local W = O.W
local env, K, ns = O.New({ before = function(_, kit)
	for module, count in pairs({ UnitFrames = 4, GroupFrames = 115 }) do
		local schema, defaults = {}, {}
		for i = 1, count do
			local key = "row" .. i
			defaults[key] = true
			schema[i] = { type = "toggle", key = key, label = "Row " .. i, help = "Toggle this test row." }
		end
		kit.Modules.Register(W.CoreEnv.Module(module, { defaults = defaults }))
		kit.Options.Register(module, schema)
	end
end })
K.Options.Open("UnitFrames")
W.Settle(env)
local parts = ns.Window.Parts()
local list = parts.content
assert(#list.items == 6 and #list.tops == 7, "start with the reported seven row tops")
local events = 0
local refresh = list.Refresh
list.Refresh = function(self, force)
	assert(#self.tops == #self.items + 1, "defer Refresh until the new page's row tops are complete")
	return refresh(self, force)
end
list:HookScript("OnSizeChanged", function(self)
	events = events + 1
	assert(#self.items == 117 and #self.tops == 7, "resize resolves inside Measure before the new row tops exist")
end)
env.QueueSizeChanged(list)
for _, row in ipairs(parts.rail.rows) do
	if row.page and row.page.id == "GroupFrames" then
		W.Click(row)
		break
	end
end
assert(#env._errors == 0 and K.ErrorCount() == 0, "page switch raised: " .. table.concat(env._errors, "\n"))
assert(events == 1, "GetWidth delivers the pending resize synchronously during the rail click")
assert(ns.Window.State().page == "GroupFrames" and #list.items == 117 and #list.tops == 118, "the long page is fully measured")
list:ScrollToIndex(117, true)
assert(list:GetOffset() == list:GetMaxOffset(), "the last row is reachable after switching pages")
K.Options.Open("UnitFrames")
assert(#list.items == 6 and #list.tops == 7 and list:GetOffset() == 0, "switching back restores the short page")
print("options scrolllist pending resize ok")
