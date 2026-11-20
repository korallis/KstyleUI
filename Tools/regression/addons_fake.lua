-- addons_fake.lua: the client addon list, including an enabled load-on-demand addon and an unknown addon.
local Fake = {}

Fake.LIST = {
	{ name = "RXPGuides", title = "RestedXP", loaded = true, enabled = 2 },
	{ name = "Questie", loaded = true, enabled = 2 },
	{ name = "Details", loaded = true, enabled = 2 },
	{ name = "Bartender4", title = "Bartender", loaded = true, enabled = 2 },
	{ name = "FishingBuddy", title = "Fishing Buddy", loaded = false, enabled = 2 },
	{ name = "DisabledAddon", loaded = false, enabled = 0 },
	{ name = "Blizzard_CharacterUI", loaded = true, enabled = 2 },
	{ name = "KstyleUI_Skins", loaded = true, enabled = 2 },
}

function Fake.Install(env, list)
	list = list or Fake.LIST
	env.UnitGUID = function() return "Player-1-1234" end
	local byName = {}
	for _, entry in ipairs(list) do byName[entry.name] = entry end
	local api = env.C_AddOns or {}
	env.C_AddOns = api
	api.GetNumAddOns = function() return #list end
	api.GetAddOnInfo = function(index)
		local entry = list[index] or byName[index]
		if entry then return entry.name, entry.title or entry.name, "", true, "", "INSECURE" end
	end
	api.GetAddOnEnableState = function(name, character)
		assert(character == env.UnitGUID("player"), "detect addons enabled for the current character")
		return byName[name] and byName[name].enabled or 0
	end
	api.IsAddOnLoaded = function(name) return byName[name] and byName[name].loaded == true or false end
	return list
end

return Fake
