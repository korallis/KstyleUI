-- Preview.lua: the live preview pane: a module's own preview builder or the kit sample for General, in a card sized to what it draws; a page with no preview hides the pane.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Model = ns.Model

local Preview = {}
ns.Preview = Preview

local SAMPLE_WIDTH = 220
local SAMPLE_BAR = 0.7
local SAMPLE_SLIDER = 68
local SNUG_MARGIN = 4
local SCALE_SAME = 0.0001
Preview.MAX_SCALE = 1.25
Preview.SCALE_STEP = 0.01
Preview.MIN_GAIN = 0.05

function Preview.Sample(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local gap = Tokens.Size("gapLarge")
	local title = Widgets.Text(frame, "caps", "capsGold")
	Widgets.CapsSize(title)
	Widgets.Point(title, "TOP", frame, "TOP", 0, -gap)
	Widgets.SetText(title, L["Sample panel"])
	local body = Widgets.Text(frame, "body", "text")
	Widgets.Point(body, "TOP", title, "BOTTOM", 0, -Tokens.Size("gapSmall"))
	body:SetWidth(SAMPLE_WIDTH)
	Widgets.SetText(body, L["Accent, font, size and motion changes show here at once."])
	local bar = Widgets.StatusBar(frame, { width = SAMPLE_WIDTH, smooth = true, spark = true })
	Widgets.Point(bar, "TOP", body, "BOTTOM", 0, -gap)
	bar:SetBarRange(0, 1)
	bar:SetBarValue(SAMPLE_BAR)
	local toggle = Widgets.Toggle(frame, { value = true, label = L["Switch"] })
	Widgets.Point(toggle, "TOPLEFT", bar, "BOTTOMLEFT", 0, -gap)
	local slider = Widgets.Slider(frame, { min = 0, max = 100, step = 1, value = SAMPLE_SLIDER, width = SAMPLE_WIDTH })
	Widgets.Point(slider, "TOPLEFT", toggle, "BOTTOMLEFT", 0, -gap)
	local button = Widgets.Button(frame, { text = L["Button"], primary = true })
	Widgets.Point(button, "TOPLEFT", slider, "BOTTOMLEFT", 0, -gap)
	frame.bar, frame.toggle, frame.slider, frame.button = bar, toggle, slider, button
	return frame
end

local function Known(value)
	return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value > 0
end

local function Edge(value)
	if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then
		return nil
	end
	return value
end

local DECOR = { "Glow", "Shadow", "Gilt", "Noise", "ForgedOrnaments" }

local function IsDecor(region)
	if region.GetObjectType and region:GetObjectType() ~= "Texture" or not region.GetTexture then
		return false
	end
	local file = region:GetTexture()
	if type(file) ~= "string" or (issecretvalue and issecretvalue(file)) then
		return false
	end
	for _, name in ipairs(DECOR) do
		if file:find(name, 1, true) then
			return true
		end
	end
	return false
end

local function Bounds(frame)
	local left, right, top, bottom
	local function take(object)
		local eff = Edge(object:GetEffectiveScale())
		local l, r, t, b = Edge(object:GetLeft()), Edge(object:GetRight()), Edge(object:GetTop()), Edge(object:GetBottom())
		if not (eff and l and r and t and b) or eff <= 0 then
			return
		end
		l, r, t, b = l * eff, r * eff, t * eff, b * eff
		left, right = math.min(left or l, l), math.max(right or r, r)
		top, bottom = math.max(top or t, t), math.min(bottom or b, b)
	end
	local function walk(object)
		for _, region in ipairs({ object:GetRegions() }) do
			if region:IsShown() and not IsDecor(region) then
				take(region)
			end
		end
		for _, child in ipairs({ object:GetChildren() }) do
			if child:IsShown() then
				walk(child)
			end
		end
	end
	walk(frame)
	return left, right, top, bottom
end

local function Extent(frame, holder)
	local left, right, top, bottom = Bounds(frame)
	local eff = Edge(holder:GetEffectiveScale())
	if not left or not eff or eff <= 0 then
		return nil
	end
	return (right - left) / eff, (top - bottom) / eff
end

local Fit, Reserve, RefreshCurrent

local function Rescale(frame, scale)
	Widgets.MarkPreview(frame)
	frame:SetScale(scale)
	Widgets.RestyleUnder({ [frame] = true })
end

function Fit(pane, frame)
	local roomW, roomH = pane.holder:GetWidth(), pane.holder:GetHeight()
	if not (Known(roomW) and Known(roomH)) then
		return
	end
	local scale = 1
	if frame.sized then
		local width, height = frame:GetWidth(), frame:GetHeight()
		if Known(width) and Known(height) then
			scale = math.min(Preview.MAX_SCALE, roomW / width, roomH / height)
		end
		Rescale(frame, scale)
		frame:ClearAllPoints()
		Widgets.Point(frame, "CENTER", pane.holder, "CENTER", 0, 0)
		return
	end
	local own = frame:GetScale()
	local width, height = Extent(frame, pane.holder)
	if not (Known(width) and Known(height) and Known(own)) then
		if not pane.refit and C_Timer and C_Timer.After then
			pane.refit = true
			C_Timer.After(0, function()
				if pane.current == frame and frame:IsShown() then
					RefreshCurrent(pane)
				end
			end)
		end
		return
	end
	scale = math.max(1, math.min(Preview.MAX_SCALE, roomW * own / width, roomH * own / height))
	local key = roomW .. "x" .. roomH
	if frame.selfFits == key then
		scale = 1
	end
	if math.abs(scale - own) <= Preview.SCALE_STEP then
		return
	end
	Rescale(frame, scale)
	if frame.Refresh then
		K.Call(frame.Refresh, frame)
	end
	if scale <= own then
		return
	end
	local grown = Extent(frame, pane.holder)
	if Known(grown) and grown < width * (1 + Preview.MIN_GAIN) then
		frame.selfFits = key
		Rescale(frame, 1)
		if frame.Refresh then
			K.Call(frame.Refresh, frame)
		end
	end
end

local function Anchor(pane, frame)
	if frame:GetNumPoints() > 0 then
		return
	end
	frame.sized = Known(frame:GetWidth()) and Known(frame:GetHeight()) or nil
	if frame.sized then
		Fit(pane, frame)
	else
		frame:SetAllPoints(pane.holder)
	end
end

local function Build(pane, id, builder)
	local built = pane.built[id]
	if built ~= nil then
		return built or nil
	end
	local ok, frame = K.Call(builder, pane.holder)
	if ok and type(frame) == "table" and type(frame.GetObjectType) == "function" then
		Anchor(pane, frame)
		pane.built[id] = frame
		return frame
	end
	Model.Log("the preview for " .. tostring(id) .. " did not return a frame")
	pane.built[id] = false
	return nil
end

local function Overflow(holder, frame)
	local l, r, t, b = Widgets.OrnamentExtent({ [frame] = true })
	local hl, hr, ht, hb, f = Edge(holder:GetLeft()), Edge(holder:GetRight()), Edge(holder:GetTop()), Edge(holder:GetBottom()), Widgets.ScaleFactor(holder)
	if not (l and hl and hr and ht and hb and Known(f)) then
		return nil
	end
	local margin = 2 * K.Scale.Pixel(1)
	hl, hr, ht, hb = hl * f + margin, hr * f - margin, ht * f - margin, hb * f + margin
	local left, right, top, bottom = math.max(0, hl - l), math.max(0, r - hr), math.max(0, t - ht), math.max(0, hb - b)
	local fit = math.min((hr - hl) / (math.max(r, hr) - math.min(l, hl)), (ht - hb) / (math.max(t, ht) - math.min(b, hb)))
	return left, right, top, bottom, left + right + top + bottom < 0.5, fit
end

function Reserve(pane, frame)
	local holder = pane.holder
	local left, right, top, bottom, fits, fit = Overflow(holder, frame)
	if not left or fits then
		return
	end
	if frame.Reserve then
		for _ = 1, 6 do
			local own = Widgets.ScaleFactor(frame)
			if not Known(own) then
				return
			end
			frame:Reserve(left / own, right / own, top / own, bottom / own)
			left, right, top, bottom, fits = Overflow(holder, frame)
			if not left or fits then
				return
			end
		end
	else
		local hi = frame:GetScale()
		local lo = hi * fit * 0.98
		for _ = 1, 4 do
			Rescale(frame, lo)
			left, _, _, _, fits, fit = Overflow(holder, frame)
			if not left then
				return
			end
			if fits then
				break
			end
			hi, lo = lo, lo * fit * 0.98
		end
		for _ = 1, 5 do
			local mid = (lo + hi) / 2
			Rescale(frame, mid)
			left, _, _, _, fits = Overflow(holder, frame)
			if not left then
				return
			end
			if fits then lo = mid else hi = mid end
		end
		Rescale(frame, lo)
	end
	Widgets.RestyleUnder({ [frame] = true }, Widgets.IsOrnament)
end

local function Choose(pane, frame)
	local _, body = pane.ruler:GetFont()
	local bodyEff = Widgets.ScaleFactor(pane.ruler)
	if not (Known(body) and Known(bodyEff)) then
		return
	end
	local floor = body * bodyEff
	local function drawn(i)
		local name = frame:Name(i)
		local _, size = name:GetFont()
		local eff = Widgets.ScaleFactor(name)
		return Known(size) and Known(eff) and size * eff or nil
	end
	local function good(i, scale)
		Rescale(frame, scale)
		local _, _, _, _, fits = Overflow(pane.holder, frame)
		return fits and frame:Whole(i)
	end
	for i = 1, frame.choices do
		frame:Choose(i)
		local lo = Preview.MAX_SCALE
		for _ = 1, 4 do
			Rescale(frame, lo)
			local size = drawn(i)
			if not size then
				return
			end
			if size >= floor and lo < Preview.MAX_SCALE then
				break
			end
			lo = lo * floor / size * (size >= floor and 1 or 1.001)
		end
		local hi = math.max(Preview.MAX_SCALE, lo)
		local ok = good(i, hi)
		if not ok and good(i, lo) then
			for _ = 1, 6 do
				local mid = (lo + hi) / 2
				if good(i, mid) then lo = mid else hi = mid end
			end
			ok = good(i, lo)
		end
		if ok or i == frame.choices then
			if not ok then
				Rescale(frame, lo)
			end
			Widgets.RestyleUnder({ [frame] = true }, Widgets.IsOrnament)
			return
		end
	end
end

local function Settle(pane)
	local frame = pane.current
	local wide = frame.Choose ~= nil and Widgets.Setting("ornaments") ~= "Off" and Widgets.Setting("cardMaterial") ~= "Glass"
	if (pane.wide or false) ~= wide then
		pane.wide = wide
		pane:Place()
	end
	if frame.Choose and not wide then
		frame:Choose(nil)
	end
	frame.reserve = nil
	if frame.Refresh then
		K.Call(frame.Refresh, frame)
	end
	Fit(pane, frame)
	if wide then
		Choose(pane, frame)
	else
		Reserve(pane, frame)
	end
end

local function Span(pane, frame)
	local _, _, top, bottom = Bounds(frame)
	local _, _, ornamentTop, ornamentBottom = Widgets.OrnamentExtent({ [frame] = true })
	if ornamentTop and top then
		top, bottom = math.max(top, ornamentTop), math.min(bottom, ornamentBottom)
	end
	local eff = Edge(pane.holder:GetEffectiveScale())
	local holderTop, holderBottom = Edge(pane.holder:GetTop()), Edge(pane.holder:GetBottom())
	if not (top and eff and eff > 0 and holderTop and holderBottom) then
		return nil
	end
	return top / eff, bottom / eff, holderTop, holderBottom
end

local function Snug(pane, frame)
	local top, bottom = Span(pane, frame)
	if not top then
		if not pane.refit and C_Timer and C_Timer.After then
			pane.refit = true
			C_Timer.After(0, function()
				if pane.current == frame and frame:IsShown() then
					RefreshCurrent(pane)
				end
			end)
		end
		return
	end
	local room = pane.holder:GetHeight()
	if not Known(room) then
		return nil
	end
	local pixel = 2 * Widgets.Border(pane)
	local function even(height)
		return room - pixel * math.floor((room - height) / pixel + 0.001)
	end
	local want = even(top - bottom + 2 * SNUG_MARGIN)
	if want >= room then
		return nil
	end
	local scale, slack = frame:GetScale(), K.Scale.Pixel(1)
	for _ = 1, 3 do
		pane:Place(want)
		Settle(pane)
		local newTop, newBottom, holderTop, holderBottom = Span(pane, frame)
		local now = frame:GetScale()
		if not newTop or newTop > holderTop + slack then
			break
		end
		if math.abs(now - scale) > SCALE_SAME then
			want = even(want * scale / now + pixel)
		elseif newBottom >= holderBottom - slack then
			return want
		else
			want = even(want + holderBottom - newBottom + SNUG_MARGIN)
		end
		if want >= room then
			break
		end
	end
	pane:Place()
	Settle(pane)
end

local function Holds(pane, frame, height)
	local top, bottom, holderTop, holderBottom = Span(pane, frame)
	if not top then
		return false
	end
	if not height then
		return Widgets.Snap(pane, top - bottom + 2 * SNUG_MARGIN) >= pane.holder:GetHeight()
	end
	local slack = K.Scale.Pixel(1)
	return top <= holderTop + slack and bottom >= holderBottom - slack and bottom - holderBottom <= SNUG_MARGIN + 2 * Widgets.Border(pane) + slack
end

function RefreshCurrent(pane)
	local frame = pane.current
	if not frame then
		return
	end
	local held = pane.held[frame]
	local again = held and held.room == pane.room and held.wide == pane.wide
	pane:Place(again and held.height or nil)
	Settle(pane)
	if again and math.abs(frame:GetScale() - held.scale) <= SCALE_SAME and Holds(pane, frame, held.height) then
		return
	end
	if again and held.height then
		pane:Place()
		Settle(pane)
	end
	local height = Snug(pane, frame)
	pane.held[frame] = { room = pane.room, wide = pane.wide, height = height, scale = frame:GetScale() }
end

function Preview.Show(pane, page)
	local frame
	if page then
		local builder = page.module and K.Options.Preview(page.module)
		if builder then
			frame = Build(pane, page.module, builder)
		elseif page.builtinPreview then
			local sample = page.builtinPreview()
			if sample then
				frame = Build(pane, page.id, sample)
			end
		end
	end
	for _, other in pairs(pane.built) do
		if other and other ~= frame then
			other:Hide()
		end
	end
	pane.current = frame
	pane.module = page and page.module
	pane.refit = nil
	pane:SetShown(frame ~= nil)
	if frame then
		frame:Show()
		RefreshCurrent(pane)
	end
	return frame ~= nil
end

function Preview.Refresh(pane, module)
	if module == nil or module == pane.module then
		RefreshCurrent(pane)
	end
end

function Preview.Create(parent)
	local pane = Widgets.Panel(parent, { shape = "tile", fill = "buttonFill", shadow = false })
	pane.caption = Widgets.SectionCap(pane, { text = L["Live preview"] })
	pane.holder = CreateFrame("Frame", nil, pane)
	pane.holder:SetClipsChildren(true)
	pane.built = {}
	pane.held = {}
	pane.ruler = Widgets.Text(pane, "body", "text")
	pane.ruler:Hide()
	pane.Place = function(self, holderHeight)
		local pad = Widgets.WindowInset(self)
		local gap = Widgets.Snap(self, Tokens.Size("gapMedium"))
		local side = self.wide and pad or 0
		self.caption:ClearAllPoints()
		Widgets.Point(self.caption, "TOPLEFT", self, "TOPLEFT", pad, -pad)
		Widgets.Point(self.caption, "TOPRIGHT", self, "TOPRIGHT", -pad, -pad)
		self.holder:ClearAllPoints()
		Widgets.Point(self.holder, "TOPLEFT", self.caption, "BOTTOMLEFT", -side, -gap)
		local width, height = self:GetWidth(), self.room or self:GetHeight()
		if Known(width) and Known(height) then
			local top = pad + self.caption:SetWrapWidth(math.max(1, width - 2 * pad)) + gap
			local holder = math.max(1, math.min(holderHeight or math.huge, height - top - pad))
			Widgets.Size(self.holder, math.max(1, width - 2 * (pad - side)), holder)
			if self.room then
				Widgets.Size(self, width, top + holder + pad)
			end
			return true
		end
		Widgets.Point(self.holder, "BOTTOMRIGHT", self, "BOTTOMRIGHT", -(pad - side), pad)
		return false
	end
	pane.SetRoom = function(self, width, height)
		self.room = height
		Widgets.Size(self, width, height)
		self:Layout()
	end
	pane.Layout = function(self)
		if self:Place() then
			RefreshCurrent(self)
		end
	end
	pane:Layout()
	local restyle = pane.Restyle
	pane.Restyle = function(self)
		restyle(self)
		self:Layout()
	end
	return pane
end
