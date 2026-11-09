-- Professions.lua: the professions skin: ProfessionsFrame, its side tabs, the recipe list and schematic, the skill bars and the overview page.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit
local Skin = K.Skin

local WINDOW = "professions"
local GEAR_SLOTS = {
	"Prof0ToolSlot", "Prof0Gear0Slot", "Prof0Gear1Slot",
	"Prof1ToolSlot", "Prof1Gear0Slot", "Prof1Gear1Slot",
	"CookingToolSlot", "CookingGear0Slot",
	"FishingToolSlot", "FishingGear0Slot", "FishingGear1Slot",
}
local CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" }

local function Tabs(frame)
	local side = {}
	if Kit.SideTab(frame.ProfessionsOverviewTab) then
		side[#side + 1] = frame.ProfessionsOverviewTab
	end
	if type(frame.rightProfessionTabs) == "table" then
		for _, tab in ipairs(frame.rightProfessionTabs) do
			if Kit.SideTab(tab) then
				side[#side + 1] = tab
			end
		end
	end
	ns.Parts.Dock(frame, side, { title = Kit.Title(frame) })
	local system = frame.TabSystem
	if type(system) == "table" and type(system.tabs) == "table" then
		for _, tab in ipairs(system.tabs) do
			Kit.Tab(tab)
		end
	end
end

local function RecipeList(list)
	if not Kit.Have(list, "ProfessionsFrame.CraftingPage.RecipeList") then
		return
	end
	Skin.Strip(list, { children = { "BackgroundNineSlice" } })
	Skin.Backdrop(list, { shape = "tile", fill = "surface", shadow = false })
	Kit.EditBox(list.SearchBox)
	Kit.Dropdown(list.FilterDropdown)
	Kit.ScrollBar(list.ScrollBar)
end

local function CraftingPage(page)
	if not Kit.Have(page, "ProfessionsFrame.CraftingPage") then
		return
	end
	Skin.Strip(page)
	RecipeList(page.RecipeList)
	local form = page.SchematicForm
	if type(form) == "table" then
		Skin.Strip(form, { children = { "Background", "MinimalBackground", "NineSlice" } })
		Skin.Backdrop(form, { shape = "tile", fill = "surface", shadow = false })
	end
	Kit.RankBar(page.RankBar)
	Kit.NumberBox(page.CreateMultipleInputBox)
	Kit.Button(page.CreateButton)
	Kit.Button(page.CreateAllButton)
	if page.ViewGuildCraftersButton then
		Kit.Button(page.ViewGuildCraftersButton)
	end
	for _, key in ipairs(GEAR_SLOTS) do
		if page[key] then
			Kit.Item(page[key], { window = WINDOW })
		end
	end
	local results = page.MinimizedSearchResults
	if type(results) == "table" then
		Kit.Window(results)
		Kit.ScrollBar(results.ScrollBar)
	end
end

local function Card(card)
	if card.StatusBar then
		Kit.RankBar(card.StatusBar)
	end
	if type(card.spellButtons) == "table" then
		for _, button in ipairs(card.spellButtons) do
			Kit.Item(button, { window = WINDOW, icon = button.IconTexture })
		end
	end
end

local function BookPage(page)
	if type(page) ~= "table" then
		return
	end
	local content = page.ProfessionsContentFrame
	if type(content) ~= "table" then
		return
	end
	for _, key in ipairs(CARDS) do
		if type(content[key]) == "table" then
			Card(content[key])
		end
	end
end

local function Apply()
	local frame = ProfessionsFrame
	if not Kit.Have(frame, "ProfessionsFrame") then
		return false
	end
	Kit.Window(frame, { tabs = false })
	Tabs(frame)
	CraftingPage(frame.CraftingPage)
	BookPage(frame.BookPage)
	return true
end

ns.Skins.Add({
	key = WINDOW,
	label = L["Professions"],
	help = L["Restyles the professions window, its recipe list and its overview page."],
	addon = "Blizzard_Professions",
	frame = "ProfessionsFrame",
	defaults = { qualityRims = true },
	rows = {
		{ type = "toggle", key = "qualityRims", label = L["Quality rims"], help = L["Rings each item in the item's quality colour."] },
	},
	Apply = Apply,
})
