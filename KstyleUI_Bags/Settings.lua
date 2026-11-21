-- Settings.lua: KstyleUI_Bags' defaults, its settings page and checked reads of each setting.
local _, ns = ...

local K = KstyleUI
local L, Tokens = ns.L, K.Tokens
local floor, max, min = math.floor, math.max, math.min

local Settings = {}
ns.Settings = Settings

Settings.MODULE = "Bags"

local COLUMNS_MIN, COLUMNS_MAX = 4, 24
local SLOT_MIN, SLOT_MAX = 24, 48
local SPACING_MIN, SPACING_MAX = 0, 12
local ROWS_MAX = 20
local FONT_MIN, FONT_MAX = 6, 20
local QUALITY = { POOR = 0, COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5 }

local accentR, accentG, accentB = Tokens.Color("accentDefault")

Settings.LIMITS = {
	columns = { COLUMNS_MIN, COLUMNS_MAX },
	bankColumns = { COLUMNS_MIN, COLUMNS_MAX },
	slotSize = { SLOT_MIN, SLOT_MAX },
	spacing = { SPACING_MIN, SPACING_MAX },
	rows = { 0, ROWS_MAX },
	fontSize = { FONT_MIN, FONT_MAX },
	iconZoom = { 0, 20 },
	maxHeight = { 30, 100 },
	capSize = { 8, 16 },
	labelSize = { FONT_MIN, FONT_MAX },
	reagentMarkSize = { 8, 24 },
	listRowHeight = { 16, 32 },
	listFontSize = { 8, 16 },
	listLeft = { 0, 50 },
	listRight = { 0, 50 },
}

Settings.defaults = {
	enabled = false,
	compactBags = false,
	slotCount = "freeTotal",
	iconZoom = 7,
	layout = "categories",
	emptySlots = "packed",
	columns = 10,
	slotSize = Tokens.Size("actionButton"),
	spacing = Tokens.Size("gapSmall"),
	rows = 0,
	growth = "RIGHT_DOWN",
	showCount = true,
	showItemLevel = true,
	separateFigures = true,
	readableHeaders = true,
	showQuality = true,
	qualityColors = true,
	qualityMin = QUALITY.UNCOMMON,
	showNewGlow = true,
	showJunk = true,
	desaturateJunk = false,
	showKeyring = true,
	font = "",
	fontSize = Tokens.Size("number"),
	fontOutline = "NONE",
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	sortDirection = "LEFT",
	bankColumns = 14,
	bankOpensBags = true,
	characterBags = false,
	replaceBank = true,
	autoSellJunk = true,
	altCounts = true,
	custom1 = { name = "", rule = "" },
	custom2 = { name = "", rule = "" },
	custom3 = { name = "", rule = "" },
	maxHeight = 100,
	nearestCorner = false,
	bagSlots = false,
	goldTooltip = true,
	goldCoins = "copper",
	currencies = false,
	capSize = 11,
	recentItems = false,
	recentClear = false,
	recentNewOnly = false,
	recentGained = false,
	mergeStacks = false,
	sectionValue = false,
	gearBySlot = false,
	compactGroups = false,
	splitTypes = false,
	splitSets = false,
	nestExpansion = false,
	bankNestExpansion = false,
	bindText = false,
	setNames = false,
	labelSize = 9,
	separateReagents = false,
	categorizeReagents = true,
	reagentMark = false,
	reagentMarkSize = 12,
	listView = false,
	listRowHeight = 24,
	listFontSize = 11,
	listLeft = 0,
	listRight = 0,
	listStripes = true,
	autoMerchant = "both",
	autoMail = "both",
	autoAuction = "both",
	autoTrade = "none",
	autoLoot = "none",
	autoQuest = "none",
	warbandGold = false,
	warbandGoldAmount = "",
	warbandGoldChat = false,
	shrink = true,
	sortBottom = false,
	currency1 = 0,
	currency2 = 0,
	currency3 = 0,
	pins = false,
	pinsOnly = false,
	pinsInGrid = true,
	pinsDim = false,
	pinsPerCharacter = true,
	openTo = "all",
	sidebar = false,
	sidebarEmpty = false,
	sidebarAdd = true,
	sidebarHide = false,
	sidebarTabs = true,
}

