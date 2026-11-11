-- Ornaments.lua: optional painted attachments authored at native texel sizes, outside existing content.
local _, ns = ...

local W, Scale = ns.Widgets, ns.Scale
local floor, min, max = math.floor, math.min, math.max
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

local function Tier(family, wanted)
	local selected
	for _, n in ipairs({ 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 64, 80, 96 }) do
		if n <= wanted and ASSETS[family .. n] then selected = family .. n end
	end
	return selected
end

function Handle:Blocked(x, y, w, h)
	local pixel = Scale.Pixel(1)
	local clearance = max(4 / pixel, 3)
	for _, frame in ipairs(self.avoid) do
		if frame.textures then frame = frame.used > 0 and frame.textures[1] or {} end
		local shown = self.avoidShown or type(frame.IsShown) == "function" and frame:IsShown()
		if W.IsSecret(shown) then return true end
		if shown then
			local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
			local f = W.ScaleFactor(frame)
			if not (Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(f)) then return true end
			l, r, t, b = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel
			local px, py = x / pixel, y / pixel
			if px < r + clearance and l < px + w + clearance and py - h < t + clearance and b < py + clearance then return true end
		end
	end
	return false
end

function Handle:Place(name, left, top, flipX, flipY, width)
	local spec = ASSETS[name]
	if not spec then return end
	self.used = self.used + 1
	local t = self.textures[self.used]
	if not t then
		if self.kind == "bar" or self.kind == "plate" then
			if not self.host then
				self.host = CreateFrame("Frame", nil, self.owner)
				self.host:SetAllPoints(self.target)
			end
			self.host:SetFrameLevel(self.target:GetFrameLevel() + 1)
			t = W.Crisp(self.host:CreateTexture(nil, "BORDER"))
		else
			t = W.Crisp(self.kind == "corners" and self.owner:CreateTexture(nil, "OVERLAY")
				or self.owner:CreateTexture(nil, "BACKGROUND", nil, self.kind == "ring" and self.used == 1 and -2 or -1))
		end
		self.textures[self.used] = t
	end
	t.ink, t.inkFlip = (INK.spans[name] or INK.circles[name]) and name or nil, flipX
	local loaded = t:SetTexture(PATH .. name .. ".png")
	if not W.IsSecret(loaded) and loaded == false then
		t:Hide()
		return t
	end
	local u, v = (name:find("^Forge") and width or spec[1]) / spec[3], spec[2] / spec[4]
	t:SetTexCoord(flipX and u or 0, flipX and 0 or u, flipY and v or 0, flipY and 0 or v)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", self.target, "TOPLEFT", left * self.pixel, -top * self.pixel)
	t:SetSize((width or spec[1]) * self.pixel, spec[2] * self.pixel)
	t:Show()
	return t
end

function Handle:Piece(name, point, relative, x, y, flipX, flipY)
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
	if self.avoid and self:Blocked((originX + left) * Scale.Pixel(1), (originY - top) * Scale.Pixel(1), spec[1], spec[2]) then
		self.blocked = true
		return
	end
	return self:Place(name, left, top, flipX, flipY)
end

