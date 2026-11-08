-- test-chat-panel.lua: KstyleUI_Chat's glass panel holds Blizzard's main chat window, and the chat windows, tabs and edit boxes wear KstyleUI's look.
local C = dofile("Tools/regression/chat_env.lua")
local W = C.W

local HOOKED = { AddMessage = true, SetPoint = true, SetAlpha = true }

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function lastCall(object, method)
	for i = #object._calls, 1, -1 do
		local call = object._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

local function element(K)
	for _, el in ipairs(K.Layout.Elements()) do
		if el.key == "chat.main" then
			return el
		end
	end
end

-- Off by default: no panel and nothing styled.
do
	local env, K = C.New()
	assert(element(K) == nil, "no Layout element before Enable")
	assert(env.ChatFrame1:GetNumPoints() == 0 and env._editModeAnchors == 0, "the chat window is untouched")
end

-- On: the panel is a resizable Layout element at the setup's position, and holds ChatFrame1.
do
	local env, K, ns = C.New()
	local snap = C.Snapshot(env)
	C.Enable(env, K)
	assert(K.Modules.IsRunning("Chat"), "running: " .. tostring(env._errors[1]))
	local el = element(K)
	assert(el, "chat.main is registered with Layout")
	assert(el.module == "Chat" and el.label == K.Setup.Layouts.Element("chat.main").label, "module and label from the element keys")
	assert(el.opts.resizable == true and el.opts.minWidth and el.opts.maxHeight, "resizable with limits")
	local settings = K.Layout.Get("chat.main")
	local default = K.Setup.Layouts.Default("chat.main")
	assert(settings.anchor == default.anchor and settings.x == default.x and settings.y == default.y, "the DPS layout's position")
	assert(near(settings.width, 424) and near(settings.height, 164), "the 424 by 164 footprint")
	local holder, glass = ns.Panel.Holder(), ns.Panel.Glass()
	assert(holder and holder:IsShown(), "the panel shows")
	assert(glass:GetParent() == holder and glass:GetFrameStrata() == "BACKGROUND", "the glass sits behind the chat")
	assert(glass.chrome.shapeName == "window", "the chat is window-grade glass: the mockup cuts its corners 12 units")
	local chat = env.ChatFrame1
	assert(chat:GetNumPoints() == 2, "two anchors")
	local p1, p2 = { chat:GetPoint(1) }, { chat:GetPoint(2) }
	assert(p1[1] == "TOPLEFT" and p1[2] == holder and p2[1] == "BOTTOMRIGHT" and p2[2] == holder, "anchored inside the panel")
	assert(p1[4] > 0 and p1[5] < 0 and p2[4] < 0 and p2[5] > 0, "inset on every side")
	assert(env._editModeAnchors == 0, "Edit Mode's SetPoint override is never called, only SetPointBase")
	K.DevTest.Run()
	local passed = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		passed = passed or entry.message:find("PASS chat panel", 1, true) ~= nil
	end
	assert(passed, "/kstyle test reports the chat window in the panel")
	C.Check(env, snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Blizzard re-anchors the window: the panel takes it back on the next frame. Edit Mode keeps it while open.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	env.EditModeAnchor()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == env.UIParent, "Blizzard moved it")
	env.RunTimers()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == holder, "back in the panel")
	env._editMode = true
	env.EditModeAnchor()
	env.RunTimers()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == env.UIParent, "Edit Mode keeps it while open")
	env._editMode = false
	env.EventRegistry:TriggerEvent("EditMode.Exit")
	env.RunTimers()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == holder, "back in the panel when Edit Mode closes")
end

-- The insets follow the scale: on a 1440p screen the chat window's own units are smaller.
do
	local env, K, ns = C.New({ width = 2560, height = 1440, uiScale = 0.75 })
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	local k = env.ChatFrame1:GetEffectiveScale() / holder:GetEffectiveScale()
	local left = select(4, env.ChatFrame1:GetPoint(1)) * k
	local pixel = K.Scale.Pixel(1)
	assert(near(left / pixel, math.floor(left / pixel + 0.5)), "the left inset is whole physical pixels: " .. left / pixel)
	local g = ns.Panel.Geometry(env.ChatFrame1)
	assert(near(left, g.left), "the inset in root units matches the geometry")
end

