-- Zygor.lua: the Zygor switch: once Zygor Guides Viewer has loaded it restyles the guide window in the KstyleUI theme without touching Zygor's settings, and hangs the window in a card of its own on the story rail, its own mover in Layout Mode, re-placed after each step and after a layout change, out of combat, and kept out of Zygor's saved anchor while the rail holds it.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L

local MODULE = "Skins"
local KEY = "zygor"
local OWNER = "Skins.Zygor"
local ADDON = "ZygorGuidesViewerForever"
local RAIL = "rail"
local FIT = "fit"
local HOLDER = "KstyleUI_ZygorCard"
local DEFAULT_PRESET = "DPS"
local MOVED = 1
local MIN_WIDTH = 120
local WHITE = "Interface\\Buttons\\WHITE8X8"

local state = { z = nil, frame = nil, master = nil, holder = nil, placed = nil, original = nil, queued = false, hooked = false, held = false, patched = false, saved = nil }
local Place, Schedule, Restore, Fit, Text

local function Log(message)
	K.DevTest.Log(MODULE, "zygor: " .. message)
end

local function T(name, fn)
	return K.DevTest.Timed("Zygor " .. name, fn)
end

local function IsTable(value)
	return type(value) == "table"
end

local function Plain(value)
	return type(value) == "number" and not Widgets.IsSecret(value) and value == value
end

local function Zygor()
	local z = rawget(_G, "ZygorGuidesViewer")
	if not IsTable(z) or not IsTable(z.Frame) then
		return nil
	end
	return z
end

local function On()
	return K.Modules.IsRunning(MODULE) and ns.Skins.IsOn(KEY) and ns.Skins.Setting(KEY, RAIL) == true
end

local function Preset()
	local Layout = K.Layout
	return Layout and type(Layout.Setting) == "function" and Layout.Setting("preset") or DEFAULT_PRESET
end

local function Shown()
	local z, quests, Setup = Zygor(), ns.Quests, K.Setup
	local Layouts = Setup and Setup.Layouts
	if not (z and z.Frame:IsShown() and On() and quests and type(quests.Active) == "function" and quests.Active() and Layouts and type(Layouts.Story) == "function") then
		return false
	end
	local _, rh = Setup.RootSize()
	local story = Layouts.Story(Preset(), rh, true, K.HudStyle.Current())
	return story ~= nil and not story.stacked
end

local function Spec(style)
	local Setup = K.Setup
	local Layouts = Setup and Setup.Layouts
	if not (Layouts and type(Layouts.Story) == "function") then
		return nil
	end
	local rw, rh = Setup.RootSize()
	local shown = Shown()
	local story = Layouts.Story(Preset(), rh, true, style, rw, shown) or Layouts.Story(DEFAULT_PRESET, rh, true, style, rw, shown)
	return story and story.guide
end

local function Remember(master, frame)
	if state.original then
		return
	end
	local function Points(region)
		local points = {}
		for i = 1, region:GetNumPoints() do
			points[i] = { region:GetPoint(i) }
		end
		return points
	end
	state.original = {
		points = Points(master),
		width = master:GetWidth(),
		height = master:GetHeight(),
		framePoints = Points(frame),
		frameWidth = frame:GetWidth(),
		frameHeight = frame:GetHeight(),
	}
end

local function Hold(on)
	state.held = on
end

local function Origin(region)
	return K.Scale.Origin() / Widgets.ScaleFactor(region)
end

local function Anchor(region, point, relativePoint, x, y)
	region:ClearAllPoints()
	if Widgets.Readability("snapEdges") then
		Widgets.Point(region, point, UIParent, relativePoint, x, y, true)
	else
		region:SetPoint(point, UIParent, relativePoint, x, y)
	end
end

local function Near(a, b)
	return Plain(a) and Plain(b) and math.abs(a - b) < 0.5
end