local function Shaped(ink, flip, l, r, t, b, clear)
	local o = { l = l, r = r, t = t, b = b, clear = clear }
	local runs = type(ink) == "string" and INK.spans[ink]
	if runs then
		local sx, sy = (r - l) / runs[1], (t - b) / runs[2]
		o.spans = {}
		for i = 3, #runs, 4 do
			local x0, x1 = runs[i + 2] * sx, runs[i + 3] * sx
			local span = { l = flip and r - x1 or l + x0, r = flip and r - x0 or l + x1, t = t - runs[i] * sy, b = t - runs[i + 1] * sy }
			o.spans[#o.spans + 1] = span
			o.l, o.r = min(o.l, span.l), max(o.r, span.r)
		end
		return o
	end
	local reach = 0
	local list = type(ink) == "table" and ink or { ink, 0 }
	for i = 1, #list, 2 do
		local fraction = INK.circles[list[i]]
		if not fraction then return o end
		reach = max(reach, fraction / (1 - 2 * list[i + 1]))
	end
	o.cx, o.cy, o.radius = (l + r) / 2, (t + b) / 2, reach * (r - l) / 2 + 1
	return o
end

local function With(o, clear)
	return setmetatable({ clear = clear }, { __index = o })
end

function Handle:Obstacles()
	local pixel = Scale.Pixel(1)
	local list = {}
	local function Add(region, clear, ink, outset)
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
		if not (Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(f)) then return false end
		if region.ink then
			list[#list + 1] = Shaped(region.ink, region.inkFlip, l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel, clear)
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
		outset = outset or 0
		list[#list + 1] = { l = (l - outset) * f / pixel, r = (r + outset) * f / pixel, t = (t + outset) * f / pixel, b = (b - outset) * f / pixel, clear = clear }
		return true
	end
	for _, set in ipairs({ self.avoid or {}, self.others or {} }) do
		for _, frame in ipairs(set) do
			if frame ~= self.yoke and (frame.blockOf ~= self or not (self.yoke and self.yoke.used > 0)) then
				for _, region in ipairs(frame.textures and { unpack(frame.textures, 1, frame.used) } or { frame }) do
					local count = #list
					if not Add(region, max(4 / pixel, 3)) then return end
					if #list > count then list[#list].icon, list[#list].other = set == self.avoid, set ~= self.avoid and frame.textures ~= nil end
				end
			end
		end
	end
	for _, text in ipairs(self.texts or {}) do
		local count = #list
		if not Add(text, 1, true) then return end
		if #list > count then list[#list].ink = true end
	end
	for _, bar in ipairs(self.near or {}) do
		if not Add(bar, 1, false, bar.rimOutset or W.Border(bar)) then return end
	end
	if self.kind == "bar" then
		for row in pairs(ROWS) do
			for i = 1, row.used do
				local count = #list
				if not Add(row.textures[i], max(4 / pixel, 3)) then return end
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
		if not (Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(f)) then return end
		local inset = card:InsetUnits() - ns.Tokens.Size("gapSmall")
		l, r, t, b = (l + inset) * f / pixel, (r - inset) * f / pixel, (t - inset) * f / pixel, (b + inset) * f / pixel
		local far = 1e6
		list[#list + 1] = { l = l - far, r = l, t = far, b = -far, clear = 1, card = true }
		list[#list + 1] = { l = r, r = r + far, t = far, b = -far, clear = 1, card = true }
		list[#list + 1] = { l = -far, r = far, t = t + far, b = t, clear = 1, card = true }
		list[#list + 1] = { l = -far, r = far, t = b, b = b - far, clear = 1, card = true }
	end
	return list
end

local INSET = 2

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

function Handle:Frame(full)
	local pixel = Scale.Pixel(1)
	local left, top, right, bottom = self.target:GetLeft(), self.target:GetTop(), self.target:GetRight(), self.target:GetBottom()
	if not (Plain(left) and Plain(top) and Plain(right) and Plain(bottom)) then return end
	local base, joined, upper = self.height, nil, bottom
	for _, span in ipairs(self.spans or { self.span }) do
		local shown = type(span.IsVisible) == "function" and span:IsVisible()
		if W.IsSecret(shown) then return end
		if shown then
			local low = span:GetBottom()
			if Plain(low) and low < bottom and (top - low) / self.pixel <= base * 4 + 0.5 then
				upper, bottom, joined = bottom, low - (span.rimOutset or W.Border(span)), span
			end
		end
	end
	if base < 4 or self.width < 24 or self.target.vertical then return end
	local list = self:Obstacles()
	if not list then return end
	local rim = max(1, floor((self.target.rimOutset or W.Border(self.target)) / self.pixel + 0.5))
	local f = self.factor / pixel
	local ox, oy = left * f, top * f
	local x0, y0 = floor(left * f + 0.5) - rim, floor(top * f + 0.5) + rim
	local boxW = floor(right * f + 0.5) + rim - x0
	local boxH = y0 - (floor(bottom * f + 0.5) - rim) + (joined and 1 or 0)
	local h = boxH - 2 * rim
	self.height = h
	local forged = full and self.forged
	local wrap, blocked = { 0, 0 }, {}
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
	if not full and Free(list, x0, y0 + 1, boxW, 1) and Free(list, x0, y0 - boxH, boxW, 1) then reach = 1 end
	if full then
		while rim + reach < 12 and reach < 6 and Free(list, x0, y0 + reach + 1, boxW, 1) and Free(list, x0, y0 - boxH - reach, boxW, 1) do
			reach = reach + 1
		end
	end
	local ring = self.yoke and self.yoke.used > 0 and self.yoke.textures[1]
	if ring then
		local l, r, t, b = ring:GetLeft(), ring:GetRight(), ring:GetTop(), ring:GetBottom()
		local scale = W.ScaleFactor(ring)
		if Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(scale) then
			ring = { x = (l + r) / 2 * scale / pixel, y = (t + b) / 2 * scale / pixel, r = (r - l) / 2 * scale / pixel }
			ring.left = ring.x < x0 + boxW / 2
		else
			ring = nil
		end
	end
	local portraitWest
	if self.yoke and not ring then
		local l, r = self.yoke.target:GetLeft(), self.yoke.target:GetRight()
		local scale = W.ScaleFactor(self.yoke.target)
		if Plain(l) and Plain(r) and Plain(scale) then portraitWest = (l + r) / 2 * scale / pixel < x0 + boxW / 2 end
	end
	local plain, pieces, hooked = {}, list, list
	for _, o in ipairs(list) do
		if not o.icon then plain[#plain + 1] = o end
	end
	if forged then
		pieces, hooked = {}, {}
		for i, o in ipairs(list) do
			pieces[i] = o.ink and With(o, max(o.clear, floor(3 / pixel + 0.5))) or o
			hooked[i] = o.row and With(o, max(o.clear, floor(boxH / 2))) or pieces[i]
		end
	end
	local function Fits(west, k, spec, near)
		if ring and ring.left == west then return 0 end
		local out = max(k, 0)
		local thickness = rim + out
		for slide = 0, self.kind == "plate" and boxH or 0 do
			local extra = wrap[west and 1 or 2] + slide
			local from = west and x0 - extra or x0 + boxW + extra - 1
			if slide > 0 and not (Free(plain, from, y0 + out, 1, thickness) and Free(plain, from, y0 - boxH - out + thickness, 1, thickness)) then return end
			if Free(near, west and x0 - extra - spec[1] or x0 + boxW + extra, y0 + k + floor(spec[5] + 0.5), spec[1], spec[2]) then return extra end
		end
	end
	local function Search(families, strict, loose)
		local single
		for _, name in ipairs(families) do
			for k = reach, -INSET, -1 do
				local spec = ASSETS["End" .. name .. (boxH + 2 * k)]
				if spec then
					local near = not strict and loose or name == "Pointed" and pieces or hooked
					local west, east = Fits(true, k, spec, near), Fits(false, k, spec, near)
					local piece = { name = "End" .. name .. (boxH + 2 * k), rise = floor(spec[5] + 0.5), width = spec[1], reach = k, west = west, east = east }
					piece.weight = spec[2] * ((west and 1 or 0) + (east and 1 or 0))
					if west and east then
						return piece
					end
					if not single and (west and (blocked[2] or portraitWest == false) or east and (blocked[1] or portraitWest == true)) then single = piece end
				end
			end
		end
		return single
	end
	local ends = Search(FAMILIES[self:Family(full)] or {}, forged)
	if forged then
		local least = Search(FAMILIES.Pointed, false, list)
		if least and (not ends or ends.weight < least.weight) then ends = least end
	end
	reach = ends and max(ends.reach, 0) or (not full and reach or 0)
	wrap = { ends and ends.west or 0, ends and ends.east or 0 }
	local caps
	if self.kind == "bar" and not self.light and (not ends or full and ends.name:find("Pointed", 1, true)) then
		local family = full and not forged and "Wing" or "Arrow"
		local tiers = { Tier(family, boxH) }
		for n = forged and boxH - 1 or 0, 6, -1 do
			local name = Tier(family, n)
			if name and name ~= tiers[#tiers] then tiers[#tiers + 1] = name end
		end
		local heights = { boxH, forged and joined and y0 - (floor(upper * f + 0.5) - rim) or nil }
		for _, name in ipairs(tiers) do
			local spec = ASSETS[name]
			for _, height in ipairs(heights) do
				local capTop = y0 - floor((height - spec[2]) / 2)
				local west = not (ring and ring.left) and Free(pieces, x0 - spec[1], capTop, spec[1], spec[2])
				local east = not (ring and not ring.left) and Free(pieces, x0 + boxW, capTop, spec[1], spec[2])
				local smaller = forged and (ends and spec[2] < ASSETS[ends.name][2] or capTop <= floor(upper * f + 0.5))
				if not smaller and spec[2] <= height and (west or ring and ring.left or portraitWest == true) and (east or ring and not ring.left or portraitWest == false) and (west or east) then
					caps = { name = name, top = capTop, width = spec[1], west = west, east = east }
					ends, wrap = nil, { 0, 0 }
					break
				end
			end
			if caps then break end
		end
	end
	local thickness = full and max(1, rim + reach - 1) or 1
	while thickness > 1 and not ASSETS["Rail" .. thickness] do thickness = thickness - 1 end
	local dx = x0 - ox
	local touching, loose = {}, {}
	for _, o in ipairs(plain) do
		touching[#touching + 1] = With(o, o.ink and self.kind == "plate" and 0 or o.clear)
		if not o.card then loose[#loose + 1] = touching[#touching] end
	end
	local fenced = { unpack(loose) }
	for _, o in ipairs(list) do
		if o.icon then fenced[#fenced + 1] = o end
	end
	local lanes = { { "Rail" .. thickness, thickness, y0 + reach }, { "Rail" .. thickness, thickness, y0 - boxH - reach + thickness } }
	if forged then
		local least = pixel <= 2 / 3 and 3 or 2
		local want = max(least, min(8, floor(3 / pixel + 0.5), floor(boxH / 5)))
		for side = 1, 2 do
			for size = want, least, -1 do
				local edge = side == 1 and y0 - rim + 1 + size or y0 - boxH + rim - 1
				if ASSETS["Forge" .. size] and Free(touching, x0 - wrap[1], edge, boxW + wrap[1] + wrap[2], size) then
					lanes[side] = { "Forge" .. size, size, edge }
					break
				end
			end
		end
	end
	self.weights = {}
	local reached = { false, false }
	for side, lane in ipairs(lanes) do
		local rail, weight, edge = lane[1], lane[2], lane[3]
		local railed = ASSETS[rail] ~= nil
		local from, to = x0 - wrap[1], x0 + boxW + wrap[2]
		local yoke = ring and rail:find("^Forge") and self.yoke.target
		local gl, gr, gs = yoke and yoke:GetLeft(), yoke and yoke:GetRight(), yoke and W.ScaleFactor(yoke)
		if yoke and Plain(gl) and Plain(gr) and Plain(gs) then
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
		local cuts = {}
		for _, o in ipairs(list) do
			local clear = forged and 1 or o.clear
			if o.icon and from < o.r + clear and o.l - clear < to and edge - weight < o.t + clear and o.b - clear < edge then
				cuts[#cuts + 1] = { floor(o.l - clear), math.ceil(o.r + clear) }
			end
		end
		table.sort(cuts, function(a, b) return a[1] < b[1] end)
		if cuts[1] and cuts[1][1] - from <= 1 then reached[1] = true end
		if cuts[#cuts] and to - cuts[#cuts][2] <= 1 then reached[2] = true end
		local start = from
		for i = 1, #cuts + 1 do
			local stop = cuts[i] and min(cuts[i][1], to) or to
			if railed and stop - start >= 1 and Free(yoke and loose or touching, start, edge, stop - start, weight) then
				local x, length, piece = start, stop - start, ASSETS[rail][1]
				local tip = rail:find("^Forge") and ASSETS["Tip" .. weight]
				if tip and length >= 2 * tip[1] + 2 then
					self:Place("Tip" .. weight, x - ox, oy - edge, false, side == 2)
					self:Place("Tip" .. weight, x + length - tip[1] - ox, oy - edge, true, side == 2)
					x, length = x + tip[1], length - 2 * tip[1]
				end
				while length > 0 do
					local run = rail:find("^Forge") and min(length, piece) or length
					self:Place(rail, x - ox, oy - edge, false, side == 2, run)
					x, length = x + run, length - run
				end
				self.weights[side] = rail
				if start == from then reached[1] = true end
				if stop == to then reached[2] = true end
			end
			if cuts[i] then start = max(start, cuts[i][2]) end
		end
	end
	if full and self.weights[1] and self.weights[1]:find("^Forge") then
		local weight, edge = lanes[1][2], lanes[1][3]
		local margin = floor(2 / pixel + 0.5)
		local guard = { unpack(pieces) }
		for _, text in ipairs(self.texts or {}) do
			local l, r, t, b, s = text:GetLeft(), text:GetRight(), text:GetTop(), text:GetBottom(), W.ScaleFactor(text)
			if Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(s) then
				guard[#guard + 1] = { l = l * s / pixel, r = r * s / pixel, t = t * s / pixel, b = b * s / pixel, clear = floor(3 / pixel + 0.5) }
			end
		end
		for _, n in ipairs({ 32, 20, 16, 12, 8 }) do
			local spec = ASSETS["Crest" .. n]
			local cx = spec and floor(x0 + (boxW - spec[1]) / 2 + 0.5)
			if spec and n <= 6 * weight + 2 and Free(guard, cx - margin, edge - 1 + spec[2] + margin, spec[1] + 2 * margin, spec[2] + 2 * margin) then
				self:Place("Crest" .. n, cx - ox, oy - edge + 1 - spec[2])
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
		if ends.west and not (ring and ring.left) and (reached[1] or wrap[1] == 0) then self:Place(ends.name, dx - wrap[1] - ends.width, tip) end
		if ends.east and not (ring and not ring.left) and (reached[2] or wrap[2] == 0) then self:Place(ends.name, dx + boxW + wrap[2], tip, true) end
	end
end

local HOLES = { 14, 17, 20, 24, 28, 32, 38, 44, 52, 60, 70, 80 }

function Handle:Rank(family, flipX)
	local hole = min(self.width, self.height) / 2 + 1
	local index = #HOLES
	for i = #HOLES, 1, -1 do
		if HOLES[i] >= hole then index = i end
	end
	while index > 1 and not ASSETS[family .. HOLES[index]] do index = index - 1 end
	local tier = HOLES[index]
	local spec = ASSETS[family .. tier]
	if not spec or not spec[6] then return end
	self:Piece(family .. tier, "TOPLEFT", "CENTER", -(flipX and spec[1] - spec[5] or spec[5]), spec[6], flipX)
end

function Handle:Ring(full)
	local side = min(self.width, self.height)
	if side < 24 or not full then return end
	local ring = ASSETS["Ring" .. side] and side or floor((side + 1) / 2) * 2
	while ring > 24 and not ASSETS["Ring" .. ring] do ring = ring - 1 end
	self:Piece("Ring" .. ring, "CENTER", "CENTER", 0, 0, self.mirror)
	if not full or self.player then return end
	if self.boss then
		self:Rank("BossPendantR")
	elseif self.elite then
		self:Rank("ElitePendantR")
	end
end

function Handle:Map(full)
	local side = min(self.width, self.height)
	local n = side >= 280 and 40 or side >= 150 and 24 or 16
	if not full then n = n == 40 and 32 or n == 24 and 20 or 12 end
	local name = Tier("Map", n)
	if not name then return end
	n = ASSETS[name][2]
	local outset = floor(n * 0.4)
	self:Piece(name, "TOPLEFT", "TOPLEFT", -outset, outset)
	self:Piece(name, "TOPRIGHT", "TOPRIGHT", outset, outset, true)
	if side >= 280 then
		self:Piece(name, "BOTTOMLEFT", "BOTTOMLEFT", -outset, -outset, false, true)
		self:Piece(name, "BOTTOMRIGHT", "BOTTOMRIGHT", outset, -outset, true, true)
		if full then self:Piece(Tier("Point", 12), "TOP", "BOTTOM", 0, -1) end
	end
end

function Handle:Corners(full)
	local block, chrome = self.block, self.chrome
	if not full or not (chrome and chrome.visible) then return end
	local found = block and block:Obstacles() or not block and {}
	if not found then return end
	local pixel = Scale.Pixel(1)
	local list = {}
	for _, o in ipairs(found) do
		if not o.card then list[#list + 1] = o end
	end
	for _, region in ipairs(self.inside or {}) do
		local l, r, t, b, f = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom(), W.ScaleFactor(region)
		if W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b) then return end
		if Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(f) then
			list[#list + 1] = { l = l * f / pixel, r = r * f / pixel, t = t * f / pixel, b = b * f / pixel, clear = 1 }
		end
	end
	for _, bar in ipairs(self.bars or {}) do
		local shown = type(bar.IsVisible) == "function" and bar:IsVisible()
		if W.IsSecret(shown) then return end
		local l, r, t, b, f = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom(), W.ScaleFactor(bar)
		if shown and Plain(l) and Plain(r) and Plain(t) and Plain(b) and Plain(f) then
			local rim = bar.rimOutset or W.Border(bar)
			list[#list + 1] = { l = (l - rim) * f / pixel, r = (r + rim) * f / pixel, t = (t + rim) * f / pixel, b = (b - rim) * f / pixel, clear = 1 }
		end
	end
	local left, top = self.target:GetLeft(), self.target:GetTop()
	if not (Plain(left) and Plain(top)) then return end
	left, top = left * self.factor / pixel, top * self.factor / pixel
	for _, n in ipairs({ 40, 32, 24, 20, 16, 12 }) do
		local spec = ASSETS["Corner" .. n]
		local out = 0
		if spec and n * 3 <= self.height * 2 then
			local w, h = spec[1], spec[2]
			local fits = true
			for _, corner in ipairs({ { left - out, top + out }, { left + self.width + out - w, top + out },
				{ left - out, top - self.height - out + h }, { left + self.width + out - w, top - self.height - out + h } }) do
				fits = fits and Free(list, floor(corner[1] + 0.5), floor(corner[2] + 0.5), w, h)
			end
			if fits then
				self:Piece("Corner" .. n, "TOPLEFT", "TOPLEFT", -out, out)
				self:Piece("Corner" .. n, "TOPRIGHT", "TOPRIGHT", out, out, true)
				self:Piece("Corner" .. n, "BOTTOMLEFT", "BOTTOMLEFT", -out, -out, false, true)
				self:Piece("Corner" .. n, "BOTTOMRIGHT", "BOTTOMRIGHT", out, -out, true, true)
				return
			end
		end
	end
end

function Handle:Crest(full)
	if not full or self.width < 180 or self.height < 64 then return end
	if self.bottom then
		local bottom = type(self.target.GetBottom) == "function" and self.target:GetBottom()
		local name = Tier("Keystone", self.pixel > 0.8 and 8 or 12)
		if name and Plain(bottom) and bottom * self.factor / Scale.Pixel(1) > ASSETS[name][2] + 1 then
			self:Piece(name, "TOP", "BOTTOM", 0, 0)
		end
		return
	end
	local size = self.pixel > 1.25 and 12 or self.pixel > 0.8 and 20 or 32
	if self.width >= 900 then size = 64 elseif self.width >= 600 then size = 48 end
	local top = type(self.target.GetTop) == "function" and self.target:GetTop()
	local rootTop = Scale.Root():GetTop()
	if not Plain(top) or not Plain(rootTop) then return end
	local room = (rootTop - top * self.factor) / Scale.Pixel(1)
	local name = Tier("Crest", min(size, room))
	if name and room >= ASSETS[name][2] then
		self:Piece(name, "BOTTOM", "TOP", 0, 0)
	end
end

function Handle:Row(full)
	if not self.keystone or self.width < 240 or not self.pair or self.pairEnabled == false then return end
	local other = self.pair
	local left, right, bottom = self.target:GetLeft(), self.target:GetRight(), self.target:GetBottom()
	local otherLeft, otherRight, top = other:GetLeft(), other:GetRight(), other:GetTop()
	if not (Plain(left) and Plain(right) and Plain(bottom) and Plain(otherLeft) and Plain(otherRight) and Plain(top)) then return end
	local factor, pixel = W.ScaleFactor(other), Scale.Pixel(1)
	if not Plain(factor) or not Plain(pixel) then return end
	if math.abs(left * self.factor - otherLeft * factor) > pixel
		or math.abs(right * self.factor - otherRight * factor) > pixel then return end
	local ownTop, otherBottom = self.target:GetTop(), other:GetBottom()
	if not Plain(ownTop) or not Plain(otherBottom) or not Plain(self.pairGap) then return end
	local gap = floor((otherBottom * factor - ownTop * self.factor) / pixel + 0.5)
	if gap < 0 or math.abs(gap - floor(self.pairGap / self.pixel + 0.5)) > 1 then return end
	local height = floor((top * factor - bottom * self.factor) / pixel + 0.5)
	if height < self.height or height > self.height * 3 then return end
	local name = Tier(full and "Tray" or "Arrow", min(full and 96 or 32, full and height or floor(height * 0.4)))
	local up = (height - self.height) / 2
	local spec = name and ASSETS[name]
	local clear = spec ~= nil
	if clear then
		local originX, originY = left * self.factor / pixel, ownTop * self.factor / pixel
		local finialTop = floor(originY - floor(self.height / 2 - up - spec[2] / 2 + 0.5) + 0.5)
		local finialBottom = finialTop - spec[2]
		local clearance = max(4 / pixel, 3)
		for _, blocker in ipairs(self.avoidBars or {}) do
			local l, r, t, b = blocker:GetLeft(), blocker:GetRight(), blocker:GetTop(), blocker:GetBottom()
			local f = W.ScaleFactor(blocker)
			if W.IsSecret(l) or W.IsSecret(r) or W.IsSecret(t) or W.IsSecret(b)
				or type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number"
				or l ~= l or r ~= r or t ~= t or b ~= b or math.abs(l) == math.huge or math.abs(r) == math.huge
				or math.abs(t) == math.huge or math.abs(b) == math.huge or not Plain(f) then
				clear = false
				break
			end
			l, r, t, b = l * f / pixel, r * f / pixel, t * f / pixel, b * f / pixel
			if r <= l or t <= b then
				clear = false
				break
			end
			if finialBottom < t and b < finialTop then
				for _, x in ipairs({ floor(originX - 2 - spec[1] + 0.5), floor(originX + self.width + 2 + 0.5) }) do
					if x < r + clearance and l < x + spec[1] + clearance then
						clear = false
						break
					end
				end
			end
			if not clear then break end
		end
	end
	if clear then
		self:Piece(name, "RIGHT", "LEFT", -2, up)
		self:Piece(name, "LEFT", "RIGHT", 2, up, true)
	end
	if full and self.height >= 30 then
		self.avoid, self.avoidShown = { other, unpack(self.avoidBars or {}) }, true
		self:Piece(Tier("Keystone", self.height >= 50 and 12 or 6), "TOP", "BOTTOM", 0, -1)
		self.avoid, self.avoidShown = nil, nil
	end
end

function Handle:Restyle()
	if self.hold then return end
	if not W.MayMove(self.owner) then
		if not self.queued then
			self.queued = true
			ns.Combat.Queue(function()
				self.queued = false
				self:Restyle()
			end)
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
	if Plain(width) and Plain(height) and Plain(factor) then
		self.pixel, self.factor = Scale.Pixel(1) / factor, factor
		if Plain(self.pixel) then
			self.width, self.height = floor(width / self.pixel + 0.5), floor(height / self.pixel + 0.5)
			local full = level == "Full"
			if self.kind == "bar" or self.kind == "plate" then self:Frame(full)
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
	for _, dependent in ipairs(self.dependents or {}) do dependent:Restyle() end
	if self.kind == "row" then
		for bar in pairs(BARS) do bar:Restyle() end
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
	handle:Restyle()
	if passive then return handle end
	return W.Track(handle)
end