Settings.CURRENCIES = { "currency1", "currency2", "currency3" }

Settings.AUTO = { merchant = "autoMerchant", mail = "autoMail", auction = "autoAuction", trade = "autoTrade", loot = "autoLoot", quest = "autoQuest" }

Settings.CUSTOM = { "custom1", "custom2", "custom3" }
local CUSTOM_LETTERS = 60

local GROWTH_OPTIONS = {
	{ value = "RIGHT_DOWN", label = L["Right, then down"] },
	{ value = "LEFT_DOWN", label = L["Left, then down"] },
	{ value = "RIGHT_UP", label = L["Right, then up"] },
	{ value = "LEFT_UP", label = L["Left, then up"] },
}
local QUALITY_OPTIONS = {
	{ value = QUALITY.POOR, label = L["Poor and better"] },
	{ value = QUALITY.COMMON, label = L["Common and better"] },
	{ value = QUALITY.UNCOMMON, label = L["Uncommon and better"] },
	{ value = QUALITY.RARE, label = L["Rare and better"] },
	{ value = QUALITY.EPIC, label = L["Epic and better"] },
	{ value = QUALITY.LEGENDARY, label = L["Legendary and better"] },
}
local OUTLINE_OPTIONS = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
}
local ACCENT_OPTIONS = {
	{ value = "class", label = L["Class colour"] },
	{ value = "custom", label = L["Custom colour"] },
}
local LAYOUT_OPTIONS = {
	{ value = "categories", label = L["Sections by item type"] },
	{ value = "grid", label = L["One grid"] },
}
local EMPTY_OPTIONS = {
	{ value = "packed", label = L["One stacked tile per bag kind"] },
	{ value = "all", label = L["Every empty slot"] },
}
local SORT_OPTIONS = {
	{ value = "LEFT", label = L["Left to right"] },
	{ value = "RIGHT", label = L["Right to left"] },
}

local function Choices(list)
	local set = {}
	for _, option in ipairs(list) do
		set[option.value] = true
	end
	return set
end

local CHOICES = {
	slotCount = { freeTotal = true, usedTotal = true, free = true },
	layout = Choices(LAYOUT_OPTIONS),
	emptySlots = Choices(EMPTY_OPTIONS),
	growth = Choices(GROWTH_OPTIONS),
	qualityMin = Choices(QUALITY_OPTIONS),
	fontOutline = Choices(OUTLINE_OPTIONS),
	accentSource = Choices(ACCENT_OPTIONS),
	sortDirection = Choices(SORT_OPTIONS),
	goldCoins = { gold = true, silver = true, copper = true },
	openTo = { all = true, grid = true, bags = true },
}
for _, key in pairs(Settings.AUTO) do
	CHOICES[key] = { both = true, open = true, none = true }
end

function Settings.Sections()
	return Settings.Get("compactBags") and Settings.Get("layout") == "categories"
end

function Settings.ReagentApart()
	if Settings.Sections() then
		return not Settings.Get("categorizeReagents")
	end
	return Settings.Get("separateReagents")
end

