-- test-pixel-audit-moving.lua: the pixel-grid audit treats a texture anchored only to a status bar fill's moving end (a spark) as the engine's on that axis, as it treats the fill's own end, and still judges its other axis and every texture anchored elsewhere.
local Audit = dofile("Tools/regression/pixel_audit_lib.lua")

local function state(fields)
	local out = {}
	for key, value in pairs(fields) do
		out[key] = { value }
	end
	return out
end

local bar = { _type = "StatusBar", _state = state({ Orientation = "HORIZONTAL" }), _points = {} }
local fill = { _type = "Texture", _barOwner = bar, _parent = bar, _state = {}, _points = {} }
local function texture(points)
	return { _type = "Texture", _parent = bar, _state = {}, _points = points }
end

local function edges(object, rect)
	local out = {}
	for _, edge in ipairs(Audit.Edges({ kind = "texture", object = object, rect = rect }, 1)) do
		out[edge[1]] = true
	end
	return out
end

local spark = texture({ { "TOPRIGHT", fill, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0 } })
local e = edges(spark, { 101.4, 10.5, 2, 18 })
assert(not e.left and not e.right, "a spark anchored only to the fill's moving end is the engine's across")
assert(e.top and e.bottom, "its top and bottom are still judged, so an off-grid top is still caught")
local mx, my = Audit.Moving(spark)
assert(mx == true and my == false, "the exemption is on the fill's axis only")

local glow = texture({ { "CENTER", spark, "CENTER", 0, 0 } })
e = edges(glow, { 97.4, 10, 10, 18 })
assert(not e.left and not e.right and e.top and e.bottom, "a glow centred on the spark moves with it across, and is judged down")

local sheen = texture({ { "TOPLEFT", fill, "TOPLEFT", 0, 0 }, { "TOPRIGHT", fill, "TOPRIGHT", 0, 0 } })
e = edges(sheen, { 0, 0, 101.4, 8 })
assert(e.left and e.right and e.top and e.bottom, "a texture also anchored to the fill's fixed end is judged on every edge")

local fixed = texture({ { "TOPLEFT", bar, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0 } })
e = edges(fixed, { 0, 0, 200, 18 })
assert(e.left and e.right and e.top and e.bottom, "a texture on the bar itself is judged on every edge")

bar._state = state({ Orientation = "HORIZONTAL", ReverseFill = true })
e = edges(spark, { 101.4, 10.5, 2, 18 })
assert(e.left and e.right, "with the fill reversed, the right end is fixed, so a texture on it is judged")
local reversed = texture({ { "TOPLEFT", fill, "TOPLEFT", 0, 0 }, { "BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0 } })
e = edges(reversed, { 101.4, 10.5, 2, 18 })
assert(not e.left and not e.right and e.top, "and the left end moves instead")

bar._state = state({ Orientation = "VERTICAL" })
local surface = texture({ { "TOPLEFT", fill, "TOPLEFT", 0, 0 }, { "TOPRIGHT", fill, "TOPRIGHT", 0, 0 } })
e = edges(surface, { 3.5, 40.3, 20, 1 })
assert(not e.top and not e.bottom and e.left and e.right, "on a vertical bar the top moves, so only the up axis is the engine's")
print("pixel audit moving ok")
