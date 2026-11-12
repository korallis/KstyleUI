-- Rects.lua: the layout KstyleUI gave its own regions, recorded as it is set, so an ornament can place pieces where the game will not measure.
local _, ns = ...

local W = ns.Widgets
local IsSecret = W.IsSecret
local RECORDS = setmetatable({}, { __mode = "k" })
local FRACTIONS = { TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, 0.5 },
	CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local LINE_EM = 1.2

local function Plain(v)
	return not IsSecret(v) and type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function Anchor(record, point, a, b, c, d)
	if not FRACTIONS[point] then return end
	local relative, relPoint, x, y = a, b, c, d
	if type(a) == "number" then
		relative, relPoint, x, y = nil, point, a, b
	elseif type(b) == "number" then
		relative, relPoint, x, y = a, point, b, c
	end
	if type(relative) == "string" then relative = _G[relative] end
	local slot = record.points[point]
	if not slot then
		slot = {}
		record.points[point] = slot
	end
	slot.relative, slot.relPoint = relative or false, FRACTIONS[relPoint] and relPoint or point
	slot.x, slot.y = Plain(x) and x or 0, Plain(y) and y or 0
	slot.set = true
	record.count = record.count + 1
end

local function Clear(record)
	for _, slot in pairs(record.points) do slot.set = false end
	record.count = 0
end

function W.Record(region)
	if RECORDS[region] or type(region) ~= "table" or type(region.SetPoint) ~= "function" then return end
	local protected = type(region.IsProtected) == "function" and region:IsProtected()
	if protected == true or IsSecret(protected) then return end
	local record = { points = {}, count = 0, width = false, height = false }
	RECORDS[region] = record
	hooksecurefunc(region, "SetPoint", function(_, point, a, b, c, d) Anchor(record, point, a, b, c, d) end)
	hooksecurefunc(region, "ClearAllPoints", function() Clear(record) end)
	hooksecurefunc(region, "SetAllPoints", function(_, relative)
		Clear(record)
		Anchor(record, "TOPLEFT", relative or false, "TOPLEFT", 0, 0)
		Anchor(record, "BOTTOMRIGHT", relative or false, "BOTTOMRIGHT", 0, 0)
	end)
	hooksecurefunc(region, "SetSize", function(_, w, h)
		record.width, record.height = Plain(w) and w, Plain(h) and h
	end)
	hooksecurefunc(region, "SetWidth", function(_, w) record.width = Plain(w) and w end)
	hooksecurefunc(region, "SetHeight", function(_, h) record.height = Plain(h) and h end)
end

function W.RecordAll(...)
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if region then W.Record(region) end
	end
end

local scratch

local function TextWidth(region)
	local width = region:GetStringWidth()
	if Plain(width) and width >= 0 then return width end
	local text = region:GetText()
	if IsSecret(text) or type(text) ~= "string" then return nil end
	if text == "" then return 0 end
	local file, size, flags = region:GetFont()
	if IsSecret(file) or IsSecret(flags) or type(file) ~= "string" or not Plain(size) then return nil end
	if not scratch then
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:Hide()
		scratch = W.FontString(holder, "OVERLAY")
		scratch:SetWordWrap(false)
	end
	scratch:SetFont(file, size, flags)
	scratch:SetText(text)
	width = scratch:GetStringWidth()
	if not Plain(width) then return nil end
	local record = RECORDS[region]
	local own = record and record.width
	if own and own > 0 and width > own then width = own end
	return width
end
W.StringWidth = TextWidth

local function Scale(region)
	local scale = region:GetEffectiveScale()
	return Plain(scale) and scale > 0 and scale or nil
end

local function Natural(region, axis)
	local record = RECORDS[region]
	local set = record and (axis == 1 and record.width or axis == 2 and record.height)
	if set and set > 0 then return set end
	local size
	if axis == 1 then size = region:GetWidth() else size = region:GetHeight() end
	if Plain(size) and size > 0 then return size end
	if type(region.GetFont) ~= "function" then return nil end
	if axis == 1 then
		local text = region:GetText()
		if not IsSecret(text) and (text == nil or text == "") then return 0 end
		return TextWidth(region)
	end
	local _, font = region:GetFont()
	return Plain(font) and font > 0 and font * LINE_EM or nil
end

local SOLVED = setmetatable({}, { __mode = "k" })
local generation = 0

function W.LocalBegin()
	generation = generation + 1
end

local Solve

local function Edge(rect, fraction, axis)
	local low, high
	if axis == 1 then low, high = rect[2], rect[3] else low, high = rect[4], rect[5] end
	if fraction == 0 then return low end
	if not (low and high) then return nil end
	if axis == 1 then return low + (high - low) * fraction end
	return low - (low - high) * fraction
end

local function Axis(region, rect, record, scale, axis, depth)
	local a1, f1, a2, f2, root, rel1
	for point, slot in pairs(record.points) do
		if slot.set then
			local relative = slot.relative or region:GetParent()
			if IsSecret(relative) or not relative then return false end
			local other = Solve(relative, depth + 1)
			if not other then return false end
			if root and other[1] ~= root then return false end
			root = other[1]
			local fraction = FRACTIONS[point][axis]
			local at = Edge(other, FRACTIONS[slot.relPoint][axis], axis)
			if at then
				at = at + (axis == 1 and slot.x or slot.y) * scale
				if not a1 then
					a1, f1, rel1 = at, fraction, other
				elseif fraction ~= f1 and not a2 then
					a2, f2 = at, fraction
				end
			end
		end
	end
	if not root then return false end
	rect[1] = root
	local sign = axis == 1 and 1 or -1
	local low, high
	if a1 and a2 then
		local span = (a2 - a1) / (f2 - f1)
		if span * sign < 0 then span = 0 end
		low = a1 - f1 * span
		high = low + span
	elseif a1 then
		local size = Natural(region, axis)
		if size then
			size = size * scale
			low = a1 - f1 * size * sign
			high = low + size * sign
		elseif axis == 1 and region.GetFont and rel1 then
			low = f1 == 0 and a1 or rel1[2]
			high = f1 == 1 and a1 or rel1[3]
		end
	end
	if axis == 1 then rect[2], rect[3] = low, high else rect[4], rect[5] = low, high end
	return low ~= nil and high ~= nil
end

function Solve(region, depth)
	if depth > 24 then return nil end
	local rect = SOLVED[region]
	if rect and rect.generation == generation then return rect.ok and rect or nil end
	if not rect then
		rect = {}
		SOLVED[region] = rect
	end
	rect.generation, rect.ok = generation, false
	local scale = Scale(region)
	if not scale then return nil end
	local record = RECORDS[region]
	if not record or record.count == 0 then
		local w, h = Natural(region, 1), Natural(region, 2)
		rect[1], rect[2], rect[4] = region, 0, 0
		rect[3], rect[5] = w and w * scale, h and -h * scale
		rect.ok = true
		return rect
	end
	if not Axis(region, rect, record, scale, 1, depth) then return nil end
	if not Axis(region, rect, record, scale, 2, depth) then return nil end
	rect.ok = true
	return rect
end

function W.LocalRect(region)
	if not RECORDS[region] then return nil end
	local rect = Solve(region, 0)
	if not rect or not (rect[3] and rect[5]) then return nil end
	return rect[1], rect[2], rect[3], rect[4], rect[5]
end