-- The geometry follows the owner's mockup: a 32-unit tab strip, 16 units of glass left of and below the messages,
-- and no room kept for the edit box unless the player wants it always shown.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local chat = env.ChatFrame1
	local snap = K.Scale.Snap
	local g = ns.Panel.Geometry(chat)
	assert(near(g.divider, snap(32)), "the divider closes a 32-unit tab strip, got " .. g.divider)
	assert(near(g.top, snap(32 + 3 * g.k)), "the window's top sits where Blizzard's dock ends, 3 chat units under the strip, got " .. g.top)
	local pad = ns.Panel.Glass().chrome:Inset("gapMedium")
	assert(pad >= 16, "the window's content inset is at least the mockup's 16 units")
	assert(near(g.left, pad), "one window content inset of glass left of the messages, got " .. g.left .. " for " .. pad)
	local reach = (2 + 32) * g.k - math.max(0, (32 * g.k - 22) / 2)
	local clear = reach + K.Tokens.Size("gapTiny") - select(2, K.Layout.Rect("chat.main"))
	assert(near(g.bottom, snap(math.max(pad, clear))), "one inset of glass below the messages, or what keeps the edit box on screen, got " .. g.bottom)
	-- Blizzard's dock ends 2 chat units right of the window and its 16-unit overflow button sits at that end; the
	-- window stops where the button clears the copy glyph's 20-unit hit area, 352 units of room for the mockup's lines.
	local copyCentre = 22 + 20 + K.Tokens.Size("gapTiny")
	assert(near(g.right, snap(copyCentre + 10 + 2 * g.k)), "the overflow button clears the copy glyph, got " .. g.right)
	K.Options.Write("Chat", "copyButton", false)
	env.RunTimers()
	assert(near(ns.Panel.Geometry(chat).right, snap(22 + 10 + 2 * g.k)), "without the copy glyph the plus alone is cleared")
	K.Options.Write("Chat", "copyButton", true)
	env.RunTimers()
	local divider = ns.Panel.Glass().divider
	local _, _, _, _, dy = divider:GetPoint(1)
	assert(near(dy, -g.divider), "the divider is drawn at the strip's bottom edge")
	K.Options.Write("Chat", "editBox", "always")
	env.RunTimers()
	g = ns.Panel.Geometry(chat)
	assert(g.bottom > snap(16) + 20, "an always-shown edit box gets its room under the messages, got " .. g.bottom)
	assert(near(g.left, ns.Panel.Glass().chrome:Inset("gapMedium")), "the other insets stay")
end

-- While the edit box shows only when typing it hangs under the panel, so where the chat window's units are larger
-- than the root's (Blizzard UI scale 1) the bottom inset grows until the box's tile clears the screen's edge, and
-- grows again when Layout moves the panel down.
do
	local env, K, ns = C.New({ width = 1920, height = 1080, uiScale = 1 })
	C.Enable(env, K)
	local chat = env.ChatFrame1
	local snap = K.Scale.Snap
	local g = ns.Panel.Geometry(chat)
	assert(g.k > 1.3, "the chat window's units are larger than the root's: " .. g.k)
	local tile = math.max(0, (32 * g.k - 22) / 2)
	local reach = (2 + 32) * g.k - tile
	local bottom = select(2, K.Layout.Rect("chat.main"))
	assert(near(bottom, 16), "the panel sits 16 above the screen's edge, got " .. tostring(bottom))
	assert(g.bottom > snap(16), "the inset grows past 16")
	assert(near(g.bottom, snap(reach - bottom + K.Tokens.Size("gapTiny"))), "the box's tile ends a tiny gap above the screen's edge, got " .. g.bottom)
	K.Layout.Set("chat.main", "y", 0)
	env.RunTimers()
	local moved = ns.Panel.Geometry(chat)
	assert(near(moved.bottom, snap(reach + K.Tokens.Size("gapTiny"))), "moving the panel to the edge re-places the window, got " .. moved.bottom)
	assert(near(select(5, chat:GetPoint(2)) * g.k, moved.bottom), "the window's anchor follows")
	K.Layout.Set("chat.main", "y", 200)
	env.RunTimers()
	assert(near(ns.Panel.Geometry(chat).bottom, ns.Panel.Glass().chrome:Inset("gapMedium")), "high on the screen the inset is the window's content inset again")
end