local function Assert(keepHeight)
	local placed, master, frame = state.placed, state.master, state.frame
	if not (placed and master and frame) then
		return
	end
	master:SetClampedToScreen(false)
	master:SetClampRectInsets(0, 0, 0, 0)
	if placed.up then
		Anchor(master, "BOTTOMLEFT", "BOTTOMLEFT", placed.left, placed.bottom)
	else
		Anchor(master, "TOPLEFT", "BOTTOMLEFT", placed.left, placed.top)
	end
	frame:SetClampRectInsets(0, 0, 0, 0)
	frame:ClearAllPoints()
	frame:SetPoint(placed.up and "BOTTOMLEFT" or "TOPLEFT", master, placed.up and "BOTTOMLEFT" or "TOPLEFT")
	if not Near(frame:GetWidth(), placed.width) then
		frame:SetWidth(placed.width)
	end
	if not keepHeight and not Near(frame:GetHeight(), placed.height) then
		frame:SetHeight(placed.height)
	end
end

Assert = T("Assert", Assert)

function Fit()
	local placed, frame = state.placed, state.frame
	if state.busy or not (placed and frame) then
		return
	end
	if ns.Skins.Setting(KEY, FIT) == true then
		return
	end
	local height = placed.room
	if Plain(height) and height > 0 and not Near(frame:GetHeight(), height) then
		local z = state.z
		local profile = IsTable(z) and IsTable(z.db) and z.db.profile
		local full = IsTable(profile) and profile.fullheight
		if frame.SetResizeBounds then
			frame:SetResizeBounds(0, 0, 0, 0)
		end
		local script = frame:GetScript("OnSizeChanged")
		frame:SetScript("OnSizeChanged", nil)
		frame:SetHeight(height)
		frame:SetScript("OnSizeChanged", script)
		if IsTable(profile) then
			profile.fullheight = full
		end
	end
end

Fit = T("Fit", Fit)

local function Follow()
	local z = state.z
	local bar = IsTable(z) and IsTable(z.ActionBar) and z.ActionBar.Frame
	if not (state.placed and bar and bar.snapped == true) then
		return
	end
	if type(z.ActionBar.SavePosition) == "function" then
		K.Call(z.ActionBar.SavePosition, z.ActionBar)
	end
end

local function Settle()
	if state.settle then
		return
	end
	state.settle = true
	C_Timer.After(0.002, T("Settle", function()
		state.settle = false
		local z = state.z
		if state.placed and IsTable(z) and type(z.ResizeFrame) == "function" then
			K.Call(z.ResizeFrame, z)
		end
		Fit()
		Follow()
		Text(state.frame)
	end))
end

local function Live()
	local Layout = K.Layout
	local spec = state.holder and Spec(K.HudStyle.Current())
	if spec and Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(spec.key, On())
	end
end

local function Strayed(master, frame)
	local placed = state.placed
	local point, relative, _, x, y = master:GetPoint(1)
	if point ~= (placed.up and "BOTTOMLEFT" or "TOPLEFT") or relative ~= UIParent or not (Plain(x) and Plain(y)) then
		return true
	end
	local want = placed.up and placed.bottom or placed.top
	if math.abs(x - placed.left) > MOVED or math.abs(y - want) > MOVED then
		return true
	end
	local width = frame:GetWidth()
	return Plain(width) and math.abs(width - placed.width) > MOVED
end

function Schedule()
	if state.queued or not On() then
		return
	end
	state.queued = true
	C_Timer.After(0, function()
		K.Combat.Queue(Place)
	end)
end

local function Holder(spec)
	if not state.holder then
		local holder = CreateFrame("Frame", HOLDER, K.Scale.Root())
		holder:EnableMouse(false)
		state.holder = holder
	end
	if spec and (spec.width ~= state.width or spec.height ~= state.height) then
		state.width, state.height = spec.width, spec.height
		state.holder:SetSize(spec.width, spec.height)
	end
	return state.holder
