-- Geometry.lua: Layout's pure position maths: the nine anchors, rects, whole-pixel snapping, guides, resizing and rescaling.
local _, ns = ...

local Layout = ns.Layout or {}
ns.Layout = Layout

local G = {}
Layout.Geometry = G

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local FRACTION = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
G.ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local COLUMNS = { "LEFT", "", "RIGHT" }
local ROWS = { "BOTTOM", "", "TOP" }
local HANDLE = {
	TOPLEFT = { -1, 1 }, TOP = { 0, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { -1, 0 }, RIGHT = { 1, 0 },
	BOTTOMLEFT = { -1, -1 }, BOTTOM = { 0, -1 }, BOTTOMRIGHT = { 1, -1 },
}
G.HANDLES = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

function G.IsAnchor(anchor)
	return type(anchor) == "string" and FRACTION[anchor] ~= nil
end

function G.IsHandle(handle)
	return type(handle) == "string" and HANDLE[handle] ~= nil
end

function G.Fraction(anchor)
	local f = FRACTION[anchor]
	return f[1], f[2]
end

function G.Rect(anchor, x, y, w, h, rootW, rootH)
	local fx, fy = G.Fraction(anchor)
	return fx * rootW + x - fx * w, fy * rootH + y - fy * h
end

local function third(centre, size)
	if size <= 0 then
		return 2
	end
	local t = centre / size
	if t < 1 / 3 then
		return 1
	elseif t > 2 / 3 then
		return 3
	end
	return 2
end

function G.NearestAnchor(left, bottom, w, h, rootW, rootH)
	local col = third(left + w / 2, rootW)
	local row = third(bottom + h / 2, rootH)
	local name = ROWS[row] .. COLUMNS[col]
	if name == "" then
		return "CENTER"
	end
	return name
end

function G.Position(left, bottom, w, h, rootW, rootH, anchor)
	anchor = anchor or G.NearestAnchor(left, bottom, w, h, rootW, rootH)
	local fx, fy = G.Fraction(anchor)
	return anchor, left + fx * w - fx * rootW, bottom + fy * h - fy * rootH
end

function G.Align(value, pixel)
	return floor(value / pixel + 0.5) * pixel
end

function G.SnapSize(size, factor, pixel)
	local pixels = max(1, floor(size * factor / pixel + 0.5))
	return pixels * pixel / factor
end

function G.ClampToRoot(left, bottom, w, h, rootW, rootH)
	return min(max(left, 0), max(0, rootW - w)), min(max(bottom, 0), max(0, rootH - h))
end

function G.Targets(rootW, rootH, rects)
	local xs, ys = { 0, rootW / 2, rootW }, { 0, rootH / 2, rootH }
	for _, r in ipairs(rects or {}) do
		xs[#xs + 1] = r.left
		xs[#xs + 1] = r.left + r.width / 2
		xs[#xs + 1] = r.left + r.width
		ys[#ys + 1] = r.bottom
		ys[#ys + 1] = r.bottom + r.height / 2
		ys[#ys + 1] = r.bottom + r.height
	end
	return { xs = xs, ys = ys }
end

local function nearestLine(value, origin, size)
	return origin + floor((value - origin) / size + 0.5) * size
end

local function snapAxis(start, size, lines, threshold, gridSize, gridOrigin)
	local bestShift, bestLine, bestDistance = 0, nil, threshold + 1
	for i = 0, 2 do
		local edge = start + size * i / 2
		for _, line in ipairs(lines) do
			local d = line - edge
			if abs(d) < bestDistance then
				bestShift, bestLine, bestDistance = d, line, abs(d)
			end
		end
		if gridSize then
			local line = nearestLine(edge, gridOrigin, gridSize)
			local d = line - edge
			if abs(d) < bestDistance then
				bestShift, bestLine, bestDistance = d, line, abs(d)
			end
		end
	end
	if bestLine == nil or bestDistance > threshold then
		return start, nil
	end
	return start + bestShift, bestLine
end

function G.SnapMove(left, bottom, w, h, targets, threshold, grid)
	local gridSize = grid and grid.size and grid.size > 0 and grid.size or nil
	local l, gx = snapAxis(left, w, targets.xs, threshold, gridSize, grid and grid.cx)
	local b, gy = snapAxis(bottom, h, targets.ys, threshold, gridSize, grid and grid.cy)
	return l, b, gx, gy
end

local function clamp(v, low, high)
	return min(max(v, low), high)
end

function G.Resize(rect, handle, dx, dy, limits)
	local dir = HANDLE[handle]
	local hx, hy = dir[1], dir[2]
	local w, h = rect.width, rect.height
	local nw = hx ~= 0 and w + hx * dx or w
	local nh = hy ~= 0 and h + hy * dy or h
	local minW, maxW = limits.minWidth, max(limits.minWidth, limits.maxWidth)
	local minH, maxH = limits.minHeight, max(limits.minHeight, limits.maxHeight)
	local aspect = limits.aspect
	if aspect then
		if hx ~= 0 and hy ~= 0 then
			local rw = w > 0 and abs(nw / w - 1) or 0
			local rh = h > 0 and abs(nh / h - 1) or 0
			if rw < rh then
				nw = nh * aspect
			end
		elseif hx == 0 then
			nw = nh * aspect
		end
		local low = max(minW, minH * aspect)
		local high = max(low, min(maxW, maxH * aspect))
		nw = clamp(nw, low, high)
		nh = nw / aspect
	else
		nw = clamp(nw, minW, maxW)
		nh = clamp(nh, minH, maxH)
	end
	local pixel = limits.pixel
	nw = max(pixel, G.Align(nw, pixel))
	nh = max(pixel, G.Align(nh, pixel))
	local left, bottom = rect.left, rect.bottom
	if hx < 0 then
		left = left + w - nw
	end
	if hy <= 0 then
		bottom = bottom + h - nh
	end
	return G.Align(left, pixel), G.Align(bottom, pixel), nw, nh
end

function G.Rescale(rect, startScale, dx, dy, minScale, maxScale)
	local w, h = rect.width, rect.height
	local d2 = w * w + h * h
	if d2 <= 0 then
		return startScale
	end
	local ratio = ((w + dx) * w + (h - dy) * h) / d2
	local scale = clamp(startScale * ratio, minScale, maxScale)
	return floor(scale * 100 + 0.5) / 100
end
