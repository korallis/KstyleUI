-- Copy.lua: the copy-chat window, built from the widget kit, that shows a chat window's lines as plain text for Ctrl+C.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Scale, L = K.Widgets, K.Tokens, K.Scale, K.L
local Format = ns.Format

local Copy = {}
ns.Copy = Copy

local KEY = "chat.copy"
local WIDTH, HEIGHT = 560, 380
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 320, 200, 1400, 1000
local POSITION = { anchor = "CENTER", x = 0, y = 40 }
local MENU_TAG = "MENU_FCF_TAB"
local STRATA = "DIALOG"

local IsSecret = Format.IsSecret

local state = {
	active = false,
	window = nil,
	source = nil,
	menu = nil,
}
local logged = {}

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(ns.NAME, message)
	end
end

local function IsText(v)
	return not IsSecret(v) and type(v) == "string"
end

local function Plain(v)
	if IsSecret(v) or type(v) ~= "number" or v ~= v then
		return nil
	end
	return v
end

function Copy.Text(frame)
	local lines = {}
	local count = Plain(frame:GetNumMessages()) or 0
	for i = 1, count do
		local message = frame:GetMessageInfo(i)
		if IsSecret(message) then
			lines[#lines + 1] = L["(a line the game keeps hidden)"]
		elseif type(message) == "string" then
			lines[#lines + 1] = Format.Strip(message)
		end
	end
	return table.concat(lines, "\n")
end

function Copy.Selected()
	local dock = GENERAL_CHAT_DOCK
	if type(FCFDock_GetSelectedWindow) == "function" and type(dock) == "table" then
		local frame = FCFDock_GetSelectedWindow(dock)
		if type(frame) == "table" then
			return frame
		end
	end
	if type(SELECTED_CHAT_FRAME) == "table" then
		return SELECTED_CHAT_FRAME
	end
	return ChatFrame1
end

local function FrameOfTab(tab)
	if type(tab) ~= "table" or type(tab.GetID) ~= "function" then
		return nil
	end
	local id = Plain(tab:GetID())
	return id and _G["ChatFrame" .. id] or nil
end

local function Title(frame)
	local name = type(frame.GetName) == "function" and frame:GetName() or nil
	local tab = IsText(name) and _G[name .. "Tab"] or nil
	local label = type(tab) == "table" and type(tab.GetText) == "function" and tab:GetText() or nil
	if IsText(label) and label ~= "" then
		return L["Copy chat"] .. " - " .. label
	end
	return L["Copy chat"]
end

local function SavePosition(window)
	local x, y = window:GetCenter()
	local rx, ry = Scale.Root():GetCenter()
	x, y, rx, ry = Plain(x), Plain(y), Plain(rx), Plain(ry)
	if x and y and rx and ry and K.Layout and K.Layout.Update then
		K.Layout.Update(KEY, { anchor = "CENTER", x = x - rx, y = y - ry })
	end
end

local function Build()
	local window = Widgets.Panel(Scale.Root(), {
		title = L["Copy chat"],
		close = true,
		escape = true,
		movable = true,
		onMoved = SavePosition,
		strata = STRATA,
	})
	Widgets.Size(window, WIDTH, HEIGHT)
	local content = window.content
	local gap = Tokens.Size("gapMedium")
	window.selectAll = Widgets.Button(content, {
		text = L["Select all"],
		onClick = function()
			window.area:SelectAll()
		end,
	})
	window.selectAll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
	window.hint = Widgets.Text(content, "caption", "text")
	window.hint:SetPoint("LEFT", content, "LEFT")
	window.hint:SetPoint("RIGHT", window.selectAll, "LEFT", -gap, 0)
	window.hint:SetPoint("TOP", window.selectAll, "TOP")
	window.hint:SetPoint("BOTTOM", window.selectAll, "BOTTOM")
	window.hint:SetJustifyH("LEFT")
	Widgets.SetText(window.hint, L["Ctrl+C copies the selected text"])
	window.area = Widgets.TextArea(content, { readOnly = true })
	window.area:SetPoint("TOPLEFT", content, "TOPLEFT")
	window.area:SetPoint("BOTTOMRIGHT", window.selectAll, "TOPRIGHT", 0, gap)
	window:Hide()
	Widgets.Place(window, KEY, POSITION, {
		label = L["Copy chat window"],
		module = ns.NAME,
		resizable = true,
		minWidth = MIN_WIDTH,
		minHeight = MIN_HEIGHT,
		maxWidth = MAX_WIDTH,
		maxHeight = MAX_HEIGHT,
	})
	state.window = window
	return window
end

function Copy.Window()
	return state.window
end

function Copy.Source()
	return state.source
end

function Copy.Open(frame)
	frame = frame or Copy.Selected()
	if type(frame) ~= "table" or type(frame.GetNumMessages) ~= "function" or type(frame.GetMessageInfo) ~= "function" then
		LogOnce("history", "a chat window has no readable history; the copy window stays closed")
		return false
	end
	local window = state.window or Build()
	state.source = frame
	window:SetTitle(Title(frame))
	window.area:SetText(Copy.Text(frame))
	if not window:IsShown() or window:GetAlpha() < 1 then
		window:Open()
	end
	C_Timer.After(0, function()
		if window:IsShown() then
			window.area:ScrollToBottom(true)
			window.area:SelectAll()
		end
	end)
	return true
end

local function OnMenu(owner, root)
	if not state.active or type(root) ~= "table" or type(root.CreateButton) ~= "function" then
		return
	end
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	root:CreateButton(L["Copy chat"], function()
		Copy.Open(FrameOfTab(owner))
	end)
end

function Copy.Start()
	state.active = true
	if state.menu then
		return
	end
	local menu = Menu
	if type(menu) == "table" and type(menu.ModifyMenu) == "function" then
		state.menu = menu.ModifyMenu(MENU_TAG, OnMenu)
	else
		LogOnce("menu", "Menu.ModifyMenu is missing; the chat tab's menu has no Copy chat entry, the panel's Copy button still works")
	end
end

function Copy.Refresh()
end

function Copy.Stop()
	state.active = false
	local menu = state.menu
	if type(menu) == "table" and type(menu.Unregister) == "function" then
		menu:Unregister()
	end
	state.menu = nil
	local window = state.window
	if window and window:IsShown() then
		window:Close()
	end
end