-- The tab row's right end: a plus glyph that opens the chat's settings page and, beside it, a small copy glyph that
-- copies the selected window. Both wear the class colour and brighten on hover.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local plus, copy, glass = ns.Panel.MenuButton(), ns.Panel.CopyButton(), ns.Panel.Glass()
	assert(plus and plus:IsShown() and copy and copy:IsShown(), "both glyphs show")
	local g = ns.Panel.Geometry(env.ChatFrame1)
	local p, rel, relp, x, y = plus:GetPoint(1)
	assert(p == "CENTER" and rel == glass and relp == "TOPRIGHT", "the plus sits in the row's right end")
	assert(near(x, -22) and near(y, -(g.top - 14 * g.k)), "22 units in from the right, level with the tab names, got " .. x .. ", " .. y)
	local cp, crel, crelp, cx, cy = copy:GetPoint(1)
	assert(cp == "CENTER" and crel == glass and crelp == "TOPRIGHT" and near(cx, -(22 + 20 + K.Tokens.Size("gapTiny"))) and near(cy, y), "the copy glyph sits one button and a tiny gap left of the plus, got " .. cx)
	for _, button in ipairs({ plus, copy }) do
		assert(near(button:GetWidth(), K.Widgets.Snap(button, 20)) and near(button:GetHeight(), K.Widgets.Snap(button, 20)), "a 20-unit hit area")
		assert(near(button.art:GetWidth(), K.Widgets.Snap(button.art, 8)), "8 units of glyph, as the mockup draws the plus")
		assert(button.label == nil, "no text label")
	end
	local glyph = plus.glyph
	assert(glyph and W.LastCall(glyph, "SetTexture")[1] == (K.Tokens.Texture("glyphClose")), "the plus is the close glyph")
	assert(near(W.LastCall(glyph, "SetRotation")[1], math.pi / 4), "turned an eighth of a turn")
	assert(#copy.tinted >= 8, "the copy glyph is drawn from outlines")
	local ar, ag, ab = ns.Accent(K.Store.Module("Chat"))
	local vr, vg, vb = glyph:GetVertexColor()
	assert(near(vr, ar) and near(vg, ag) and near(vb, ab), "the plus wears the class colour")
	vr, vg, vb = copy.tinted[1]:GetVertexColor()
	assert(near(vr, ar) and near(vg, ag) and near(vb, ab), "so does the copy glyph")
	local opened
	K.Options.SetWindow(function(page)
		opened = page
		return true
	end)
	plus:GetScript("OnClick")(plus, "LeftButton")
	assert(opened == "Chat", "the plus opens the chat's settings page, got " .. tostring(opened))
	env.GENERAL_CHAT_DOCK.selected = env.ChatFrame2
	copy:GetScript("OnClick")(copy, "LeftButton")
	env.RunTimers()
	assert(ns.Copy.Window():IsShown() and ns.Copy.Source() == env.ChatFrame2, "the copy glyph copies the selected window")
	local right = select(4, env.ChatFrame1:GetPoint(2))
	K.Options.Write("Chat", "copyButton", false)
	env.RunTimers()
	assert(not copy:IsShown() and plus:IsShown(), "the setting hides the copy glyph only")
	assert(select(4, env.ChatFrame1:GetPoint(2)) > right, "the messages take the copy glyph's room")
	env.ChatFrame1Tab:SetAlpha(0.4)
	assert(near(plus:GetAlpha(), 0.4), "the plus fades with the tabs")
end

-- Layout's shown rule and opacity carry over to Blizzard's chat, and turning the module off restores them.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	K.Layout.Set("chat.main", "shown", "never")
	assert(not holder:IsShown(), "Layout hides the panel")
	assert(env.ChatFrame1:GetAlpha() == 0 and env.GENERAL_CHAT_DOCK:GetAlpha() == 0, "the chat and its tabs hide with it")
	K.Layout.Set("chat.main", "shown", "always")
	assert(holder:IsShown() and env.ChatFrame1:GetAlpha() == 1, "and come back")
	holder:SetAlpha(0.5)
	assert(env.ChatFrame1:GetAlpha() == 0.5 and env.ChatFrame2:GetAlpha() == 0.5, "docked windows follow the panel's opacity")
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(not holder:IsShown(), "the panel hides when the module is off")
	assert(env.ChatFrame1:GetAlpha() == 1 and env.GENERAL_CHAT_DOCK:GetAlpha() == 1, "Blizzard's chat is fully visible again")
end

-- Glass opacity and shadow settings repaint the panel.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	K.Options.Write("Chat", "panelOpacity", 0.4)
	local glass = ns.Panel.Glass()
	local fill = glass.chrome.fill[5]
	local args = lastCall(fill, "SetVertexColor")
	assert(args and near(args[4], 0.4), "the glass is 40% opaque")
	K.Options.Write("Chat", "shadow", false)
	assert(glass.chrome.shadow[1]:IsShown() == false, "no shadow")
	K.Layout.Set("chat.main", "strata", "HIGH")
	assert(holder:GetFrameStrata() == "HIGH", "Layout sets the element's strata")
	assert(glass:GetFrameStrata() == "BACKGROUND" and W.LastCall(glass, "SetFixedFrameStrata")[1] == true, "the glass stays behind Blizzard's chat")
end

-- The edit box shows only while the player types: at rest its alpha is 0, whatever Blizzard set, and a box being
-- typed in shows at Blizzard's alpha. Windows that leave the dock and windows opened later follow the panel's opacity.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	local box = env.ChatFrame1.editBox
	assert(box:GetAlpha() == 0, "the edit box is hidden while nobody types")
	assert(W.LastCall(box, "EnableMouse")[1] == false, "and takes no clicks while invisible")
	box:SetAlpha(0.35)
	assert(box:GetAlpha() == 0, "Blizzard's resting alpha is hidden too")
	box:SetAlpha(1)
	rawset(box, "HasFocus", function()
		return true
	end)
	box:GetScript("OnEditFocusGained")(box)
	assert(math.abs(box:GetAlpha() - 1) < 1e-6, "a box being typed in shows at Blizzard's alpha")
	assert(W.LastCall(box, "EnableMouse")[1] == true, "and takes the mouse again")
	rawset(box, "HasFocus", nil)
	box:GetScript("OnEditFocusLost")(box)
	assert(box:GetAlpha() == 0, "and hides again when typing ends")
	assert(W.LastCall(box, "EnableMouse")[1] == false, "without the mouse")
	box:SetAlpha(0.35)
	holder:SetAlpha(0.5)
	K.Options.Write("Chat", "editBox", "always")
	assert(math.abs(box:GetAlpha() - 0.175) < 1e-6, "always shown: Blizzard's own resting alpha is scaled by the panel's, not replaced")
	assert(W.LastCall(box, "EnableMouse")[1] == true, "always shown: the resting box takes clicks, as Blizzard's does")
	rawset(box, "HasFocus", function()
		return true
	end)
	box:GetScript("OnEditFocusGained")(box)
	assert(math.abs(box:GetAlpha() - 0.35) < 1e-6, "a box being typed in shows at Blizzard's alpha")
	rawset(box, "HasFocus", nil)
	env.FCF_UnDockFrame(env.ChatFrame2)
	assert(env.ChatFrame2:GetAlpha() == 1, "a window that leaves the dock gets its own alpha back")
	local whisper = env.FCF_OpenTemporaryWindow("WHISPER", "Kragar")
	env.RunTimers()
	assert(math.abs(whisper:GetAlpha() - 0.5) < 1e-6, "a window opened into the dock fades with the panel")
	holder:SetAlpha(1)
	K.Options.Write("Chat", "editBox", "typing")
	assert(box:GetAlpha() == 0, "back to typing only: hidden at rest")
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(math.abs(box:GetAlpha() - 0.35) < 1e-6, "off: the edit box is back at Blizzard's alpha")
	assert(W.LastCall(box, "EnableMouse")[1] == true, "off: and takes the mouse")
end

-- Window art, tabs and edit boxes.
do
	local env, K = C.New()
	local snap = C.Snapshot(env)
	C.Enable(env, K)
	env.RunTimers()
	local chat, tab, box = env.ChatFrame1, env.ChatFrame1Tab, env.ChatFrame1.editBox
	assert(env.ChatFrame1Background:GetAlpha() == 0 and env.ChatFrame1TopTexture:GetAlpha() == 0, "Blizzard's window art is gone")
	assert(tab.Left:GetAlpha() == 0 and tab.ActiveMiddle:GetAlpha() == 0, "Blizzard's tab art is gone")
	assert(tab.glow:GetAlpha() == 1, "the new-message glow stays")
	assert(env.ChatFrame1EditBoxMid:GetAlpha() == 0, "Blizzard's edit box art is gone")
	assert(K.Skin.IsSkinned(box, "EditBox"), "the edit box is a raised tile")
	assert(tab:GetText() == "GENERAL", "tab names in capitals")
	env.FCFTab_UpdateColors(tab, true)
	local parts = K.Skin.Parts(tab)
	assert(parts.underline:IsShown(), "the selected tab has the accent underline")
	local line = parts.underline
	local lp, lrel, _, lx = line:GetPoint(1)
	local rp, rrel, _, rx = line:GetPoint(2)
	assert(lp == "BOTTOMLEFT" and lrel == tab and near(lx, 0) and rp == "BOTTOMRIGHT" and rrel == tab and near(rx, 0), "the underline spans the tab's full width, as the design's tabs do")
	assert(near(line:GetHeight(), K.Widgets.Snap(line, 1)), "the underline is one unit: the mockup's thin line")
	local ar, ag, ab = K.Theme.Accent()
	local lr, lg, lb = line:GetVertexColor()
	assert(near(lr, ar) and near(lg, ag) and near(lb, ab), "the underline is the class colour itself")
	local glow = parts.chatGlow
	assert(glow and glow:IsShown(), "a glow rises from the underline")
	assert(near(glow:GetHeight(), K.Widgets.Snap(glow, 5)), "the glow is 5 units tall")
	local gp, grel, grelp = glow:GetPoint(1)
	assert(gp == "BOTTOMLEFT" and grel == line and grelp == "TOPLEFT", "the glow sits on the underline")
	assert(not K.Skin.Parts(env.ChatFrame2Tab).chatGlow:IsShown(), "an unselected tab has no glow")
	env.FCFTab_UpdateColors(env.ChatFrame2Tab, false)
	assert(not K.Skin.Parts(env.ChatFrame2Tab).underline:IsShown(), "other tabs do not")
	K.Options.Write("Chat", "tabStyle", "minimal")
	assert(not parts.underline:IsShown(), "the minimal style has no underline")
	K.Options.Write("Chat", "tabStyle", "filled")
	assert(parts.backdrop and parts.backdrop:IsShown(), "the filled style puts a tile behind the selected tab")
	K.Options.Write("Chat", "tabCase", "normal")
	assert(tab:GetText() == "General", "names as typed: " .. tostring(tab:GetText()))
	K.Options.Write("Chat", "tabCase", "upper")
	env.FCF_SetWindowName(chat, "Trade")
	assert(tab:GetText() == "TRADE", "a renamed tab is in capitals")
	local secret = env.Secret("Kragar")
	env.ChatFrame3Tab:SetText(secret)
	env.FCF_SetWindowName(env.ChatFrame3, secret)
	assert(env.issecretvalue(env.ChatFrame3Tab:GetText()), "a secret tab name is left alone")
	C.Check(env, snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Fonts: the chosen font, size and outline on every window, the edit box and the tabs.
do
	local env, K = C.New()
	C.Enable(env, K)
	local path = K.Store.Module("Chat").font
	assert(path == K.Tokens.FontPath("SourceSans3Regular"), "messages default to the regular face, the mockup's lighter chat text: " .. tostring(path))
	local args = lastCall(env.ChatFrame1, "SetFont")
	assert(args and args[1] == path and args[2] == 14 and args[3] == "", "messages in the chat font at 14, the mockup's size")
	assert(K.Store.Module("Chat").tabFontSize == 13, "tab names at 13: the mockup's cap height and label widths at 1.348 px per unit")
	K.Options.Write("Chat", "fontSize", 15)
	K.Options.Write("Chat", "fontOutline", "OUTLINE")
	args = lastCall(env.ChatFrame2, "SetFont")
	assert(args[2] == 15 and args[3] == "OUTLINE", "a size and outline change reaches every window")
	args = lastCall(env.ChatFrame1.editBox, "SetFont")
	assert(args and args[2] == 15, "the edit box follows")
	args = lastCall(env.ChatFrame1Tab.Text, "SetFont")
	assert(args and args[2] == K.Store.Module("Chat").tabFontSize, "tabs use the tab size")
	env.FCF_SetChatWindowFontSize(nil, env.ChatFrame1, 18)
	assert(K.Store.Module("Chat").fontSize == 18, "a size picked from the game's tab menu becomes the setting")
	assert(lastCall(env.ChatFrame2, "SetFont")[2] == 18, "and reaches every window")
	env.FireEvent("UPDATE_CHAT_WINDOWS")
	env.ChatFrame1:SetFont(path, 14, "")
	env.RunTimers()
	assert(lastCall(env.ChatFrame1, "SetFont")[2] == 18, "the game's per-window size is put back after UPDATE_CHAT_WINDOWS")
	assert(lastCall(env.ChatFrame1, "SetSpacing")[1] == 4, "4 units between lines, the mockup's pitch at 14")
	K.Options.Write("Chat", "lineSpacing", 0)
	assert(lastCall(env.ChatFrame2, "SetSpacing")[1] == 0, "line spacing reaches every window")
	K.Options.Write("Chat", "fade", false)
	assert(lastCall(env.ChatFrame1, "SetFading")[1] == false, "fading off")
	K.Options.Write("Chat", "fade", true)
	K.Options.Write("Chat", "fadeTime", 60)
	assert(lastCall(env.ChatFrame1, "SetTimeVisible")[1] == 60, "fade time")
end

-- A font the game cannot load falls back to KstyleUI's body font.
do
	local env, K = C.New({
		setup = function(e)
			local create = e.CreateFrame
			e.CreateFrame = function(...)
				local frame = create(...)
				local make = frame.CreateFontString
				rawset(frame, "CreateFontString", function(self, ...)
					local fs = make(self, ...)
					rawset(fs, "SetFont", function(_, file)
						return file ~= "Interface\\Missing.ttf"
					end)
					return fs
				end)
				return frame
			end
		end,
	})
	C.Enable(env, K)
	K.Options.Write("Chat", "font", "Interface\\Missing.ttf")
	local args = lastCall(env.ChatFrame1, "SetFont")
	assert(args[1] == (K.Tokens.Font("body")), "fell back to the body font: " .. tostring(args[1]))
end

-- Chat buttons: hidden through Safe by default, shown again by the setting.
do
	local env, K = C.New()
	C.Enable(env, K)
	env.RunTimers()
	local buttons = env.ChatFrame1.buttonFrame
	assert(K.Safe.IsHidden(buttons), "the button column is hidden")
	K.Options.Write("Chat", "buttons", true)
	env.RunTimers()
	assert(not K.Safe.IsHidden(buttons), "and back")
end

-- Undocked windows get their own glass; docked ones share the panel. A new whisper window is styled too.
do
	local env, K = C.New()
	C.Enable(env, K)
	local floating = env.ChatFrame3
	assert(not floating.isDocked, "ChatFrame3 starts undocked")
	local parts = K.Skin.Parts(floating)
	assert(parts and parts.backdrop and parts.backdrop:IsShown(), "an undocked window has a glass backdrop")
	local docked = K.Skin.Parts(env.ChatFrame2)
	assert(not (docked and docked.backdrop and docked.backdrop:IsShown()), "a docked window has none")
	env.FCF_DockFrame(floating)
	assert(not parts.backdrop:IsShown(), "docking hides it")
	env.FCF_UnDockFrame(floating)
	assert(parts.backdrop:IsShown(), "undocking shows it")
	local whisper = env.FCF_OpenTemporaryWindow("WHISPER", "Kragar")
	env.RunTimers()
	assert(env[whisper:GetName() .. "Background"]:GetAlpha() == 0, "the new window's art is gone")
	assert(lastCall(whisper, "SetFont"), "and it has the chat font")
end

-- Without ChatFrame1 the module still runs and logs why the panel is empty.
do
	local env, K = C.New({ setup = function(e)
		e.ChatFrame1 = nil
	end })
	C.Enable(env, K)
	assert(K.Modules.IsRunning("Chat"), "still running")
	local found = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		found = found or (entry.module == "Chat" and entry.message:find("ChatFrame1", 1, true) ~= nil)
	end
	assert(found, "the missing window is logged")
end

-- A protected chat window in combat waits for the combat queue.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	rawset(env.ChatFrame1, "IsProtected", function()
		return true
	end)
	env.SetCombat(true)
	env.EditModeAnchor()
	env.RunTimers()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == env.UIParent, "no anchor change in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(select(2, env.ChatFrame1:GetPoint(1)) == ns.Panel.Holder(), "placed after combat")
end

print("chat panel ok")