function Settings.Schema()
	local function isOff(settings)
		return not settings.enabled
	end

	local function customAccent(settings)
		return settings.accentSource == "custom"
	end

	local function qualityOn(settings)
		return settings.showQuality == true
	end

	local function compactOn(settings)
		return settings.compactBags == true
	end

	local function sectionsOn(settings)
		return settings.compactBags == true and settings.layout ~= "grid"
	end
	local function notSections(settings) return not sectionsOn(settings) end
	local function recentOn(settings) return sectionsOn(settings) and settings.recentItems == true end
	local function listOn(settings) return settings.listView == true end
	local function markOn(settings) return settings.reagentMark == true end
	local function goldOn(settings) return settings.goldTooltip == true end
	local function warbandOn(settings) return settings.warbandGold == true end
	local function currenciesOn(settings) return settings.currencies == true end
	local function pinsOn(settings) return settings.pins == true end
	local function pinsGrid(settings) return settings.pins == true and settings.pinsInGrid == true end
	local function sidebarOn(settings) return settings.sidebar == true end
	local AUTO_OPTIONS = { { value = "both", label = L["Open and close bags"] }, { value = "open", label = L["Open bags"] }, { value = "none", label = L["Leave bags alone"] } }
	local function currencies()
		local list, seen = { { value = 0, label = L["Tracked on the backpack"] } }, { [0] = true }
		local info = C_CurrencyInfo
		local size = info and type(info.GetCurrencyListSize) == "function" and type(info.GetCurrencyListInfo) == "function" and ns.Data.Plain(info.GetCurrencyListSize(), "number") or 0
		for i = 1, size do
			local entry = info.GetCurrencyListInfo(i)
			local id = type(entry) == "table" and not ns.Data.IsSecret(entry) and not entry.isHeader and ns.Data.Plain(entry.currencyID, "number")
			if id and id > 0 and not seen[id] then
				seen[id] = true
				list[#list + 1] = { value = id, label = ns.Data.Plain(entry.name, "string") or tostring(id) }
			end
		end
		return list
	end
	local function currency(key, label)
		return { type = "dropdown", key = key, label = label, options = currencies, help = L["A currency for the footer, in place of the backpack's. Open its group in the currency tab first."], disableWhen = isOff, showWhen = currenciesOn }
	end
	local function auto(key, label)
		return { type = "dropdown", key = key, label = label, options = AUTO_OPTIONS, disableWhen = isOff, help = L["What your bags do when this window opens and closes. Closing only closes bags it opened."] }
	end

	Settings.schema = {
		{ type = "header", label = L["Bags"] },
		{ type = "toggle", key = "enabled", label = L["KstyleUI bags"], help = L["Replace Blizzard's bags with one KstyleUI bag window."] },
		{ type = "dropdown", key = "slotCount", label = L["Slot count format"], help = L["Show free slots, used slots or free slots alone in the footer."], options = {
			{ value = "freeTotal", label = L["Free / total"] }, { value = "usedTotal", label = L["Used / total"] },
			{ value = "free", label = L["Free slots only"] },
		}, disableWhen = isOff },
		{ type = "slider", key = "iconZoom", label = L["Icon zoom"], help = L["Crop item icon edges by this percentage on each side."], min = 0, max = 20, step = 1, disableWhen = isOff },
		{ type = "header", label = L["Slots"] },
		{ type = "toggle", key = "compactBags", label = L["Compact bags"], help = L["Group items and pack empty slots. Off keeps bags and bank in a fixed grid with every slot shown."], disableWhen = isOff },
		{
			type = "dropdown", key = "layout", label = L["Layout"], help = L["Sort items into sections by type, or show one grid."],
			options = LAYOUT_OPTIONS, disableWhen = isOff, showWhen = compactOn,
		},
		{
			type = "dropdown", key = "emptySlots", label = L["Empty slots"], help = L["In sections, show each bag kind's free slots as one counted tile, or every empty slot."],
			options = EMPTY_OPTIONS, disableWhen = isOff, showWhen = compactOn,
		},
		{
			type = "slider", key = "columns", label = L["Columns"], help = L["How many slots sit in each row of the bag window."],
			min = COLUMNS_MIN, max = COLUMNS_MAX, step = 1, disableWhen = isOff,
		},
		{
			type = "slider", key = "rows", label = L["Rows shown"], help = L["How many rows show before the grid or the sections scroll; 0 fits the screen."],
			min = 0, max = ROWS_MAX, step = 1, disableWhen = isOff,
		},
		{
			type = "slider", key = "slotSize", label = L["Slot size"], help = L["The size of each item slot."],
			min = SLOT_MIN, max = SLOT_MAX, step = 1, disableWhen = isOff,
		},
		{
			type = "slider", key = "spacing", label = L["Spacing"], help = L["The gap between item slots."],
			min = SPACING_MIN, max = SPACING_MAX, step = 1, disableWhen = isOff,
		},
		{
			type = "dropdown", key = "growth", label = L["Growth"], help = L["The way the grid fills from its first slot."],
			options = GROWTH_OPTIONS, disableWhen = isOff,
		},
		{ type = "slider", key = "maxHeight", label = L["Maximum height"], help = L["The tallest the bag and bank windows grow, as a percentage of the screen's height."], min = 30, max = 100, step = 5, disableWhen = isOff },
		{ type = "toggle", key = "shrink", label = L["Shrink while open"], help = L["The window shrinks as soon as it needs less room. Off keeps its size until you close it."], disableWhen = isOff },
		{ type = "toggle", key = "nearestCorner", label = L["Hold the nearest corner"], help = L["A moved window holds the screen corner nearest it, so it grows and shrinks toward that corner."], disableWhen = isOff },
		{ type = "toggle", key = "bagSlots", label = L["Bag slots"], help = L["Show your equipped bags in a row under the search box, to swap them."], disableWhen = isOff },
		{ type = "toggle", key = "listView", label = L["List view"], help = L["Show items as rows with their names instead of tiles."], disableWhen = isOff },
		{ type = "slider", key = "listRowHeight", label = L["Row height"], help = L["The height of each row in the list."], min = 16, max = 32, step = 1, disableWhen = isOff, showWhen = listOn },
		{ type = "slider", key = "listFontSize", label = L["Row text size"], help = L["The size of item names in the list."], min = 8, max = 16, step = 1, disableWhen = isOff, showWhen = listOn },
		{ type = "slider", key = "listLeft", label = L["Left gap"], help = L["Empty space between the list's left edge and its rows."], min = 0, max = 50, step = 1, disableWhen = isOff, showWhen = listOn },
		{ type = "slider", key = "listRight", label = L["Right gap"], help = L["Empty space between the list's right edge and its rows."], min = 0, max = 50, step = 1, disableWhen = isOff, showWhen = listOn },
		{ type = "toggle", key = "listStripes", label = L["Row stripes"], help = L["Shade every other row of the list."], disableWhen = isOff, showWhen = listOn },
		{ type = "header", label = L["Sections"] },
		{ type = "slider", key = "capSize", label = L["Heading size"], help = L["The size of the headings above each section."], min = 8, max = 16, step = 1, disableWhen = isOff },
		{ type = "toggle", key = "recentItems", label = L["Recent items"], help = L["Put items you just got in a Recent section first."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "recentClear", label = L["Clear button"], help = L["Show a button that empties the Recent section."], disableWhen = isOff, showWhen = recentOn },
		{ type = "toggle", key = "recentNewOnly", label = L["New items only"], help = L["List only items you were not carrying already."], disableWhen = isOff, showWhen = recentOn },
		{ type = "toggle", key = "recentGained", label = L["Picked-up amount"], help = L["Show each recent item once, with how many you picked up."], disableWhen = isOff, showWhen = recentOn },
		{ type = "toggle", key = "mergeStacks", label = L["Merge stacks"], help = L["Show stacks of one item as a single tile. Not gear, and not while you trade, mail, sell or bank."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "sectionValue", label = L["Section value"], help = L["Show what each section's items sell for beside its count."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "gearBySlot", label = L["Gear by slot"], help = L["Split equipment into sections by where it is worn."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "splitTypes", label = L["Split by type"], help = L["Split equipment by armour or weapon type and trade goods by material."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "splitSets", label = L["Equipment set sections"], help = L["Give gear in each of your equipment sets its own section, named after the set."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "nestExpansion", label = L["Split by expansion"], help = L["Split each bag section by the expansion its items come from, newest first."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "bankNestExpansion", label = L["Split the bank by expansion"], help = L["Split each bank section by the expansion its items come from, newest first."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "compactGroups", label = L["Small sections side by side"], help = L["Place small sections two to a row."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "toggle", key = "categorizeReagents", label = L["Reagent bag in sections"], help = L["File the reagent bag's items under their sections. Off gives the reagent bag a section of its own."], disableWhen = isOff, showWhen = sectionsOn },
		{ type = "header", label = L["Category list"] },
		{ type = "dropdown", key = "openTo", label = L["Opens to"], help = L["What the bag window shows each time it opens."], options = {
			{ value = "all", label = L["All items"] }, { value = "grid", label = L["One grid"] }, { value = "bags", label = L["Bag by bag"] },
		}, disableWhen = isOff },
		{ type = "toggle", key = "sidebar", label = L["Category list"], help = L["List the window's sections down its side. Click one to show only it."], disableWhen = isOff },
		{ type = "toggle", key = "sidebarEmpty", label = L["Empty categories"], help = L["Also list categories that hold no items."], disableWhen = isOff, showWhen = sidebarOn },
		{ type = "toggle", key = "sidebarAdd", label = L["Add category entry"], help = L["End the list with an entry that opens these settings at your custom categories."], disableWhen = isOff, showWhen = sidebarOn },
		{ type = "toggle", key = "sidebarHide", label = L["Hide the folded list"], help = L["A folded list hides completely; the arrow beside the window's title unfolds it."], disableWhen = isOff, showWhen = sidebarOn },
		{ type = "toggle", key = "sidebarTabs", label = L["Bank tabs in the list"], help = L["List each bank tab, to show one tab at a time."], disableWhen = isOff, showWhen = sidebarOn },
		{ type = "header", label = L["Pinned items"] },
		{ type = "toggle", key = "pins", label = L["Pinned items"], help = L["Alt-click an item to pin it. Pinned items also show in a Pinned section at the top."], disableWhen = isOff },
		{ type = "toggle", key = "pinsOnly", label = L["Only in Pinned"], help = L["In sections, pinned items leave their own section and Recent items."], disableWhen = isOff, showWhen = pinsOn },
		{ type = "toggle", key = "pinsInGrid", label = L["Pinned in grids"], help = L["Show the Pinned section above one grid and bag by bag too."], disableWhen = isOff, showWhen = pinsOn },
		{ type = "toggle", key = "pinsDim", label = L["Dim pinned in grids"], help = L["Dim pinned items in their bag slots, since they also show in Pinned."], disableWhen = isOff, showWhen = pinsGrid },
		{ type = "toggle", key = "pinsPerCharacter", label = L["Pins per character"], help = L["Each character keeps its own pins, starting from the shared ones."], disableWhen = isOff, showWhen = pinsOn },
		{ type = "header", label = L["Custom categories"] },
		{ type = "header", label = L["Slot text"] },
		{ type = "toggle", key = "separateFigures", label = L["Separate item figures"], help = L["Put item levels above stack counts. Off keeps item levels at the lower left."] },
		{ type = "toggle", key = "readableHeaders", label = L["Readable bag headings"], help = L["Use a full title band and smaller category headings. Off restores the previous headings."] },
		{ type = "toggle", key = "showCount", label = L["Stack counts"], help = L["Show how many items are in each stack."], disableWhen = isOff },
		{ type = "toggle", key = "showItemLevel", label = L["Item levels"], help = L["Show the item level of weapons and armour."], disableWhen = isOff },
		{ type = "font", key = "font", label = L["Font"], help = L["The font of stack counts and item levels."], options = K.Widgets.InheritedFontOptions, disableWhen = isOff },
		{
			type = "slider", key = "fontSize", label = L["Font size"], help = L["The size of stack counts and item levels."],
			min = FONT_MIN, max = FONT_MAX, step = 1, disableWhen = isOff,
		},
		{
			type = "dropdown", key = "fontOutline", label = L["Font outline"], help = L["A soft shadow or an outline behind slot text."],
			options = OUTLINE_OPTIONS, disableWhen = isOff,
		},
		{ type = "toggle", key = "bindText", label = L["Bind labels"], help = L["Mark gear that binds when equipped with BoE, or WuE for Warbound until equipped."], disableWhen = isOff },
		{ type = "toggle", key = "setNames", label = L["Equipment set names"], help = L["Show the equipment set an item belongs to across the bottom of its slot."], disableWhen = isOff },
		{ type = "slider", key = "labelSize", label = L["Label size"], help = L["The size of bind labels and equipment set names."], min = FONT_MIN, max = FONT_MAX, step = 1, disableWhen = isOff },
		{ type = "header", label = L["Markers"] },
		{ type = "toggle", key = "showQuality", label = L["Quality borders"], help = L["Colour each slot's border by the item's quality."], disableWhen = isOff },
		{ type = "toggle", key = "qualityColors", label = L["Refined item colours"], help = L["Softer quality colours and quiet common-item rims. Off restores the original colours."], disableWhen = isOff },
		{
			type = "dropdown", key = "qualityMin", label = L["Coloured from"], help = L["The lowest quality whose border is coloured."],
			options = QUALITY_OPTIONS, showWhen = qualityOn, disableWhen = isOff,
		},
		{ type = "toggle", key = "showNewGlow", label = L["New item glow"], help = L["Make items you just got glow until you point at them."], disableWhen = isOff },
		{ type = "toggle", key = "showJunk", label = L["Junk marker"], help = L["Mark grey items that sell for money."], disableWhen = isOff },
		{ type = "toggle", key = "desaturateJunk", label = L["Desaturate junk"], help = L["Show sellable grey items with grey icons."], disableWhen = isOff },
		{ type = "toggle", key = "showKeyring", label = L["Keyring"], help = L["Show the keyring's slots under your bags."], disableWhen = isOff },
		{ type = "toggle", key = "separateReagents", label = L["Reagent bag apart"], help = L["Show the reagent bag's slots in their own row under your bags."], disableWhen = isOff, showWhen = notSections },
		{ type = "toggle", key = "reagentMark", label = L["Reagent bag marker"], help = L["Mark items that sit in the reagent bag when they share a grid with other bags."], disableWhen = isOff },
		{ type = "slider", key = "reagentMarkSize", label = L["Marker size"], help = L["The size of the reagent bag marker."], min = 8, max = 24, step = 1, disableWhen = isOff, showWhen = markOn },
		{ type = "header", label = L["Junk"] },
		{
			type = "toggle", key = "autoSellJunk", label = L["Sell junk by itself"],
			help = L["Sell grey items as soon as you open a merchant, out of combat only."], disableWhen = isOff,
		},
		{ type = "header", label = L["Other characters"] },
		{
			type = "toggle", key = "altCounts", label = L["Counts in tooltips"],
			help = L["Show how many of an item your other characters hold, from the bags and bank KstyleUI last saw."], disableWhen = isOff,
		},
		{ type = "header", label = L["Footer"] },
		{ type = "toggle", key = "goldTooltip", label = L["Gold of every character"], help = L["Point at your money to see each character's gold and the total."], disableWhen = isOff },
		{ type = "dropdown", key = "goldCoins", label = L["Coins shown"], help = L["The coins the gold list shows for each character."], options = {
			{ value = "gold", label = L["Gold only"] }, { value = "silver", label = L["Gold and silver"] }, { value = "copper", label = L["Gold, silver and copper"] },
		}, disableWhen = isOff, showWhen = goldOn },
		{ type = "toggle", key = "currencies", label = L["Tracked currencies"], help = L["Show the currencies you track on the backpack under the footer."], disableWhen = isOff },
		currency("currency1", L["Currency 1"]), currency("currency2", L["Currency 2"]), currency("currency3", L["Currency 3"]),
		{ type = "header", label = L["Accent"] },
		{
			type = "dropdown", key = "accentSource", label = L["Accent colour"], help = L["The colour of the window's hairlines and the new item glow."],
			options = ACCENT_OPTIONS, disableWhen = isOff,
		},
		{
			type = "color", key = "accentColor", label = L["Custom accent"], help = L["The accent colour when it does not follow your class."],
			showWhen = customAccent, disableWhen = isOff,
		},
		{ type = "header", label = L["Bank"] },
		{
			type = "toggle", key = "replaceBank", label = L["KstyleUI bank"],
			help = L["Replace Blizzard's bank window; a change takes effect after a reload."], disableWhen = isOff,
		},
		{
			type = "slider", key = "bankColumns", label = L["Bank columns"], help = L["How many slots sit in each row of the bank window."],
			min = COLUMNS_MIN, max = COLUMNS_MAX, step = 1, disableWhen = isOff,
		},
		{ type = "toggle", key = "bankOpensBags", label = L["Bank opens bags"], help = L["Open your bags beside the bank when you visit a banker."], disableWhen = isOff },
		{ type = "toggle", key = "characterBags", label = L["Character window opens bags"], help = L["Open your bags with the character window and close them with it, unless you opened them first."], disableWhen = isOff },
		{ type = "toggle", key = "warbandGold", label = L["Keep gold on hand"], help = L["At the bank, move gold to or from the Warband bank so you keep the amount below."], disableWhen = isOff },
		{ type = "text", key = "warbandGoldAmount", label = L["Gold to keep"], help = L["The gold each character keeps when the bank opens. Empty moves nothing."], maxLetters = 7, disableWhen = isOff, showWhen = warbandOn },
		{ type = "toggle", key = "warbandGoldChat", label = L["Report in chat"], help = L["Say in chat how much gold moved."], disableWhen = isOff, showWhen = warbandOn },
		{ type = "header", label = L["Open and close with"] },
		auto("autoMerchant", L["Merchant"]), auto("autoMail", L["Mailbox"]), auto("autoAuction", L["Auction house"]),
		auto("autoTrade", L["Trade"]), auto("autoLoot", L["Loot window"]), auto("autoQuest", L["Quest giver"]),
		{ type = "header", label = L["Sorting"] },
		{
			type = "dropdown", key = "sortDirection", label = L["Sort direction"], help = L["The way Sort packs items across your bags."],
			options = SORT_OPTIONS, disableWhen = isOff,
		},
		{ type = "toggle", key = "sortBottom", label = L["Sort to bottom"], help = L["Grids show empty slots first, so your items sit at the bottom in their order."], disableWhen = isOff },
	}

	do
		local at
		for i, row in ipairs(Settings.schema) do
			if row.type == "header" and row.label == L["Custom categories"] then
				at = i
			end
		end
		local CUSTOM_LABELS = { L["Category 1"], L["Category 2"], L["Category 3"] }
		for i = #Settings.CUSTOM, 1, -1 do
			local key = Settings.CUSTOM[i]
			table.insert(Settings.schema, at + 1, {
				type = "text", key = key .. ".rule", label = L["Rule"], maxLetters = CUSTOM_LETTERS,
				help = L["Items this search matches fill the section: & both, | either, ! not, type:, ilvl>30, junk, bound."],
				disableWhen = isOff,
			})
			table.insert(Settings.schema, at + 1, {
				type = "text", key = key .. ".name", label = CUSTOM_LABELS[i], maxLetters = CUSTOM_LETTERS,
				help = L["The section's name. A named category with a rule sorts before the built-in sections."],
				disableWhen = isOff,
			})
		end
	end
	Settings.schema.preview = ns.Preview.Build
	return Settings.schema
end

local function Plain(value, kind)
	return ns.Data.Plain(value, kind)
end

function Settings.Custom()
	local all = Settings.All()
	local list = {}
	for _, key in ipairs(Settings.CUSTOM) do
		local entry = all[key]
		local name = type(entry) == "table" and Plain(entry.name, "string") or nil
		local rule = type(entry) == "table" and ns.Data.Query(entry.rule) or nil
		if name and name ~= "" and rule then
			list[#list + 1] = { key = key, label = name, rule = rule }
		end
	end
	return list
end

function Settings.All()
	local Store = K.Store
	if Store and Store.IsLoaded and Store.IsLoaded() then
		return Store.Module(Settings.MODULE)
	end
	return Settings.defaults
end

function Settings.Get(key)
	local default = Settings.defaults[key]
	if default == nil then
		error("KstyleUI_Bags Settings.Get: unknown setting " .. tostring(key), 2)
	end
	local value = Settings.All()[key]
	local limits = Settings.LIMITS[key]
	if limits then
		value = Plain(value, "number")
		if not value then
			return default
		end
		return max(limits[1], min(limits[2], floor(value + 0.5)))
	end
	local choices = CHOICES[key]
	if choices then
		return choices[value] and value or default
	end
	if type(value) ~= type(default) then
		return default
	end
	return value
end

local function Channel(value)
	value = Plain(value, "number")
	if not value or value < 0 or value > 1 then
		return nil
	end
	return value
end

function Settings.Accent()
	if Settings.Get("accentSource") == "custom" then
		local color = Settings.Get("accentColor")
		local r, g, b = Channel(color.r), Channel(color.g), Channel(color.b)
		if r and g and b then
			return r, g, b
		end
	end
	return K.Theme.Accent()
end

function Settings.Font()
	local outline = Settings.Get("fontOutline")
	local path = Settings.Get("font")
	if K.Theme.FollowsKit(path) then
		path = Tokens.Font("number")
	end
	return path, Settings.Get("fontSize"), outline == "NONE" and "" or outline
end
