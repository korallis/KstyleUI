-- test-nameplates-presets.lua: one dropdown applies a whole nameplate preset; a hand-changed setting turns it to Custom; Lumen puts the defaults back.
local N = dofile("Tools/regression/nameplates_env.lua")

local function lookup(root, key)
	local node = root
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

-- Every preset names real settings with allowed values, and the page offers each one --------------------

do
	local _, K, ns = N.New({ enable = false })
	local Presets = ns.Presets
	local names = {}
	for _, option in ipairs(Presets.LIST) do
		names[option.value] = true
		assert(type(option.label) == "string" and option.label ~= "", option.value .. " has a label")
	end
	for _, name in ipairs({ "lumen", "compact", "tank", "healer", "custom" }) do
		assert(names[name], "the presets offer " .. name)
	end
	for name, values in pairs(Presets.VALUES) do
		assert(names[name], name .. " is on the list")
		local count = 0
		for key, value in pairs(values) do
			count = count + 1
			local default = lookup(ns.Settings.defaults, key)
			assert(default ~= nil, name .. " names a setting that exists: " .. key)
			assert(type(value) == type(default), name .. "." .. key .. " has the default's type")
			local row = ns.Settings.Row(key)
			assert(row, name .. "." .. key .. " is on the settings page")
			if row.type == "dropdown" then
				local found = false
				for _, option in ipairs(row.options) do
					found = found or option.value == value
				end
				assert(found, name .. "." .. key .. " picks one of the row's options")
			elseif row.type == "slider" then
				assert(value >= row.min and value <= row.max, name .. "." .. key .. " is in the slider's range")
			end
		end
		assert(count > 0 or name == "lumen", name .. " changes something")
	end
	local row = ns.Settings.Row("preset")
	assert(row and row.type == "dropdown", "the preset is a dropdown row")
	assert(K.Options.Get("Nameplates")[2] == row, "and the first row on the page, under its header")
	assert(ns.Settings.Get("preset") == "lumen", "a fresh profile is the Lumen preset")
end

-- Applying a preset writes its settings; a change by hand turns the preset to Custom ----------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local Presets = ns.Presets
	K.Options.Write("Nameplates", "preset", "compact")
	for key, value in pairs(Presets.VALUES.compact) do
		local got = ns.Settings.Get(key)
		if type(value) == "table" then
			assert(got.r == value.r and got.g == value.g and got.b == value.b, "compact sets " .. key)
		else
			assert(got == value, "compact sets " .. key .. " to " .. tostring(value) .. ", got " .. tostring(got))
		end
	end
	assert(ns.Settings.Get("preset") == "compact", "the preset stays Compact after it applies")
	assert(select(2, plate.name:GetFont()) == Presets.VALUES.compact["name.size"], "the live plate restyled with the preset's name size")

	K.Options.Write("Nameplates", "name.size", 17)
	assert(ns.Settings.Get("preset") == "custom", "a setting changed by hand makes the preset Custom")
	assert(ns.Settings.Get("name.size") == 17, "and keeps the change")

	K.Options.Write("Nameplates", "preset", "custom")
	assert(ns.Settings.Get("name.size") == 17, "choosing Custom changes nothing")

	K.Options.Write("Nameplates", "preset", "lumen")
	for key in pairs(Presets.VALUES.compact) do
		local got, default = ns.Settings.Get(key), lookup(ns.Settings.defaults, key)
		if type(default) == "table" then
			assert(got.r == default.r and got.g == default.g and got.b == default.b, "Lumen restores " .. key)
		else
			assert(got == default, "Lumen restores " .. key .. ", got " .. tostring(got))
		end
	end
	assert(ns.Settings.Get("name.size") == 14, "Lumen puts the hand-changed name size back too")
	assert(ns.Settings.Get("preset") == "lumen", "and reads as Lumen")

	K.Options.Write("Nameplates", "preset", "tank")
	assert(ns.Settings.Get("threat.display") == "health" and ns.Settings.Get("threat.role") == "tank", "the tank preset colours bars by threat for a tank")
	assert(ns.Settings.Get("threat.groupOnly") == false, "and shows threat alone too")
	K.Options.Write("Nameplates", "preset", "healer")
	assert(ns.Settings.Get("friendly.nameOnly") == false and ns.Settings.Get("healthText.show") == true, "the healer preset keeps friendly bars with health text")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A preset chosen while the module is off applies all the same, so Enable shows it -------------------------

do
	local env, K, ns = N.New({ enable = false })
	K.Options.Write("Nameplates", "preset", "compact")
	assert(ns.Settings.Get("name.size") == ns.Presets.VALUES.compact["name.size"], "the preset applies while the module is off")
	K.Modules.Enable("Nameplates")
	env.RunTimers()
	N.Add(env, "nameplate1")
	assert(select(2, ns.Plates.Get("nameplate1").name:GetFont()) == ns.Presets.VALUES.compact["name.size"], "and the plates come up in it")
	assert(ns.Settings.Get("preset") == "compact", "the dropdown still reads Compact")
end

print("nameplates presets ok")
