local Audit = dofile("Tools/regression/pixel_audit_lib.lua")
local text = { _type = "FontString", _points = { { "TOPLEFT" } }, _calls = {} }
local function region(points)
	return { _type = "Texture", _state = {}, _points = points }
end
local corner = region({ { "TOPLEFT", text, "BOTTOMLEFT" } })
local middle = region({ { "TOPLEFT", corner, "BOTTOMRIGHT" } })
local fixed = region({ { "TOPLEFT", text, "TOPLEFT" } })
local function judged(object)
	local axes = {}
	for _, edge in ipairs(Audit.Edges({ kind = "texture", object = object, rect = { 0, 0, 8, 8 } }, 1)) do
		axes[edge[3]] = true
	end
	return axes
end
assert(judged(corner).x and not judged(corner).y, "a lower corner follows glyph height only")
assert(judged(middle).x and not judged(middle).y, "propagate glyph-dependent height through the slice corner")
assert(judged(fixed).x and judged(fixed).y, "fixed top-left edges remain judged")
local a, b = region({}), region({})
a._points, b._points = { { "TOPLEFT", b, "TOPLEFT" } }, { { "TOPLEFT", a, "TOPLEFT" } }
assert(judged(a).x and judged(a).y, "cyclic anchors cannot disable pixel checks")
print("pixel audit glyph propagation passed")
