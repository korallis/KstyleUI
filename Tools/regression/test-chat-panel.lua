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
	assert(near(settings.width, 320) and near(settings.height, 130), "the 320 by 130 footprint")
	local holder, glass = ns.Panel.Holder(), ns.Panel.Glass()
	assert(holder and holder:IsShown(), "the panel shows")
	assert(glass:GetParent() == holder and glass:GetFrameStrata() == "BACKGROUND", "the glass sits behind the chat")
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

-- Edit boxes, windows that leave the dock and windows opened later follow the panel's opacity too.
do
	local env, K, ns = C.New()
	C.Enable(env, K)
	local holder = ns.Panel.Holder()
	local box = env.ChatFrame1.editBox
	holder:SetAlpha(0.5)
	assert(math.abs(box:GetAlpha() - 0.5) < 1e-6, "the edit box fades with the panel")
	box:SetAlpha(0.35)
	assert(math.abs(box:GetAlpha() - 0.175) < 1e-6, "Blizzard's own resting alpha is scaled, not replaced")
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
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(math.abs(box:GetAlpha() - 0.35) < 1e-6, "off: the edit box is back at Blizzard's alpha")
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
	assert(near(line:GetHeight(), K.Widgets.Snap(line, 1)), "the underline is one unit")
	local ar, ag, ab = K.Theme.Accent()
	local lr, lg, lb = line:GetVertexColor()
	assert(near(lr, ar + (1 - ar) * 0.6) and near(lg, ag + (1 - ag) * 0.6) and near(lb, ab + (1 - ab) * 0.6), "the underline is the accent lifted 60% toward white")
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
	local args = lastCall(env.ChatFrame1, "SetFont")
	assert(args and args[1] == path and args[2] == 12 and args[3] == "", "messages in the chat font at 12")
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
