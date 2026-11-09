-- Preview.lua: the live preview pane: a module's own preview builder, the kit sample for General, or a quiet placeholder.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Model = ns.Model

local Preview = {}
ns.Preview = Preview

local SAMPLE_WIDTH = 220
local SAMPLE_BAR = 0.7
local SAMPLE_SLIDER = 68
local LOGO_SIZE = 64
local LOGO_ALPHA = 0.35
Preview.MAX_SCALE = 1.25
Preview.SCALE_STEP = 0.01
Preview.MIN_GAIN = 0.05

function Preview.Sample(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local gap = Tokens.Size("gapLarge")
	local title = Widgets.Text(frame, "heading", "textEmphasis")
	title:SetPoint("TOP", frame, "TOP", 0, -gap)
	Widgets.SetText(title, L["Sample panel"])
	local body = Widgets.Text(frame, "body", "text")
	body:SetPoint("TOP", title, "BOTTOM", 0, -Tokens.Size("gapSmall"))
	body:SetWidth(SAMPLE_WIDTH)
	Widgets.SetText(body, L["Accent, font, size and motion changes show here at once."])
	local bar = Widgets.StatusBar(frame, { width = SAMPLE_WIDTH, smooth = true, spark = true })
	bar:SetPoint("TOP", body, "BOTTOM", 0, -gap)
	bar:SetBarRange(0, 1)
	bar:SetBarValue(SAMPLE_BAR)
	local toggle = Widgets.Toggle(frame, { value = true, label = L["Switch"] })
	toggle:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -gap)
	local slider = Widgets.Slider(frame, { min = 0, max = 100, step = 1, value = SAMPLE_SLIDER, width = SAMPLE_WIDTH })
	slider:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -gap)
	local button = Widgets.Button(frame, { text = L["Button"], primary = true })
	button:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -gap)
	frame.bar, frame.toggle, frame.slider, frame.button = bar, toggle, slider, button
	return frame
end

local function Placeholder(pane)
	local frame = CreateFrame("Frame", nil, pane.holder)
	frame:SetAllPoints(pane.holder)
	local logo = frame:CreateTexture(nil, "ARTWORK")
	logo:SetTexture((Tokens.Texture("logo")))
	logo:SetSize(LOGO_SIZE, LOGO_SIZE)
	logo:SetPoint("CENTER", frame, "CENTER", 0, LOGO_SIZE / 2)
	logo:SetAlpha(LOGO_ALPHA)
	frame.text = Widgets.Text(frame, "body", "text")
	frame.text:SetPoint("TOP", logo, "BOTTOM", 0, -Tokens.Size("gapMedium"))
	frame.text:SetWidth(SAMPLE_WIDTH)
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

local DECOR = { "Glow", "Shadow", "Gilt", "Noise" }

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

local function Extent(frame, holder)
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
	local eff = Edge(holder:GetEffectiveScale())
	if not left or not eff or eff <= 0 then
		return nil
	end
	return (right - left) / eff, (top - bottom) / eff
end

local Fit

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
		frame:SetScale(scale)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", pane.holder, "CENTER", 0, 0)
		return
	end
	local own = frame:GetScale()
	local width, height = Extent(frame, pane.holder)
	if not (Known(width) and Known(height) and Known(own)) then
		if not pane.refit and C_Timer and C_Timer.After then
			pane.refit = true
			C_Timer.After(0, function()
				if pane.current == frame and frame:IsShown() then
					Fit(pane, frame)
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
	frame:SetScale(scale)
	if frame.Refresh then
		K.Call(frame.Refresh, frame)
	end
	if scale <= own then
		return
	end
	local grown = Extent(frame, pane.holder)
	if Known(grown) and grown < width * (1 + Preview.MIN_GAIN) then
		frame.selfFits = key
		frame:SetScale(1)
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

local function RefreshCurrent(pane)
	local frame = pane.current
	if not frame or frame == pane.placeholder then
		return
	end
	if frame.Refresh then
		K.Call(frame.Refresh, frame)
	end
	Fit(pane, frame)
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
	if not frame then
		frame = pane.placeholder
		local text = page and page.id == "Elements" and L["Press Layout Mode to drag and resize elements on screen."] or L["This page has no preview."]
		Widgets.SetText(frame.text, text)
	end
	for _, other in pairs(pane.built) do
		if other and other ~= frame then
			other:Hide()
		end
	end
	if frame ~= pane.placeholder then
		pane.placeholder:Hide()
	end
	frame:Show()
	pane.current = frame
	pane.module = page and page.module
	pane.refit = nil
	RefreshCurrent(pane)
end

function Preview.Refresh(pane, module)
	if module == nil or module == pane.module then
		RefreshCurrent(pane)
	end
end

function Preview.Create(parent)
	local pane = Widgets.Panel(parent, { shape = "tile", fill = "buttonFill", shadow = false })
	pane.caption = Widgets.Text(pane, "caption", "text")
	Widgets.SetText(pane.caption, L["Live preview"])
	pane.rule = pane:CreateTexture(nil, "ARTWORK")
	pane.rule:SetTexture((Tokens.Texture("divider")))
	pane.holder = CreateFrame("Frame", nil, pane)
	pane.holder:SetClipsChildren(true)
	pane.built = {}
	pane.placeholder = Placeholder(pane)
	pane.Layout = function(self)
		local pad = Widgets.WindowInset(self)
		local gap = Widgets.Snap(self, Tokens.Size("gapMedium"))
		self.caption:ClearAllPoints()
		self.caption:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		self.rule:ClearAllPoints()
		self.rule:SetPoint("TOPLEFT", self.caption, "BOTTOMLEFT", 0, -gap)
		self.rule:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
		self.rule:SetHeight(Widgets.Border(self))
		Widgets.Tint(self.rule, "accent")
		self.holder:ClearAllPoints()
		self.holder:SetPoint("TOPLEFT", self.rule, "BOTTOMLEFT", 0, -gap)
		local width, height = self:GetWidth(), self:GetHeight()
		if Known(width) and Known(height) then
			local line = Widgets.LineHeight(self.caption)
			Widgets.Size(self.caption, math.max(1, width - 2 * pad), line)
			local top = pad + line + gap + Widgets.Border(self) + gap
			Widgets.Size(self.holder, math.max(1, width - 2 * pad), math.max(1, height - top - pad))
			RefreshCurrent(self)
		else
			self.holder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -pad, pad)
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