end

local function Register(spec)
	if state.holder and spec then
		Widgets.Place(state.holder, spec.key, { anchor = spec.anchor, x = spec.x, y = spec.y }, { label = L["Zygor guide"], module = MODULE })
	end
end

local function Skip(why)
	if state.why ~= why then
		state.why = why
		Log("rail skipped: " .. why)
	end
	return false
end

function Place()
	state.queued = false
	if not On() then
		return Skip("rail off")
	end
	if not ns.Guide.Is(KEY) then
		Restore()
		return Skip("another guide owns the card")
	end
	local z = Zygor()
	local frame = z and z.Frame
	local master = frame and frame:GetParent()
	local spec = Spec(K.HudStyle.Current())
	local story = K.Setup.Story(Preset(), true, Shown())
	local band = story and story.guide
	if not (master and spec and band) then
		return Skip("no " .. (not master and "window" or not spec and "slot" or "story band") .. " (shown=" .. tostring(Shown()) .. ")")
	end
	if state.placed and Strayed(master, frame) then
		state.placed = nil
		Restore()
		K.Options.Write(MODULE, KEY .. "." .. RAIL, false)
		Log("the player moved the guide; the story rail lets it be")
		K.Print(L["KstyleUI leaves the Zygor guide where you put it. Turn Story rail back on in the Zygor skin's settings."])
		return false
	end
	state.why = nil
	Remember(master, frame)
	Hold(true)
	state.z, state.frame, state.master = z, frame, master
	Holder(spec)
	Register(spec)
	local scale = Widgets.ScaleFactor(master)
	local resizeup = IsTable(z.db) and IsTable(z.db.profile) and z.db.profile.resizeup
	state.placed = {
		left = band.left / scale + Origin(master),
		top = band.top / scale,
		bottom = band.bottom / scale,
		width = math.max(MIN_WIDTH, (band.right - band.left) / scale),
		room = (band.top - band.bottom) / scale,
		height = (band.top - band.bottom) / scale,
		up = resizeup == true,
	}
	state.busy = true
	Assert(true)
	if z.ResizeFrame then
		K.Call(z.ResizeFrame, z)
	end
	state.busy = false
	Fit()
	Settle()
	Live()
	return true
end

Place = T("Place", Place)

function Restore()
	state.placed = nil
	local z, master, frame, original = state.z, state.master, state.frame, state.original
	Hold(false)
	if not (z and master and frame) then
		return
	end
	state.original = nil
	master:SetClampedToScreen(true)
	master:ClearAllPoints()
	if original then
		for _, point in ipairs(original.points) do
			master:SetPoint(unpack(point))
		end
		if Plain(original.width) and Plain(original.height) then
			master:SetSize(original.width, original.height)
		end
		frame:ClearAllPoints()
		for _, point in ipairs(original.framePoints) do
			frame:SetPoint(unpack(point))
		end
		if Plain(original.frameWidth) and Plain(original.frameHeight) then
			frame:SetSize(original.frameWidth, original.frameHeight)
		end
	end
	if type(z.ResizeFrame) == "function" then
		K.Call(z.ResizeFrame, z)
	end
	Live()
end

