-- Logic.lua: the module's pure rules: the fixed anchor's corner, font flags, quality edges, softened line colours and the tooltip scale.
local _, ns = ...

local Logic = {}
ns.Logic = Logic

local abs = math.abs

local UNCOMMON = 2
local COLOR_TOLERANCE = 0.02
local FLAGS = { OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function IsNumber(v)
	return not IsSecret(v) and type(v) == "number" and v == v
end
Logic.IsNumber = IsNumber
Logic.IsSecret = IsSecret

function Logic.Corner(left, bottom, width, height, rootWidth, rootHeight)
	if not (IsNumber(left) and IsNumber(bottom) and IsNumber(width) and IsNumber(height) and IsNumber(rootWidth) and IsNumber(rootHeight)) then
		return "BOTTOMRIGHT"
	end
	if rootWidth <= 0 or rootHeight <= 0 then
		return "BOTTOMRIGHT"
	end
	local vertical = (bottom + height / 2) > rootHeight / 2 and "TOP" or "BOTTOM"
	local horizontal = (left + width / 2) < rootWidth / 2 and "LEFT" or "RIGHT"
	return vertical .. horizontal
end

function Logic.Flags(outline)
	return FLAGS[outline] or ""
end

function Logic.EdgeQuality(quality)
	return IsNumber(quality) and quality >= UNCOMMON
end

function Logic.Soften(r, g, b, palette)
	if type(palette) ~= "table" or not (IsNumber(r) and IsNumber(g) and IsNumber(b)) then
		return nil
	end
	for _, soft in ipairs(palette) do
		if abs(r - soft[1]) < COLOR_TOLERANCE and abs(g - soft[2]) < COLOR_TOLERANCE and abs(b - soft[3]) < COLOR_TOLERANCE then
			return soft[4]
		end
	end
	return nil
end

function Logic.TooltipScale(rootScale, parentScale, elementScale)
	local element = IsNumber(elementScale) and elementScale > 0 and elementScale or 1
	if not (IsNumber(rootScale) and IsNumber(parentScale)) or rootScale <= 0 or parentScale <= 0 then
		return element
	end
	return rootScale / parentScale * element
end
