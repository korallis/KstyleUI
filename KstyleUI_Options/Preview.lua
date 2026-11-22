-- Preview.lua: the live preview pane: a module's own preview builder or the typography sample for General, in a card sized to what it draws; a page with no preview hides the pane.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Model = ns.Model

local Preview = {}
ns.Preview = Preview

local SAMPLE_WIDTH = 160
local SNUG_MARGIN = 4
local SCALE_SAME = 0.0001
Preview.MAX_SCALE = 1.6
Preview.SCALE_STEP = 0.01
Preview.MIN_GAIN = 0.05

local function MaxScale()
	return K.Store.Module("OptionsPresentation").preview and Preview.MAX_SCALE or 1.25
end

function Preview.Sample(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local samples = {
		Widgets.Text(frame, "caps", "capsGold"),
		Widgets.Text(frame, "unit", "textEmphasis"),
		Widgets.Text(frame, "number", "text"),
		Widgets.Text(frame, "body", "text"),
	}
	Widgets.CapsSize(samples[1])
	Widgets.SetText(samples[1], L["Sample panel"])
	Widgets.SetText(samples[2], L["Frost Howler"])
	Widgets.SetText(samples[3], string.format("%d / %d", 2240, 4020))
	Widgets.SetText(samples[4], L["Accent, font, size and motion changes show here at once."])
	frame.body = samples[4]
	frame.Refresh = function(self)
		local width, gap = Widgets.Snap(self, SAMPLE_WIDTH), Tokens.Size("gapMedium")
		local height = -gap
		Widgets.Point(samples[1], "TOPLEFT", self, "TOPLEFT", Tokens.Size("gapLarge"), 0, true)
		for i, text in ipairs(samples) do
			Widgets.StyleText(text)
			local row = Widgets.Snap(text, Widgets.WrappedHeight(text, width))
			Widgets.Size(text, width, row)
			if i > 1 then Widgets.Point(text, "TOPLEFT", samples[i - 1], "BOTTOMLEFT", 0, -gap, true) end
			height = height + row + gap
		end
		Widgets.Size(self, width + 2 * Tokens.Size("gapLarge"), height)
		for i, key in pairs({ [2] = K.Theme.Class() or "", [3] = "MANA" }) do
			local c = K.Theme.Palette(key)
			if c then samples[i]:SetTextColor(c.r, c.g, c.b) else Widgets.TextColor(samples[i], i == 2 and "textEmphasis" or "text") end
		end
	end
	frame.Restyle = frame.Refresh
	Widgets.Track(frame)
	frame:Refresh()
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
			scale = math.min(MaxScale(), roomW / width, roomH / height)
		end
		Rescale(frame, scale)
		frame:ClearAllPoints()
		local anchor = K.Store.Module("OptionsPresentation").preview and "TOP" or "CENTER"
		Widgets.Point(frame, anchor, pane.holder, anchor, 0, 0)
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
	scale = math.max(1, math.min(MaxScale(), roomW * own / width, roomH * own / height))
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
	local margin = 2 * K.Scale.Pixel(1)
	if l then
		l, r, t, b = l - margin, r + margin, t + margin, b - margin
	end
	if frame.Reserve then
		local cl, cr, ct, cb = Bounds(frame)
		local root = Edge(K.Scale.Root():GetEffectiveScale())
		if cl and Known(root) then
			l, r = math.min(l or cl / root, cl / root), math.max(r or cr / root, cr / root)
			t, b = math.max(t or ct / root, ct / root), math.min(b or cb / root, cb / root)
		end
	end
	local hl, hr, ht, hb, f = Edge(holder:GetLeft()), Edge(holder:GetRight()), Edge(holder:GetTop()), Edge(holder:GetBottom()), Widgets.ScaleFactor(holder)
	if not (l and hl and hr and ht and hb and Known(f)) then
		return nil
	end
	hl, hr, ht, hb = hl * f, hr * f, ht * f, hb * f
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
		local lo = MaxScale()
		for _ = 1, 4 do
			Rescale(frame, lo)
			local size = drawn(i)
			if not size then
				return
			end
			if size >= floor and lo < MaxScale() then
				break
			end
			lo = lo * floor / size * (size >= floor and 1 or 1.001)
		end
		local hi = math.max(MaxScale(), lo)
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

local function FitLabels(frame)
	for _, text in ipairs({ frame:GetRegions() }) do
		if text:GetObjectType() == "FontString" and text:IsShown() then
			local cut = text.IsTruncated and text:IsTruncated()
			local room, width = Edge(text:GetWidth()), Widgets.TextWidth(text, 0)
			if not Widgets.IsSecret(cut) and cut and Known(room) and Known(width) and width > room then
				local path, size, flags = text:GetFont()
				if Known(size) then
					local pixel = Widgets.Border(text)
					Widgets.Fitted(text)
					Widgets.ApplyFont(text, path, math.max(pixel, math.floor(size * room / width / pixel) * pixel), flags)
				end
			end
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsShown() then FitLabels(child) end
	end
end

local function MovePreview(frame, offset)
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	frame:ClearAllPoints()
	for _, point in ipairs(points) do
		Widgets.Point(frame, point[1], point[2], point[3], point[4] or 0, (point[5] or 0) + offset)
	end
end

local function Settle(pane)
	local frame = pane.current
	if frame.previewOffset then
		MovePreview(frame, -frame.previewOffset)
		frame.previewOffset = nil
	end
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
	if frame.Reserve then FitLabels(frame) end
	if not frame.sized and K.Store.Module("OptionsPresentation").preview then
		local _, _, top = Bounds(frame)
		local _, _, ornamentTop = Widgets.OrnamentExtent({ [frame] = true })
		local root = Edge(K.Scale.Root():GetEffectiveScale())
		if top and ornamentTop and Known(root) then top = math.max(top, ornamentTop * root) end
		local holderTop, eff = Edge(pane.holder:GetTop()), Edge(pane.holder:GetEffectiveScale())
		local own = Edge(frame:GetEffectiveScale())
		if top and holderTop and Known(eff) and Known(own) then
			frame.previewOffset = (holderTop * eff - top) / own
			MovePreview(frame, frame.previewOffset)
			Widgets.RestyleUnder({ [frame] = true }, Widgets.IsOrnament)
		end
	end
end

local function Span(pane, frame)
	local _, _, top, bottom = Bounds(frame)
	local _, _, ornamentTop, ornamentBottom = Widgets.OrnamentExtent({ [frame] = true })
	local root = K.Store.Module("OptionsPresentation").preview and Edge(K.Scale.Root():GetEffectiveScale()) or 1
	if ornamentTop and top and Known(root) then
		top, bottom = math.max(top, ornamentTop * root), math.min(bottom, ornamentBottom * root)
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
		if K.Store.Module("OptionsPresentation").preview then
			local slack = K.Scale.Pixel(1)
			return top <= holderTop + slack and bottom >= holderBottom - slack
		end
		return Widgets.Snap(pane, top - bottom + 2 * SNUG_MARGIN) >= pane.holder:GetHeight()
	end
	local slack = K.Scale.Pixel(1)
	local margin = SNUG_MARGIN * (K.Store.Module("OptionsPresentation").preview and 2 or 1)
	return top <= holderTop + slack and bottom >= holderBottom - slack and bottom - holderBottom <= margin + 2 * Widgets.Border(pane) + slack
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

function Preview.Show(pane, page, section)
	pane.page = page
	pane.section = section
	local previous = pane.current
	local frame
	if page then
		local builder = page.module and K.Options.Preview(page.module)
		if builder then
			frame = Build(pane, page.module, builder)
		elseif page.builtinPreview then
			local sample = page.builtinPreview(section)
			if sample then
				frame = Build(pane, sample, sample)
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
		if frame ~= previous and K.Appearance.Get("calmLists") then
			frame:SetAlpha(0)
			K.Motion.FadeIn(frame, 0.2)
		else
			frame:Show()
		end
		RefreshCurrent(pane)
	end
	return frame ~= nil
end

function Preview.Refresh(pane, module)
	if pane.page and pane.page.builtinPreview then
		Preview.Show(pane, pane.page, pane.section)
	elseif module == nil or module == pane.module then
		RefreshCurrent(pane)
	end
end

function Preview.Create(parent)
	local pane = Widgets.Panel(parent, { shape = "tile", fill = "buttonFill", shadow = false })
	pane.caption = Widgets.SectionCap(pane, { text = L["Live preview"] })
	pane.holder = Widgets.MarkPreview(CreateFrame("Frame", nil, pane))
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
