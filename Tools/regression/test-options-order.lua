-- test-options-order.lua: ordered modules persist, filter, show children and reuse the virtual list's controls at every screen size.
local O = dofile("Tools/regression/options_env.lua")
local Fixture = dofile("Tools/regression/options_order_fixture.lua")
local Scene = dofile("Tools/render/scene.lua")
local W, CoreEnv = O.W, O.W.CoreEnv

local function settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function rowFor(ns, id)
	local list = ns.Window.Parts().content
	local _, index = O.Find(ns.Window.State().items, function(item) return item.entry == id end)
	assert(index, "entry is in the list: " .. id)
	list:ScrollToIndex(index, true, "TOP")
	return assert(O.Find(list.rows, function(row) return row:IsShown() and row.item.entry == id end))
end

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local env, K, ns = O.New({ width = screen[1], height = screen[2], before = function(_, K) Fixture(K, 60) end })
	assert(K.Options.Open("DataBars"))
	settle(env)
	local list = ns.Window.Parts().content
	local moduleRow = assert(O.Find(list.rows, function(row) return row:IsShown() and row.item.key == "enabled" end))
	local toggleX = Scene.Rect(env, moduleRow.controls.toggle)
	local first = rowFor(ns, "module1")
	local control = first.controls.order
	assert(control and control.toggle:GetValue() and control.zone:GetValue() == "left")
	assert(Scene.Rect(env, control.toggle) == toggleX, "entry and module toggles share one x position")
	assert(first:GetHeight() == ns.Rows.HEIGHT, "an entry keeps the standard 48-unit row")
	assert(not control.up:IsEnabled(), "up is disabled at the start")
	local events = 0
	K.Callbacks.Register("SettingChanged", "OrderTest", function(_, module, key)
		if module == "DataBars" and key == "modules" then events = events + 1 end
	end)
	first.item.move(-1)
	assert(events == 0, "up at the start does not write")
	W.Click(control.down)
	settle(env)
	assert(K.Options.Read("DataBars", "modules")[2].id == "module1", "down persists the new order")
	local clock = rowFor(ns, "module2")
	clock.controls.order.zone:SetValue("right")
	W.Click(clock.controls.order.toggle)
	settle(env)
	assert(not O.Find(ns.Window.State().items, function(item) return item.key == "clock24" end), "off hides children")
	clock = rowFor(ns, "module2")
	W.Click(clock.controls.order.toggle)
	settle(env)
	local _, clockIndex = O.Find(ns.Window.State().items, function(item) return item.entry == "module2" end)
	assert(ns.Window.State().items[clockIndex + 1].key == "clock24", "on shows the child directly under its reordered entry")
	local schema = K.Options.Get("DataBars")
	schema[2].options[2].rows[1].showWhen = function(db) return db.clock24 end
	K.Options.Write("DataBars", "clock24", false)
	settle(env)
	assert(not O.Find(ns.Window.State().items, function(item) return item.key == "clock24" end), "a child's own showWhen still filters it")
	K.Options.Write("DataBars", "clock24", true)
	settle(env)
	local hits = ns.Model.Search(ns.Pages.List(), "clock")
	assert(O.Find(hits, function(item) return item.entry == "module2" end), "search finds entry names")
	assert(O.Find(ns.Model.Search(ns.Pages.List(), "gold"), function(item) return item.entry == "module3" end), "search finds switched-off entries")
	local known = {}
	for _, row in ipairs(list.rows) do known[row] = true end
	local last = rowFor(ns, "module60")
	assert(known[last], "scrolling reuses a row")
	assert(last.controls.order ~= nil and last.controls.order.zone:GetValue() == "right", "the recycled control binds the new entry")
	assert(not last.controls.order.down:IsEnabled(), "down is disabled at the end")
	local before = events
	last.item.move(1)
	assert(events == before, "down at the end does not write")
	local disabled = last.item
	disabled.disabled = true
	ns.Rows.Update(last, disabled, nil, list)
	for _, name in ipairs({ "toggle", "zone", "up", "down" }) do
		assert(not last.controls.order[name]:IsEnabled(), "disableWhen disables " .. name)
	end
	disabled.disabled = nil
	ns.Rows.Update(last, disabled, nil, list)
	W.Click(last.controls.order.toggle)
	settle(env)
	assert(K.Options.Read("DataBars", "modules")[60].shown == false, "a recycled toggle writes its current entry")
	assert(K.Options.Read("DataBars", "modules")[1].shown == true, "a recycled toggle leaves the old entry alone")
	assert(#list.rows < 30, "the 60-entry list stays virtualised")
	first = rowFor(ns, "module2")
	local controlBox = { Scene.Rect(env, first.controls.order) }
	local labelBox = { Scene.Rect(env, first.label) }
	assert(labelBox[1] + labelBox[3] <= controlBox[1], "entry text stays outside its controls")
	for _, child in ipairs({ "toggle", "zone", "up", "down" }) do
		local x, y, w, h = Scene.Rect(env, first.controls.order[child])
		assert(x >= controlBox[1] - 0.01 and x + w <= controlBox[1] + controlBox[3] + 0.01, child .. " fits the control group")
		assert(y >= controlBox[2] - 0.01 and y + h <= controlBox[2] + controlBox[4] + 0.01, child .. " fits the row height")
	end
	env.FireEvent("PLAYER_LOGOUT")
	local _, restored = O.New({ saved = env.KstyleUIDB, before = function(_, restoredK) Fixture(restoredK, 60) end })
	local saved = restored.Options.Read("DataBars", "modules")
	assert(saved[1].id == "module2" and saved[1].zone == "right" and saved[1].shown == true, "order, zone and shown survive logout and reload")
	assert(saved[60].shown == false, "the last toggle survives reload")
	first:GetScript("OnMouseUp")(first, "RightButton")
	settle(env)
	assert(K.Options.Read("DataBars", "modules")[1].id == "module1", "right-click resets the entire ordered setting")
	assert(ns.Model.ResetSchema("DataBars", K.Options.Get("DataBars")) == 2, "reset includes child settings")
	assert(K.Options.Read("DataBars", "modules")[1].id == "module1", "reset restores default order")
	CoreEnv.Raises(function() K.Options.Write("DataBars", "modules", { saved[1], saved[1] }) end, "every option once", "incomplete order")
	local duplicate = ns.Model.Copy(saved)
	duplicate[2] = duplicate[1]
	CoreEnv.Raises(function() K.Options.Write("DataBars", "modules", duplicate) end, "unique option id", "duplicate id")
	local invalid = ns.Model.Copy(saved)
	invalid[1].shown = "yes"
	CoreEnv.Raises(function() K.Options.Write("DataBars", "modules", invalid) end, "boolean shown", "invalid shown flag")
end

do
	local _, K = CoreEnv.New()
	K.Store.RegisterDefaults("DataBars", { modules = { {id = "clock", shown = true, zone = "middle"} } })
	CoreEnv.Raises(function()
		K.Options.Register("DataBars", { { type = "order", key = "modules", label = "Modules", help = "Order modules.", options = { {value = "clock", label = "Clock"} } } })
	end, "zone left, centre or right", "invalid default zone")
end

print("options order: ok")
