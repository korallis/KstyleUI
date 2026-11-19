-- options_order_fixture.lua: sample modules for the generic ordered Options row, shared by its tests and render.
return function(K, count)
	local entries, options = {}, {}
	local names = { "Micro menu", "Clock", "Gold", "Durability", "System" }
	for i = 1, count or #names do
		local id = "module" .. i
		entries[i] = { id = id, shown = i ~= 3, zone = i == 1 and "left" or i == 2 and "centre" or "right" }
		options[i] = { value = id, label = names[i] or "Module " .. i }
	end
	options[2].rows = {
		{ type = "toggle", key = "clock24", label = "24-hour clock", help = "Use a 24-hour clock.", showWhen = function(db)
			for _, entry in ipairs(db.modules) do if entry.id == "module2" then return entry.shown end end
		end },
	}
	K.Store.RegisterDefaults("DataBars", { modules = entries, clock24 = true })
	K.Options.Register("DataBars", {
		{ type = "header", label = "Modules" },
		{ type = "order", key = "modules", label = "Modules", help = "Choose, place and order the modules.", options = options },
	})
end
