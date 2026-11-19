-- Travel.lua: the Medallions crest's secure Hearthstone and narrow, grouped travel flyout.
local _, ns = ...

local K = KstyleUI
local Widgets, L = K.Widgets, K.L
local Travel = {}
ns.Travel = Travel

local OWNER = "ActionBars.Travel"
local SIZE, GAP, PAD, COLS, PAGE = 36, 5, 8, 3, 12
local WIDTH = 3 * SIZE + 2 * GAP + 2 * PAD
local HEAD, GROUP_GAP = 20, 8
local TITLES = { L["Home"], L["Travel"], L["Mounts"] }
local pending, enabled, prepared = false, false, false
local dirty, preparing, hearth = true, false, true

local TOGGLE = [[
	if button == "RightButton" then
		local menu = control:GetFrameRef("menu")
		if not menu then return false end
		if menu:IsShown() then
			menu:Hide()
		else
			if not menu:GetAttribute("hasTravel") then return false end
			menu:Show()
			menu:SetBindingClick(true, "ESCAPE", self:GetName(), "RightButton")
		end
		return false
	end
	return nil, true
]]
local CLOSE = [[ local menu = control:GetFrameRef("menu") if menu then menu:Hide() end ]]
local CLEAR = [[ self:ClearBindings() ]]
local NEXT = [[
	if down then return false end
	local page = control:GetAttribute("page")
	control:GetFrameRef("page" .. page):Hide()
	page = page % control:GetAttribute("pages") + 1
	control:SetAttribute("page", page)
	control:GetFrameRef("page" .. page):Show()
	return false
]]

local function Tooltip(tip)
	Travel.Prepare()
	local bind, cooldown = ns.TravelData.Hearth()
	local present = hearth
	if dirty then local _; _, present = ns.TravelData.Read() end
	tip:AddTitle(L["Hearthstone"])
	tip:AddDoubleLine(L["Bind location"], bind)
	tip:AddDoubleLine(L["Hearthstone cooldown"], cooldown)
	if not present then tip:AddLine(L["No Hearthstone in your bags."]) end
	if InCombatLockdown() and not Travel.menu then tip:AddLine(L["The travel menu will be ready after combat."]) end
	tip:AddLine(L["Left click: Hearthstone \194\183 Right click: travel"])
end

local function Build()
	local root = K.Scale.Root()
	local crest = CreateFrame("Button", "KstyleUI_CrestTravel", root, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
	crest:SetFrameStrata("MEDIUM")
	crest:RegisterForClicks("AnyUp")
	crest:SetAttribute("useOnKeyDown", false)
	crest:Hide()
	Widgets.AttachTooltip(crest, Tooltip, "ANCHOR_TOP")
	crest:HookScript("OnMouseDown", function(_, button) if button == "RightButton" then Travel.Prepare() end end)
	SecureHandlerWrapScript(crest, "OnClick", crest, TOGGLE, CLOSE)
	Travel.crest, Travel.groups = crest, {}
end

local function BuildMenu()
	local menu = CreateFrame("Frame", nil, K.Scale.Root(), "SecureHandlerBaseTemplate")
	menu.chrome = Widgets.Chrome(menu, { shape = "panel", fill = "surface", shadow = true, popup = true })
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:Hide()
	Travel.menu = menu
	SecureHandlerSetFrameRef(Travel.crest, "menu", menu)
	SecureHandlerWrapScript(menu, "OnHide", menu, CLEAR)
end

local function NewGroup(menu, index)
	local group = CreateFrame("Frame", nil, menu, "SecureHandlerBaseTemplate")
	group.pages, group.buttons = {}, {}
	local title = Widgets.SectionCap(group, { text = TITLES[index], width = WIDTH - PAD * 2 })
	title:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
	group.cap = title
	local nextPage = Widgets.Button(group, { template = "SecureActionButtonTemplate", text = L["Next travel page"], width = WIDTH - PAD * 2, height = HEAD, silent = true })
	nextPage:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 0, 0)
	nextPage:RegisterForClicks("AnyUp")
	Widgets.AttachTooltip(nextPage, L["Next travel page"], "ANCHOR_TOP")
	SecureHandlerWrapScript(nextPage, "OnClick", group, NEXT)
	group.nextPage = nextPage
	Travel.groups[index] = group
	return group
end

local function Button(page)
	local b = Widgets.Slot(page, { template = "SecureActionButtonTemplate", size = SIZE, silent = true, inputContinuity = ns.Config("inputContinuity") })
	b.kind = "travel"
	b:SetAttribute("useOnKeyDown", false)
	b:RegisterForClicks("AnyUp")
	ns.Socket.Decorate(b)
	ns.Slab.Dress(b)
	Widgets.AttachTooltip(b, function(tip)
		tip:AddTitle(b.travel.name or tostring(b.travel.id))
	end, "ANCHOR_RIGHT")
	SecureHandlerWrapScript(b, "OnClick", Travel.crest, [[ return nil, true ]], CLOSE)
	return b
end

