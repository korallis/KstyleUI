-- Names.lua: fits a member's name to the width its row gives it, stepping the size down first and then ending in an ellipsis, keeping it distinct from the other members' names.
local _, ns = ...

local Unit = ns.Unit

local Names = {}
ns.Names = Names

local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local ELLIPSIS = "..."
local MAX_TAIL = 3
local EM = 0.55

local function Chars(text)
	local out = {}
	for c in text:gmatch(CHAR) do
		out[#out + 1] = c
	end
	return out
end

local function Width(region, text, size)
	local measure = region.GetUnboundedStringWidthForText
	if measure then
		local ok, width = pcall(measure, region, text)
		if ok and type(width) == "number" and not Unit.IsSecret(width) and width > 0 then
			return width
		end
	end
	return #Chars(text) * size * EM
end
Names.Width = Width

local function Prefix(chars, n)
	return table.concat(chars, "", 1, n)
end

local function Tail(chars, n)
	return table.concat(chars, "", #chars - n + 1, #chars)
end

local function Starts(text, head)
	return text:lower():sub(1, #head) == head:lower()
end

local function Ends(text, tail)
	return tail == "" or text:lower():sub(-#tail) == tail:lower()
end

local function Clashes(head, tail, own, others)
	for i = 1, #others do
		local other = others[i]
		if other ~= own and Starts(other, head) and Ends(other, tail) then
			return true
		end
	end
	return false
end

function Names.Short(name, fits, others)
	if fits(name) then
		return name
	end
	local chars = Chars(name)
	local n = #chars - 1
	while n > 1 and not fits(Prefix(chars, n) .. ELLIPSIS) do
		n = n - 1
	end
	local head = Prefix(chars, n)
	if not Clashes(head, "", name, others) then
		return head .. ELLIPSIS
	end
	for tail = 1, MAX_TAIL do
		local keep = n - tail
		local last = Tail(chars, tail)
		while keep >= 1 and not fits(Prefix(chars, keep) .. ELLIPSIS .. last) do
			keep = keep - 1
		end
		if keep < 1 then
			break
		end
		local first = Prefix(chars, keep)
		if not Clashes(first, last, name, others) then
			return first .. ELLIPSIS .. last
		end
	end
	return head .. ELLIPSIS
end

local function Others(f)
	local out = {}
	Unit.ForEach(function(other)
		if other ~= f and other.unit and type(other.rawName) == "string" then
			out[#out + 1] = other.rawName
		end
	end)
	return out
end

function Names.Apply(f)
	local name, text = f.rawName, f.name
	if type(name) ~= "string" then
		return
	end
	local width = f.nameWidth
	if type(width) ~= "number" or width <= 0 then
		text:SetText(name)
		return
	end
	local fit = f.nameFit
	if fit then
		for step = fit.size, fit.min, -1 do
			fit.set(text, step)
			if Width(text, name, step) <= width then
				text:SetText(name)
				return
			end
		end
	end
	local _, size = text:GetFont()
	size = type(size) == "number" and not Unit.IsSecret(size) and size or 10
	local function fits(candidate)
		return Width(text, candidate, size) <= width
	end
	text:SetText(Names.Short(name, fits, f.others or Others(f)))
end

function Names.Set(f, name)
	if Unit.IsSecret(name) or type(name) ~= "string" then
		f.rawName = nil
		f.name:SetText(Unit.IsSecret(name) and name or "")
		return
	end
	f.rawName = name
	Names.Apply(f)
end
