-- test-actionbars-crest-seats.lua: the crest's seat registry (SlabSeats.lua; the crest plan's Part 4 asks for one owner per seat): every class, in every form, with every piece known, seats each point piece on a named seat and leaves none off for a taken seat; a second claimant of a seat is refused and the first keeps it; the hunter's Shot holds the emblem and the Mark's reticle shows over it as an overlay, which claims no seat.
local F = dofile("Tools/regression/crest_armory_fixture.lua")

local FORMS = { WARRIOR = { 17, 18, 19 }, DRUID = { 0, 1, 5, 31 }, ROGUE = { 0, 30 }, PRIEST = { 0, 28 } }
local CLASSES = { "WARRIOR", "PALADIN", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN" }

for _, class in ipairs(CLASSES) do
	local env, K, ns = F.New(class, {})
	setmetatable(env._known, { __index = function() return true end })
	for _, form in ipairs(FORMS[class] or { 0 }) do
		env._form = form
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		env.FireEvent("SPELLS_CHANGED")
		env.RunTimers()
		local where = class .. " form " .. form
		local crest = ns.SlabTrackers.state.forms.crest
		assert(#crest.refused == 0, where .. ": " .. table.concat(crest.refused, "; "))
		local held = 0
		for seat, key in pairs(crest.claims) do
			assert(ns.SlabSeats.AT[seat], where .. ": " .. key .. " sits at " .. seat .. ", which is no named seat")
			held = held + 1
		end
		assert(held >= 4, where .. ": " .. held .. " seats held")
		F.Clean(env, K, where)
	end
	if class == "HUNTER" then
		local crest = ns.SlabTrackers.state.forms.crest
		assert(crest.claims.emblem == "crestShot", "HUNTER: the Shot holds the emblem")
		assert(F.Find(ns, "crestMark"), "HUNTER: the Mark, an overlay on the emblem, still shows")
	end
end

local _, _, ns = F.New("WARRIOR", { 6673 })
local Seats = ns.SlabSeats
local specs = { a = { key = "first", seat = { -47, -36.5 } }, b = { key = "second", seat = "lowerLeft" }, c = { key = "ring", seat = "rim" }, d = { key = "over", seat = { -47, -36.5 }, overlay = true } }
local kept, claims, refused = Seats.Claim({ "a", "b", "c", "d" }, specs, true)
assert(#kept == 3 and kept[1] == "a" and kept[2] == "c" and kept[3] == "d", "the groove and the socket on the lower left are one seat: the second is left off, the ring layer and the overlay stay")
assert(claims.lowerLeft == "first" and #refused == 1 and refused[1]:find("first holds the lowerLeft seat", 1, true), "the first owner keeps the seat: " .. tostring(refused[1]))
assert(#select(1, Seats.Claim({ "a", "b" }, specs, false)) == 2, "the Frames row claims no crest seat")
assert(Seats.Name(Seats.RAIL) == "rail", "the rail is a seat claimed by name")

print("test-actionbars-crest-seats: ok")
