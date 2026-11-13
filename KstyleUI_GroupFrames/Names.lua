-- Names.lua: fits one face and size across a party, preserves compact raid names, and passes secret names straight to the engine.
local _, ns = ...

local Unit = ns.Unit
local Names = {}
ns.Names = Names

local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local ELLIPSIS = "..."
local MAX_TAIL = 3
local EM = 0.55
local PARTY_NAME_EM = 9

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

local function Apply(f)
	local name, text = f.rawName, f.name
	local fit = f.nameFit
	if type(name) ~= "string" then
		if fit and f.nativeName then
			fit.set(text, fit.min)
		end
		return
	end
	local width = f.nameWidth
	if type(width) ~= "number" or width <= 0 then
		if fit then
			fit.set(text, f.nameFloor and fit.min or fit.size)
		end
		text:SetText(name)
		return
	end
	if fit then
		for step = fit.size, fit.min, -1 do
			fit.set(text, step)
			if Width(text, name, step) <= width + fit.slack then
				text:SetText(name)
				return
			end
		end
	end
	if f.nativeName then
		text:SetText(name)
		return
	end
	local _, size = text:GetFont()
	size = type(size) == "number" and not Unit.IsSecret(size) and size or 10
	local function fits(candidate)
		return Width(text, candidate, size) <= width
	end
	text:SetText(Names.Short(name, fits, f.others or Others(f)))
end

function Names.Party(f)
	local group = {}
	if f.nameGroup then
		for _, other in ipairs(f.nameGroup) do
			if other.nameFit then
				group[#group + 1] = other
			end
		end
	else
		Unit.ForEach(function(other)
			if other.kind == "party" and other.unit and other.nameFit then
				group[#group + 1] = other
			end
		end)
	end
	if #group == 0 then
		Apply(f)
		return
	end
	local first = group[1].nameFit
	local requested, minimum = first.size, first.min
	local unknown = false
	for _, other in ipairs(group) do
		requested = math.min(requested, other.nameFit.size)
		minimum = math.max(minimum, other.nameFit.min)
		unknown = unknown or other.nameFloor == true or other.rawName == nil
	end
	local path = first.path
	if first.kit then
		for _, other in ipairs(group) do
			local fit, width = other.nameFit, other.nameWidth
			fit.set(other.name, minimum, path)
			local _, size = other.name:GetFont()
			if not width or PARTY_NAME_EM * size > width + fit.slack
				or (other.rawName and Width(other.name, other.rawName, size) > width + fit.slack) then
				path = ns.Settings.COMPACT_NAME_FONT
				break
			end
		end
	end
	local chosen = minimum
	if not unknown then
		for step = requested, minimum, -1 do
			local fits = true
			for _, other in ipairs(group) do
				local fit, width = other.nameFit, other.nameWidth
				fit.set(other.name, step, path)
				if width and other.rawName and Width(other.name, other.rawName, step) > width + fit.slack then
					fits = false
					break
				end
			end
			if fits then
				chosen = step
				break
			end
		end
	end
	for _, other in ipairs(group) do
		local fit, text, name, width = other.nameFit, other.name, other.rawName, other.nameWidth
		fit.set(text, chosen, path)
		other.nativeName = fit.native and path == fit.path
		if name then
			local _, size = text:GetFont()
			if not width or other.nativeName or Width(text, name, size) <= width + fit.slack then
				text:SetText(name)
			else
				local function fits(candidate)
					return Width(text, candidate, size) <= width + fit.slack
				end
				text:SetText(Names.Short(name, fits, other.others or Others(other)))
			end
		end
	end
end

function Names.Apply(f)
	if f.kind == "party" and (f.unit or f.nameGroup) then
		Names.Party(f)
	else
		Apply(f)
	end
end

function Names.Set(f, name)
	if Unit.IsSecret(name) or type(name) ~= "string" then
		f.rawName = nil
		Names.Apply(f)
		f.name:SetText(Unit.IsSecret(name) and name or "")
		return
	end
	f.rawName = name
	Names.Apply(f)
end