local function Patch(z)
	if state.patched then
		return
	end
	state.patched = true
	local F = z.F
	local function Ours(region)
		return region ~= nil and (region == state.master or region == state.frame)
	end
	if IsTable(F) and type(F.SaveFrameAnchor) == "function" then
		local save = F.SaveFrameAnchor
		F.SaveFrameAnchor = function(frame, name, context)
			if state.held and name == "frame_anchor" and Ours(frame) then
				return
			end
			return save(frame, name, context)
		end
	end
	if IsTable(F) and type(F.SetFrameAnchor) == "function" then
		local set = F.SetFrameAnchor
		F.SetFrameAnchor = function(frame, anchor)
			if state.held and Ours(frame) then
				return
			end
			return set(frame, anchor)
		end
	end
	if type(z.ResizeFrame) == "function" then
		hooksecurefunc(z, "ResizeFrame", T("ResizeFrame", function()
			Fit()
		end))
	end
	if type(z.ReanchorFrame) == "function" then
		hooksecurefunc(z, "ReanchorFrame", T("ReanchorFrame", function()
			if not state.busy then
				Assert(true)
			end
		end))
	end
	if type(z.SetFrameScale) == "function" then
		hooksecurefunc(z, "SetFrameScale", T("SetFrameScale", function()
			Schedule()
		end))
	end
	if type(z.ApplySkin) == "function" then
		hooksecurefunc(z, "ApplySkin", T("ApplySkin", function()
			Text(state.frame)
		end))
	end
end

local function Flat()
	return { bgFile = WHITE, tile = true, tileSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } }
end

local function Color(name)
	local r, g, b, a = Tokens.Color(name)
	return { r, g, b, a }
end

local function Clear()
	return { 0, 0, 0, 0 }
end

local function Face(text)
	if not (IsTable(text) and type(text.GetFont) == "function") then
		return
	end
	local path = ns.Style.Font("body")
	local current, size, flags = text:GetFont()
	if type(path) == "string" and current ~= path and Plain(size) then
		text:SetFont(path, size, flags)
	end
end

function Text(frame)
	local controls = frame and frame.Controls
	local container = IsTable(controls) and controls.StepContainer
	if not (container and type(container.GetChildren) == "function") then
		return
	end
	local children = { container:GetChildren() }
	for i = 1, #children do
		local lines = children[i].lines
		if IsTable(lines) then
			for j = 1, #lines do
				Face(lines[j].label)
			end
		end
	end
end

local LINE_ALPHA = 0
local hookedSteps = setmetatable({}, { __mode = "k" })

local function QuietStep(step)
	if state.saved and type(step.SetBackdropColor) == "function" then
		local r, g, b = Tokens.Color("surface")
		step:SetBackdropColor(r, g, b, 0)
		step:SetBackdropBorderColor(r, g, b, 0)
	end
end

local function QuietBack(back, r, g, b, a)
	local center = back.Center
	if state.saved and IsTable(center) and type(center.SetColorTexture) == "function" and Plain(a) then
		center:SetColorTexture(r, g, b, a * LINE_ALPHA)
	end
end

local function AccentBar(bar, r, g)
	if state.saved and r == 0 and Plain(g) and g > 0.7 and IsTable(bar.Texture) then
		local ar, ag, ab = Tokens.Color("accent")
		bar.Texture:SetVertexColor(ar, ag, ab, 1)
		if IsTable(bar.Decor) then bar.Decor:SetVertexColor(ar, ag, ab, 1) end
	end
end

local function Steps(frame)
	local steps = IsTable(frame) and frame.stepframes
	if not IsTable(steps) then
		return
	end
	for _, step in ipairs(steps) do
		if not hookedSteps[step] and type(step.SetBackgroundForStep) == "function" then
			hookedSteps[step] = true
			hooksecurefunc(step, "SetBackgroundForStep", T("SetBackgroundForStep", QuietStep))
			for _, line in ipairs(IsTable(step.lines) and step.lines or {}) do
				local back = line.back
				if IsTable(back) and type(back.SetBackdropColor) == "function" and type(back.GetBackdropColor) == "function" then
					hooksecurefunc(back, "SetBackdropColor", T("SetBackdropColor", QuietBack))
					QuietBack(back, back:GetBackdropColor())
				end
			end
		end
		QuietStep(step)
	end
end

local MENU_LEFT = 9

