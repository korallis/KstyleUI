-- Features.lua: the on/off default of every module and account switch, in one strict table.
local _, ns = ...

local Features = {
	modules = {
		Options = false,
		UnitFrames = false,
		GroupFrames = false,
		ActionBars = false,
		Cooldowns = false,
		Auras = false,
		Nameplates = false,
		CombatText = false,
		Minimap = false,
		Chat = false,
		Bags = false,
		Tooltips = false,
		DataBars = false,
		Meters = false,
		Skins = false,
	},
	account = {
		setupSeen = false,
	},
}

ns.Features = Features

function Features.Get(store, key)
	local switches = Features[store]
	if type(switches) ~= "table" then
		error("KstyleUI.Features.Get: unknown store " .. tostring(store), 2)
	end
	local value = switches[key]
	if type(value) ~= "boolean" then
		error("KstyleUI.Features.Get: unknown key " .. tostring(key) .. " in store " .. tostring(store), 2)
	end
	return value
end
