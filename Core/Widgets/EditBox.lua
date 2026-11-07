-- EditBox.lua: the text field, a raised tile with a placeholder whose hairline lights with the accent while it has focus.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens, Scale = ns.Tokens, ns.Scale

local DEFAULT_WIDTH = 200
local HOVER_EDGE_ALPHA = 0.6

local EditBox = {}

local function IsEmpty(self)
	local text = self:GetText()
	if Widgets.IsSecret(text) then
		return false
	end
	return text == nil or text == ""
end

function EditBox:Paint()
	local hover = self.hoverT or 0
	if self.focused then
		self.chrome:SetEdge("accent")
	else
		self.chrome:SetEdgeRGBA(Widgets.MixTokens("edgeInner", 1, "accent", HOVER_EDGE_ALPHA, hover))
	end
	self.placeholder:SetShown(not self.focused and IsEmpty(self))
end

function EditBox:Restyle()
	local opts = self.opts
	Widgets.Size(self, opts.width or DEFAULT_WIDTH, opts.height or (Tokens.Size("rowHeight") + Tokens.Size("gapSmall")))
	local pad = Widgets.Snap(self, Tokens.Size("gapMedium"))
	self:SetTextInsets(pad, pad, 0, 0)
	self.placeholder:ClearAllPoints()
	self.placeholder:SetPoint("LEFT", self, "LEFT", pad, 0)
	self.placeholder:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
	self:Paint()
end

local function Call(self, name, ...)
	local fn = self.opts[name]
	if fn then
		ns.Call(fn, ...)
	end
end

local function OnFocusGained(self)
	self.focused = true
	self:Paint()
	Call(self, "onFocus", self)
end

local function OnFocusLost(self)
	self.focused = false
	self:Paint()
	Call(self, "onBlur", self)
end

local function OnEnterPressed(self)
	Call(self, "onEnter", self:GetText(), self)
	self:ClearFocus()
end

local function OnEscapePressed(self)
	self:ClearFocus()
	Call(self, "onEscape", self)
end

local function OnTextChanged(self, userInput)
	self:Paint()
	Call(self, "onChange", self:GetText(), self, userInput)
end

function Widgets.EditBox(parent, opts)
	opts = opts or {}
	local box = CreateFrame("EditBox", opts.name, parent or Scale.Root())
	for k, fn in pairs(EditBox) do
		box[k] = fn
	end
	box.opts = opts
	box:SetAutoFocus(false)
	Widgets.StyleText(box, "body")
	box:SetTextColor(Tokens.Color("textEmphasis"))
	if opts.maxLetters then
		box:SetMaxLetters(opts.maxLetters)
	end
	if opts.numeric then
		box:SetNumeric(true)
	end
	box.chrome = Widgets.Chrome(box, { shape = "tile", fill = "raised", shadow = false })
	box.placeholder = Widgets.Text(box, "body", "textDisabled")
	box.placeholder:SetJustifyH("LEFT")
	box.placeholder:SetWordWrap(false)
	Widgets.SetText(box.placeholder, opts.placeholder or "")
	box:HookScript("OnEditFocusGained", OnFocusGained)
	box:HookScript("OnEditFocusLost", OnFocusLost)
	box:HookScript("OnEnterPressed", OnEnterPressed)
	box:HookScript("OnEscapePressed", OnEscapePressed)
	box:HookScript("OnTextChanged", OnTextChanged)
	box:HookScript("OnEnter", function(self)
		Widgets.Hover(self, true)
	end)
	box:HookScript("OnLeave", function(self)
		Widgets.Hover(self, false)
	end)
	if opts.text then
		box:SetText(opts.text)
	end
	if opts.tooltip and Widgets.AttachTooltip then
		Widgets.AttachTooltip(box, opts.tooltip)
	end
	box:Restyle()
	return Widgets.Track(box)
end