local function Caption(z, panel)
	local frame = z.Frame
	local bar = IsTable(frame.Border) and frame.Border.TitleBar
	if not (panel and IsTable(bar)) then
		return
	end
	local caption = state.caption
	if not caption then
		local Parts, Style, Lumen = ns.Parts, ns.Style, ns.Lumen
		if IsTable(frame.Controls) then
			Parts.Hush(frame.Controls.Logo)
		end
		caption = Widgets.FontString(bar, "OVERLAY")
		caption:SetPoint("LEFT", bar, "LEFT")
		caption:SetJustifyH("LEFT")
		caption:SetWordWrap(false)
		Style.ApplyFont(caption, "caps", Lumen.Size(bar, Lumen.CAP_SIZE))
		Widgets.TextColor(caption, "capsGold")
		state.caption = caption
		local controls = IsTable(frame.Controls) and frame.Controls or {}
		local menu = controls.MenuSettingsButton
		local inset = IsTable(menu) and Plain(menu:GetWidth()) and MENU_LEFT + menu:GetWidth() or 0
		Parts.Heading(panel, caption, { row = bar, inset = inset, close = controls.CloseButton })
	end
	local guide = z.CurrentGuide
	local title = IsTable(guide) and (guide.title_short or guide.title)
	caption:SetText(type(title) == "string" and title:upper() or L["Zygor"])
	caption:Show()
end

local function Fonts(z)
	if not state.saved then
		return
	end
	local controls = IsTable(z.Frame) and z.Frame.Controls
	Face(IsTable(controls) and IsTable(controls.StepNum) and controls.StepNum.Step)
	local pool = IsTable(z.Tabs) and z.Tabs.Pool
	for _, tab in pairs(IsTable(pool) and pool or {}) do
		Face(IsTable(tab) and tab.Text)
	end
end

local ROLES = {
	MenuSettingsButton = "ink", TabsAddButton = "ink", TabsMoreButton = "ink", GuideShareButton = "ink", ReportStep = "ink", MenuAdditionalButton = "ink",
	PrevButton = -math.pi / 2, NextButton = math.pi / 2, CloseButton = "close",
}

local function Ink(button)
	local role = state.saved and ROLES[button.kstyleKey]
	if not role then
		return
	end
	local r, g, b = Tokens.Color("muted")
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local texture = type(button[getter]) == "function" and button[getter](button)
		if IsTable(texture) and role == "ink" then
			texture:SetVertexColor(r, g, b, 1)
		elseif IsTable(texture) then
			texture:SetAlpha(0)
		end
	end
end

local function Controls(z)
	local controls = IsTable(z.Frame) and z.Frame.Controls
	if not IsTable(controls) or state.controls then
		return
	end
	state.controls = true
	for key, role in pairs(ROLES) do
		local button = controls[key]
		if IsTable(button) then
			button.kstyleKey = key
			if role == "close" then
				K.Skin.CloseButton(button)
			elseif type(role) == "number" then
				ns.Parts.Glyph(button, "glyphChevron", { rotation = role })
			end
			if type(button.AssignTextures) == "function" then
				hooksecurefunc(button, "AssignTextures", T("AssignTextures", Ink))
			end
			Ink(button)
		end
	end
end

local function ArrowText(arrow)
	if not (state.saved and IsTable(arrow)) then
		return
	end
	local offset = Tokens.Size("textShadowOffset")
	for _, key in ipairs({ "title", "desc" }) do
		local text = arrow[key]
		if IsTable(text) and type(text.GetFont) == "function" then
			Face(text)
			text:SetTextColor(Tokens.Color("textEmphasis"))
			text:SetShadowColor(Tokens.Color("textShadow"))
			text:SetShadowOffset(offset, -offset)
		end
	end
end

local function FlatArrow(frame)
	local arrow = state.saved and IsTable(frame) and frame.arrow
	if IsTable(arrow) and IsTable(arrow.arr) then
		arrow.arr:SetVertexColor(Tokens.Color("textEmphasis"))
	end
	if IsTable(arrow) and IsTable(arrow.arrspecular) then
		arrow.arrspecular:SetAlpha(0)
	end
