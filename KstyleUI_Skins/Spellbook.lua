-- Spellbook.lua: the spellbook and talents skins for Forever's PlayerSpellsFrame: the window, the spell pages and the talent tree's chrome.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, L = K.Skin, K.Tokens, K.L
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local ADDON = "Blizzard_PlayerSpells"
local FRAME = "PlayerSpellsFrame"
local ICON_CROP = 0.07
local HALF_TURN = math.pi / 2
local BOOK_ART = { "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }
local ITEM_ART = { "Border", "BorderShadow", "TrainableShadow", "TrainableBackplate", "BorderSheen" }
local TALENT_ART = { "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight" }
local TALENT_TREE = { "TalentsFrame.ButtonsParent", "TalentsFrame.SelectionChoiceFrame" }

local WEAK = { __mode = "k" }
local items = setmetatable({}, WEAK)
local queued = false

local function Log(key, message)
	K.DevTest.Log("Skins", key .. ": " .. message)
end

local function Window(frame)
	if Skin.IsSkinned(frame, "Window") then
		return
	end
	Skin.Window(frame, { tabs = false })
	local title = type(frame.TitleContainer) == "table" and frame.TitleContainer.TitleText
	if title then
		Style.Text(title, "heading")
	end
	local maxMin = frame.MaximizeMinimizeButton or frame.MaxMinButtonFrame
	if type(maxMin) == "table" then
		Parts.Glyph(maxMin.MaximizeButton, "glyphChevron", { flip = true })
		Parts.Glyph(maxMin.MinimizeButton, "glyphChevron")
	end
end

local function Tab(tab)
	if type(tab) ~= "table" then
		return
	end
	if tab.tabIcon ~= nil and Parts.IsTexture(tab.Icon) then
		Parts.SideTab(tab)
	else
		Skin.Tab(tab)
	end
end

local function TabSystem(system)
	if type(system) ~= "table" or type(system.tabs) ~= "table" then
		return
	end
	local function Each(self)
		for _, tab in ipairs(self.tabs) do
			Tab(tab)
		end
	end
	Each(system)
	if type(system.AddTab) == "function" then
		hooksecurefunc(system, "AddTab", Each)
	end
end

local function SpellItem(item)
	local button = item.Button
	if items[item] or type(button) ~= "table" then
		return
	end
	items[item] = true
	Parts.Hush(item.Backplate)
	for _, key in ipairs(ITEM_ART) do
		Parts.Hush(button[key])
	end
	local icon = button.Icon
	if Parts.IsTexture(icon) then
		if button.IconMask and type(icon.RemoveMaskTexture) == "function" then
			pcall(icon.RemoveMaskTexture, icon, button.IconMask)
		end
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
		Parts.Rim(button, { target = icon, outset = Tokens.Size("gapTiny") })
	end
	if item.Name then
		Style.Text(item.Name, "heading", "textEmphasis")
	end
	if item.SubName then
		Style.Text(item.SubName, "body", "text")
	end
	if item.RequiredLevel then
		Style.Text(item.RequiredLevel, "caption", "text")
	end
end

local function Header(frame)
	if items[frame] then
		return
	end
	items[frame] = true
	Parts.Hush(frame.Backplate)
	Parts.Divider(frame, frame.Border)
	Style.Text(frame.Text, "display", "textEmphasis")
end

local function PageFrame(frame)
	if type(frame) ~= "table" then
		return
	end
	if type(frame.Button) == "table" then
		SpellItem(frame)
	elseif frame.Text and frame.Border then
		Header(frame)
	end
end

local function SkinShown(paged)
	if not InCombatLockdown() then
		paged:ForEachFrame(PageFrame)
		return
	end
	if not queued then
		queued = true
		K.Combat.Queue(function()
			queued = false
			paged:ForEachFrame(PageFrame)
		end)
	end
end

local function SkinPages(paged)
	if type(paged) ~= "table" or type(paged.ForEachFrame) ~= "function" then
		Log("spellbook", "the spell pages are missing; they keep Blizzard's look")
		return
	end
	SkinShown(paged)
	if type(paged.DisplayViewsForCurrentPage) == "function" then
		hooksecurefunc(paged, "DisplayViewsForCurrentPage", SkinShown)
	else
		Log("spellbook", "DisplayViewsForCurrentPage is missing; pages after the first keep Blizzard's look")
	end
	local paging = paged.PagingControls
	if type(paging) == "table" then
		if paging.PageText then
			Style.Text(paging.PageText, "caption", "text")
		end
		Parts.Glyph(paging.PrevPageButton, "glyphChevron", { rotation = -HALF_TURN })
		Parts.Glyph(paging.NextPageButton, "glyphChevron", { rotation = HALF_TURN })
	end
end

local function ApplySpellbook()
	local frame = _G[FRAME]
	Window(frame)
	local book = frame.SpellBookFrame
	if type(book) ~= "table" then
		Log("spellbook", "SpellBookFrame is missing; skipped")
		return
	end
	for _, key in ipairs(BOOK_ART) do
		Parts.Hush(book[key])
	end
	TabSystem(book.CategoryTabSystem)
	Skin.EditBox(book.SearchBox)
	Parts.Glyph(book.SettingsDropdown, "glyphChevron")
	SkinPages(book.PagedSpellsFrame)
end

local function ApplyTalents()
	local frame = _G[FRAME]
	Window(frame)
	local talents = frame.TalentsFrame
	if type(talents) ~= "table" then
		Log("talents", "TalentsFrame is missing; skipped")
		return
	end
	for _, key in ipairs(TALENT_ART) do
		Parts.Hush(talents[key])
	end
	TabSystem(talents.TabSystem)
	Skin.EditBox(talents.SearchBox)
	for _, key in ipairs({ "ApplyButton", "InspectCopyButton" }) do
		if type(talents[key]) == "table" then
			Skin.Button(talents[key])
		end
	end
	local currency = talents.ClassCurrencyDisplay
	if type(currency) == "table" then
		Parts.Hush(currency.Border)
		if currency.UnspentLabel then
			Style.Text(currency.UnspentLabel, "caption", "text")
		end
		local amount = type(currency.CurrentAmountContainer) == "table" and currency.CurrentAmountContainer.CurrencyAmount
		if amount then
			Style.Text(amount, "display", "textEmphasis")
		end
	end
end

Skins.Add({
	key = "spellbook",
	label = L["Spellbook"],
	help = L["Restyles the spellbook: its window, pages, spell icons and search."],
	addon = ADDON,
	frame = FRAME,
	sweepSkip = TALENT_TREE,
	Apply = ApplySpellbook,
})

Skins.Add({
	key = "talents",
	label = L["Talents"],
	help = L["Restyles the talent window's frame, search, buttons and point counter."],
	addon = ADDON,
	frame = FRAME,
	sweepSkip = TALENT_TREE,
	Apply = ApplyTalents,
})
