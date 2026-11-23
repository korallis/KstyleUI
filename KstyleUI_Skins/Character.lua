-- Character.lua: the character sheet skin: the window whose glass docks its side tabs in a gutter, the paper doll on the glass with quality-rimmed equipment slots carrying item levels (the inspect window's too) and sidebar tabs spaced by the kit gap, the stats, reputation and currency.
local _, ns = ...

local K = KstyleUI
local Skin, Theme, Tokens, L = K.Skin, K.Theme, K.Tokens, K.L
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local KEY = "character"
local ICON_CROP = 0.07
local HALF_TURN = math.pi / 2
local QUALITY_POOR, QUALITY_COMMON, QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 0, 1, 2, 3, 4

local SLOTS = {
	"CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot", "CharacterChestSlot",
	"CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot", "CharacterHandsSlot", "CharacterWaistSlot",
	"CharacterLegsSlot", "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot",
	"CharacterTrinket1Slot", "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterAmmoSlot",
}
local SLOT_KEEP = { "icon", "Icon", "searchOverlay", "ItemContextOverlay", "IconOverlay", "IconOverlay2", "ignoreTexture" }
local SIDEBAR_TABS = { "PaperDollSidebarTab1", "PaperDollSidebarTab2", "PaperDollSidebarTab3", "PaperDollSidebarTab4" }
local STAT_PANES = { "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" }
local REP_CHECKS = { "AtWarCheckbox", "MakeInactiveCheckbox", "WatchFactionCheckbox" }
local TOKEN_CHECKS = { "InactiveCheckbox", "BackpackCheckbox" }

local SLOT_AMMO, SLOT_SHIRT, SLOT_TABARD = 0, 4, 19
local NO_LEVEL = { [SLOT_AMMO] = true, [SLOT_SHIRT] = true, [SLOT_TABARD] = true }

local WEAK = { __mode = "k" }
local slots = setmetatable({}, WEAK)
local rows = setmetatable({}, WEAK)
local levelTexts = setmetatable({}, WEAK)
local levelLinks = setmetatable({}, WEAK)

local function Log(message)
	K.DevTest.Log("Skins", KEY .. ": " .. message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Frame(name)
	local frame = _G[name]
	if type(frame) ~= "table" then
		Log(name .. " is missing on this client; skipped")
		return nil
	end
	return frame
end

local function PaintSlot(button)
	local rim = slots[button]
	if not rim then
		return
	end
	if not Skins.Setting(KEY, "qualityBorders") then
		rim:SetRimColor(nil)
		return
	end
	local quality
	if type(GetInventoryItemQuality) == "function" and type(button.GetID) == "function" then
		quality = GetInventoryItemQuality("player", button:GetID())
	end
	if IsSecret(quality) or type(quality) ~= "number" or quality < Skins.Setting(KEY, "qualityFrom") then
		rim:SetRimColor(nil)
		return
	end
	rim:SetRimColor(Theme.QualityColor(quality))
end

local function ItemLevel(link)
	local item = C_Item
	if not link or not item or type(item.GetDetailedItemLevelInfo) ~= "function" then
		return nil
	end
	local ok, level = pcall(item.GetDetailedItemLevelInfo, link)
	return ok and not IsSecret(level) and type(level) == "number" and level > 0 and level or nil
end

local function ShowLevel(button, unit, link)
	local level, text = ItemLevel(link), levelTexts[button]
	if not level then
		if text then
			text:Hide()
		end
		return false
	end
	if not text then
		text = K.Widgets.FontString(button, "OVERLAY")
		Style.Text(text, "number")
		local inset = K.Widgets.Snap(button, Tokens.Size("gapTiny"))
		text:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
		levelTexts[button] = text
	end
	text:SetText(level)
	text:SetTextColor(Theme.QualityColor(type(GetInventoryItemQuality) == "function" and GetInventoryItemQuality(unit, button:GetID()), true))
	text:Show()
	return true
end

local function PaintLevel(button, unit)
	local id = button:GetID()
	local on = not IsSecret(id) and not IsSecret(unit) and type(unit) == "string" and not NO_LEVEL[id]
		and K.Modules.IsRunning("Skins") and Skins.IsOn(KEY) and Skins.Setting(KEY, "itemLevels")
	local link = on and type(GetInventoryItemLink) == "function" and GetInventoryItemLink(unit, id)
	if IsSecret(link) or type(link) ~= "string" then
		link = false
	end
	if levelLinks[button] == link then
		return
	end
	levelLinks[button] = link
	if ShowLevel(button, unit, link) or not link or type(Item) ~= "table" or type(Item.CreateFromItemLink) ~= "function" then
		return
	end
	local item = Item:CreateFromItemLink(link)
	pcall(item.ContinueOnItemLoad, item, function()
		if levelLinks[button] ~= link then
			return
		elseif button:IsVisible() then
			ShowLevel(button, unit, link)
		else
			levelLinks[button] = nil
		end
	end)
end

local function InspectUnit()
	local frame = _G.InspectFrame
	return type(frame) == "table" and frame.unit
end

local function PaintLevels()
	for button in pairs(levelLinks) do
		if button:IsVisible() then
			PaintLevel(button, slots[button] and "player" or InspectUnit())
		else
			levelLinks[button] = nil
			ShowLevel(button)
		end
	end
end

K.Callbacks.Register("SettingChanged", "Skins.ItemLevels", function(_, module, key)
	if module == "Skins" and key == "character.itemLevels" then
		PaintLevels()
	end
end)
K.Callbacks.Register("ProfileChanged", "Skins.ItemLevels", PaintLevels)

local function OnSlotEvent(button, event, slot)
	local id = event == "PLAYER_EQUIPMENT_CHANGED" and button:GetID()
	if event == nil or not IsSecret(id) and id == slot then
		PaintLevel(button, "player")
	end
end

local inspectHooked = false

local function HookInspect()
	if inspectHooked or type(InspectPaperDollItemSlotButton_Update) ~= "function" then
		return
	end
	inspectHooked = true
	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
		PaintLevel(button, InspectUnit())
	end)
end

if type(InspectFrame_LoadUI) == "function" then
	hooksecurefunc("InspectFrame_LoadUI", HookInspect)
end
HookInspect()

local function SkinSlot(button)
	if slots[button] then
		return
	end
	local keep = {}
	for _, key in ipairs(SLOT_KEEP) do
		if Parts.IsTexture(button[key]) then
			keep[button[key]] = true
		end
	end
	local name = type(button.GetName) == "function" and button:GetName()
	local named = not IsSecret(name) and type(name) == "string" and _G[name .. "IconTexture"]
	if Parts.IsTexture(named) then
		keep[named] = true
	end
	if type(button.GetHighlightTexture) == "function" then
		local highlight = button:GetHighlightTexture()
		if Parts.IsTexture(highlight) then
			keep[highlight] = true
		end
	end
	Skin.Strip(button, { keep = keep, children = { "BorderFrame" } })
	for icon in pairs(keep) do
		if icon == button.icon or icon == button.Icon or icon == named then
			icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		end
	end
	if button.Count then
		Style.Text(button.Count, "number", "textEmphasis")
	end
	slots[button] = Parts.Rim(button, { outset = Tokens.Size("gapTiny") })
	PaintSlot(button)
	PaintLevel(button, "player")
	button:HookScript("OnShow", OnSlotEvent)
	button:HookScript("OnEvent", OnSlotEvent)
end

local function PaintSlots()
	for button in pairs(slots) do
		PaintSlot(button)
	end
end

local function SkinToggle(frame)
	local chevron = Parts.Glyph(frame.RightPaneToggleButton, "glyphChevron")
	if not chevron then
		return
	end
	local function Point()
		local collapsed = type(frame.IsRightPaneCollapsed) == "function" and frame:IsRightPaneCollapsed() == true
		chevron:SetRotation(collapsed and HALF_TURN or -HALF_TURN)
	end
	if type(frame.UpdateRightPaneToggleButton) == "function" then
		hooksecurefunc(frame, "UpdateRightPaneToggleButton", Point)
	end
	Point()
end

local function SkinWindow(frame)
	Skin.Window(frame, { tabs = false })
	local title = type(frame.TitleContainer) == "table" and frame.TitleContainer.TitleText
	if title then
		Style.Title(title, "textEmphasis", "names")
		Parts.TitleCap(frame, title)
	end
	for _, pane in ipairs({ frame.LeftPaneHost, frame.RightPaneHost }) do
		if type(pane) == "table" then
			Skin.Strip(pane)
			Parts.StripLeaves(pane)
		end
	end
	local modes = type(frame.ModeTabs) == "table" and frame.ModeTabs.Tabs
	if type(modes) == "table" and type(modes[1]) == "table" then
		for _, tab in ipairs(modes) do
			Parts.SideTab(tab)
		end
		if type(frame.UpdateTabLayout) ~= "function" then
			Log("UpdateTabLayout is missing; the tab gutter spans the tabs shown at skin time")
		end
		Parts.Dock(frame, modes, { title = title or nil, relayout = "UpdateTabLayout" })
	else
		Log("the side tabs are missing; they keep Blizzard's look")
	end
	SkinToggle(frame)
end

local function StatRow(row, elementData)
	if not rows[row] then
		rows[row] = true
		local keep = {}
		if Parts.IsTexture(row.Icon) then
			keep[row.Icon] = true
		end
		Skin.Strip(row, { keep = keep })
		if row.Title and type(elementData) == "table" and elementData.isHeader then
			Parts.AccentLine(row, { alpha = 0.5 })
		end
	end
	if row.Title and type(elementData) == "table" and elementData.isHeader then
		Style.Title(row.Title)
	elseif row.Title then
		Style.Text(row.Title, "caption", "text")
	end
	if row.Label then
		Style.Text(row.Label, "body", "text")
	end
	if row.Value then
		Style.Text(row.Value, "number")
	end
end

local function SkinStats()
	for _, name in ipairs(STAT_PANES) do
		local pane = _G[name]
		if type(pane) == "table" then
			Skin.Strip(pane)
			Skin.ScrollBar(pane.ScrollBar)
			Parts.EachRow(pane.ScrollBox, StatRow)
		end
	end
	local doll = PaperDollFrame
	for _, key in ipairs({ "TitleManagerPane", "EquipmentManagerPane" }) do
		local pane = doll and doll[key]
		if type(pane) == "table" then
			Skin.ScrollBar(pane.ScrollBar)
			if pane.EquipSet then
				Skin.Button(pane.EquipSet)
			end
			if pane.SaveSet then
				Skin.Button(pane.SaveSet)
			end
		end
	end
end

local function SpaceSidebar()
	local tab1, tab2, tab3, tab4 = _G.PaperDollSidebarTab1, _G.PaperDollSidebarTab2, _G.PaperDollSidebarTab3, _G.PaperDollSidebarTab4
	if type(tab1) ~= "table" or type(tab2) ~= "table" or type(tab3) ~= "table" then
		return
	end
	local gap = K.Widgets.Snap(tab2, Tokens.Size("gapSmall"))
	tab1:ClearAllPoints()
	tab1:SetPoint("RIGHT", tab2, "LEFT", -gap, 0)
	tab3:ClearAllPoints()
	tab3:SetPoint("LEFT", tab2, "RIGHT", gap, 0)
	if type(tab4) == "table" then
		tab4:ClearAllPoints()
		tab4:SetPoint("LEFT", tab3, "RIGHT", gap, 0)
	end
end

local function SkinPaperDoll()
	local missing = 0
	for _, name in ipairs(SLOTS) do
		local button = _G[name]
		if type(button) == "table" then
			SkinSlot(button)
		else
			missing = missing + 1
			Log(name .. " is missing on this client; skipped")
		end
	end
	if type(PaperDollItemSlotButton_Update) == "function" then
		hooksecurefunc("PaperDollItemSlotButton_Update", PaintSlot)
	else
		Log("PaperDollItemSlotButton_Update is missing; slot rims show the quality at skin time only")
	end
	local doll = Frame("PaperDollFrame")
	if doll and type(doll.TopBackgroundStripHost) == "table" then
		Skin.Strip(doll.TopBackgroundStripHost)
	end
	local scene = _G.CharacterModelScene
	if type(scene) == "table" then
		Skin.Strip(scene)
	end
	local level = _G.CharacterLevelText
	if type(level) == "table" then
		Style.Text(level, "caption", "text")
	end
	for _, name in ipairs(SIDEBAR_TABS) do
		local tab = _G[name]
		if type(tab) == "table" then
			Parts.SideTab(tab, { rimTab = true })
		end
	end
	SpaceSidebar()
	if type(PaperDollFrame_UpdateSidebarTabLayout) == "function" then
		hooksecurefunc("PaperDollFrame_UpdateSidebarTabLayout", SpaceSidebar)
	else
		Log("PaperDollFrame_UpdateSidebarTabLayout is missing; the sidebar tabs keep their gap until Blizzard lays them out again")
	end
	SkinStats()
	return missing
end

local function DescriptionText(pane)
	local description = pane.Description
	local box = type(description) == "table" and description.ScrollBox
	local container = type(box) == "table" and box.FontStringContainer
	local text = type(container) == "table" and container.FontString
	if type(text) == "table" and type(text.SetJustifyH) == "function" then
		return text
	end
	return nil
end

local function DetailPane(pane, checks)
	if type(pane) ~= "table" then
		return
	end
	if pane.Title then
		Style.Text(pane.Title, "heading")
	end
	if pane.Subtitle then
		Style.Text(pane.Subtitle, "body", "text")
	end
	if pane.EmptyText then
		Style.Text(pane.EmptyText, "body", "textDisabled")
	end
	Parts.Divider(pane, pane.Divider)
	Skin.ScrollBar(pane.DescriptionScrollBar)
	local description = DescriptionText(pane)
	if description then
		Style.Text(description, "body", "text")
		description:SetJustifyH("LEFT")
	end
	if pane.StandingBar then
		Parts.FillBar(pane.StandingBar, { tone = Parts.StandingTone })
	end
	for _, key in ipairs(checks) do
		local check = pane[key]
		if type(check) == "table" then
			Skin.CheckBox(check)
			if check.Label then
				Style.Text(check.Label, "body")
			end
		end
	end
	for _, key in ipairs({ "ViewRenownButton", "CurrencyTransferToggleButton" }) do
		if type(pane[key]) == "table" then
			Skin.Button(pane[key])
		end
	end
end

local function ListRow(row)
	local content = row.Content
	if not rows[row] then
		rows[row] = true
		if type(content) == "table" then
			if content.ReputationBar then
				Parts.FillBar(content.ReputationBar, { tone = Parts.StandingTone })
			end
			Parts.Wash(content.BackgroundHighlight)
		else
			local keep = {}
			if Parts.IsTexture(row.StateIcon) then
				keep[row.StateIcon] = true
			end
			Skin.Strip(row, { keep = keep })
		end
	end
	if type(content) == "table" then
		if content.Name then
			Style.Text(content.Name, "body")
		end
		if content.Count then
			Style.Text(content.Count, "number")
		end
		return
	end
	local name = row.Name or row.Text
	if name then
		Style.Text(name, "body", "textEmphasis")
	end
end

local function SkinList(frame, checks, detail)
	Parts.Dropdown(frame.filterDropdown)
	Skin.ScrollBar(frame.ScrollBar)
	if type(frame.ScrollBox) == "table" then
		Parts.StripLeaves(frame.ScrollBox)
		Parts.EachRow(frame.ScrollBox, ListRow)
	end
	DetailPane(detail, checks)
end

local function Apply()
	local frame = Frame("CharacterFrame")
	if not frame then
		return
	end
	SkinWindow(frame)
	SkinPaperDoll()
	local rep = Frame("ReputationFrame")
	if rep then
		SkinList(rep, REP_CHECKS, rep.ReputationDetailFrame)
	end
	local token = Frame("TokenFrame")
	if token then
		SkinList(token, TOKEN_CHECKS, token.DetailFrame)
	end
end

local function OnSetting(_, field)
	if field == nil or field == "qualityBorders" or field == "qualityFrom" then
		PaintSlots()
	end
end

Skins.Add({
	key = KEY,
	label = L["Character sheet"],
	help = L["Restyles the character window: equipment, stats, reputation and currency."],
	frame = "CharacterFrame",
	defaults = { qualityBorders = true, qualityFrom = QUALITY_UNCOMMON, itemLevels = true },
	rows = {
		{
			type = "toggle", key = "qualityBorders", label = L["Quality borders"],
			help = L["Colours each equipment slot's border by its item's quality."],
		},
		{
			type = "dropdown", key = "qualityFrom", label = L["Colour borders from"],
			options = {
				{ value = QUALITY_POOR, label = L["Poor and better"] },
				{ value = QUALITY_COMMON, label = L["Common and better"] },
				{ value = QUALITY_UNCOMMON, label = L["Uncommon and better"] },
				{ value = QUALITY_RARE, label = L["Rare and better"] },
				{ value = QUALITY_EPIC, label = L["Epic and better"] },
			},
			help = L["The lowest item quality that colours a slot border."],
			disableWhen = function(settings)
				return settings.qualityBorders ~= true
			end,
		},
		{
			type = "toggle", key = "itemLevels", label = L["Item levels"],
			help = L["Shows each piece of gear's item level on your equipment and on players you inspect."],
		},
	},
	metrics = true,
	Apply = Apply,
	OnSetting = OnSetting,
})
