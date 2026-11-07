-- OptionsEntry.lua: the settings window's other doors: a canvas category in Blizzard's Settings panel and the addon compartment entry.
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
	local pad = Tokens.Size("panelPadding")
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

ns.Events.Register(OWNER, "PLAYER_LOGIN", function()
	ns.Events.Unregister(OWNER, "PLAYER_LOGIN")
	Register()
end)

function KstyleUI_OnAddonCompartmentClick()
	ns.Options.Open()
end
