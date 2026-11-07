-- Paging.lua: the paging spike pages one secure action button with a state driver and a wrapped OnClick, and logs each page.
local _, ns = ...

local DRIVER = "[possessbar] 12; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; [stealth] 7; 1"
local CONDITIONS = { "possessbar", "overridebar", "vehicleui", "bonusbar:1", "bonusbar:2", "bonusbar:3", "bonusbar:4", "stealth", "form:1", "stance:1" }
local EVENTS = { "UPDATE_SHAPESHIFT_FORM", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED", "UPDATE_STEALTH", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
local NEEDED = { "RegisterStateDriver", "SecureHandlerWrapScript", "SecureHandlerSetFrameRef" }
local BUTTON_SIZE = 40
local OFFSET_Y = -160
local BUTTONS_PER_PAGE = 12
local ON_STATE = [[
	local page = tonumber(newstate) or 1
	self:GetFrameRef("button"):SetAttribute("action", (page - 1) * 12 + 1)
]]
local PRE_CLICK = [[
	control:SetAttribute("kspike-clicks", (control:GetAttribute("kspike-clicks") or 0) + 1)
]]

local frames
local current

local function Snapshot(page)
	local bar = C_ActionBar or {}
	local conditions = {}
	for _, condition in ipairs(CONDITIONS) do
		conditions[condition] = ns.Try(SecureCmdOptionParse, "[" .. condition .. "] yes; no")
	end
	return {
		t = current:Since(),
		page = ns.Describe(page),
		bonusBarOffset = ns.Try(bar.GetBonusBarOffset),
		actionBarPage = ns.Try(bar.GetActionBarPage),
		possessBar = ns.Try(bar.IsPossessBarVisible),
		bonusBar = ns.Try(bar.HasBonusActionBar),
		shapeshiftForm = ns.Try(GetShapeshiftForm),
		stealthed = ns.Try(IsStealthed),
		inCombat = ns.InCombat(),
		conditions = conditions,
	}
end

local function ShowPage(page)
	local number = tonumber(page) or 1
	local action = (number - 1) * BUTTONS_PER_PAGE + 1
	local bar = C_ActionBar
	if bar and bar.GetActionTexture then
		local ok, texture = pcall(bar.GetActionTexture, action)
		frames.icon:SetTexture(ok and texture or nil)
	end
	frames.label:SetText("Spike page " .. number .. ", action " .. action)
	if current then
		current:Set("displayedPage", number)
	end
end

local function OnAttributeChanged(_, name, value)
	if not current then
		return
	end
	if name == "state-page" then
		current:Add("changes", Snapshot(value))
		if not ns.IsSecret(value) then
			ShowPage(value)
		end
	elseif name == "kspike-clicks" then
		current:Count("clicks")
	end
end

local function Build()
	local driver = CreateFrame("Frame", "KstyleUISpike_PagingDriver", UIParent, "SecureHandlerStateTemplate")
	driver:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	driver:SetPoint("CENTER", UIParent, "CENTER", 0, OFFSET_Y)
	local button = CreateFrame("Button", "KstyleUISpike_PagingButton", driver, "SecureActionButtonTemplate")
	button:SetAllPoints(driver)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("type", "action")
	button:SetAttribute("action", 1)
	button:SetAttribute("useOnKeyDown", false)
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.8)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	local label = ns.Text(button, "GameFontHighlightSmall")
	label:SetPoint("TOP", button, "BOTTOM", 0, -4)
	frames = { driver = driver, button = button, icon = icon, label = label }
	SecureHandlerSetFrameRef(driver, "button", button)
	driver:SetAttribute("_onstate-page", ON_STATE)
	SecureHandlerWrapScript(button, "OnClick", driver, PRE_CLICK)
	driver:HookScript("OnAttributeChanged", OnAttributeChanged)
	RegisterStateDriver(driver, "page", DRIVER)
end

ns.Register("paging", {
	autostart = true,
	summary = "pages one secure action button on stance, form, stealth and possess. Rebuilds at each login until /kspike stop.",
	Run = function(run)
		local inCombat = ns.InCombat()
		run:Set("driver", DRIVER)
		if not frames then
			if inCombat and run.data.origin ~= "PLAYER_LOGIN" then
				run:Set("refused", "in combat")
				run:Note("cannot create secure frames in combat. Leave combat and type /kspike paging again.")
				return
			end
			local missing = {}
			for _, name in ipairs(NEEDED) do
				if type(_G[name]) ~= "function" then
					missing[#missing + 1] = name
				end
			end
			if #missing > 0 then
				run:Set("missing", missing)
				run:Note("missing " .. table.concat(missing, ", ") .. ".")
				return
			end
			local ok, err = pcall(Build)
			if not ok then
				run:Set("buildError", tostring(err))
				run:Note("build failed: " .. tostring(err))
				return
			end
			run:Set("createdAt", run.data.origin)
			run:Set("inCombatAtCreate", inCombat)
		end
		current = run
		run:Set("clicks", 0)
		run:Set("blocked", 0)
		local page = frames.driver:GetAttribute("state-page")
		run:Set("initial", Snapshot(page))
		if not ns.IsSecret(page) then
			ShowPage(page)
		end
		if not inCombat then
			frames.driver:Show()
		end
		local listener, failed = ns.Listen(EVENTS, function(event, addon, fn)
			if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
				run:Count("blocked")
				run:Add("blockedEvents", { t = run:Since(), event = event, addon = ns.Describe(addon), fn = ns.Describe(fn) })
			else
				run:Add("triggers", { t = run:Since(), event = event, inCombat = ns.InCombat() })
			end
		end)
		if #failed > 0 then
			run:Set("unregisteredEvents", failed)
		end
		run:Note("button is under the screen centre. Change stance or form, stealth, and click the button. /kspike stop ends it.")
		return function()
			current = nil
			ns.Unlisten(listener)
			ns.OutOfCombat(function()
				if not current then
					frames.driver:Hide()
				end
			end)
		end
	end,
})