end

local function Arrow(z)
	local pointer = z.Pointer
	local frame = IsTable(pointer) and pointer.ArrowFrame
	if not IsTable(frame) then
		return
	end
	if frame ~= state.arrow then
		state.arrow = frame
		if type(frame.ShowTraveling) == "function" then
			hooksecurefunc(frame, "ShowTraveling", T("ShowTraveling", FlatArrow))
		end
	end
	if not state.arrowFonts and type(pointer.SetFontSize) == "function" then
		state.arrowFonts = true
		hooksecurefunc(pointer, "SetFontSize", T("SetFontSize", function() ArrowText(state.arrow) end))
	end
	ArrowText(frame)
	FlatArrow(frame)
end

local function Paint(z)
	local style = z.CurrentSkinStyle
	if not IsTable(style) then
		return
	end
	state.saved = state.saved or {}
	local function Set(name, value)
		if state.saved[name] == nil then
			state.saved[name] = { style[name] }
		end
		style[name] = value
	end
	Set("WindowBackdropColor", Clear())
	Set("WindowBackdropBorderColor", Clear())
	Set("WindowBottomBackdropColor", Clear())
	Set("WindowBottomBackdropBorderColor", Clear())
	Set("TabBackdrop", Flat())
	Set("TabBackdropColor", Clear())
	Set("SystemBarBackdropColor", Clear())
	Set("SystemBarBackdropBorderColor", Clear())
	Set("StepBackdropColor", Clear())
	Set("StepBackdropBorderColor", Clear())
	Set("StepBackdropPersistentBorder", false)
	Set("ProgressBarBackdrop", Flat())
	Set("ProgressBarBackdropColor", Color("surface"))
	Set("ProgressBarBackdropBorderColor", Clear())
	Set("ProgressBarTextureFile", WHITE)
	Set("ProgressBarTextureColor", Color("accent"))
	Set("ProgressBarDecorUse", 0)
	Set("StepFontSizeMod", 1)
	Set("Accent", Color("accent"))
	Set("ScrollBarTexture", WHITE)
	Set("ScrollBarColor", Color("muted"))
	Set("TabsTextColor", Color("text"))
	Set("TabsBackdropActive", Clear())
	Set("TabsBackdropInactive", Clear())
	Set("TabsBorderColor", Clear())
	local path = ns.Style.Font("body")
	if type(path) == "string" then
		z.Font = path
	end
	if type(z.ApplySkin) == "function" then
		K.Call(z.ApplySkin, z)
	end
	local border = IsTable(z.Frame) and z.Frame.Border
	local panel = IsTable(border) and K.Skin.Backdrop(border, { shape = "window", fill = "surface", shadow = true })
	if panel then
		panel:Show()
		Caption(z, panel)
	end
	Text(z.Frame)
	Steps(z.Frame)
	Fonts(z)
	Controls(z)
	Arrow(z)
	if not state.steps and IsTable(z.Frame) and type(z.Frame.AddStep) == "function" then
		state.steps = true
		hooksecurefunc(z.Frame, "AddStep", T("AddStep", Steps))
		if type(z.Frame.ApplySkin) == "function" then
			hooksecurefunc(z.Frame, "ApplySkin", T("ApplySkin", function() Fonts(z) end))
		end
		if IsTable(z.Tabs) and type(z.Tabs.ReanchorTabs) == "function" then
			hooksecurefunc(z.Tabs, "ReanchorTabs", T("ReanchorTabs", function() Fonts(z) end))
		end
		local bar = z.ProgressBar
		if IsTable(bar) and type(bar.SetColor) == "function" then
			hooksecurefunc(bar, "SetColor", T("SetColor", AccentBar))
			if IsTable(bar.Texture) and type(bar.Texture.GetVertexColor) == "function" then
				AccentBar(bar, bar.Texture:GetVertexColor())
			end
		end
	end