local function FillGroup(group, list, y)
	group:Hide()
	local pages = math.ceil(#list / PAGE)
	group:SetAttribute("page", 1)
	group:SetAttribute("pages", pages)
	group.nextPage:SetShown(pages > 1)
	for _, page in ipairs(group.pages) do page:Hide() end
	for _, b in ipairs(group.buttons) do b:Hide() end
	for i, entry in ipairs(list) do
		local p = math.ceil(i / PAGE)
		local page = group.pages[p]
		if not page then
			page = CreateFrame("Frame", nil, group, "SecureHandlerBaseTemplate")
			page:SetAllPoints(group)
			group.pages[p] = page
			SecureHandlerSetFrameRef(group, "page" .. p, page)
		end
		local b = group.buttons[i] or Button(page)
		group.buttons[i], b.travel = b, entry
		b.opts.inputContinuity = ns.Config("inputContinuity")
		b:SetAttribute("type", entry.kind)
		b:SetAttribute("item", entry.kind == "item" and "item:" .. entry.id or nil)
		b:SetAttribute("spell", entry.kind == "spell" and entry.id or nil)
		b:SetIcon(entry.icon)
		b:ClearAllPoints()
		local cell = (i - 1) % PAGE
		b:SetPoint("TOPLEFT", page, "TOPLEFT", (cell % COLS) * (SIZE + GAP), -HEAD - math.floor(cell / COLS) * (SIZE + GAP))
		b:Show()
		page:SetShown(p == 1)
	end
	local height = HEAD + math.ceil(math.min(#list, PAGE) / COLS) * (SIZE + GAP) - GAP
	if pages > 1 then height = height + HEAD + GAP end
	group:ClearAllPoints()
	group:SetPoint("TOPLEFT", Travel.menu, "TOPLEFT", PAD, -y)
	Widgets.Size(group, WIDTH - PAD * 2, height)
	group:Show()
	return y + height + GROUP_GAP
end

local function Refresh()
	pending = false
	local hub = ns.Slab.hub
	local active = enabled and ns.Slab.Active() and hub and hub:IsShown() and ns.Config("crestTravel") ~= false and not ns.gamepad
	if not active then
		if Travel.crest then Travel.crest:Hide() end
		if Travel.menu then Travel.menu:Hide() end
		return
	end
	if not Travel.crest then
		if type(SecureHandlerWrapScript) ~= "function" or type(SecureHandlerSetFrameRef) ~= "function" then
			ns.LogOnce("noCrestTravel", "Secure handlers unavailable; crest travel is unavailable")
			return
		end
		Build()
	end
	local crest = Travel.crest
	if prepared and dirty and (preparing or Travel.menu and Travel.menu:IsShown()) then
		if not Travel.menu then BuildMenu() end
		local groups
		groups, hearth = ns.TravelData.Read()
		Travel.menu:SetAttribute("hasTravel", #groups[1] + #groups[2] + #groups[3] > 0)
		local y = PAD
		for i, list in ipairs(groups) do
			local group = Travel.groups[i]
			if #list > 0 then
				y = FillGroup(group or NewGroup(Travel.menu, i), list, y)
			elseif group then
				group:Hide()
			end
		end
		Widgets.Size(Travel.menu, WIDTH, y - GROUP_GAP + PAD)
		dirty = false
	end
	preparing = false
	crest:SetAttribute("item1", "item:6948")
	crest:SetAttribute("type1", (not prepared or hearth) and "item" or nil)
	if not Widgets.Cover(crest, hub.crest) then crest:Hide(); return end
	crest:Show()
	if not Travel.menu then return end
	local menu = Travel.menu
	menu:ClearAllPoints()
	local top = crest:GetTop()
	local lift = GAP
	for _, key in ipairs({ "unitframes.castbar.player", "unitframes.castbar.target" }) do
		local element = K.Layout.Element(key)
		local frame = element and element.frame
		local place = K.Setup.Layouts.Style("medallions", "DPS", key)
		local edge = frame and ns.TravelData.Plain(frame:GetTop(), "number")
		local scale = frame and ns.TravelData.Plain(frame:GetEffectiveScale(), "number")
		local own = ns.TravelData.Plain(menu:GetEffectiveScale(), "number")
		if edge and scale and own and own > 0 then edge = edge * scale / own else edge = nil end
		edge = edge or (place and place.y + place.height)
		if edge and ns.TravelData.Plain(top, "number") then lift = math.max(lift, edge - top + GAP + GROUP_GAP) end
	end
	menu:SetPoint("BOTTOM", crest, "TOP", 0, lift)
end

function Travel.Refresh()
	if not enabled or pending then return end
	pending = true
	K.Combat.Queue(Refresh)
end

function Travel.Prepare()
	if prepared and not dirty then return end
	prepared, preparing = true, true
	Travel.Refresh()
end

local function Changed()
	dirty = true
	if Travel.menu and Travel.menu:IsShown() then Travel.Refresh() end
end

local function Settings()
	for _, group in pairs(Travel.groups or {}) do
		for _, b in ipairs(group.buttons) do b.opts.inputContinuity = ns.Config("inputContinuity") end
	end
	Travel.Refresh()
end

function Travel.Enable()
	enabled, dirty = true, true
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "NEW_MOUNT_ADDED" }) do
		K.Events.Register(OWNER, event, Changed)
	end
	K.Callbacks.Register("SettingChanged", OWNER, function(_, module) if module == "ActionBars" then Settings() end end)
	K.Callbacks.Register("ProfileChanged", OWNER, Settings)
	K.Callbacks.Register("LayoutChanged", OWNER, function(_, key)
		if key == "unitframes.castbar.player" or key == "unitframes.castbar.target" then Travel.Refresh() end
	end)
	K.Callbacks.Register("ReadabilityChanged", OWNER, Travel.Refresh)
	K.Callbacks.Register("ThemeChanged", OWNER, Travel.Refresh)
	K.Callbacks.Register("ModuleChanged", OWNER, function(_, module) if module == "UnitFrames" then Travel.Refresh() end end)
	Travel.Refresh()
end

function Travel.Disable()
	enabled = false
	K.Events.UnregisterAll(OWNER)
	for _, name in ipairs({ "SettingChanged", "ProfileChanged", "LayoutChanged", "ReadabilityChanged", "ThemeChanged", "ModuleChanged" }) do K.Callbacks.Unregister(name, OWNER) end
	K.Combat.Queue(Refresh)
end
