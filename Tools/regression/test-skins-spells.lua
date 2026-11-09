-- test-skins-spells.lua: the spellbook and talents skins wait for Blizzard_PlayerSpells, then restyle Forever's PlayerSpellsFrame, its spell pages and the talent tree's chrome.
local S = dofile("Tools/regression/skins_env.lua")

local HOOKED = { DisplayViewsForCurrentPage = true, SetTabSelected = true, AddTab = true }

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

-- SpellItem(B, parent) -> a stand-in SpellBookItemTemplate frame: a backplate, texts and an icon button.
local function SpellItem(B, parent)
	local item = B.frame("Frame", parent)
	item.Backplate = B.texture(item, "BACKGROUND")
	item.Name, item.SubName, item.RequiredLevel = B.text(item), B.text(item), B.text(item)
	local button = B.frame("Button", item)
	item.Button = button
	button.Icon = B.texture(button)
	button.IconMask = B.add(button:CreateMaskTexture())
	button.Icon:AddMaskTexture(button.IconMask)
	button.Border, button.BorderShadow = B.texture(button, "OVERLAY"), B.texture(button)
	button.TrainableShadow, button.BorderSheen = B.texture(button), B.texture(button, "OVERLAY")
	button.Arrow = B.texture(button, "OVERLAY")
	return item
end

local function Header(B, parent)
	local header = B.frame("Frame", parent)
	header.Text = B.text(header)
	header.Border = B.texture(header)
	header.Backplate = B.texture(header, "BACKGROUND")
	return header
end