end

local function Unpaint(z)
	local style, saved = z.CurrentSkinStyle, state.saved
	if not (IsTable(style) and saved) then
		return
	end
	for name, value in pairs(saved) do
		style[name] = value[1]
	end
	state.saved = nil
	if type(z.ApplySkin) == "function" then
		K.Call(z.ApplySkin, z)
	end
	local border = IsTable(z.Frame) and z.Frame.Border
	local panel = IsTable(border) and K.Skin.Parts(border).backdrop
	if panel then
		panel:Hide()
	end
	if state.caption then
		state.caption:Hide()
	end
end

local function Hook(z)
	state.z = z
	Patch(z)
	if state.hooked then
		return
	end
	state.hooked = true
	if type(z.AddMessageHandler) == "function" then
		z:AddMessageHandler("ZGV_FRAME_VISIBILITY", function(visible)
			if visible then
				ns.Guide.Touch(KEY)
			end
			ns.Guide.Schedule()
		end)
		z:AddMessageHandler("ZGV_GUIDE_LOADED", function()
			local live = Zygor()
			local panel = live and state.saved and IsTable(live.Frame.Border) and K.Skin.Parts(live.Frame.Border).backdrop
			if panel then Caption(live, panel) end
			Schedule()
		end)
		z:AddMessageHandler("ZGV_STEP_CHANGED", function()
			local live = Zygor()
			if live then Arrow(live) end
			Schedule()
		end)
		z:AddMessageHandler("SKIN_UPDATED", function()
			K.Combat.Queue(function()
				local live = Zygor()
				if live then Paint(live) end
				Schedule()
			end)
		end)
	end
	K.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Schedule)
	K.Callbacks.Register("LayoutChanged", OWNER, Schedule)
	K.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
		if module == "Layout" and key == "preset" then
			Schedule()
		end
	end)
	if not state.tracked then
		state.tracked = { Restyle = Schedule }
		Widgets.Track(state.tracked)
	end
end

local function Start(z)
	Hook(z)
	Paint(z)
	K.Combat.Queue(Place)
end

ns.Guide.Add(KEY, {
	addon = ADDON,
	Enabled = function()
		return Zygor() ~= nil and ns.Skins.IsOn(KEY) and ns.Skins.Setting(KEY, RAIL) == true
	end,
	Visible = function()
		return Shown()
	end,
	Schedule = Schedule,
})

ns.Skins.Add({
	key = KEY,
	label = L["Zygor"],
	help = L["Gives Zygor Guides Viewer the KstyleUI theme and puts its guide on the story rail."],
	addon = ADDON,
	defaults = { rail = true, fit = true },
	rows = {
		{ type = "toggle", key = FIT, label = L["Fit guide to its steps"], help = L["Size the guide to its steps. Off stretches it over the story slot."] },
		{
			type = "toggle", key = RAIL, label = L["Story rail"],
			help = L["Puts the guide in its own card on the story rail. Drag the guide away to keep your spot."],
		},
	},
	Apply = function()
		local z = Zygor()
		if z then
			Start(z)
			return
		end
		local raw = rawget(_G, "ZygorGuidesViewer")
		if IsTable(raw) and type(raw.SetSkin) == "function" and not state.waiting then
			state.waiting = true
			hooksecurefunc(raw, "SetSkin", T("SetSkin", function()
				local live = Zygor()
				if live and not state.z and ns.Skins.IsOn(KEY) then
					Start(live)
				end
			end))
		end
	end,
	OnSwitch = function(_, on)
		local z = Zygor()
		if not z then
			return
		end
		if on then
			Start(z)
		else
			Restore()
			Unpaint(z)
		end
	end,
	OnSetting = function(_, field)
		if field == nil or field == RAIL then
			if On() then
				Schedule()
			else
				Restore()
			end
		elseif field == FIT then
			Schedule()
		end
	end,
})
