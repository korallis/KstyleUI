-- test-skin.lua: the Skin helpers restyle Blizzard frames through alpha, hooks and KstyleUI's own child frames, never SetScript, Hide or field writes.
local W = dofile("Tools/regression/widget_env.lua")

-- Fields a hook may add: hooksecurefunc replaces the hooked method on the object it hooks.
local HOOKED = { SetAlpha = true, SetTabSelected = true, SetChecked = true }

local function fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

-- Blizzard(env) -> a builder of stand-in Blizzard frames that remembers every object it made.
local function Blizzard(env)
	local made = {}
	local b = { made = made }
	function b.frame(kind, parent, name)
		local f = env.CreateFrame(kind or "Frame", name, parent or env.UIParent)
		made[#made + 1] = f
		return f
	end
	function b.texture(frame, layer)
		local t = frame:CreateTexture(nil, layer or "ARTWORK")
		t:SetTexture("Interface\\Blizzard\\Art")
		made[#made + 1] = t
		return t
	end
	function b.text(frame)
		local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		made[#made + 1] = fs
		return fs
	end
	function b.snapshot()
		local snap = {}
		for _, object in ipairs(made) do
			snap[object] = fields(object)
		end
		return snap
	end
	function b.check(snap)
		for _, object in ipairs(made) do
			local before = snap[object] or {}
			for k in pairs(fields(object)) do
				assert(before[k] or HOOKED[k], "a field was written onto a Blizzard object: " .. tostring(k))
			end
			for _, call in ipairs(object._calls) do
				assert(call.method ~= "SetScript", "SetScript on a Blizzard object")
				assert(call.method ~= "Hide" or object._kstyleAllowHide, "Hide on a Blizzard object")
				assert(call.method ~= "SetParent", "SetParent on a Blizzard object")
			end
		end
	end
	return b
end

-- Strip: every texture goes to alpha 0 and stays there through Blizzard's own SetAlpha; text stays.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local frame = B.frame()
	local art, edge = B.texture(frame), B.texture(frame, "BORDER")
	local keep = B.texture(frame)
	local label = B.text(frame)
	frame.NineSlice = B.frame("Frame", frame)
	local corner = B.texture(frame.NineSlice)
	frame.Inset = B.frame("Frame", frame)
	frame.Inset.Bg = B.texture(frame.Inset)
	local snap = B.snapshot()
	local count = K.Skin.Strip(frame, { keep = { [keep] = true }, children = { "NineSlice", "Inset.Bg" } })
	assert(count == 4, "four textures stripped, got " .. tostring(count))
	assert(art:GetAlpha() == 0 and edge:GetAlpha() == 0 and corner:GetAlpha() == 0 and frame.Inset.Bg:GetAlpha() == 0)
	assert(keep:GetAlpha() == 1 and label:GetAlpha() == 1, "kept regions and text are untouched")
	art:SetAlpha(1)
	assert(art:GetAlpha() == 0, "Blizzard's SetAlpha cannot bring a stripped texture back")
	assert(K.Skin.Strip(frame) == 0 and art:GetAlpha() == 0, "stripping again strips nothing new")
	local late = B.texture(frame)
	frame:GetScript("OnShow")(frame)
	assert(late:GetAlpha() == 0, "a texture Blizzard adds later is stripped on show")
	B.check(snap)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A missing frame is logged and skipped, so callers can pass _G.SomeFrame unchecked.
do
	local env, K = W.New()
	for _, name in ipairs({ "Strip", "Backdrop", "CloseButton", "Tab", "Tabs", "ScrollBar", "EditBox", "CheckBox", "Button", "Window" }) do
		K.Skin[name](nil)
	end
	local logged = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.module == "Skin" then
			logged = logged + 1
		end
	end
	assert(logged >= 1 and #env._errors == 0, "missing frames are logged, not errors")
end

-- Backdrop: a KstyleUI panel on its own child frame one level behind the Blizzard frame.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local frame = B.frame()
	frame:SetFrameLevel(10)
	local snap = B.snapshot()
	local panel = K.Skin.Backdrop(frame, { inset = 4 })
	assert(panel and panel:GetParent() == frame and panel:GetFrameLevel() == 9, "behind the frame")
	assert(panel.chrome and #panel.chrome.fill == 9 and panel.chrome.shadow[1]:IsShown(), "panel chrome with a shadow")
	local p = panel._points[1]
	local inset = K.Widgets.Snap(panel, 4)
	assert(p[1] == "TOPLEFT" and p[2] == frame and W.Near(p[4], inset) and W.Near(p[5], -inset), "inset from the frame, in whole pixels of its scale")
	assert(K.Skin.Backdrop(frame) == panel, "a second call returns the same panel")
	env._physical = { 3456, 2234 }
	env.GetPhysicalScreenSize = function()
		return env._physical[1], env._physical[2]
	end
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	local moved = panel._points[1]
	assert(W.Near(moved[4], K.Widgets.Snap(panel, 4)) and not W.Near(moved[4], inset), "a display change re-snaps the inset, got " .. moved[4])
	assert(K.Skin.IsSkinned(frame, "Backdrop"))
	local tile = K.Skin.Backdrop(B.frame(), { shape = "tile", fill = "raised", shadow = false })
	assert(tile.chrome.shadow[1]:IsShown() == false)
	B.check(snap)
end

-- Backdrop with a target: the panel stays the frame's backdrop, one level behind it, but surrounds the target.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local frame = B.frame()
	frame:SetFrameLevel(10)
	local target = env.CreateFrame("Frame", nil, frame)
	local snap = B.snapshot()
	local panel = K.Skin.Backdrop(frame, { inset = -8, target = target })
	assert(panel:GetParent() == frame and panel:GetFrameLevel() == 9 and K.Skin.IsSkinned(frame, "Backdrop"), "the frame's backdrop")
	local function Anchors()
		local a, b = panel._points[1], panel._points[2]
		return a[1] == "TOPLEFT" and a[2] == target and b[1] == "BOTTOMRIGHT" and b[2] == target
	end
	assert(Anchors(), "placed around the target")
	assert(W.Near(panel._points[1][4], K.Widgets.Snap(panel, -8)), "with the inset, in whole pixels")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	assert(Anchors(), "a restyle keeps the target")
	B.check(snap)
end

-- CloseButton: Blizzard's art goes, KstyleUI's cross glyph lights under the mouse.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local close = B.frame("Button")
	local normal, pushed = B.texture(close), B.texture(close)
	local snap = B.snapshot()
	local glyph = K.Skin.CloseButton(close)
	assert(normal:GetAlpha() == 0 and pushed:GetAlpha() == 0, "Blizzard's close art is stripped")
	assert(glyph and W.LastCall(glyph, "SetTexture")[1] == K.Tokens.Texture("glyphClose"), "the cross glyph")
	assert(W.SameRGB(glyph, K.Tokens.Color("text")))
	W.Enter(close)
	W.Settle(env)
	assert(W.SameRGB(glyph, K.Tokens.Color("textHover")), "it lights under the mouse")
	W.Leave(close)
	close:Disable()
	W.Settle(env)
	assert(W.SameRGB(glyph, K.Tokens.Color("textDisabled")), "and greys when disabled")
	B.check(snap)
end

-- Tabs from PanelTemplates: Blizzard's select and deselect drive an accent underline through global hooks.
do
	local env, K = W.New({ setup = function(e)
		function e.PanelTemplates_SelectTab(tab)
			tab:Disable()
		end
		function e.PanelTemplates_DeselectTab(tab)
			tab:Enable()
		end
		function e.PanelTemplates_SetDisabledTabState(tab)
			tab:Disable()
		end
	end })
	local B = Blizzard(env)
	local owner = B.frame()
	owner.Tabs = {}
	for i = 1, 3 do
		local tab = B.frame("Button", owner)
		B.texture(tab)
		tab.Text = B.text(tab)
		owner.Tabs[i] = tab
	end
	owner.numTabs = 3
	local disabled = B.frame("Button", owner)
	disabled.Text = B.text(disabled)
	disabled.isDisabled = 1
	disabled:Disable()
	owner.Tabs[4] = disabled
	owner.numTabs = 4
	env.PanelTemplates_SelectTab(owner.Tabs[1])
	local snap = B.snapshot()
	K.Skin.Tabs(owner)
	assert(not K.Skin.Parts(disabled).underline:IsShown(), "a tab Blizzard disabled with isDisabled = 1 is not selected")
	assert(W.SameRGB({ GetVertexColor = function()
		return disabled.Text:GetTextColor()
	end }, K.Tokens.Color("textDisabled")), "and its text is grey")
	local function underline(tab)
		return K.Skin.Parts(tab).underline
	end
	assert(underline(owner.Tabs[1]):IsShown() and not underline(owner.Tabs[2]):IsShown(), "the selected tab starts underlined")
	assert(W.SameRGB(underline(owner.Tabs[1]), K.Tokens.Color("accent")))
	env.PanelTemplates_DeselectTab(owner.Tabs[1])
	env.PanelTemplates_SelectTab(owner.Tabs[2])
	assert(underline(owner.Tabs[2]):IsShown() and not underline(owner.Tabs[1]):IsShown(), "the underline follows Blizzard's selection")
	assert(W.SameRGB({ GetVertexColor = function()
		return owner.Tabs[2].Text:GetTextColor()
	end }, K.Tokens.Color("textEmphasis")), "the selected tab's text is bright")
	assert(W.SameRGB({ GetVertexColor = function()
		return owner.Tabs[1].Text:GetTextColor()
	end }, K.Tokens.Color("text")), "the others are grey")
	B.check(snap)
	assert(#env._errors == 0)
end

-- Tabs from the newer tab system report selection through SetTabSelected, which the helper hooks per tab.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local tab = B.frame("Button")
	tab.isSelected = false
	function tab:SetTabSelected(selected)
		self.isSelected = selected
	end
	B.texture(tab)
	local snap = B.snapshot()
	K.Skin.Tab(tab)
	assert(not K.Skin.Parts(tab).underline:IsShown())
	tab:SetTabSelected(true)
	assert(K.Skin.Parts(tab).underline:IsShown(), "selection through the tab system")
	B.check(snap)
end

-- ScrollBar: the track and thumb art go; a thin track, an accent-on-hover thumb and chevron steppers come.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local bar = B.frame("EventFrame")
	bar.Track = B.frame("Frame", bar)
	B.texture(bar.Track)
	bar.Track.Thumb = B.frame("Button", bar.Track)
	bar.Thumb = bar.Track.Thumb
	local thumbArt = B.texture(bar.Thumb)
	bar.Background = B.frame("Frame", bar)
	local trim = B.texture(bar.Background)
	bar.Back = B.frame("Button", bar)
	bar.Forward = B.frame("Button", bar)
	B.texture(bar.Back)
	B.texture(bar.Forward)
	local snap = B.snapshot()
	K.Skin.ScrollBar(bar)
	assert(thumbArt:GetAlpha() == 0 and trim:GetAlpha() == 0, "the thumb and the trim bar's background art are stripped")
	local parts = K.Skin.Parts(bar)
	assert(parts.thumb and parts.thumb._points[1][2] == bar.Thumb, "KstyleUI's thumb follows Blizzard's")
	assert(parts.track and W.SameColor(parts.track, K.Tokens.Color("track")))
	assert(parts.back and W.LastCall(parts.back, "SetTexCoord")[3] == 1, "the back stepper's chevron points up")
	assert(parts.forward and W.LastCall(parts.forward, "SetTexture")[1] == K.Tokens.Texture("glyphChevron"))
	W.Enter(bar.Thumb)
	W.Settle(env)
	assert(W.SameRGB(parts.thumb, K.Tokens.Color("accent")), "the thumb lights under the mouse")
	bar.Thumb._kstyleAllowHide, bar.Track._kstyleAllowHide = true, true
	bar.Thumb:Hide()
	assert(not parts.thumb:IsVisible(), "KstyleUI's thumb hides with Blizzard's")
	bar.Thumb:Show()
	assert(parts.thumb:IsVisible())
	bar.Track:Hide()
	assert(not parts.track:IsVisible(), "and the rail with the track")
	bar.Track:Show()
	B.check(snap)
	local oneWay = B.frame("Frame")
	oneWay.Forward = B.frame("Button", oneWay)
	snap = B.snapshot()
	local oneParts = K.Skin.ScrollBar(oneWay)
	assert(oneParts.back == nil and W.SameRGB(oneParts.forward, K.Tokens.Color("text")), "a bar with only a forward stepper still tints its chevron")
	assert(W.Near(oneParts.forward:GetWidth(), K.Widgets.Snap(oneParts.forward, 8)), "and sizes it")
	B.check(snap)
	local slider = B.frame("Slider")
	local thumbTexture = B.texture(slider)
	slider.GetThumbTexture = function()
		return thumbTexture
	end
	snap = B.snapshot()
	K.Skin.ScrollBar(slider)
	assert(thumbTexture:GetAlpha() == 0 and K.Skin.Parts(slider).thumb._points[1][2] == thumbTexture, "an old slider scroll bar too")
	B.check(snap)
end

-- EditBox and CheckBox: tiles behind, focus lights the edit box, the check mark follows SetChecked and clicks.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local box = B.frame("EditBox")
	local left = B.texture(box)
	box.searchIcon = B.texture(box)
	local check = B.frame("CheckButton")
	local checkArt = B.texture(check)
	local snap = B.snapshot()
	local backdrop = K.Skin.EditBox(box)
	assert(left:GetAlpha() == 0 and box.searchIcon:GetAlpha() == 1, "the search icon stays")
	assert(backdrop and W.SameRGB(backdrop.chrome.fill[5], K.Tokens.Color("raised")))
	box:GetScript("OnEditFocusGained")(box)
	assert(W.SameRGB(backdrop.chrome.inner[5], K.Tokens.Color("accent")), "focus lights the edit box")
	box:GetScript("OnEditFocusLost")(box)
	assert(W.SameRGB(backdrop.chrome.inner[5], K.Tokens.Color("edgeInner")))
	local parts = K.Skin.CheckBox(check)
	assert(checkArt:GetAlpha() == 0 and parts.box and parts.mark, "a KstyleUI box and mark")
	assert(parts.mark:IsShown() == false)
	check:SetChecked(true)
	assert(parts.mark:IsShown() and W.SameRGB(parts.mark, K.Tokens.Color("accent")), "SetChecked shows the accent mark")
	check:SetChecked(false)
	check:GetScript("OnClick")(check)
	assert(parts.mark:IsShown() == false)
	B.check(snap)
	assert(#env._errors == 0)
end

-- Button: Blizzard's three-piece art goes; a raised tile with a hairline that lights under the mouse comes.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local button = B.frame("Button")
	local l, m, r = B.texture(button), B.texture(button), B.texture(button)
	local text = B.text(button)
	button.GetFontString = function()
		return text
	end
	local snap = B.snapshot()
	local backdrop = K.Skin.Button(button)
	assert(l:GetAlpha() == 0 and m:GetAlpha() == 0 and r:GetAlpha() == 0)
	W.Enter(button)
	W.Settle(env)
	assert(W.SameRGB(backdrop.chrome.inner[5], K.Tokens.Color("accent")), "hover lights the hairline")
	assert(W.SameRGB({ GetVertexColor = function()
		return text:GetTextColor()
	end }, K.Tokens.Color("textHover")), "and the text")
	W.Leave(button)
	button:Disable()
	W.Settle(env)
	assert(W.SameRGB({ GetVertexColor = function()
		return text:GetTextColor()
	end }, K.Tokens.Color("textDisabled")), "a disabled button greys its text")
	B.check(snap)
end

-- Window: the portrait frame's art, title, close button and tabs in one call.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local window = B.frame("Frame", nil, "TestBlizzardWindow")
	window.NineSlice = B.frame("Frame", window)
	local nine = B.texture(window.NineSlice)
	window.Bg = B.texture(window, "BACKGROUND")
	window.PortraitContainer = B.frame("Frame", window)
	local portrait = B.texture(window.PortraitContainer)
	window.TitleContainer = B.frame("Frame", window)
	window.TitleContainer.TitleText = B.text(window.TitleContainer)
	window.CloseButton = B.frame("Button", window)
	B.texture(window.CloseButton)
	window.Inset = B.frame("Frame", window)
	window.Inset.NineSlice = B.frame("Frame", window.Inset)
	local insetNine = B.texture(window.Inset.NineSlice)
	local snap = B.snapshot()
	local panel = K.Skin.Window(window)
	assert(nine:GetAlpha() == 0 and window.Bg:GetAlpha() == 0 and portrait:GetAlpha() == 0 and insetNine:GetAlpha() == 0, "the window's art is stripped")
	assert(panel and panel:GetParent() == window and panel.chrome, "a KstyleUI panel behind it")
	assert(panel.chrome.shapeName == "window" and panel.chrome.shadow[1]:IsShown(), "the window grade: four lines, 10-unit chamfers and a shadow")
	assert(W.LastCall(window.TitleContainer.TitleText, "SetFont")[1] == (K.Tokens.Font("heading")), "the title in the heading font")
	assert(K.Skin.IsSkinned(window.CloseButton, "CloseButton"), "the close button")
	assert(K.Skin.Window(window) == panel, "a second call does nothing new")
	B.check(snap)
	assert(#env._errors == 0)
end

-- In combat a protected Blizzard frame waits for Combat.Queue; KstyleUI never touches it in lockdown.
do
	local env, K = W.New()
	local B = Blizzard(env)
	local frame = B.frame("Button")
	frame.IsProtected = function()
		return true
	end
	local art = B.texture(frame)
	env.SetCombat(true)
	assert(K.Skin.Button(frame) == nil, "deferred")
	assert(art:GetAlpha() == 1 and #W.Calls(frame, "HookScript") == 0, "nothing happens in combat")
	env.SetCombat(false)
	assert(art:GetAlpha() == 0 and K.Skin.IsSkinned(frame, "Button"), "it is skinned once combat ends")
end

print("skin ok")
