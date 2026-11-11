-- Ornaments.lua: optional painted attachments authored at native texel sizes, outside existing content.
local _, ns = ...

local W, Scale = ns.Widgets, ns.Scale
local floor, min, max, huge = math.floor, math.min, math.max, math.huge
local PATH = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\ForgedOrnaments\\"
local ASSETS, INK = W.OrnamentAssets, W.OrnamentInk
local POINTS = { TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, 0.5 },
	CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local Handle = {}
Handle.__index = Handle
local BARS, ROWS = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
W.OrnamentRows, W.OrnamentBars = ROWS, BARS

local function Plain(v)
	return not W.IsSecret(v) and type(v) == "number" and v > 0
end

local function Known(v)
	return not W.IsSecret(v) and type(v) == "number" and v == v and v > -huge and v < huge
end

local EMPTY = {}
local TIER_SIZES = { 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 64, 80, 96 }
local NAMED, PATHS = {}, {}

local function Named(prefix, n)
	local names = NAMED[prefix]
	if not names then
		names = {}
		NAMED[prefix] = names
	end
	local name = names[n]
	if not name then
		name = prefix .. n
		names[n] = name
	end
	return name
end

local function Tier(family, wanted)
	for i = #TIER_SIZES, 1, -1 do
		local n = TIER_SIZES[i]
		if n <= wanted then
			local name = Named(family, n)
			if ASSETS[name] then return name end
		end
	end
end

local function Scratch(self)
	local S = self.scratch
	if not S then
		S = { recs = {}, nrec = 0, cands = {}, ncand = 0, wrap = { 0, 0 }, blocked = { false, false }, ring = {}, caps = {},
			lanes = { {}, {} } }
		self.scratch = S
	end
	return S
end

local FIELDS = { "l", "r", "t", "b", "clear", "icon", "other", "ink", "row", "cut", "card", "cx", "cy", "radius", "spans", "inkb" }

local function Rec(S)
	local n = S.nrec + 1
	S.nrec = n
	local o = S.recs[n]
	if not o then
		o = {}
		S.recs[n] = o
	end
	for i = 1, #FIELDS do o[FIELDS[i]] = false end
	return o
end

local function Copy(S, o, clear)
	local c = Rec(S)
	for i = 1, #FIELDS do
		local key = FIELDS[i]
		c[key] = o[key]
	end
	c.clear = clear
	return c
end

local function List(S, key)
	local t = S[key]
	if not t then
		t = {}
		S[key] = t
	end
	for i = #t, 1, -1 do t[i] = nil end
	return t
end

function Handle:Blocked(x, y, w, h)
	local pixel = Scale.Pixel(1)
	local clearance = max(4 / pixel, 3)
	for _, frame in ipairs(self.avoid) do
		if frame.textures then frame = frame.used > 0 and frame.textures[1] or EMPTY end
		local shown = self.avoidShown or type(frame.IsShown) == "function" and frame:IsShown()
		if W.IsSecret(shown) then return true end
		if shown then
			local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
			local f = W.ScaleFactor(frame)
			if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then return true end
			l, r, t, b = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel
			local px, py = x / pixel, y / pixel
			if px < r + clearance and l < px + w + clearance and py - h < t + clearance and b < py + clearance then return true end
		end
	end
	return false
end

local function Slot(self)
	local level = (self.kind == "bar" or self.kind == "plate") and self.target:GetFrameLevel()
	if level ~= false and (W.IsSecret(level) or type(level) ~= "number") then return end
	self.used = self.used + 1
	local t = self.textures[self.used]
	if not t then
		if self.kind == "bar" or self.kind == "plate" then
			if not self.host then
				self.host = CreateFrame("Frame", nil, self.owner)
				self.host:SetAllPoints(self.target)
			end
			self.host:SetFrameLevel(level + 1)
			t = W.Crisp(self.host:CreateTexture(nil, "BORDER"))
		else
			t = W.Crisp(self.kind == "corners" and self.owner:CreateTexture(nil, "OVERLAY")
				or self.owner:CreateTexture(nil, "BACKGROUND", nil, self.kind == "ring" and self.used == 1 and -2 or -1))
		end
		self.textures[self.used] = t
	end
	return t
end

function Handle:Place(name, left, top, flipX, flipY, width)
	local spec = ASSETS[name]
	if not spec then return end
	local t = Slot(self)
	if not t then return end
	t.ink, t.inkFlip = (INK.spans[name] or INK.circles[name]) and name or nil, flipX
	local path = PATHS[name]
	if not path then
		path = PATH .. name .. ".png"
		PATHS[name] = path
	end
	local loaded = t:SetTexture(path)
	if not W.IsSecret(loaded) and loaded == false then
		t.placed = false
		t:Hide()
		return t
	end
	local u, v = (name:find("^Forge") and width or spec[1]) / spec[3], spec[2] / spec[4]
	t:SetTexCoord(flipX and u or 0, flipX and 0 or u, flipY and v or 0, flipY and 0 or v)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", self.target, "TOPLEFT", left * self.pixel, -top * self.pixel)
	t:SetSize((width or spec[1]) * self.pixel, spec[2] * self.pixel)
	t.placed = true
	t:Show()
	return t
end

