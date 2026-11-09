-- test-qol.lua: KstyleUI_QoL registers its switch, defaults and settings page, links to Bags for junk, appears in the setup and the settings window, and migration 5 turns it on for profiles that finished the setup.
local Q = dofile("Tools/regression/qol_env.lua")

local function Row(K, key)
	for _, row in ipairs(K.Options.Get("QoL")) do
		if row.key == key then
			return row
		end
	end
end

-- Defaults: the owner's picks. Loot, repair and the camera are on; quests, guild funds and quiet errors wait to be asked.
do
	local _, K = Q.New()
	assert(K.Features.Get("modules", "QoL") == false, "the module switch follows Features, off in code")
	local defaults = K.Store.Defaults("QoL")
	assert(defaults, "QoL registers its defaults")
	assert(defaults.fastLoot == true, "faster auto loot is on by default")
	assert(defaults.autoRepair == true, "auto repair is on by default")
	assert(defaults.guildRepair == false, "guild funds wait to be asked for")
	assert(defaults.autoQuests == false, "quest automation is off by default")
	assert(defaults.questModifier == "SHIFT", "Shift pauses quest automation by default")
	assert(defaults.maxCamera == true, "max camera distance is on by default")
	assert(defaults.quietErrors == false, "quiet error text is off by default")

	for _, key in ipairs({ "enabled", "fastLoot", "autoRepair", "guildRepair", "autoQuests", "maxCamera", "quietErrors" }) do
		local row = Row(K, key)
		assert(row and row.type == "toggle", "the settings page has a toggle for " .. key)
		assert(type(row.help) == "string" and row.help ~= "", key .. " has help text")
	end
	local modifier = Row(K, "questModifier")
	assert(modifier and modifier.type == "dropdown", "the pause key is a dropdown")
	local values = {}
	for _, option in ipairs(modifier.options) do
		values[option.value] = true
	end
	assert(values.SHIFT and values.CTRL and values.ALT, "the pause key is Shift, Ctrl or Alt")

	local junk
	for _, row in ipairs(K.Options.Get("QoL")) do
		if row.type == "note" and row.label:find("Bags", 1, true) then
			junk = row
		end
	end
	assert(junk, "a note on the page sends junk selling to the Bags page instead of a second switch")
	assert(not Row(K, "sellJunk") and not Row(K, "autoSellJunk"), "QoL has no junk switch of its own")
end

-- Selling junk is one feature, in Bags, and it is on by default.
do
	local B = dofile("Tools/regression/bags_env.lua")
	local _, K = B.New({ enable = false })
	assert(K.Store.Defaults("Bags").autoSellJunk == true, "Bags sells junk by itself by default")
end

-- The setup offers QoL with the other modules, and the settings window has a page for it.
do
	local _, K = Q.New()
	local found
	for _, entry in ipairs(K.Setup.PICKER) do
		if entry.name == "QoL" then
			found = entry
		end
	end
	assert(found and found.label ~= "" and found.note ~= "", "the setup's module picker lists QoL")
	assert(K.Setup.NewChoice().modules.QoL == true, "a new setup turns QoL on")
end

do
	local pages = assert(io.open("KstyleUI_Options/Pages.lua", "rb")):read("*a")
	local order = pages:match("local MODULE_ORDER = (%b{})")
	assert(order and order:find('"QoL"', 1, true), "the settings window orders the QoL page")
	assert(pages:find('QoL = L%["Quality of Life"%]'), "the QoL page has a label")
end

-- Migration 5: a profile that finished the setup gets QoL on; an untouched profile and a player's own choice stay.
do
	local saved = {
		version = 4,
		profiles = {
			Default = { UnitFrames = { enabled = true }, Bags = { enabled = true } },
			Fresh = {},
			Chosen = { UnitFrames = { enabled = true }, QoL = { fastLoot = false } },
			Off = { UnitFrames = { enabled = true }, QoL = { enabled = false } },
		},
		characters = {}, layouts = {}, account = {},
	}
	local env, K = Q.New({ saved = saved })
	local data = env.KstyleUIDB
	assert(data.version >= 5, "saved data migrates to version 5, got " .. tostring(data.version))
	assert(data.profiles.Default.QoL and data.profiles.Default.QoL.enabled == true, "a set-up profile gets QoL on")
	assert(data.profiles.Fresh.QoL == nil, "a profile that never ran the setup stays as it is")
	assert(data.profiles.Chosen.QoL.enabled == true and data.profiles.Chosen.QoL.fastLoot == false, "a QoL table gets the switch and keeps the player's settings")
	assert(data.profiles.Off.QoL.enabled == false, "a player who turned QoL off keeps it off")
	assert(K.Modules.IsEnabled("QoL"), "the active profile runs QoL after the migration")
end

-- Enable and Disable run cleanly, and the devtest check reports.
do
	local env, K = Q.New()
	Q.Enable(env, K)
	assert(K.Modules.IsRunning("QoL"), "the module starts")
	Q.Disable(env, K)
	assert(not K.Modules.IsRunning("QoL"), "the module stops")
	assert(#env._errors == 0, "no errors while starting and stopping: " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "no handler raised")
end

print("qol ok")
