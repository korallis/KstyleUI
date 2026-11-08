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

local function Anchor(frame, holder)
	if frame:GetNumPoints() == 0 then
		frame:SetAllPoints(holder)
	end
end

local function Build(pane, id, builder)
	local built = pane.built[id]
	if built ~= nil then
		return built or nil
	end
	local ok, frame = K.Call(builder, pane.holder)
	if ok and type(frame) == "table" and type(frame.GetObjectType) == "function" then
		Anchor(frame, pane.holder)
		pane.built[id] = frame
		return frame
	end
	Model.Log("the preview for " .. tostring(id) .. " did not return a frame")
	pane.built[id] = false
	return nil
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
	if frame.Refresh then
		K.Call(frame.Refresh, frame)
	end
end

function Preview.Refresh(pane, module)
	local frame = pane.current
	if frame and frame.Refresh and (module == nil or module == pane.module) then
		K.Call(frame.Refresh, frame)
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
		self.holder:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -pad, pad)
	end
	pane:Layout()
	local restyle = pane.Restyle
	pane.Restyle = function(self)
		restyle(self)
		self:Layout()
	end
	return pane
end
