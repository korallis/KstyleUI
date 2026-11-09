-- geometry.lua: resolve where a stub region sits from its anchors and sizes, relative to a root frame.
--
--   local Geometry = dofile("Tools/regression/geometry.lua")
--   local rect, why = Geometry.Rect(region, root)   -- { left, right, bottom, top }, or nil and a reason
--   local outside = Geometry.Outside(rect, Geometry.Rect(root, root))
--
-- The root sits at the origin with its own size. Every other object is placed by its points, the way the
-- game places it: two points on one axis fix both edges, one point and a size fix the rest. A region with
-- one point on an axis and no size there has no known extent (the game would draw it at its file's size),
-- so Rect returns nil and says why; a size set to 0 is a known extent, as an empty aura container's is.
-- Animations are not applied.
local Geometry = {}

local function Horizontal(point)
	if point:find("LEFT") then
		return "min"
	elseif point:find("RIGHT") then
		return "max"
	end
	return "mid"
end

local function Vertical(point)
	if point:find("BOTTOM") then
		return "min"
	elseif point:find("TOP") then
		return "max"
	end
	return "mid"
end

local function At(rect, point)
	local h, v = Horizontal(point), Vertical(point)
	local x = h == "min" and rect.left or h == "max" and rect.right or (rect.left + rect.right) / 2
	local y = v == "min" and rect.bottom or v == "max" and rect.top or (rect.bottom + rect.top) / 2
	return x, y
end

local function Unpack(object, p)
	local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
	if type(rel) ~= "table" then
		point, rel, relPoint, x, y = p[1], object._parent, p[1], p[2], p[3]
	end
	if type(relPoint) ~= "string" then
		relPoint, x, y = point, relPoint, x
	end
	return point, rel, relPoint, tonumber(x) or 0, tonumber(y) or 0
end

local function Edges(lo, hi, mid, size)
	if lo and hi then
		return lo, hi
	end
	if type(size) ~= "number" or size < 0 then
		return nil
	end
	if lo then
		return lo, lo + size
	elseif hi then
		return hi - size, hi
	elseif mid then
		return mid - size / 2, mid + size / 2
	end
	return nil
end

function Geometry.Rect(object, root, seen)
	if object == root then
		return { left = 0, right = root:GetWidth() or 0, bottom = 0, top = root:GetHeight() or 0 }
	end
	seen = seen or {}
	if seen[object] then
		return nil, "an anchor loop"
	end
	seen[object] = true
	local points = object._points or {}
	if #points == 0 then
		return nil, "no points"
	end
	local x, y = {}, {}
	for _, p in ipairs(points) do
		local point, rel, relPoint, dx, dy = Unpack(object, p)
		if not rel then
			return nil, point .. " has no target"
		end
		local target, why = Geometry.Rect(rel, root, seen)
		if not target then
			return nil, why
		end
		local tx, ty = At(target, relPoint)
		x[Horizontal(point)] = tx + dx
		y[Vertical(point)] = ty + dy
	end
	seen[object] = nil
	local left, right = Edges(x.min, x.max, x.mid, object._width)
	local bottom, top = Edges(y.min, y.max, y.mid, object._height)
	if not left then
		return nil, "no width and one horizontal point"
	end
	if not bottom then
		return nil, "no height and one vertical point"
	end
	return { left = left, right = right, bottom = bottom, top = top }
end

-- How far rect reaches past bounds on its worst side, in units; 0 when it stays inside.
function Geometry.Outside(rect, bounds)
	return math.max(0, bounds.left - rect.left, rect.right - bounds.right, bounds.bottom - rect.bottom, rect.top - bounds.top)
end

-- Every frame and region under root, root included, in a stable order.
function Geometry.Tree(root, out)
	out = out or {}
	out[#out + 1] = root
	for _, region in ipairs(root._regions or {}) do
		out[#out + 1] = region
	end
	for _, kid in ipairs(root._kids or {}) do
		Geometry.Tree(kid, out)
	end
	return out
end

return Geometry
