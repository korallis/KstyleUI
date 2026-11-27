-- SlabSeats.lua: the crest's seat registry (docs/medallions-effects.md#seats lists the seats and the rules): a point seat resolves to the named seat within NEAR units, a seat holds one owner, earlier rows win, the hunter's rail claims "rail" by name, and the ring layers, self-placing pieces and overlays (a piece drawn over its seat's owner) claim nothing.
local _, ns = ...

local Medals = ns.SlabMedals
local sqrt, format = math.sqrt, string.format

local Seats = {}
ns.SlabSeats = Seats

local NEAR = 12
local AT = {
	emblem = { 0, 0 }, upper = { 0, 80 }, armLeft = { -48, 6 }, armRight = { 48, 6 }, bandLeft = { -64, 0 }, bandRight = { 64, 0 },
	armor = { -37, 51 }, lowerBand = { 0, -39 }, pet = { 42, -46 }, trinketLeft = { -33, -24 }, trinketRight = { 33, -24 },
	perchLeft = { -48.8, -54.2 }, perchRight = { 49.5, -55 }, crownLeft = { -56.7, 47.6 }, crownRight = { 56.7, 47.6 },
	popLeft = { -40, 84 }, popRight = { 40, 84 },
}
for _, name in ipairs({ "left", "right", "top", "topGem", "lowerLeft", "lowerRight", "footLeft", "footRight" }) do
	AT[name] = { Medals.Seat(name) }
end
Seats.AT = AT
Seats.RAIL = "rail"

function Seats.Name(seat)
	if type(seat) ~= "table" then
		return (AT[seat] or seat == Seats.RAIL) and seat or nil
	end
	local best, far = nil, NEAR
	for name, at in pairs(AT) do
		local d = sqrt((seat[1] - at[1]) ^ 2 + (seat[2] - at[2]) ^ 2)
		if d < far then
			best, far = name, d
		end
	end
	return best or format("%g,%g", seat[1], seat[2])
end

function Seats.Claim(order, specs, crest)
	local kept, claims, refused = {}, {}, {}
	for _, key in ipairs(order) do
		local spec = specs[key]
		local seat = crest and not (spec.place or spec.overlay) and Seats.Name(spec.seat)
		if seat and claims[seat] then
			refused[#refused + 1] = format("%s left off the crest: %s holds the %s seat", tostring(spec.key), claims[seat], seat)
		else
			if seat then
				claims[seat] = spec.key
			end
			kept[#kept + 1] = key
		end
	end
	return kept, claims, refused
end
