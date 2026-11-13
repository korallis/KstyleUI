-- group_looks.lua: group frame looks a test can boot with by name. PARTY_CARD is KSTY-31's Lumen party card (the
-- card on, the role ring in the portrait slot, the class and level caption, the class pill and no power bar or health
-- number), which KSTY-57's bare lanes replaced as the default and which stays a choice in the settings.
local Looks = {}

Looks.PARTY_CARD = {
	party = {
		card = true, portrait = true, roleRing = true, classLine = true, power = false, powerHeight = 4,
		width = 278, height = 40, spacing = 8, nameSize = 11, healthText = "NONE", buffSize = 14,
	},
	text = { nameColorSource = "text" },
	health = { colorSource = "class" },
}

local function merge(into, from)
	for key, value in pairs(from) do
		if type(value) == "table" then
			into[key] = merge(type(into[key]) == "table" and into[key] or {}, value)
		else
			into[key] = value
		end
	end
	return into
end

-- Saved(look, extra) -> SavedVariables whose profile holds the look's GroupFrames settings, merged with extra.
function Looks.Saved(look, extra)
	local group = merge(merge({}, look), extra or {})
	return { version = 2, profiles = { Default = { GroupFrames = group } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

-- Write(K, look) writes the look's settings through Options, as the player would.
function Looks.Write(K, look)
	local function walk(node, prefix)
		for key, value in pairs(node) do
			if type(value) == "table" then
				walk(value, prefix .. key .. ".")
			else
				assert(K.Options.Write("GroupFrames", prefix .. key, value))
			end
		end
	end
	walk(look, "")
end

return Looks