-- Tabs(B, parent, icons) -> a stand-in TabSystem. With icons, its tabs are the icon-only square tabs
-- Forever's spellbook makes with AddIconTab; system.AddTab adds one more, as the pet category does.
local function Tabs(B, parent, icons)
	local system = B.frame("Frame", parent)
	system.tabs = {}
	local function NewTab()
		local tab = B.frame("Button", system)
		B.texture(tab)
		tab.Text = B.text(tab)
		if icons then
			tab.tabIcon = 136243
			tab.Icon = B.texture(tab)
			tab.SquareBackground, tab.SquareBackgroundActive = B.texture(tab, "BACKGROUND"), B.texture(tab, "BACKGROUND")
		end
		function tab.SetTabSelected(self, selected)
			self.isSelected = selected
		end
		system.tabs[#system.tabs + 1] = tab
		return tab
	end
	NewTab():SetTabSelected(true)
	NewTab():SetTabSelected(false)
	system.spare = NewTab()
	table.remove(system.tabs)
	function system.AddTab(self)
		self.tabs[#self.tabs + 1] = self.spare
	end
	return system
end

-- PlayerSpells(env, B) -> the stand-in PlayerSpellsFrame Blizzard_PlayerSpells builds on Forever.
local function PlayerSpells(env, B)
	local p = {}
	local f = B.frame("Frame", nil, "PlayerSpellsFrame")
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	f.CloseButton = B.frame("Button", f)
	B.texture(f.CloseButton)
	f.MaximizeMinimizeButton = B.frame("Frame", f)
	for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
		local button = B.frame("Button", f.MaximizeMinimizeButton)
		p[key] = B.texture(button)
		f.MaximizeMinimizeButton[key] = button
	end

	local book = B.frame("Frame", f)
	f.SpellBookFrame = book
	book.TopBar, book.BookBGLeft, book.BookBGRight = B.texture(book), B.texture(book), B.texture(book)
	book.CategoryTabSystem = Tabs(B, book, true)
	book.SearchBox = B.frame("EditBox", book)
	B.texture(book.SearchBox)
	book.SettingsDropdown = B.frame("Button", book)
	book.SettingsDropdown.Icon = B.texture(book.SettingsDropdown)
	local paged = B.frame("Frame", book)
	book.PagedSpellsFrame = paged
	p.items = { SpellItem(B, paged), Header(B, paged) }
	p.late = SpellItem(B, paged)
	p.shown = { p.items[1], p.items[2] }
	function paged.ForEachFrame(self, fn)
		for _, frame in ipairs(p.shown) do
			fn(frame)
		end
	end
	function paged.DisplayViewsForCurrentPage() end
	paged.PagingControls = B.frame("Frame", paged)
	paged.PagingControls.PageText = B.text(paged.PagingControls)
	paged.PagingControls.PrevPageButton = B.frame("Button", paged.PagingControls)
	paged.PagingControls.NextPageButton = B.frame("Button", paged.PagingControls)
	p.prevArt = B.texture(paged.PagingControls.PrevPageButton)

	local talents = B.frame("Frame", f)
	f.TalentsFrame = talents
	talents.Background, talents.BackgroundBorder = B.texture(talents, "BACKGROUND"), B.texture(talents)
	talents.ClassBackground = B.texture(talents, "BACKGROUND")
	talents.DividerHorizontalLeft = B.texture(talents)
	talents.TabSystem = Tabs(B, talents)
	talents.SearchBox = B.frame("EditBox", talents)
	talents.ApplyButton = B.frame("Button", talents)
	B.texture(talents.ApplyButton)
	talents.ClassCurrencyDisplay = B.frame("Frame", talents)
	talents.ClassCurrencyDisplay.Border = B.texture(talents.ClassCurrencyDisplay)
	talents.ClassCurrencyDisplay.UnspentLabel = B.text(talents.ClassCurrencyDisplay)
	p.frame, p.book, p.talents, p.paged = f, book, talents, paged
	return p
end

do
	local B, snap, p
	local env, K, ns = S.New({ before = function() end })
	local Style = ns.Style
	assert(K.Options.Row("Skins", "spellbook.enabled") and K.Options.Row("Skins", "talents.enabled"), "a switch each for the spellbook and the talents")
	K.Modules.Enable("Skins")
	assert(S.Logged(env, "spellbook: waits for Blizzard_PlayerSpells to load"), "nothing loads the on-demand addon for KstyleUI")
	B = S.Blizzard(env)
	p = PlayerSpells(env, B)
	snap = B.snapshot()
	S.LoadAddOn(env, "Blizzard_PlayerSpells")
	assert(not ns.Skins.IsApplied("spellbook"), "the window has not opened")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("spellbook") and ns.Skins.IsApplied("talents"), "both skins apply on the first show")

	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(f.Bg) == 0, "the window wears the glass panel")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"))
	assert(Alpha(p.MaximizeButton) == 0 and Alpha(p.MinimizeButton) == 0, "the red size buttons lose their art")

	local book = p.book
	assert(Alpha(book.TopBar) == 0 and Alpha(book.BookBGLeft) == 0, "the book's page art goes")
	local categories = book.CategoryTabSystem
	local first = categories.tabs[1]
	assert(Alpha(first.Icon) == 1, "an icon-only category tab keeps its icon")
	assert(Alpha(first.SquareBackground) == 0 and Alpha(first.SquareBackgroundActive) == 0, "and loses Blizzard's square frame")
	assert(ns.Parts.RimOf(first).rim[1]:IsShown(), "the selected category wears an accent rim")
	assert(not ns.Parts.RimOf(categories.tabs[2]).rim[1]:IsShown())
	categories.tabs[2]:SetTabSelected(true)
	first:SetTabSelected(false)
	assert(ns.Parts.RimOf(categories.tabs[2]).rim[1]:IsShown() and not ns.Parts.RimOf(first).rim[1]:IsShown(), "the rim follows the selection")
	categories:AddTab()
	assert(Alpha(categories.spare.Icon) > 0 and Alpha(categories.spare.Icon) < 1 and ns.Parts.RimOf(categories.spare), "a category added later is skinned too, its icon quiet until chosen")
	assert(K.Skin.IsSkinned(p.talents.TabSystem.tabs[1], "Tab"), "text tabs get the accent underline")
	assert(K.Skin.IsSkinned(book.SearchBox, "EditBox"), "the search box is restyled")
	assert(Alpha(book.SettingsDropdown.Icon) == 0, "the yellow filter arrow gives way to a KstyleUI chevron")
	local item = p.items[1]
	assert(Alpha(item.Backplate) == 0 and Alpha(item.Button.Border) == 0 and Alpha(item.Button.BorderShadow) == 0, "the spell item's frame art goes")
	assert(Alpha(item.Button.Icon) == 1 and Alpha(item.Button.Arrow) == 1, "the icon and the flyout arrow stay")
	assert(item.Button.Icon:GetNumMaskTextures() == 0, "the icon loses Blizzard's rounded mask")
	assert(ns.Parts.RimOf(item.Button), "the icon sits on a KstyleUI rim")
	assert(FontPath(item.Name) == Style.Font("heading") and FontPath(item.SubName) == Style.Font("body"))
	local header = p.items[2]
	assert(Alpha(header.Border) == 0 and Alpha(header.Backplate) == 0 and FontPath(header.Text) == Style.Font("display"), "a section header becomes display text over an accent line")
	p.shown[#p.shown + 1] = p.late
	env.SetCombat(true)
	p.paged:DisplayViewsForCurrentPage()
	assert(Alpha(p.late.Backplate) == 1, "spell buttons can be protected, so a page shown in combat waits")
	env.SetCombat(false)
	assert(Alpha(p.late.Backplate) == 0, "a page shown later is skinned once combat ends")
	assert(Alpha(p.prevArt) == 0 and FontPath(p.paged.PagingControls.PageText) == Style.Font("caption"), "the paging controls are restyled")

	local talents = p.talents
	assert(Alpha(talents.Background) == 0 and Alpha(talents.BackgroundBorder) == 0 and Alpha(talents.DividerHorizontalLeft) == 0, "the talent frame's own art goes")
	assert(Alpha(talents.ClassBackground) == 1, "the class background art stays")
	assert(K.Skin.IsSkinned(talents.ApplyButton, "Button") and K.Skin.IsSkinned(talents.SearchBox, "EditBox"))
	assert(Alpha(talents.ClassCurrencyDisplay.Border) == 0 and FontPath(talents.ClassCurrencyDisplay.UnspentLabel) == Style.Font("caption"))

	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The talents switch alone skins the window and the talents, and leaves the spell pages alone -----------

do
	local env, K, ns = S.New({ loaded = { Blizzard_PlayerSpells = true } })
	K.Options.Write("Skins", "spellbook.enabled", false)
	local B = S.Blizzard(env)
	local p = PlayerSpells(env, B)
	K.Modules.Enable("Skins")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("talents") and not ns.Skins.IsApplied("spellbook"))
	assert(K.Skin.IsSkinned(p.frame, "Window"), "the shared window is skinned once")
	assert(Alpha(p.book.TopBar) == 1, "the spell pages keep Blizzard's look")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins spells ok")