function Handle:Fill(left, top, width, height, color)
	local t = Slot(self)
	if not t then return end
	t.ink, t.inkFlip = nil, nil
	local r, g, b, a = W.Rgba(color)
	t:SetColorTexture(r * a, g * a, b * a, 1)
	t:SetTexCoord(0, 1, 0, 1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", self.target, "TOPLEFT", left * self.pixel, -top * self.pixel)
	t:SetSize(width * self.pixel, height * self.pixel)
	t.placed = true
	t:Show()
	return t
end

function Handle:Spot(name, point, relative, x, y)
	local spec = name and ASSETS[name]
	if not spec then return end
	local originX, originY = self.target:GetLeft(), self.target:GetTop()
	if W.IsSecret(originX) or W.IsSecret(originY) or type(originX) ~= "number" or type(originY) ~= "number" then return end
	local a, b = POINTS[point], POINTS[relative]
	local left = floor(b[1] * self.width + x - a[1] * spec[1] + 0.5)
	local top = floor(b[2] * self.height - y - a[2] * spec[2] + 0.5)
	originX, originY = originX / self.pixel, originY / self.pixel
	left = floor(originX + left + 0.5) - originX
	top = originY - floor(originY - top + 0.5)
	return left, top, originX, originY, spec
end

function Handle:Piece(name, point, relative, x, y, flipX, flipY)
	local left, top, originX, originY, spec = self:Spot(name, point, relative, x, y)
	if not left then return end
	if self.avoid and self:Blocked((originX + left) * Scale.Pixel(1), (originY - top) * Scale.Pixel(1), spec[1], spec[2]) then
		self.blocked = true
		return
	end
	return self:Place(name, left, top, flipX, flipY)
end

local function Shaped(S, ink, flip, l, r, t, b, clear)
	local o = Rec(S)
	o.l, o.r, o.t, o.b, o.clear = l, r, t, b, clear
	local runs = type(ink) == "string" and INK.spans[ink]
	if runs then
		local sx, sy = (r - l) / runs[1], (t - b) / runs[2]
		local spans = o.spanList
		if not spans then
			spans = {}
			o.spanList = spans
		end
		for i = #spans, 1, -1 do spans[i] = nil end
		o.spans = spans
		for i = 3, #runs, 4 do
			local x0, x1 = runs[i + 2] * sx, runs[i + 3] * sx
			local span = Rec(S)
			span.l, span.r, span.t, span.b = flip and r - x1 or l + x0, flip and r - x0 or l + x1, t - runs[i] * sy, t - runs[i + 1] * sy
			spans[#spans + 1] = span
			o.l, o.r = min(o.l, span.l), max(o.r, span.r)
		end
		return o
	end
	local reach = 0
	if type(ink) == "table" then
		for i = 1, #ink, 2 do
			local fraction = INK.circles[ink[i]]
			if not fraction then return o end
			reach = max(reach, fraction / (1 - 2 * ink[i + 1]))
		end
	else
		local fraction = INK.circles[ink]
		if not fraction then return o end
		reach = max(reach, fraction)
	end
	o.cx, o.cy, o.radius = (l + r) / 2, (t + b) / 2, reach * (r - l) / 2 + 1
	return o
end



local function Add(self, S, list, pixel, region, clear, ink, outset)
	local reserved = ink and self.reserve and self.reserve[region]
	local shown, frame = true, region
	while shown and frame and frame ~= self.owner do
		shown = type(frame.IsShown) == "function" and frame:IsShown()
		if W.IsSecret(shown) then return false end
		frame = type(frame.GetParent) == "function" and frame:GetParent() or nil
	end
	if not shown then return true end
	if ink and not reserved and type(region.GetText) == "function" then
		local text = region:GetText()
		if not W.IsSecret(text) and (text == nil or text == "") then return true end
	end
	local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	local f = W.ScaleFactor(region)
	if W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) then return false end
	if l == nil and r == nil and t == nil and b == nil then return true end
	if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then return false end
	if region.ink then
		list[#list + 1] = Shaped(S, region.ink, region.inkFlip, l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel, clear)
		return true
	end
	if ink and not reserved and type(region.GetStringWidth) == "function" then
		local width = region:GetStringWidth()
		if Plain(width) and width < r - l then
			local justify = type(region.GetJustifyH) == "function" and region:GetJustifyH()
			if justify == "LEFT" then r = l + width
			elseif justify == "RIGHT" then l = r - width
			else l, r = (l + r - width) / 2, (l + r + width) / 2 end
		end
	end
	local inkb
	if ink and not reserved and self.kind == "plate" and type(region.GetFont) == "function" then
		local file, size = region:GetFont()
		local text = region:GetText()
		if type(file) == "string" and not W.IsSecret(file) and region.inkFile ~= file then
			region.inkFile, region.inkFont = file, file:match("([^/\\]+)%.[tT][tT][fF]$") or false
		end
		local metrics = region.inkFile == file and region.inkFont and INK.fonts[region.inkFont]
		if metrics and Plain(size) and type(text) == "string" and not W.IsSecret(text) then
			local deep, i, n = 0, 1, #text
			while i <= n do
				local c = text:byte(i)
				local code, step = c, 1
				if c >= 0xF0 then
					code, step = nil, 4
				elseif c >= 0xE0 then
					code, step = nil, 3
				elseif c >= 0xC0 then
					code, step = (c % 32) * 64 + (text:byte(i + 1) or 0) % 64, 2
				end
				local reach = code and (code < 0x250 and (metrics.deep[code] or 0) or metrics.descent) or metrics.descent
				if reach > deep then deep = reach end
				i = i + step
			end
			inkb = b + max(0, metrics.descent - deep) * min(size, (t - b) / (metrics.ascent + metrics.descent))
			local _, drop
			if type(region.GetShadowOffset) == "function" then _, drop = region:GetShadowOffset() end
			if Known(drop) and drop < 0 then inkb = max(b, inkb + drop) end
		end
	end
	outset = outset or 0
	local o = Rec(S)
	o.l, o.r, o.t, o.b, o.clear = (l - outset) * f / pixel, (r + outset) * f / pixel, (t + outset) * f / pixel, (b - outset) * f / pixel, clear
	o.inkb = inkb and inkb * f / pixel or false
	list[#list + 1] = o
	return true
end

local function AddSet(self, S, list, pixel, set, avoid, clear)
	for _, frame in ipairs(set) do
		if frame ~= self.yoke and (frame.blockOf ~= self or not (self.yoke and self.yoke.used > 0)) then
			local textures = frame.textures
			for i = 1, textures and frame.used or 1 do
				local count = #list
				if not Add(self, S, list, pixel, textures and textures[i] or frame, clear or max(4 / pixel, 3)) then return false end
				if #list > count then list[#list].icon, list[#list].other = avoid, not avoid and textures ~= nil end
			end
		end
	end
	return true
end

local function Far(S, list, l, r, t, b, card)
	local o = Rec(S)
	o.l, o.r, o.t, o.b, o.clear, o.card = l, r, t, b, 1, card
	list[#list + 1] = o
end

local function AddNeighbours(self, S, list, pixel)
	local near = self.neighbours
	if type(near) == "function" then near = near() end
	for _, frame in ipairs(near or EMPTY) do
		local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
		local f = W.ScaleFactor(frame)
		local known = not (W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) or W.IsSecret(f))
			and type(l) == "number" and type(r) == "number" and type(t) == "number" and type(b) == "number" and Plain(f)
		if known then
			local o = Rec(S)
			o.l, o.r, o.t, o.b, o.clear, o.cut = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel, 1, self.kind == "bar"
			list[#list + 1] = o
		end
	end
end

function Handle:Obstacles()
	local pixel = Scale.Pixel(1)
	local S = Scratch(self)
	S.nrec = 0
	local list = List(S, "list")
	if not AddSet(self, S, list, pixel, self.avoid or EMPTY, true) then return end
	if not AddSet(self, S, list, pixel, self.others or EMPTY, false) then return end
	if not AddSet(self, S, list, pixel, self.peers or EMPTY, false, 1) then return end
	for _, text in ipairs(self.texts or EMPTY) do
		local count = #list
		if not Add(self, S, list, pixel, text, 1, true) then return end
		if #list > count then list[#list].ink = true end
	end
	for _, bar in ipairs(self.near or EMPTY) do
		if not Add(self, S, list, pixel, bar, 1, false, bar.rimOutset or W.Border(bar)) then return end
	end
	AddNeighbours(self, S, list, pixel)
	if self.kind == "bar" then
		for row in pairs(ROWS) do
			for i = 1, row.used do
				local count = #list
				if not Add(self, S, list, pixel, row.textures[i], max(4 / pixel, 3)) then return end
				if #list > count then list[#list].row = true end
			end
		end
	end
	local card = self.card
	if card and card.visible then
		local frame = card.owner
		local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
		local f = W.ScaleFactor(frame)
		if W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) then return end
		if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then return end
		local inset = card:InsetUnits() - ns.Tokens.Size("gapSmall")
		l, r, t, b = (l + inset) * f / pixel, (r - inset) * f / pixel, (t - inset) * f / pixel, (b + inset) * f / pixel
		local far = 1e6
		Far(S, list, l - far, l, far, -far, true)
		Far(S, list, r, r + far, far, -far, true)
		Far(S, list, -far, far, t + far, t, true)
		Far(S, list, -far, far, b, b - far, true)
	end
	local clip = not self.unbounded and self.owner
	while clip do
		local clips = type(clip.DoesClipChildren) == "function" and clip:DoesClipChildren()
		if W.IsSecret(clips) then return end
		if clips then break end
		local parent = type(clip.GetParent) == "function" and clip:GetParent()
		if W.IsSecret(parent) then parent = nil end
		clip = parent or nil
	end
	if clip then
		local l, r, t, b = clip:GetLeft(), clip:GetRight(), clip:GetTop(), clip:GetBottom()
		local f = W.ScaleFactor(clip)
		if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then return end
		l, r, t, b = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel
		local far = 1e6
		Far(S, list, l - far, l, far, -far)
		Far(S, list, r, r + far, far, -far)
		Far(S, list, -far, far, t + far, t)
		Far(S, list, -far, far, b, b - far)
	end
	return list
end

local INSET = 2
local CAP_SHARE = 0.4

local CREST_SIZES = { 32, 20 }
local ENDS = { Crested = "EndCrested", Winged = "EndWinged", Clawed = "EndClawed", Pointed = "EndPointed" }

local function CutOrder(a, b)
	return a[1] < b[1]
end

local FAMILIES = {
	Crested = { "Crested", "Winged", "Clawed", "Pointed" },
	Winged = { "Winged", "Clawed", "Pointed" },
	Clawed = { "Clawed", "Pointed" },
	Pointed = { "Pointed" },
}
local function Free(list, l, t, w, h)
	for _, o in ipairs(list) do
		local c = o.clear
		if l < o.r + c and o.l < l + w + c and t - h < o.t + c and o.b < t + c then
			if o.radius then
				local dx, dy = max(o.cx - l - w, l - o.cx, 0), max(o.cy - t, t - h - o.cy, 0)
				if dx * dx + dy * dy < (o.radius + c) ^ 2 then return false end
			elseif o.spans then
				for _, s in ipairs(o.spans) do
					if l < s.r + c and s.l < l + w + c and t - h < s.t + c and s.b < t + c then return false end
				end
			else
				return false
			end
		end
	end
	return true
end

function Handle:Family(full)
	if self.light then return "Pointed" end
	if self.kind == "plate" then
		if not full then return "Pointed" end
		if self.boss or self.selected then return "Crested" end
		return self.elite and "Winged" or "Clawed"
	end
	return full and "Clawed" or "Pointed"
end

local function CapFits(pieces, x0, boxW, y0, height, spec, ring, portraitWest)
	local capTop = y0 - floor((height - spec[2]) / 2)
	local west = not (ring and ring.left) and Free(pieces, x0 - spec[1], capTop, spec[1], spec[2])
	local east = not (ring and not ring.left) and Free(pieces, x0 + boxW, capTop, spec[1], spec[2])
	local fits = spec[2] <= height and (west or ring and ring.left or portraitWest == true) and (east or ring and not ring.left or portraitWest == false) and (west or east)
	return fits, capTop, west, east
end

local function Fits(S, west, k, spec, near)
	local ring = S.ringOn and S.ring
	if ring and ring.left == west then return 0 end
	local out = max(k, 0)
	local thickness = S.rim + out
	local x0, y0, boxW, boxH = S.x0, S.y0, S.boxW, S.boxH
	for slide = 0, S.plate and boxH or 0 do
		local extra = S.wrap[west and 1 or 2] + slide
		local from = west and x0 - extra or x0 + boxW + extra - 1
		if slide > 0 and not (Free(S.plain, from, y0 + out, 1, thickness) and Free(S.plain, from, y0 - boxH - out + thickness, 1, thickness)) then return end
		if Free(near, west and x0 - extra - spec[1] or x0 + boxW + extra, y0 + k + floor(spec[5] + 0.5), spec[1], spec[2]) then return extra end
	end
end

local function Clip(list, l, r, b, t)
	for _, o in ipairs(list) do
		local c = o.clear
		if o.icon and l < o.r + c and o.l - c < r and b < o.t + c and o.b - c < t then
			local top, low, right, left = floor(o.b - c), math.ceil(o.t + c), floor(o.l - c), math.ceil(o.r + c)
			local w, h = r - l, t - b
			local least = min((t - top) * w, (low - b) * w, (r - right) * h, (left - l) * h)
			if least == (t - top) * w then t = top
			elseif least == (low - b) * w then b = low
			elseif least == (r - right) * h then r = right
			else l = left end
			if r <= l or t <= b then return end
		end
	end
	return l, r, b, t
end

local function Reachable(n, reach)
	for k = reach, -INSET, -1 do
		if ASSETS[Named(ENDS.Pointed, n + 2 * k)] then return k end
	end
	return -INSET - 1
end

local function Grown(n, rim)
	local most = min(6, 12 - rim)
	return Reachable(n + 1, most) > Reachable(n, most) and n + 1 or n
end

local function Search(S, families, strict, loose)
	local single
	for _, name in ipairs(families) do
		for k = S.reach, -INSET, -1 do
			local endName = Named(ENDS[name], S.boxH + 2 * k)
			local spec = ASSETS[endName]
			if spec then
				local near = not strict and loose or name == "Pointed" and S.pieces or S.hooked
				local west, east = Fits(S, true, k, spec, near), Fits(S, false, k, spec, near)
				S.ncand = S.ncand + 1
				local piece = S.cands[S.ncand]
				if not piece then
					piece = {}
					S.cands[S.ncand] = piece
				end
				piece.name, piece.rise, piece.width, piece.reach, piece.west, piece.east = endName, floor(spec[5] + 0.5), spec[1], k, west, east
				piece.weight = spec[2] * ((west and 1 or 0) + (east and 1 or 0))
				if west and east then
					return piece
				end
				local blocked = S.blocked
				if not single and not S.plate and (west and (blocked[2] or S.portraitWest == false) or east and (blocked[1] or S.portraitWest == true)) then single = piece end
			end
		end
	end
	return single
end

function Handle:Frame(full)
	local pixel = Scale.Pixel(1)
	local left, top, right, bottom = self.target:GetLeft(), self.target:GetTop(), self.target:GetRight(), self.target:GetBottom()
	if not (Known(left) and Known(top) and Known(right) and Known(bottom)) then return end
	local base, joined, upper = self.height, nil, bottom
	local spans = self.spans
	for i = 1, spans and #spans or (self.span and 1 or 0) do
		local span = spans and spans[i] or self.span
		local shown = type(span.IsVisible) == "function" and span:IsVisible()
		if W.IsSecret(shown) then return end
		if shown then
			local low = span:GetBottom()
			if self.swaps and not Known(low) then return end
			if Known(low) and low < bottom and (top - low) / self.pixel <= base * 4 + 0.5 then
				upper, bottom, joined = bottom, low - (span.rimOutset or W.Border(span)), span
			end
		end
	end
	if base < 4 or self.width < 24 or self.target.vertical then return true end
	local list = self:Obstacles()
	if not list then return end
	local S = self.scratch
	S.ncand, S.ncut = 0, 0
	local rim = max(1, floor((self.target.rimOutset or W.Border(self.target)) / self.pixel + 0.5))
	local f = self.factor / pixel
	local ox, oy = left * f, top * f
	local x0, y0 = floor(left * f + 0.5) - rim, floor(top * f + 0.5) + rim
	local boxW = floor(right * f + 0.5) + rim - x0
	local boxH = y0 - (floor(bottom * f + 0.5) - rim) + (joined and 1 or 0)
	if joined and self.kind == "plate" then boxH = Grown(boxH, rim) end
	local h = boxH - 2 * rim
	self.height = h
	local forged = full and self.forged
	local wrap, blocked = S.wrap, S.blocked
	wrap[1], wrap[2], blocked[1], blocked[2] = 0, 0, false, false
	S.rim, S.x0, S.y0, S.boxW, S.boxH, S.plate = rim, x0, y0, boxW, boxH, self.kind == "plate"
	if self.kind == "plate" then
		for _, o in ipairs(list) do
			local mid = (o.t + o.b) / 2
			if o.icon then o.clear = 1 end
			if o.icon and mid < y0 and mid > y0 - boxH then
				blocked[1] = blocked[1] or o.l < x0 + boxH and o.r > x0 - 3 * boxH
				blocked[2] = blocked[2] or o.r > x0 + boxW - boxH and o.l < x0 + boxW + 3 * boxH
			end
			if o.icon and mid < y0 - rim and mid > y0 - boxH + rim then
				if o.r <= x0 and o.l >= x0 - 3 * boxH then
					wrap[1] = max(wrap[1], math.ceil(x0 - o.l) + 1)
				elseif o.l >= x0 + boxW and o.r <= x0 + boxW + 3 * boxH then
					wrap[2] = max(wrap[2], math.ceil(o.r - x0 - boxW) + 1)
				end
			end
		end
	end
	local reach = 0
	local open, bar = list, self.kind == "bar" and not forged
	if not forged then
		open = List(S, "open")
		for _, o in ipairs(list) do
			if not (o.row or bar and o.other) then open[#open + 1] = o end
		end
	end
	if not full and Free(open, x0, y0 + 1, boxW, 1) and Free(open, x0, y0 - boxH, boxW, 1) then reach = 1 end
	if full then
		while rim + reach < 12 and reach < 6 and Free(open, x0, y0 + reach + 1, boxW, 1) and Free(open, x0, y0 - boxH - reach, boxW, 1) do
			reach = reach + 1
		end
	end
	local ring
	local tex = self.yoke and self.yoke.used > 0 and self.yoke.textures[1]
	if tex then
		local l, r, t, b = tex:GetLeft(), tex:GetRight(), tex:GetTop(), tex:GetBottom()
		local scale = W.ScaleFactor(tex)
		if Known(l) and Known(r) and Known(t) and Known(b) and Plain(scale) then
			ring = S.ring
			ring.x, ring.y, ring.r = (l + r) / 2 * scale / pixel, (t + b) / 2 * scale / pixel, (r - l) / 2 * scale / pixel
			ring.left = ring.x < x0 + boxW / 2
		end
	end
	S.ringOn = ring ~= nil
	local portraitWest
	if self.yoke and not ring then
		local l, r = self.yoke.target:GetLeft(), self.yoke.target:GetRight()
		local scale = W.ScaleFactor(self.yoke.target)
		if Known(l) and Known(r) and Plain(scale) then portraitWest = (l + r) / 2 * scale / pixel < x0 + boxW / 2 end
	end
	S.portraitWest = portraitWest
	local plain, pieces, hooked = List(S, "plain"), list, list
	for _, o in ipairs(list) do
		if not o.icon then plain[#plain + 1] = o end
	end
	if forged then
		pieces, hooked = List(S, "pieces"), List(S, "hooked")
		for i, o in ipairs(list) do
			pieces[i] = o.ink and Copy(S, o, max(o.clear, floor(3 / pixel + 0.5))) or o
			hooked[i] = o.row and Copy(S, o, max(o.clear, floor(boxH / 2))) or pieces[i]
		end
	end
	if self.swaps and not joined then
		local span = self.span
		local low = span:GetBottom()
		if not Known(low) and self.spanDrop then low = bottom - self.spanDrop end
		if Known(low) and low < bottom and (top - low) / self.pixel <= base * 4 + 0.5 then
			local k = Reachable(Grown(y0 - (floor((low - (span.rimOutset or W.Border(span))) * f + 0.5) - rim) + 1, rim), reach)
			if k >= 0 then reach = min(reach, k) end
		end
	end
	S.plain, S.pieces, S.hooked, S.reach = plain, pieces, hooked, reach
	local ends = Search(S, FAMILIES[self:Family(full)] or EMPTY, forged)
	if forged then
		local least = Search(S, FAMILIES.Pointed, false, list)
		if least and (not ends or ends.weight < least.weight) then ends = least end
	end
	local solid = self.target.solidRim
	if solid and ends and ends.reach < 1 then ends = nil end
	reach = ends and max(ends.reach, 0) or ((not full or solid) and reach or 0)
	wrap[1], wrap[2] = ends and ends.west or 0, ends and ends.east or 0
	local caps
	if self.kind == "bar" and not self.light and (not ends or full and ends.name:find("Pointed", 1, true)) then
		local family = full and not forged and "Wing" or "Arrow"
		local tiers = List(S, "tiers")
		tiers[1] = Tier(family, boxH)
		for n = forged and boxH - 1 or 0, 6, -1 do
			local name = Tier(family, n)
			if name and name ~= tiers[#tiers] then tiers[#tiers + 1] = name end
		end
		local second = forged and joined and y0 - (floor(upper * f + 0.5) - rim) or nil
		local least
		if full and not forged then
			if ends then
				least = ASSETS[ends.name]
			else
				local arrow = Tier("Arrow", boxH)
				local spec = arrow and ASSETS[arrow]
				if spec and CapFits(pieces, x0, boxW, y0, boxH, spec, ring, portraitWest) then
					least, tiers[#tiers + 1] = spec, arrow
				end
			end
		end
		for _, name in ipairs(tiers) do
			local spec = ASSETS[name]
			for pass = 1, second and 2 or 1 do
				local height = pass == 1 and boxH or second
				local fits, capTop, west, east = CapFits(pieces, x0, boxW, y0, height, spec, ring, portraitWest)
				local smaller = forged and (ends and spec[2] < ASSETS[ends.name][2] or capTop <= floor(upper * f + 0.5))
					or least and (spec[2] < least[2] or spec[2] == least[2] and spec[1] < least[1])
					or not forged and spec[2] < CAP_SHARE * height
				if not smaller and fits then
					caps = S.caps
					caps.name, caps.top, caps.width, caps.west, caps.east = name, capTop, spec[1], west, east
					ends, wrap[1], wrap[2] = nil, 0, 0
					break
				end
			end
			if caps then break end
		end
	end
	local thickness = full and max(1, rim + reach - 1) or 1
	if self.kind == "plate" then thickness = min(thickness, max(reach, 1)) end
	while thickness > 1 and not ASSETS[Named("Rail", thickness)] do thickness = thickness - 1 end
	local dx = x0 - ox
	local touching, loose = List(S, "touching"), List(S, "loose")
	for _, o in ipairs(plain) do
		if not (o.row or o.cut or bar and o.other) then
			touching[#touching + 1] = Copy(S, o, o.ink and self.kind == "plate" and 0 or o.clear)
			if o.inkb then touching[#touching].b = o.inkb end
			if not o.card then loose[#loose + 1] = touching[#touching] end
		end
	end
	local fenced = List(S, "fenced")
	for i, o in ipairs(loose) do fenced[i] = o end
	for _, o in ipairs(list) do
		if o.icon then fenced[#fenced + 1] = o end
	end
	local railName = Named("Rail", thickness)
	local lanes = S.lanes
	local out = self.kind == "plate" and max(reach, thickness) or full and reach or max(reach, 1)
	lanes[1][1], lanes[1][2], lanes[1][3] = railName, thickness, y0 + out
	lanes[2][1], lanes[2][2], lanes[2][3] = railName, thickness, y0 - boxH - out + thickness
	if forged then
		local least = pixel <= 2 / 3 and 3 or 2
		local want = max(least, min(8, floor(3 / pixel + 0.5), floor(boxH / 5)))
		for side = 1, 2 do
			for size = want, least, -1 do
				local edge = side == 1 and y0 - rim + 1 + size or y0 - boxH + rim - 1
				local forge = Named("Forge", size)
				if ASSETS[forge] and Free(touching, x0 - wrap[1], edge, boxW + wrap[1] + wrap[2], size) then
					lanes[side][1], lanes[side][2], lanes[side][3] = forge, size, edge
					break
				end
			end
		end
	end
	local weights = self.weights
	if not weights then
		weights = {}
		self.weights = weights
	end
	weights[1], weights[2] = nil, nil
	local reached1, reached2 = false, false
	for side = 1, 2 do
		local lane = lanes[side]
		local rail, weight, edge = lane[1], lane[2], lane[3]
		local railed = ASSETS[rail] ~= nil
		local isForge = rail:find("^Forge") ~= nil
		local from, to = x0 - wrap[1], x0 + boxW + wrap[2]
		local yoke = ring and isForge and self.yoke.target
		local gl, gr, gs = yoke and yoke:GetLeft(), yoke and yoke:GetRight(), yoke and W.ScaleFactor(yoke)
		if yoke and Known(gl) and Known(gr) and Plain(gs) then
			local far = max(math.abs(edge - ring.y), math.abs(edge - weight - ring.y))
			local near = (edge - ring.y) * (edge - weight - ring.y) < 0 and 0 or min(math.abs(edge - ring.y), math.abs(edge - weight - ring.y))
			local gilt = (gr - gl) * gs / pixel / 2 + 1
			local chord = near < gilt and math.sqrt(gilt * gilt - near * near) or gilt
			local stop = ring.left and math.ceil(ring.x + chord) + 1 or floor(ring.x - chord) - 1
			if (stop - ring.x) ^ 2 + far * far < (ring.r - 1) ^ 2 then
				if ring.left and stop < from and Free(fenced, stop, edge, from - stop, weight) then
					from = stop
				elseif not ring.left and stop > to and Free(fenced, to, edge, stop - to, weight) then
					to = stop
				end
			end
		elseif ring then
			local d = max(math.abs(edge - ring.y), math.abs(edge - weight - ring.y))
			if d < ring.r then
				local chord = math.sqrt(ring.r * ring.r - d * d)
				if ring.left then
					local touch = floor(ring.x + chord)
					if touch < from and Free(forged and fenced or list, touch, edge, from - touch, weight) then from = touch end
				else
					local touch = math.ceil(ring.x - chord)
					if touch > to and Free(forged and fenced or list, to, edge, touch - to, weight) then to = touch end
				end
			end
		end
		local cuts = List(S, "cuts")
		local pool = S.cutPool
		if not pool then
			pool = {}
			S.cutPool = pool
		end
		for _, o in ipairs(list) do
			local split = o.row or o.cut or bar and o.other or self.kind == "plate" and o.ink
			local clear = (forged or split) and 1 or o.clear
			if (o.icon or split) and from < o.r + clear and o.l - clear < to and edge - weight < o.t + clear and (o.inkb or o.b) - clear < edge then
				S.ncut = S.ncut + 1
				local cut = pool[S.ncut]
				if not cut then
					cut = {}
					pool[S.ncut] = cut
				end
				cut[1], cut[2], cut[3] = floor(o.l - clear), math.ceil(o.r + clear), split
				cuts[#cuts + 1] = cut
			end
		end
		table.sort(cuts, CutOrder)
		if cuts[1] and cuts[1][1] - from <= 1 then reached1 = true end
		if cuts[#cuts] and to - cuts[#cuts][2] <= 1 then reached2 = true end
		local start = from
		for i = 1, #cuts + 1 do
			local stop = cuts[i] and min(cuts[i][1], to) or to
			local beside = cuts[i] and cuts[i][3] or i > 1 and cuts[i - 1][3]
			local shortest = beside and max(1, ends and ends.width or caps and caps.width or 1) or 1
			if railed and stop - start >= shortest and Free(yoke and loose or touching, start, edge, stop - start, weight) then
				local x, length, piece = start, stop - start, ASSETS[rail][1]
				local tipName = isForge and Named("Tip", weight)
				local tip = tipName and ASSETS[tipName]
				if tip and length >= 2 * tip[1] + 2 then
					self:Place(tipName, x - ox, oy - edge, false, side == 2)
					self:Place(tipName, x + length - tip[1] - ox, oy - edge, true, side == 2)
					x, length = x + tip[1], length - 2 * tip[1]
				end
				while length > 0 do
					local run = isForge and min(length, piece) or length
					self:Place(rail, x - ox, oy - edge, false, side == 2, run)
					x, length = x + run, length - run
				end
				weights[side] = rail
				if start == from then reached1 = true end
				if stop == to then reached2 = true end
			end
			if cuts[i] then start = max(start, cuts[i][2]) end
		end
	end
	if full and weights[1] and weights[1]:find("^Forge") then
		local weight, edge = lanes[1][2], lanes[1][3]
		local margin = floor(2 / pixel + 0.5)
		local guard = List(S, "guard")
		for i, o in ipairs(pieces) do guard[i] = o end
		for _, text in ipairs(self.texts or EMPTY) do
			local l, r, t, b, sc = text:GetLeft(), text:GetRight(), text:GetTop(), text:GetBottom(), W.ScaleFactor(text)
			if Known(l) and Known(r) and Known(t) and Known(b) and Plain(sc) then
				local o = Rec(S)
				o.l, o.r, o.t, o.b, o.clear = l * sc / pixel, r * sc / pixel, t * sc / pixel, b * sc / pixel, floor(3 / pixel + 0.5)
				guard[#guard + 1] = o
			end
		end
		for _, n in ipairs(CREST_SIZES) do
			local name = Named("Crest", n)
			local spec = ASSETS[name]
			local cx = spec and floor(x0 + (boxW - spec[1]) / 2 + 0.5)
			if spec and n <= 6 * weight + 2 and Free(guard, cx - margin, edge - 1 + spec[2] + margin, spec[1] + 2 * margin, spec[2] + 2 * margin) then
				self:Place(name, cx - ox, oy - edge + 1 - spec[2])
				break
			end
		end
	end
	if caps then
		if caps.west then self:Place(caps.name, dx - caps.width, oy - caps.top) end
		if caps.east then self:Place(caps.name, dx + boxW, oy - caps.top, true) end
	end
	if ends then
		local tip = oy - y0 - ends.reach - ends.rise
		local west = ends.west and not (ring and ring.left) and (reached1 or wrap[1] == 0)
		local east = ends.east and not (ring and not ring.left) and (reached2 or wrap[2] == 0)
		if S.plate and not (west and east) then west, east = false, false end
		if west then self:Place(ends.name, dx - wrap[1] - ends.width, tip) end
		if east then self:Place(ends.name, dx + boxW + wrap[2], tip, true) end
	end
	if S.plate and (wrap[1] > 0 or wrap[2] > 0) then
		local l, t, r, b
		if joined then
			local outset = joined.rimOutset or W.Border(joined)
			local sl, st, sr, sb = joined:GetLeft(), joined:GetTop(), joined:GetRight(), joined:GetBottom()
			if Known(sl) and Known(st) and Known(sr) and Known(sb) then
				l, t, r, b = floor((sl - outset) * f + 0.5), floor((st + outset) * f + 0.5), floor((sr + outset) * f + 0.5), floor((sb - outset) * f + 0.5)
			end
		end
		if l or not joined then
			local roof = weights[1] and min(y0, lanes[1][3] - lanes[1][2]) or y0
			local low = max(b or floor(upper * f + 0.5) - rim, weights[2] and lanes[2][3] or -math.huge)
			for side = 1, 2 do
				if wrap[side] > 0 then
					local cl = side == 1 and x0 - wrap[1] or max(x0 + boxW, r or x0 + boxW)
					local cr = side == 1 and min(x0, l or x0) or x0 + boxW + wrap[2]
					local fl, fr, fb, ft = Clip(list, cl, cr, low, roof)
					if fl == cl and fr == cr and fb == low and ft == roof then
						self:Fill(cl - ox, oy - roof, cr - cl, roof - low, self.target.backgroundName or "track")
					elseif l then
						fl, fr, fb, ft = Clip(list, side == 1 and x0 - wrap[1] or r, side == 1 and l or x0 + boxW + wrap[2], b, t)
						if fl and fr > fl then self:Fill(fl - ox, oy - ft, fr - fl, ft - fb, joined.backgroundName or "track") end
					end
				end
			end
		end
	end
	if self.swaps then
		self.textures.reach = reach
		local idle = joined and self.sets and self.sets[false]
		if joined then self.spanDrop = upper - joined:GetBottom() end
		if idle and idle.reach ~= reach then idle.epoch = nil end
	end
	return true
end

local HOLES = { 14, 17, 20, 24, 28, 32, 38, 44, 52, 60, 70, 80 }

function Handle:Rank(family, flipX)
	local hole = min(self.width, self.height) / 2 + 1
	local index = #HOLES
	for i = #HOLES, 1, -1 do
		if HOLES[i] >= hole then index = i end
	end
	while index > 1 and not ASSETS[Named(family, HOLES[index])] do index = index - 1 end
	local name = Named(family, HOLES[index])
	local spec = ASSETS[name]
	if not spec or not spec[6] then return end
	self:Piece(name, "TOPLEFT", "CENTER", -(flipX and spec[1] - spec[5] or spec[5]), spec[6], flipX)
end

function Handle:Ring(full)
	local side = min(self.width, self.height)
	if side < 24 or not full then return end
	local ring = ASSETS[Named("Ring", side)] and side or floor((side + 1) / 2) * 2
	while ring > 24 and not ASSETS[Named("Ring", ring)] do ring = ring - 1 end
	self:Piece(Named("Ring", ring), "CENTER", "CENTER", 0, 0, self.mirror)
	if not full or self.player then return end
	if self.boss then
		self:Rank("BossPendantR")
	elseif self.elite then
		self:Rank("ElitePendantR")
	end
end

local function MapObstacles(self, pixel)
	local S = Scratch(self)
	S.nrec = 0
	local list = List(S, "list")
	for _, text in ipairs(self.texts or EMPTY) do
		if not Add(self, S, list, pixel, text, 1, true) then return end
	end
	AddNeighbours(self, S, list, pixel)
	return list
end

function Handle:Clear(list, name, point, relative, x, y, flipX, flipY)
	local left, top, originX, originY, spec = self:Spot(name, point, relative, x, y)
	if not left then return false end
	if #list == 0 then return true end
	local pl, pt, runs = originX + left, originY - top, INK.spans[name]
	if not runs then return Free(list, pl, pt, spec[1], spec[2]) end
	for i = 3, #runs, 4 do
		local r0, r1, x0, x1 = runs[i], runs[i + 1], runs[i + 2], runs[i + 3]
		if flipX then x0, x1 = spec[1] - x1, spec[1] - x0 end
		if flipY then r0, r1 = spec[2] - r1, spec[2] - r0 end
		if not Free(list, pl + x0, pt - r0, x1 - x0, r1 - r0) then return false end
	end
	return true
end

function Handle:MapPair(list, n, bottom)
	local wanted = n
	while true do
		local name = Tier("Map", wanted)
		if not name then return end
		local size = ASSETS[name][2]
		local outset = floor(size * 0.4)
		local y = bottom and -outset or outset
		local west, east = bottom and "BOTTOMLEFT" or "TOPLEFT", bottom and "BOTTOMRIGHT" or "TOPRIGHT"
		if self:Clear(list, name, west, west, -outset, y, false, bottom) and self:Clear(list, name, east, east, outset, y, true, bottom) then
			self:Piece(name, west, west, -outset, y, false, bottom)
			self:Piece(name, east, east, outset, y, true, bottom)
			return name
		end
		wanted = size - 1
	end
end

function Handle:Map(full)
	local side = min(self.width, self.height)
	local n = side >= 280 and 40 or side >= 150 and 24 or 16
	if not full then n = n == 40 and 32 or n == 24 and 20 or 12 end
	local list = MapObstacles(self, Scale.Pixel(1))
	if not list then return end
	self:MapPair(list, n, false)
	if side >= 280 then
		self:MapPair(list, n, true)
		local point = Tier("Point", 12)
		if full and point and self:Clear(list, point, "TOP", "BOTTOM", 0, -1) then self:Piece(point, "TOP", "BOTTOM", 0, -1) end
	end
end

local CORNER_SIZES = { 40, 32, 24, 20, 16, 12 }

function Handle:Corners(full)
	local block, chrome = self.block, self.chrome
	if not full or not (chrome and chrome.visible) then return end
	local found = block and block:Obstacles() or not block and EMPTY
	if not found then return end
	local pixel = Scale.Pixel(1)
	local S = Scratch(self)
	S.nrec = 0
	local list = List(S, "corners")
	for _, o in ipairs(found) do
		if not o.card then list[#list + 1] = o end
	end
	for _, region in ipairs(self.inside or EMPTY) do
		local l, r, t, b, f = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom(), W.ScaleFactor(region)
		if W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) then return end
		if Known(l) and Known(r) and Known(t) and Known(b) and Plain(f) then
			local o = Rec(S)
			o.l, o.r, o.t, o.b, o.clear = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel, 1
			list[#list + 1] = o
		end
	end
	for _, bar in ipairs(self.bars or EMPTY) do
		local shown = type(bar.IsVisible) == "function" and bar:IsVisible()
		if W.IsSecret(shown) then return end
		local l, r, t, b, f = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom(), W.ScaleFactor(bar)
		if shown and Known(l) and Known(r) and Known(t) and Known(b) and Plain(f) then
			local rim = bar.rimOutset or W.Border(bar)
			local o = Rec(S)
			o.l, o.r, o.t, o.b, o.clear = (l - rim) * f / pixel, (r + rim) * f / pixel, (t + rim) * f / pixel, (b - rim) * f / pixel, 1
			list[#list + 1] = o
		end
	end
	local left, top = self.target:GetLeft(), self.target:GetTop()
	if not (Known(left) and Known(top)) then return end
	left, top = left * self.factor / pixel, top * self.factor / pixel
	for _, n in ipairs(CORNER_SIZES) do
		local name = Named("Corner", n)
		local spec = ASSETS[name]
		local out = 0
		if spec and n * 3 <= self.height * 2 then
			local w, h = spec[1], spec[2]
			local fits = true
			for corner = 1, 4 do
				local x = (corner == 1 or corner == 3) and left - out or left + self.width + out - w
				local y = corner <= 2 and top + out or top - self.height - out + h
				fits = fits and Free(list, floor(x + 0.5), floor(y + 0.5), w, h)
			end
			if fits then
				self:Piece(name, "TOPLEFT", "TOPLEFT", -out, out)
				self:Piece(name, "TOPRIGHT", "TOPRIGHT", out, out, true)
				self:Piece(name, "BOTTOMLEFT", "BOTTOMLEFT", -out, -out, false, true)
				self:Piece(name, "BOTTOMRIGHT", "BOTTOMRIGHT", out, -out, true, true)
				return
			end
		end
	end
end

local CREST_SHARE, CREST_SINK, CREST_WIDTH, CREST_HEIGHT = 0.06, 0.25, 180, 64
local WINDOW_CRESTS = { 64, 48, 32, 20 }

function Handle:Crest(full)
	local pixel = Scale.Pixel(1)
	local height = self.height
	if self.body then
		local top, bottom, f = self.target:GetTop(), self.body:GetBottom(), W.ScaleFactor(self.body)
		if not (Known(top) and Known(bottom) and Plain(f)) then return end
		height = (top * self.factor - bottom * f) / pixel
	end
	if not full or not self.span and self.width * pixel < CREST_WIDTH or height * pixel < CREST_HEIGHT then return end
	if self.bottom then
		local bottom = type(self.target.GetBottom) == "function" and self.target:GetBottom()
		local name = Tier("Keystone", self.pixel > 0.8 and 8 or 12)
		if name and Known(bottom) and bottom * self.factor / Scale.Pixel(1) > ASSETS[name][2] + 1 then
			self:Piece(name, "TOP", "BOTTOM", 0, 0)
		end
		return
	end
	if not self.inside or not next(self.inside) then return end
	local root = Scale.Root()
	local top, left, right = self.target:GetTop(), self.target:GetLeft(), self.target:GetRight()
	local rootTop, rootRight = root:GetTop(), root:GetRight()
	if not (Known(top) and Known(right) and Plain(rootTop) and Plain(rootRight) and Known(left)) then return end
	local S = Scratch(self)
	S.nrec = 0
	local list = List(S, "crest")
	for _, region in ipairs(self.inside) do
		local shown = type(region.IsVisible) ~= "function" or region:IsVisible()
		local l, r, t, b, f = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom(), W.ScaleFactor(region)
		if W.IsSecret(shown) or W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) then return end
		if shown and (l ~= nil or r ~= nil or t ~= nil or b ~= nil) then
			if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then return end
			local o = Rec(S)
			o.l, o.r, o.t, o.b, o.clear = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel, 1
			list[#list + 1] = o
		end
	end
	local edge, origin = top * self.factor / pixel, left / self.pixel
	local above = List(S, "above")
	for card in pairs(W.Cards) do
		local owner = card.owner
		if card ~= self.chrome and card.visible then
			local shown = owner:IsVisible()
			local l, r, t, b, f = owner:GetLeft(), owner:GetRight(), owner:GetTop(), owner:GetBottom(), W.ScaleFactor(owner)
			if not W.IsSecret(shown) and shown and Known(l) and Known(r) and Known(t) and Known(b) and Plain(f) and b * f / pixel - edge > 0.5 then
				local reach = card.shadowState and ns.Tokens.Size("shadow") * f / pixel or 0
				local o = Rec(S)
				o.l, o.r, o.t, o.b, o.clear = l * f / pixel - reach, r * f / pixel + reach, t * f / pixel + reach, b * f / pixel - reach, 1
				above[#above + 1] = o
			end
		end
	end
	for _, n in ipairs(WINDOW_CRESTS) do
		local name = Named("Crest", n)
		local spec = ASSETS[name]
		if spec and (self.span and spec[1] * self.span <= self.width or not self.span and n <= self.width * CREST_SHARE) then
			local x, sink = floor(origin + floor(self.width / 2 - spec[1] / 2 + 0.5) + 0.5), floor(spec[2] * CREST_SINK)
			if rootTop / pixel - edge >= spec[2] - sink and x >= 0 and x + spec[1] <= rootRight / pixel and Free(list, x, floor(edge + 0.5), spec[1], sink) and Free(above, x, floor(edge + 0.5) - sink + spec[2], spec[1], spec[2]) then
				self:Piece(name, "BOTTOM", "TOP", 0, -sink)
				return
			end
		end
	end
end

function Handle:Row(full)
	if not self.keystone or self.width < 240 or not self.pair or self.pairEnabled == false then return end
	local other = self.pair
	local left, right, bottom = self.target:GetLeft(), self.target:GetRight(), self.target:GetBottom()
	local otherLeft, otherRight, top = other:GetLeft(), other:GetRight(), other:GetTop()
	if not (Known(left) and Known(right) and Known(bottom) and Known(otherLeft) and Known(otherRight) and Known(top)) then return end
	local factor, pixel = W.ScaleFactor(other), Scale.Pixel(1)
	if not Plain(factor) or not Plain(pixel) then return end
	if math.abs(left * self.factor - otherLeft * factor) > pixel
		or math.abs(right * self.factor - otherRight * factor) > pixel then return end
	local ownTop, otherBottom = self.target:GetTop(), other:GetBottom()
	if not Known(ownTop) or not Known(otherBottom) or not Plain(self.pairGap) then return end
	local gap = floor((otherBottom * factor - ownTop * self.factor) / pixel + 0.5)
	if gap < 0 or math.abs(gap - floor(self.pairGap / self.pixel + 0.5)) > 1 then return end
	local height = floor((top * factor - bottom * self.factor) / pixel + 0.5)
	if height < self.height or height > self.height * 3 then return end
	local up = (height - self.height) / 2
	local S = Scratch(self)
	S.nrec = 0
	local bars = List(S, "rowBars")
	for bar in pairs(BARS) do
		local target = bar.target
		local shown = target and type(target.IsVisible) == "function" and target:IsVisible()
		if W.IsSecret(shown) then return end
		if shown then
			local l, r, t, b, f = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom(), W.ScaleFactor(target)
			if Known(l) and Known(r) and Known(t) and Known(b) and Plain(f) then
				local rim = target.rimOutset or W.Border(target)
				local o = Rec(S)
				o.l, o.r, o.t, o.b, o.clear = (l - rim) * f / pixel, (r + rim) * f / pixel, (t + rim) * f / pixel, (b - rim) * f / pixel, 1
				bars[#bars + 1] = o
			end
		end
	end
	local wanted = min(full and 96 or 32, full and height or floor(height * 0.4))
	local name, spec
	while true do
		name = Tier(full and "Tray" or "Arrow", wanted)
		spec = name and ASSETS[name]
		if not spec then break end
		local clear = true
		local originX, originY = left * self.factor / pixel, ownTop * self.factor / pixel
		local finialTop = floor(originY - floor(self.height / 2 - up - spec[2] / 2 + 0.5) + 0.5)
		local finialBottom = finialTop - spec[2]
		local clearance = max(4 / pixel, 3)
		for _, blocker in ipairs(self.avoidBars or EMPTY) do
			local l, r, t, b = blocker:GetLeft(), blocker:GetRight(), blocker:GetTop(), blocker:GetBottom()
			local f = W.ScaleFactor(blocker)
			if not (Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)) then
				clear = false
				break
			end
			l, r, t, b = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel
			if r <= l or t <= b then
				clear = false
				break
			end
			if finialBottom < t and b < finialTop then
				for side = 1, 2 do
					local x = side == 1 and floor(originX - 2 - spec[1] + 0.5) or floor(originX + self.width + 2 + 0.5)
					if x < r + clearance and l < x + spec[1] + clearance then
						clear = false
						break
					end
				end
			end
			if not clear then break end
		end
		if not clear then break end
		for side = 1, 2 do
			local x = side == 1 and floor(originX - 2 - spec[1] + 0.5) or floor(originX + self.width + 2 + 0.5)
			if not Free(bars, x, finialTop, spec[1], spec[2]) then
				clear = false
				break
			end
		end
		if clear then
			self:Piece(name, "RIGHT", "LEFT", -2, up)
			self:Piece(name, "LEFT", "RIGHT", 2, up, true)
			break
		end
		wanted = spec[2] - 1
	end
	if full and self.height >= 30 then
		local avoid = List(Scratch(self), "avoid")
		avoid[1] = other
		for i, bar in ipairs(self.avoidBars or EMPTY) do avoid[i + 1] = bar end
		self.avoid, self.avoidShown = avoid, true
		local keystone = Tier("Keystone", self.height >= 50 and 12 or 6)
		local kx, ky, kox, koy, kspec = self:Spot(keystone, "TOP", "BOTTOM", 0, -1)
		if kx and Free(bars, kox + kx, koy - ky, kspec[1], kspec[2]) then
			self:Piece(keystone, "TOP", "BOTTOM", 0, -1)
		end
		self.avoid, self.avoidShown = nil, nil
	end
end

local function Spanned(self)
	local shown = self.span:IsVisible()
	if W.IsSecret(shown) then return nil end
	return shown and true or false
end

local function Select(self, key)
	if key == self.key then return false end
	local textures = self.textures
	if self.key == nil then
		self.key, textures.epoch = key, nil
		return true
	end
	local sets = self.sets or {}
	self.sets = sets
	textures.used = self.used
	sets[self.key] = textures
	for i = 1, self.used do textures[i]:Hide() end
	textures = sets[key] or { used = 0 }
	self.key, self.textures, self.used = key, textures, textures.used
	return true
end

local function Draw(self)
	self.textures.epoch = nil
	if self.hold then return end
	local visible = self.owner:IsVisible()
	if not W.IsSecret(visible) and not visible then
		self.stale = true
		return
	end
	self.stale = nil
	if not W.MayMove(self.owner) then
		if not self.queued then
			self.queued = true
			if not self.requeue then
				self.requeue = function()
					self.queued = false
					self:Restyle()
				end
			end
			ns.Combat.Queue(self.requeue)
		end
		return
	end
	self.used = 0
	local level = W.Setting("ornaments")
	if level == "Off" or W.Setting("cardMaterial") == "Glass" or self.enabled == false or self.joined then
		for _, texture in ipairs(self.textures) do texture:Hide() end
		return
	end
	local width, height = self.target:GetWidth(), self.target:GetHeight()
	local factor = W.ScaleFactor(self.owner)
	local done = false
	if Plain(width) and Plain(height) and Plain(factor) then
		self.pixel, self.factor = Scale.Pixel(1) / factor, factor
		if Plain(self.pixel) then
			self.width, self.height = floor(width / self.pixel + 0.5), floor(height / self.pixel + 0.5)
			local full = level == "Full"
			done = true
			if self.kind == "bar" or self.kind == "plate" then done = self:Frame(full)
			elseif self.kind == "ring" then self:Ring(full)
			elseif self.kind == "map" then self:Map(full)
			elseif self.kind == "crest" then self:Crest(full)
			elseif self.kind == "corners" then self:Corners(full)
			elseif self.kind == "row" then self:Row(full)
			elseif self.kind == "plaque" and full then
				local name = Tier("Plaque", self.height + 4)
				if name and ASSETS[name][2] + 2 >= self.height then
					self:Piece(name, "CENTER", "CENTER", 0, 0)
				end
			end
		end
	end
	for i = self.used + 1, #self.textures do self.textures[i]:Hide() end
	self.textures.epoch = done and self.epoch or nil
	if self.swaps then
		if done then
			self.tries = nil
		elseif (self.tries or 0) < 3 then
			self.tries = (self.tries or 0) + 1
			if not self.retry then
				self.retry = function()
					if self.textures.epoch ~= self.epoch and Spanned(self) == self.key then Draw(self) end
				end
			end
			C_Timer.After(0, self.retry)
		end
	end
	for _, dependent in ipairs(self.dependents or EMPTY) do dependent:Restyle() end
	if self.kind == "row" then
		for bar in pairs(BARS) do bar:Restyle() end
	end
end

function Handle:Restyle()
	self.epoch, self.tries = (self.epoch or 0) + 1, nil
	if self.swaps then
		local key = Spanned(self)
		if key ~= nil then Select(self, key) end
	end
	Draw(self)
end

function Handle:Swap()
	local key = Spanned(self)
	if key == nil then return self:Restyle() end
	if not Select(self, key) then return end
	self.tries = nil
	local textures = self.textures
	if textures.epoch ~= self.epoch then return Draw(self) end
	for i = 1, self.used do
		if textures[i].placed then textures[i]:Show() end
	end
end

function Handle:Yield(frame)
	local l, r, t, b, f
	if frame then
		l, r, t, b, f = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom(), W.ScaleFactor(frame)
	end
	local known = frame and Known(l) and Known(r) and Known(t) and Known(b) and Plain(f)
	local own, gap = W.ScaleFactor(self.owner), max(4, 3 * Scale.Pixel(1))
	for i = 1, self.used do
		local texture = self.textures[i]
		local hide = not known or not Plain(own)
		if not hide then
			local tl, tr, tt, tb = texture:GetLeft(), texture:GetRight(), texture:GetTop(), texture:GetBottom()
			hide = not (Known(tl) and Known(tr) and Known(tt) and Known(tb))
				or (tl * own < r * f + gap and l * f < tr * own + gap and tb * own < t * f + gap and b * f < tt * own + gap)
		end
		if hide then texture:Hide() end
	end
end

function Handle:Follow()
	if self.enabled == false or W.Setting("ornaments") == "Off" or W.Setting("cardMaterial") == "Glass" or not W.MayMove(self.owner) then return end
	if not Plain(self.pixel) then self:Restyle() return end
	local x, y = self.target:GetLeft(), self.target:GetTop()
	if W.IsSecret(x) or W.IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then
		self.lastX, self.lastY = nil, nil
		if self.used > 0 then self:Restyle() end
		return
	end
	x, y = floor(x / self.pixel + 0.5), floor(y / self.pixel + 0.5)
	if x ~= self.lastX or y ~= self.lastY then
		self.lastX, self.lastY = x, y
		self:Restyle()
	end
end

function W.IsOrnament(widget)
	return getmetatable(widget) == Handle
end

function W.OrnamentExtent(roots)
	local found = {}
	W.RestyleUnder(roots, function(widget)
		if getmetatable(widget) ~= Handle then return false end
		widget.unbounded = true
		found[#found + 1] = widget
		return true
	end)
	local l, r, t, b
	for _, handle in ipairs(found) do
		handle.unbounded = nil
		for i = 1, handle.used do
			local texture = handle.textures[i]
			if texture:IsVisible() then
				local x0, x1, y1, y0, f = texture:GetLeft(), texture:GetRight(), texture:GetTop(), texture:GetBottom(), W.ScaleFactor(texture)
				if Known(x0) and Known(x1) and Known(y0) and Known(y1) and Plain(f) then
					x0, x1, y0, y1 = x0 * f, x1 * f, y0 * f, y1 * f
					l, r, t, b = min(l or x0, x0), max(r or x1, x1), max(t or y1, y1), min(b or y0, y0)
				end
			end
		end
	end
	if #found > 0 then W.RestyleUnder(roots, W.IsOrnament) end
	return l, r, t, b
end

function W.Ornament(owner, kind, target, passive)
	target = target or owner
	local handle = setmetatable({ owner = owner, target = target, kind = kind, textures = {}, used = 0 }, Handle)
	if kind == "bar" then BARS[handle] = true elseif kind == "row" then ROWS[handle] = true end
	if not passive and type(target.HookScript) == "function" then
		target:HookScript("OnSizeChanged", function() handle:Restyle() end)
		if target ~= owner then
			target:HookScript("OnShow", function()
				handle.enabled = true
				handle:Restyle()
			end)
			target:HookScript("OnHide", function()
				handle.enabled = false
				handle:Restyle()
			end)
		end
	end
	local function wake()
		if handle.stale then handle:Restyle() end
		if kind == "bar" then
			for row in pairs(ROWS) do
				if not W.MayMove(row.owner) then row:Yield(handle.target) end
				row:Restyle()
			end
		end
	end
	local function hidden()
		for row in pairs(ROWS) do row:Restyle() end
	end
	local frame = owner
	while frame and frame ~= UIParent do
		if type(frame.HookScript) == "function" then
			frame:HookScript("OnShow", wake)
			if kind == "bar" then frame:HookScript("OnHide", hidden) end
		end
		frame = type(frame.GetParent) == "function" and frame:GetParent() or nil
	end
	handle:Restyle()
	if passive then return handle end
	return W.Track(handle)
end
