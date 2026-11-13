-- test-store-placement.lua: migration 31 lets every saved place still at its pre-KSTY-60 default follow the new one (the party out of the top-left corner to mid-left, the map's card onto the card margin with the aura rows beside it, the taller experience strip, the Orbs party and raid), and keeps a place or a size the player chose.
local C = dofile("Tools/regression/core_env.lua")
local Layouts
do
	local probe, PK = C.New()
	C.Boot(probe)
	Layouts = PK.Setup.Layouts
end
-- Staging's defaults at d3195d80, written out so a wrong old place in Layouts.PlaceMoves fails here.
local MOCK = 19 / 16
local TRAY_BOTTOM, STRIP_GAP = 40 * MOCK, 9 * MOCK
local OLD = {
	["groupframes.party"] = { "TOPLEFT", 17, -17 },
	["orbs:groupframes.party"] = { "TOPLEFT", 17, -465 },
	["orbs:groupframes.raid"] = { "TOPLEFT", 17, -465 },
	["minimap.main"] = { "TOPRIGHT", -16, -38 },
	["auras.buffs"] = { "TOPRIGHT", -(17 + 188 + 10.9), -18.4 },
	["auras.debuffs"] = { "TOPRIGHT", -(17 + 188 + 10.9), -(18.4 + 41.5 + 8) },
	["databars.xp"] = { "BOTTOM", 0, TRAY_BOTTOM - STRIP_GAP - 5, 491, 5 },
}
local moves = Layouts.PlaceMoves()
for key, place in pairs(OLD) do
	local got = moves[key]
	assert(got and got[1] == place[1] and math.abs(got[2] - place[2]) < 1e-6 and math.abs(got[3] - place[3]) < 1e-6 and got[4] == place[4] and got[5] == place[5], key .. ": PlaceMoves names staging's old default")
end
local orbsXP = Layouts.Style("orbs", "DPS", "databars.xp")
assert(math.abs(moves["orbs:databars.xp"][3] - (orbsXP.y + 7 * MOCK - 5)) < 1e-6, "the Orbs strip's old place keeps its top where the 5-unit strip had it")
local function At(key, extra)
	local place = OLD[key] or moves[key]
	local entry = { anchor = place[1], x = place[2], y = place[3] }
	for field, value in pairs(extra or {}) do
		entry[field] = value
	end
	return entry
end
local env, K = C.New({ saved = {
	version = 30,
	profiles = { Default = {}, Healer = { Layout = { preset = "Healer" } }, Custom = {} },
	layouts = {
		Default = {
			["groupframes.party"] = At("groupframes.party"),
			["minimap.main"] = At("minimap.main"),
			["auras.buffs"] = At("auras.buffs"),
			["auras.debuffs"] = At("auras.debuffs"),
			["databars.xp"] = At("databars.xp", { width = 491, height = 5 }),
			["orbs:groupframes.party"] = At("orbs:groupframes.party"),
			["orbs:groupframes.raid"] = At("orbs:groupframes.raid"),
			["orbs:databars.xp"] = At("orbs:databars.xp"),
		},
		Healer = { ["groupframes.party"] = { width = 300 } },
		Custom = {
			["groupframes.party"] = { anchor = "TOPLEFT", x = 40, y = -200 },
			["minimap.main"] = At("minimap.main", { scale = 1.2 }),
			["databars.xp"] = At("databars.xp", { width = 600, height = 5 }),
		},
	},
} })
C.Boot(env)
local db = env.KstyleUIDB
assert(db.version == K.Store.DB_VERSION and db.version == 32 and K.ErrorCount() == 0, "the migration reaches the current version without errors")
for key in pairs(db.layouts.Default) do
	error(key .. " at its old default still holds a saved place")
end
assert(db.layouts.Healer["groupframes.party"].width == 300 and db.layouts.Healer["groupframes.party"].anchor == nil, "a saved size alone stays, and the party follows its new place")
local custom = db.layouts.Custom
assert(custom["groupframes.party"].anchor == "TOPLEFT" and custom["groupframes.party"].x == 40 and custom["groupframes.party"].y == -200, "a party the player placed stays put")
assert(custom["minimap.main"].anchor == nil and custom["minimap.main"].scale == 1.2, "the map follows its new place and keeps its scale")
assert(custom["databars.xp"].anchor == nil and custom["databars.xp"].width == 600 and custom["databars.xp"].height == 5, "a strip the player sized keeps its size")
-- The new places themselves: the party at mid-left in both styles and every role, the map's card on the card margin.
local margin = K.Tokens.Size("screenMargin")
for _, name in ipairs(Layouts.Names()) do
	for _, style in ipairs({ "frames", "orbs" }) do
		local party = Layouts.Place(name, style, "16:9", "groupframes.party")
		local _, height = Layouts.Footprint("DPS", "groupframes.party")
		assert(party.anchor == "LEFT" and party.x == margin and math.abs(Layouts.HEIGHT / 2 - party.y - height / 2 - 465) < 1e-6, name .. " " .. style .. ": the party stands at mid-left, its top 465 under the top as the mock-ups draw it")
		local raid = Layouts.Place(name, style, "16:9", "groupframes.raid")
		assert(raid.anchor == "TOPLEFT" and raid.x == margin and raid.y == -margin, name .. " " .. style .. ": the raid card keeps the top-left corner")
	end
end
local map = Layouts.Get("DPS")["minimap.main"]
assert(map.x == -(margin + Layouts.MAP_FRAME), "the map's card, its frame outside the square, ends on the card margin")
print("store placement ok")
