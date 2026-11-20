-- OptionsEntry.lua: the settings window's other doors: a canvas category in Blizzard's Settings panel, the addon compartment entry and optional game menu buttons.
local _, ns = ...

local L = ns.L
local OWNER = "OptionsEntry"
local CATEGORY_NAME = "KstyleUI"
local LOGO_SIZE = 64
local TEXT_WIDTH = 420

local canvas, built

local function Log(message)
	ns.DevTest.Log(OWNER, message)
end

local function Build(frame)
	if built then
		return
	end
	built = true
	local Widgets, Tokens = ns.Widgets, ns.Tokens
	local pad = Widgets.WindowInset(frame)
	local gap = Tokens.Size("gapMedium")
	local logo = frame:CreateTexture(nil, "ARTWORK")
	logo:SetTexture((Tokens.Texture("logo")))
	logo:SetSize(LOGO_SIZE, LOGO_SIZE)
	logo:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
	local title = Widgets.Text(frame, "display", "textEmphasis")
	title:SetPoint("LEFT", logo, "RIGHT", gap, 0)
	Widgets.SetText(title, "KSTYLEUI")
	local body = Widgets.Text(frame, "body", "text")
	body:SetJustifyH("LEFT")
	body:SetWidth(TEXT_WIDTH)
	body:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -gap)
	Widgets.SetText(body, L["KstyleUI has its own settings window, with search, live previews and Layout Mode."])
	local button = Widgets.Button(frame, {
		text = L["Open KstyleUI settings"],
		primary = true,
		onClick = function()
			ns.Options.Open()
		end,
	})
	button:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -gap * 2)
	frame.openButton = button
	local hint = Widgets.Text(frame, "caption", "text")
	hint:SetPoint("LEFT", button, "RIGHT", gap, 0)
	Widgets.SetText(hint, L["or type /kstyle"])
end

local function Register()
	local api = Settings
	if type(api) ~= "table" or type(api.RegisterCanvasLayoutCategory) ~= "function" or type(api.RegisterAddOnCategory) ~= "function" then
		Log("Settings.RegisterCanvasLayoutCategory is missing; KstyleUI has no category in the Settings panel")
		return
	end
	canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas:SetScript("OnShow", Build)
	local ok, category = pcall(api.RegisterCanvasLayoutCategory, canvas, CATEGORY_NAME)
	local err = category
	if ok and category == nil then
		ok, err = false, "no category came back"
	elseif ok then
		ok, err = pcall(api.RegisterAddOnCategory, category)
	end
	if ok then
		Log("registered the KstyleUI category in the Settings panel")
	else
		Log("the Settings panel refused the KstyleUI category: " .. tostring(err))
	end
end

local Entry = {}
ns.OptionsEntry = Entry
local menu

local function MenuButton(text, onClick)
	local button = ns.Widgets.Button(menu, { text = text, onClick = function()
		if not InCombatLockdown() and type(HideUIPanel) == "function" then HideUIPanel(GameMenuFrame) end
		onClick()
	end })
	button:SetWidth(ns.Widgets.Snap(button, 200))
	return button
end

function Entry.GameMenu()
	local account = ns.Store.IsLoaded() and ns.Store.Account() or {}
	local options, layout = account.gameMenuOptions == true, account.gameMenuLayout == true
	local parent = rawget(_G, "GameMenuFrame")
	if not (options or layout or menu) or type(parent) ~= "table" then return end
	if not menu then
		menu = CreateFrame("Frame", nil, parent)
		menu.options = MenuButton(L["KstyleUI settings"], function() ns.Options.Open() end)
		menu.layout = MenuButton(L["Layout Mode"], function() ns.Layout.Enter() end)
		Log("added KstyleUI buttons under the game menu")
	end
	local gap = ns.Widgets.Snap(menu, ns.Tokens.Size("gapSmall"))
	menu:ClearAllPoints()
	menu:SetPoint("TOP", parent, "BOTTOM", 0, -gap)
	menu:SetSize(menu.options:GetWidth(), 2 * menu.options:GetHeight() + gap)
	menu.options:SetShown(options)
	menu.layout:SetShown(layout)
	menu.options:ClearAllPoints()
	menu.options:SetPoint("TOP", menu, "TOP")
	menu.layout:ClearAllPoints()
	menu.layout:SetPoint("TOP", options and menu.options or menu, options and "BOTTOM" or "TOP", 0, options and -gap or 0)
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", function()
	ns.Events.Unregister(OWNER, "PLAYER_LOGIN")
	Register()
	Entry.GameMenu()
end)

function KstyleUI_OnAddonCompartmentClick()
	ns.Options.Open()
end
