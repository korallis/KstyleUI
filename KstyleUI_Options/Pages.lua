-- Pages.lua: the settings window's pages, built from the registered schemas, the Layout elements, the profiles and the About text.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Model = ns.Model
local format, floor, lower = string.format, math.floor, string.lower

local Pages = {}
ns.Pages = Pages

Pages.WINDOW_KEY = "Options.Window"
Pages.GENERAL_SECTIONS = { "HudStyle", "Appearance", "Medallions", "Widgets", "ColorVision", "Integrations", "Setup", "OptionControls", "OptionsPresentation" }
Pages.ELEMENTS_SECTION = "Layout"
local APPLY_ON_RELEASE = { ["Appearance.uiScale"] = true }
local HIDDEN_MODULES = { Options = true, ProfileTools = true, LayoutControls = true }
local MODULE_ORDER = {
	"UnitFrames", "GroupFrames", "ActionBars", "Cooldowns", "Auras", "Nameplates", "CombatText",
	"Minimap", "Chat", "Bags", "Tooltips", "DataBars", "Meters", "Skins", "QoL",
}
local MODULE_LABELS = {
	Options = L["Settings"],
	Integrations = L["Existing addons"],
	UnitFrames = L["Unit Frames"],
	GroupFrames = L["Party and Raid"],
	ActionBars = L["Action Bars"],
	Cooldowns = L["Cooldowns"],
	Auras = L["Auras"],
	Nameplates = L["Nameplates"],
	CombatText = L["Combat Text"],
	Minimap = L["Minimap"],
	Chat = L["Chat"],
	Bags = L["Bags"],
	Tooltips = L["Tooltips"],
	DataBars = L["Data Bars"],
	Meters = L["Meters"],
	Skins = L["Window Skins"],
	QoL = L["Quality of Life"],
	Appearance = L["Appearance"],
	HudStyle = L["HUD style"],
	Readability = L["Readability"],
	Widgets = L["Widgets"],
	Layout = L["Layout"],
}

local ANCHORS = {
	{ value = "TOPLEFT", label = L["Top left"] },
	{ value = "TOP", label = L["Top"] },
	{ value = "TOPRIGHT", label = L["Top right"] },
	{ value = "LEFT", label = L["Left"] },
	{ value = "CENTER", label = L["Centre"] },
	{ value = "RIGHT", label = L["Right"] },
	{ value = "BOTTOMLEFT", label = L["Bottom left"] },
	{ value = "BOTTOM", label = L["Bottom"] },
	{ value = "BOTTOMRIGHT", label = L["Bottom right"] },
}
local SHOWN = {
	{ value = "always", label = L["Always"] },
	{ value = "combat", label = L["In combat only"] },
	{ value = "noCombat", label = L["Out of combat only"] },
	{ value = "party", label = L["In a party only"] },
	{ value = "raid", label = L["In a raid only"] },
	{ value = "solo", label = L["When solo only"] },
	{ value = "noParty", label = L["Not in a party"] },
	{ value = "noRaid", label = L["Not in a raid"] },
	{ value = "noSolo", label = L["In a group only"] },
	{ value = "target", label = L["With a target"] },
	{ value = "mouseover", label = L["On mouseover"] },
	{ value = "never", label = L["Never"] },
}
local STRATA = {
	{ value = "BACKGROUND", label = L["Background"] },
	{ value = "LOW", label = L["Low"] },
	{ value = "MEDIUM", label = L["Medium"] },
	{ value = "HIGH", label = L["High"] },
}
Pages.ANCHORS, Pages.SHOWN, Pages.STRATA = ANCHORS, SHOWN, STRATA

local ELEMENT_FIELDS = { "anchor", "x", "y", "width", "height", "scale", "shown", "alphaCombat", "alphaIdle", "strata" }
local FALLBACK = { anchor = "CENTER", x = 0, y = 0, scale = 1, shown = "always", alphaCombat = 1, alphaIdle = 1, strata = "MEDIUM" }
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 2, 0.05
local ALPHA_STEP = 0.05
local OWN_MIN_ALPHA = 0.25
local SIZE_MIN = 8
local ROOT_WIDTH, ROOT_HEIGHT = 1920, 1080

local function Whole(value)
	return tostring(floor(value + 0.5))
end

function Pages.ModuleLabel(name)
	local label = MODULE_LABELS[name]
	if label then
		return label
	end
	return (tostring(name):gsub("(%l)(%u)", "%1 %2"))
end

local function IsGeneral(name)
	for _, section in ipairs(Pages.GENERAL_SECTIONS) do
		if section == name then
			return true
		end
	end
	return false
end

local function LayoutFn(name)
	local layout = K.Layout
	if type(layout) == "table" and type(layout[name]) == "function" then
		return layout[name]
	end
	return nil
end

function Pages.HasLayout()
	return LayoutFn("Elements") ~= nil and LayoutFn("Get") ~= nil and LayoutFn("Set") ~= nil
end

function Pages.Elements(all)
	local elements = LayoutFn("Elements")
	if not elements then
		return {}
	end
	local ok, list = K.Call(elements)
	local out = {}
	if ok and type(list) == "table" then
		for _, element in ipairs(list) do
			if type(element) == "table" and type(element.key) == "string" and (all or element.live ~= false) then
				out[#out + 1] = element
			end
		end
	end
	return out
end

local function ElementSettings(key)
	local get = LayoutFn("Get")
	if not get then
		return nil
	end
	local ok, settings = pcall(get, key)
	if ok and type(settings) == "table" then
		return settings
	end
	return nil
end

function Pages.ResetElement(key)
	local reset = LayoutFn("Reset")
	if reset then
		K.Call(reset, key)
		return
	end
	local set = LayoutFn("Set")
	if not set then
		return
	end
	Model.Log("Layout.Reset is missing; clearing each field of " .. key .. " with Layout.Set")
	for _, field in ipairs(ELEMENT_FIELDS) do
		K.Call(set, key, field, nil)
	end
end

local function Choices(name, fallback)
	local layout = K.Layout
	local list = type(layout) == "table" and layout[name]
	if type(list) == "table" and #list > 0 then
		return list
	end
	return fallback
end

local function Limit(name, fallback)
	local layout = K.Layout
	local value = type(layout) == "table" and layout[name]
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function RootSize()
	local width, height
	local rootSize = LayoutFn("RootSize")
	if rootSize then
		local ok, w, h = pcall(rootSize)
		if ok then
			width, height = w, h
		end
	end
	if type(width) ~= "number" or type(height) ~= "number" then
		local root = K.Scale.Root()
		width, height = root:GetWidth(), root:GetHeight()
	end
	if type(width) ~= "number" or width <= 0 then
		width = ROOT_WIDTH
	end
	if type(height) ~= "number" or height <= 0 then
		height = ROOT_HEIGHT
	end
	return floor(width + 0.5), floor(height + 0.5)
end

function Pages.ElementItems(element, page, level)
	local key = element.key
	local opts = type(element.opts) == "table" and element.opts or {}
	local own = key == Pages.WINDOW_KEY
	local window = own or opts.window == true
	local allowed
	if type(opts.fields) == "table" then
		allowed = {}
		for _, field in ipairs(opts.fields) do
			allowed[field] = true
		end
	end
	local function has(field)
		return allowed == nil or allowed[field] == true
	end
	local items = {}
	local function add(item)
		item.page = page
		item.element = key
		item.defer = own or nil
		items[#items + 1] = item
		return item
	end
	local function get(field, fallback)
		return function()
			local settings = ElementSettings(key)
			local value = settings and settings[field]
			if value == nil then
				return fallback
			end
			return value
		end
	end
	local function set(field)
		return function(value)
			local fn = LayoutFn("Set")
			if fn then
				K.Call(fn, key, field, value)
			end
		end
	end
	local width, height = RootSize()
	local minAlpha = window and OWN_MIN_ALPHA or 0
	local function link(field)
		return function()
			local settings = ElementSettings(key)
			return settings and settings.link and settings.link[field]
		end, function(value)
			local settings = ElementSettings(key)
			local changed = Model.Copy(settings and settings.link or {})
			changed[field] = value ~= "" and value ~= 0 and value or nil
			set("link")(next(changed) and changed or nil)
		end
	end
	local function others(first)
		return function()
			local choices = { { value = "", label = first } }
			for _, target in ipairs(Pages.Elements()) do
				if target.key ~= key then choices[#choices + 1] = { value = target.key, label = target.label or target.key } end
			end
			return choices
		end
	end
	local function linkRow(item, field, fallback)
		local read, put = link(field)
		item.get, item.set = function() return read() or fallback end, put
		return add(item)
	end
	local function pointed()
		return link("point")() ~= nil
	end
	add({ kind = "header", level = level, label = element.label or opts.label or key })
	if not window and has("shown") then
		add({
			kind = "dropdown", label = L["Shown"], help = L["When the element shows."], options = Choices("SHOWN_OPTIONS", SHOWN),
			get = get("shown", FALLBACK.shown), set = set("shown"),
		})
	end
	if has("attachTo") then
		add({ kind = "dropdown", label = L["Attach to"], help = L["Follows another element. An unavailable element uses your saved place."],
			options = function()
				local choices = { { value = "", label = L["Not attached"] } }
				local can = LayoutFn("CanAttach")
				for _, target in ipairs(Pages.Elements()) do
					if target.key ~= key and (not can or can(key, target.key)) then
						choices[#choices + 1] = { value = target.key, label = target.label or target.key }
					end
				end
				return choices
			end, get = get("attachTo", ""), set = set("attachTo"),
		})
		add({ kind = "dropdown", label = L["Side"], help = L["Which side of the other element this one sits on."],
			options = LayoutFn("SideOptions"), get = get("side", "above"), set = set("side"), disableWhen = pointed })
		add({ kind = "slider", label = L["Offset"], help = L["The gap from the attached element, in interface units."],
			min = -height, max = height, step = 1, format = Whole, get = get("offset", 0), set = set("offset"), disableWhen = pointed })
		local points = { { value = "", label = L["Use Side"] } }
		for _, anchor in ipairs(Choices("ANCHOR_OPTIONS", ANCHORS)) do points[#points + 1] = anchor end
		linkRow({ kind = "dropdown", label = L["Point on this element"], options = points,
			help = L["Joins this point to a point on the other element instead of using Side."] }, "point", "")
		linkRow({ kind = "dropdown", label = L["Point on the other element"], options = Choices("ANCHOR_OPTIONS", ANCHORS),
			help = L["The point on the attached element that this element joins."], disableWhen = function() return not pointed() end }, "target", "CENTER")
		linkRow({ kind = "slider", label = L["Attached X offset"], min = -width, max = width, step = 1, format = Whole,
			help = L["Moves an attached element left or right of where it joins."] }, "x", 0)
		linkRow({ kind = "slider", label = L["Attached Y offset"], min = -height, max = height, step = 1, format = Whole,
			help = L["Moves an attached element down or up from where it joins."] }, "y", 0)
		if opts.resizable then
			add({ kind = "toggle", label = L["Match width"], help = L["Uses the other element's width within this element's size limits."],
				get = get("matchWidth", false), set = set("matchWidth") })
			add({ kind = "toggle", label = L["Match height"], help = L["Uses the other element's height within this element's size limits."],
				get = get("matchHeight", false), set = set("matchHeight") })
			add({ kind = "slider", label = L["Extra width"], min = -width, max = width, step = 1,
				help = L["Adds interface units to the matched width; zero matches exactly."],
				get = get("extraWidth", 0), set = set("extraWidth"), disableWhen = function() return not get("matchWidth", false)() end })
			add({ kind = "slider", label = L["Extra height"], min = -height, max = height, step = 1,
				help = L["Adds interface units to the matched height; zero matches exactly."],
				get = get("extraHeight", 0), set = set("extraHeight"), disableWhen = function() return not get("matchHeight", false)() end })
			linkRow({ kind = "dropdown", label = L["Match width of"], options = others(L["The attached element"]),
				help = L["Takes the width from this element, attached or not."], disableWhen = function() return not get("matchWidth", false)() end }, "width", "")
			linkRow({ kind = "dropdown", label = L["Match height of"], options = others(L["The attached element"]),
				help = L["Takes the height from this element, attached or not."], disableWhen = function() return not get("matchHeight", false)() end }, "height", "")
		end
	end
	if has("anchor") then
		add({
			kind = "dropdown", label = L["Anchor"], help = L["The point of the screen the element is placed from."], options = Choices("ANCHOR_OPTIONS", ANCHORS),
			get = get("anchor", FALLBACK.anchor), set = set("anchor"),
		})
	end
	if has("x") and not window then
		local snaps = others(L["Follow Snap while dragging"])
		linkRow({ kind = "dropdown", label = L["Snap"], help = L["Snap this element to everything, nothing or one element while dragging."],
			options = function()
				local choices = snaps()
				table.insert(choices, 2, { value = "none", label = L["Never"] })
				table.insert(choices, 3, { value = "all", label = L["Always"] })
				for i = 4, #choices do choices[i].label = format(L["Only to %s"], choices[i].label) end
				return choices
			end }, "snap", "")
	end
	if has("x") then
		add({
			kind = "slider", label = L["X offset"], help = L["Moves the element left or right from its anchor."],
			min = -width, max = width, step = 1, format = Whole, get = get("x", FALLBACK.x), set = set("x"),
		})
	end
	if has("y") then
		add({
			kind = "slider", label = L["Y offset"], help = L["Moves the element down or up from its anchor."],
			min = -height, max = height, step = 1, format = Whole, get = get("y", FALLBACK.y), set = set("y"),
		})
	end
	if opts.resizable then
		local minW, maxW = opts.minWidth or SIZE_MIN, opts.maxWidth or width
		local minH, maxH = opts.minHeight or SIZE_MIN, opts.maxHeight or height
		if minW < maxW and has("width") then
			add({
				kind = "slider", label = L["Width"], help = own and L["Settings window width in interface units; release the slider to apply."] or L["The element's width in interface units."],
				min = minW, max = maxW, step = 1, format = Whole, get = get("width", minW), set = set("width"),
			})
		end
		if minH < maxH and has("height") then
			add({
				kind = "slider", label = L["Height"], help = own and L["Settings window height in interface units; release the slider to apply."] or L["The element's height in interface units."],
				min = minH, max = maxH, step = 1, format = Whole, get = get("height", minH), set = set("height"),
			})
		end
	end
	if opts.scalable and has("scale") then
		add({
			kind = "slider", label = L["Scale"], help = own and L["Scales the entire settings window, including its text; release to apply."] or L["Makes the element larger or smaller."],
			min = Limit("SCALE_MIN", SCALE_MIN), max = Limit("SCALE_MAX", SCALE_MAX), step = Limit("SCALE_STEP", SCALE_STEP),
			percent = true, get = get("scale", FALLBACK.scale), set = set("scale"),
		})
	end
	if has("alphaCombat") then
		add({
			kind = "slider", label = L["Opacity in combat"], help = own and L["Settings window opacity during combat, with a 25 percent minimum."] or L["How solid the element is while you fight."],
			min = minAlpha, max = 1, step = ALPHA_STEP, percent = true, get = get("alphaCombat", FALLBACK.alphaCombat), set = set("alphaCombat"),
		})
	end
	if has("alphaIdle") then
		add({
			kind = "slider", label = L["Opacity out of combat"], help = own and L["Settings window opacity outside combat, with a 25 percent minimum."] or L["How solid the element is the rest of the time."],
			min = minAlpha, max = 1, step = ALPHA_STEP, percent = true, get = get("alphaIdle", FALLBACK.alphaIdle), set = set("alphaIdle"),
		})
	end
	if has("strata") then
		add({
			kind = "dropdown", label = L["Strata"], help = L["Which layer the element draws in, from back to front."], options = Choices("STRATA_OPTIONS", STRATA),
			get = get("strata", FALLBACK.strata), set = set("strata"),
		})
	end
	add({
		kind = "button", label = own and L["Reset window size and opacity"] or L["Reset this element"], help = own and L["Restores the settings window size, scale and opacity while keeping its position."] or L["Puts the element back where its module placed it."],
		buttons = {
			{
				label = L["Reset"],
				onClick = function()
					if own then
						for _, field in ipairs({ "width", "height", "scale", "alphaCombat", "alphaIdle" }) do set(field)(nil) end
					else Pages.ResetElement(key) end
				end,
			},
		},
	})
	return items
end

local function ElementsOf(module, all)
	local out = {}
	for _, element in ipairs(Pages.Elements(all)) do
		if module == nil or element.module == module then
			out[#out + 1] = element
		end
	end
	return out
end

local function ElementSection(items, module, page)
	local elements = ElementsOf(module)
	if #elements == 0 then
		return
	end
	items[#items + 1] = { kind = "header", level = 1, label = L["Positions and sizes"], page = page }
	for _, element in ipairs(elements) do
		for _, item in ipairs(Pages.ElementItems(element, page, 2)) do
			if module == "ActionBars" then
				local key = element.key == "consumables.bar" and "consumables" or element.key:match("^actionbars%.(.+)$")
				if key then item.showWhen = function()
					local settings = K.Store.Module(module)
					return settings.editBar == key and settings[key] and settings[key].enabled
				end end
			end
			items[#items + 1] = item
		end
	end
end

local function Append(items, more)
	for _, item in ipairs(more) do
		items[#items + 1] = item
	end
end

local function NoLayoutNote(items, page)
	if not Pages.HasLayout() then
		items[#items + 1] = { kind = "note", label = L["Layout Mode is not available yet, so elements cannot be placed here."], page = page }
	end
end

local NONE = ""

local function OtherProfiles(placeholder)
	return function()
		local out = { { value = NONE, label = placeholder } }
		local active = K.Store.ProfileName()
		for _, name in ipairs(K.Store.ListProfiles()) do
			if name ~= active then
				out[#out + 1] = { value = name, label = name }
			end
		end
		return out
	end
end

local function GeneralItems()
	local items = {}
	for _, section in ipairs(Pages.GENERAL_SECTIONS) do
		local schema = K.Options.Get(section)
		if schema then
			Append(items, Model.SchemaItems(section, schema, "General"))
		end
	end
	for _, item in ipairs(items) do
		if item.module == "Widgets" and item.key == "ornaments" and K.Store.Module("OptionsPresentation").samples then
			item.kind = "ornaments"
		end
		if item.module and item.key and APPLY_ON_RELEASE[item.module .. "." .. item.key] then
			item.defer = true
		end
	end
	local function account(key, default, apply)
		return function()
			local value = K.Store.Account()[key]
			if value == nil then return default end
			return value
		end, function(value)
			K.Store.Account()[key] = value
			if apply == true then K.Appearance.ApplyGameText() elseif apply then apply() end
			ns.Changed()
		end
	end
	for i, item in ipairs(items) do
		if item.module == "Appearance" and item.key == "paletteDarken" then
			local function confirm(text, run)
				K.Widgets.Confirm({ title = L["Class and power colours"], text = text, acceptLabel = L["Apply"], onAccept = function() run(); ns.Changed() end })
			end
			table.insert(items, i + 1, { kind = "button", page = "General", label = L["Use these colours in every profile"],
				help = L["Copies these class and power colours to all your other profiles."], buttons = { { label = L["Apply"], onClick = function()
					confirm(L["Copy these class and power colours to every other profile?"], function() K.Appearance.CopyPalette(K.Store.ProfileName()) end)
				end } } })
			table.insert(items, i + 2, { kind = "dropdown", page = "General", label = L["Copy colours from"],
				help = L["Takes the class and power colours from another profile."], get = function() return NONE end,
				options = OtherProfiles(L["Choose a profile"]), set = function(name)
					if name == NONE then return end
					confirm(format(L["Copy the class and power colours from %s?"], name), function() K.Appearance.CopyPalette(name, K.Store.ProfileName()) end)
				end })
			break
		end
	end
	local function add(item, key, default, apply)
		item.kind, item.page = item.kind or "toggle", "General"
		if key then item.get, item.set = account(key, default, apply) end
		items[#items + 1] = item
	end
	add({ kind = "header", level = 1, label = L["Game text"] })
	add({ label = L["Use your font for game text"], help = L["Blizzard windows and quest text use your font; names in the world follow after relogging."] }, "gameFont", false, true)
	add({ kind = "slider", label = L["Game text size"], min = 0.8, max = 1.5, step = 0.05, percent = true, defer = true,
		help = L["Makes Blizzard's own text larger or smaller; 100 percent keeps the game's sizes."] }, "gameTextScale", 1, true)
	add({ label = L["Use your number font for combat text"], help = L["Damage and healing numbers in the world use your number font after relogging."] }, "combatFont", false, true)
	add({ label = L["Use your names font for names in the world"], help = L["Names over characters use the Names font after relogging; other game text keeps its font."] }, "nameFont", false, true)
	add({ kind = "slider", label = L["Combat text size"], min = 0.8, max = 1.5, step = 0.05, percent = true, defer = true,
		help = L["Makes the game's combat text beside your character larger or smaller."] }, "combatTextScale", 1, true)
	add({ kind = "header", level = 1, label = L["Window conveniences"] })
	add({ label = L["Search current page only"], help = L["Searches this page only. Off searches every settings page."] }, "optionsSearchPage", false)
	add({ label = L["List page sections in the rail"], help = L["Shows the open page's sections; right-click a page to fold them. Off lists pages only."] }, "optionsRailSections", true)
	add({ label = L["Remember search picks"], help = L["Settings you change from search results are listed first in later searches."] }, "optionsSearchMemory", false)
	add({ kind = "button", label = L["Clear search picks"], help = L["Forgets the settings remembered from your searches."],
		buttons = { { label = L["Clear"], onClick = function() K.Store.Account().optionsSearchPicks = nil; ns.Changed() end } } })
	add({ label = L["Double-click the header to fold"], help = L["Double-click the window's header to fold it to its header; again to open it."] }, "optionsFold", false)
	add({ kind = "header", level = 1, label = L["Game menu"] })
	add({ label = L["KstyleUI settings button"], help = L["Adds a button under the game menu that opens these settings."] }, "gameMenuOptions", false, function() K.OptionsEntry.GameMenu() end)
	add({ label = L["Layout Mode button"], help = L["Adds a button under the game menu that opens Layout Mode."] }, "gameMenuLayout", false, function() K.OptionsEntry.GameMenu() end)
	for _, element in ipairs(Pages.Elements(true)) do
		if element.key == Pages.WINDOW_KEY then
			element.label = L["Window size and opacity"]
			element.opts.fields = { "width", "height", "scale", "alphaCombat", "alphaIdle" }
			Append(items, Pages.ElementItems(element, "General", 1))
		end
	end
	items[#items + 1] = { kind = "header", level = 1, page = "General", label = L["Text preset"] }
	items[#items + 1] = {
		kind = "dropdown", page = "General", module = "Readability", key = "preset", label = L["Text preset"], help = L["Readable grows text and its rows; Standard restores the usual sizes."],
		options = { { value = "Standard", label = L["Standard"] }, { value = "Readable", label = L["Readable"] } },
		get = function() return K.Store.Module("Readability").preset end, set = K.Profiles.Readable,
	}
	if K.Store.Module("Integrations").notices then
		items[#items + 1] = { kind = "note", page = "General", label = L["BigWigs and DBM are not skinned; tested addon versions: none, pending a verified Forever API."] }
	end
	return items
end

local function ResetGeneral()
	local account = K.Store.Account()
	account.optionsSearchPage, account.optionsRailSections, account.gameFont, account.gameTextScale, account.combatFont = nil, nil, nil, nil, nil
	account.nameFont, account.combatTextScale, account.optionsSearchMemory, account.optionsFold = nil, nil, nil, nil
	account.gameMenuOptions, account.gameMenuLayout, account.optionsRailFolded = nil, nil, nil
	K.Appearance.ApplyGameText()
	K.OptionsEntry.GameMenu()
	for _, section in ipairs(Pages.GENERAL_SECTIONS) do
		Model.ResetSchema(section, K.Options.Get(section))
	end
	K.Profiles.Readable("Standard")
end

local function ElementsItems()
	local items = {}
	local schema = K.Options.Get(Pages.ELEMENTS_SECTION)
	if schema then
		Append(items, Model.SchemaItems(Pages.ELEMENTS_SECTION, schema, "Elements"))
	end
	Append(items, Model.SchemaItems("LayoutControls", K.Options.Get("LayoutControls"), "Elements"))
	items[#items + 1] = { kind = "toggle", page = "Elements", label = L["Double-click movers for settings"],
		help = L["Opens element settings on double-click. Action bars keep their own shortcut setting."],
		get = function() return K.Store.Account().moverOptions ~= false end,
		set = function(value) K.Store.Account().moverOptions = value; ns.Changed() end }
	items[#items + 1] = { kind = "toggle", page = "Elements", label = L["Light the grid around the pointer"],
		help = L["While you drag, grid lines near the pointer brighten. Off keeps the grid even."],
		get = function() return K.Store.Account().layoutGridLight == true end,
		set = function(value) K.Store.Account().layoutGridLight = value or nil; ns.Changed() end }
	items[#items + 1] = { kind = "toggle", page = "Elements", label = L["Fade the toolbar until pointed at"],
		help = L["The Layout Mode toolbar rests at 25 percent until pointed at; hold Shift to hide it."],
		get = function() return K.Store.Account().layoutToolbarHover == true end,
		set = function(value) K.Store.Account().layoutToolbarHover = value; ns.Changed() end }
	NoLayoutNote(items, "Elements")
	local byModule, order = {}, {}
	for _, element in ipairs(Pages.Elements()) do
		local module = element.module or "Other"
		if not byModule[module] then
			byModule[module] = {}
			order[#order + 1] = module
		end
		local list = byModule[module]
		list[#list + 1] = element
	end
	for _, module in ipairs(order) do
		items[#items + 1] = { kind = "header", level = 1, label = Pages.ModuleLabel(module), page = "Elements" }
		for _, element in ipairs(byModule[module]) do
			Append(items, Pages.ElementItems(element, "Elements", 2))
		end
	end
	if #order == 0 and Pages.HasLayout() then
		items[#items + 1] = { kind = "note", label = L["No element has registered with Layout Mode yet."], page = "Elements" }
	end
	return items
end

local function ResetElements(module)
	local all = LayoutFn("ResetAll")
	if module == nil then K.Store.Account().layoutToolbarHover, K.Store.Account().layoutGridLight = nil, nil end
	if module == nil and all then
		K.Call(all)
		return
	end
	for _, element in ipairs(ElementsOf(module, true)) do
		Pages.ResetElement(element.key)
	end
end

local function HasKey(schema, key)
	for _, row in ipairs(schema or {}) do
		if row.key == key then
			return true
		end
	end
	return false
end

local function SharesTitle(schema, label)
	local first = type(schema) == "table" and schema[1]
	return type(first) == "table" and first.type == "header" and (first.level or 1) == 1
		and first.showWhen == nil and first.disableWhen == nil
		and type(first.label) == "string" and lower(first.label) == lower(tostring(label))
end

local function ModuleItems(page)
	local module = page.module
	local items = {}
	local schema = K.Options.Get(module)
	local defaults = K.Store.Defaults(module)
	local titled = false
	if K.Features.modules[module] ~= nil and defaults and not HasKey(schema, "enabled") then
		local label = Pages.ModuleLabel(module)
		titled = SharesTitle(schema, label)
		items[#items + 1] = { kind = "header", level = 1, label = label, page = page.id }
		items[#items + 1] = {
			kind = "toggle", label = format(L["Enable %s"], label), help = L["Turns this module on or off."],
			page = page.id, module = module, key = "enabled",
			get = function()
				return K.Modules.IsEnabled(module)
			end,
			set = function(value)
				K.Options.Write(module, "enabled", value)
			end,
		}
	end
	if schema then
		local rows = Model.SchemaItems(module, schema, page.id)
		if titled then
			table.remove(rows, 1)
		end
		for _, item in ipairs(rows) do
			if module == "ActionBars" and item.kind == "header" and item.label == L["Slab and cooldowns"] then ElementSection(items, module, page.id) end
			items[#items + 1] = item
		end
	end
	if module ~= "ActionBars" then ElementSection(items, module, page.id) end
	if module == "ActionBars" and K.Store.Module("ActionBars").bindingHints ~= false then
		table.insert(items, 2, { kind = "button", page = page.id, label = L["Bind keys"],
			help = L["Hover a button and press a key; Save keeps the bindings."],
			buttons = { { label = L["Bind keys"], onClick = K.Options.BindKeys } } })
	end
	return items
end

local function ResetModule(page)
	Model.ResetSchema(page.module, K.Options.Get(page.module))
	ResetElements(page.module)
end

local function Notify(title, text)
	K.Widgets.Popup({ title = title, text = text })
end

local function Report(ok, err, done)
	ns.Changed()
	if ok then
		if done then
			K.Print(done)
		end
	else
		Notify(L["That did not work"], tostring(err))
	end
	return ok
end

local function AskName(title, text, initial, onName, placeholder)
	K.Widgets.Popup({
		title = title,
		text = text,
		editBox = { text = initial or "", placeholder = placeholder or L["Profile name"], maxLetters = 48 },
		buttons = {
			{ label = L["Cancel"] },
			{
				label = L["OK"], primary = true,
				onClick = function(handle)
					onName(handle:GetText())
				end,
			},
		},
	})
end

local function AllProfiles()
	local out = {}
	for _, name in ipairs(K.Store.ListProfiles()) do
		out[#out + 1] = { value = name, label = name }
	end
	return out
end

local function ShareScope()
	return Pages.shareScope == "modules" and (Pages.shareModules or {}) or Pages.shareScope or "everything"
end

local function ShareModules()
	local modules = {}
	for _, name in ipairs({ "Appearance", "Widgets", "HudStyle", "Readability" }) do
		if K.Store.Defaults(name) then modules[#modules + 1] = name end
	end
	for _, name in ipairs(K.Modules.List()) do
		if name ~= "Options" then modules[#modules + 1] = name end
	end
	return modules
end

local function SelectLater(handle)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			C_Timer.After(0, function()
				if handle:IsShown() and handle.editBox then
					handle.editBox:HighlightText()
				end
			end)
		end)
	end
end

local function Extras()
	return { specs = Pages.shareSpecs == true, editMode = Pages.shareEditMode == true }
end

function Pages.ExportProfile()
	local text, why = K.Profiles.Export(ShareScope(), Pages.includeLayout ~= false, Extras())
	if not text then
		Notify(L["Export failed"], tostring(why))
		return nil
	end
	SelectLater(K.Widgets.Popup({
		title = L["Export profile"],
		text = L["Press Ctrl+C to copy this string, then share it."],
		editBox = { text = text },
		buttons = { { label = L["Close"], primary = true } },
	}))
	return text
end

function Pages.ImportProfile(text, name)
	local ok, result = K.Store.Import(text, name, Extras())
	ns.Changed()
	if ok then
		Notify(L["Profile imported"], format(L["Imported the profile as %s. This character now uses it."], tostring(result)))
	else
		Notify(L["Import failed"], tostring(result))
	end
	return ok, result
end

function Pages.ReviewImport(text)
	if type(text) == "string" and text:match("^%s*KSA1:") then
		K.Widgets.Confirm({ title = L["Import profile"], text = L["Add every profile in this string and its character choices? Your other profiles stay."],
			acceptLabel = L["Import"], onAccept = function() Report(K.Profiles.ImportAccount(text:match("^%s*(.-)%s*$"))) end })
		return true
	end
	if not K.Store.Module("ProfileTools").review then return Pages.ImportProfile(text) end
	local preview, why = K.Profiles.Preview(text, ShareScope(), Pages.includeLayout ~= false, Extras())
	if not preview then Notify(L["Import failed"], tostring(why)); return false, why end
	local message = K.Store.Module("ProfileTools").backups and L["Will change: %s. A Before import backup will be saved."] or L["Will change: %s."]
	local labels = {}
	for _, module in ipairs(preview.changes) do labels[#labels + 1] = Pages.ModuleLabel(module) end
	message = format(message, #labels > 0 and table.concat(labels, ", ") or L["No changes"])
	if preview.warning then message = message .. "\n\n" .. preview.warning end
	K.Widgets.Popup({ title = L["Review import"], text = message,
		editBox = { placeholder = L["Profile name (optional)"], maxLetters = 48 }, buttons = {
			{ label = L["Cancel"] }, { label = L["Apply"], primary = true, onClick = function(handle)
				local name = handle:GetText():match("^%s*(.-)%s*$")
				Pages.ImportProfile(preview.text, name ~= "" and name or nil)
			end },
		} })
	return true, preview
end

local function ProfileItems()
	local items = {}
	local store = K.Store
	local page = "Profiles"
	local function add(item)
		item.page = page
		items[#items + 1] = item
	end
	if not store.IsLoaded() then
		add({ kind = "note", label = L["KstyleUI has not loaded its saved settings yet."] })
		return items
	end
	add({ kind = "header", level = 1, label = L["Active profile"] })
	add({
		kind = "toggle", label = L["Use a profile per specialization"],
		help = L["Switch profiles with your spec after combat; without specs, use your assigned role."],
		get = K.Specialization.Enabled, set = K.Specialization.SetEnabled,
	})
	add({ kind = "note", label = L["Every specialization starts on your current profile. Pick another profile to customize it."] })
	local function LayoutChoices()
		local choices, names = { { value = "", label = L["Profile's layout"] } }, {}
		for name in pairs(K.Profiles.Layouts()) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do choices[#choices + 1] = { value = name, label = name } end
		return choices
	end
	for _, choice in ipairs(K.Specialization.Choices()) do
		local key = choice.key
		add({
			kind = "dropdown", label = choice.label, options = AllProfiles,
			help = L["The profile for this specialization or assigned role. Changes wait until combat ends."],
			disableWhen = function() return not K.Specialization.Enabled() end,
			get = function() return K.Specialization.Profile(key) end,
			set = function(name) K.Specialization.Assign(key, name) end,
		})
		add({ kind = "dropdown", label = format(L["%s layout"], choice.label), options = LayoutChoices,
			help = L["Positions only. Every other setting stays with the profile. Changes wait until combat ends."],
			disableWhen = function() return not K.Specialization.Enabled() end,
			get = function() return K.Specialization.Layout(key) end,
			set = function(name) Report(K.Specialization.AssignLayout(key, name)) end })
	end
	add({ kind = "button", label = L["Save layout"], help = L["Save the current element positions under a name, then choose it for a specialization."],
		buttons = { { label = L["Save"], onClick = function()
			AskName(L["Save layout"], L["Name the layout."], "", function(name) Report(K.Profiles.SaveLayout(name)) end, L["Layout name"])
		end } } })
	add({ kind = "dropdown", label = L["Delete layout"], help = L["Specializations using a deleted layout return to their profile's layout."],
		options = function()
			local choices = LayoutChoices()
			choices[1].label = L["Saved layouts"]
			return choices
		end, get = function() return "" end,
		set = function(name)
			if name == "" then return end
			K.Widgets.Confirm({ title = L["Delete layout"], text = format(L["Delete the saved layout %s?"], name),
				acceptLabel = L["Delete"], onAccept = function() Report(K.Profiles.DeleteLayout(name)) end })
		end })
	add({
		kind = "dropdown", label = L["Profile"], help = L["The profile this character uses."], options = AllProfiles,
		get = store.ProfileName,
		set = function(name)
			Report(store.SetProfile(name))
		end,
	})
	add({
		kind = "button", label = L["New profile"], help = L["Creates a profile with the default settings and switches to it."],
		buttons = { {
			label = L["New"],
			onClick = function()
				AskName(L["New profile"], L["Name the new profile."], "", function(name)
					local ok, result = store.CreateProfile(name)
					if Report(ok, result) then
						Report(store.SetProfile(result))
					end
				end)
			end,
		} },
	})
	add({ kind = "dropdown", label = L["New profile from a preset"], help = L["Creates a profile from a role and HUD style preset, then switches to it."],
		options = function()
			local choices = K.Profiles.Presets()
			table.insert(choices, 1, { value = NONE, label = L["Choose a preset."] })
			return choices
		end, get = function() return NONE end,
		set = function(preset)
			if preset == NONE then return end
			local label = preset
			for _, choice in ipairs(K.Profiles.Presets()) do if choice.value == preset then label = choice.label end end
			AskName(L["New profile"], L["Name the new profile."], label, function(name) Report(K.Profiles.FromPreset(preset, name)) end)
		end })
	add({
		kind = "dropdown", label = L["Copy from"], help = L["Copies another profile's settings and layout into this one."],
		options = OtherProfiles(L["Choose a profile"]),
		get = function()
			return NONE
		end,
		set = function(name)
			if name == NONE then
				return
			end
			K.Widgets.Confirm({
				title = L["Copy profile"],
				text = format(L["Copy %s into %s? This replaces its settings and layout."], name, tostring(store.ProfileName())),
				acceptLabel = L["Copy"],
				onAccept = function()
					Report(store.CopyProfile(name, store.ProfileName()))
				end,
			})
		end,
	})
	add({
		kind = "button", label = L["Rename"], help = L["Renames the active profile."],
		buttons = { {
			label = L["Rename"],
			onClick = function()
				AskName(L["Rename profile"], L["Choose a new name for the active profile."], store.ProfileName(), function(name)
					Report(store.RenameProfile(store.ProfileName(), name))
				end)
			end,
		} },
	})
	add({
		kind = "dropdown", label = L["Delete"], help = L["Deletes another profile. The active one cannot be deleted."],
		options = OtherProfiles(L["Choose a profile"]),
		get = function()
			return NONE
		end,
		set = function(name)
			if name == NONE then
				return
			end
			K.Widgets.Confirm({
				title = L["Delete profile"],
				text = format(L["Delete the profile %s? This cannot be undone."], name),
				acceptLabel = L["Delete"],
				onAccept = function()
					Report(store.DeleteProfile(name))
				end,
			})
		end,
	})
	add({
		kind = "button", label = L["Reset profile"], help = L["Puts every setting and position of this profile back to the defaults."],
		buttons = { {
			label = L["Reset"],
			onClick = function()
				K.Widgets.Confirm({
					title = L["Reset profile"],
					text = format(store.Module("ProfileTools").backups and L["Reset %s to the defaults? A Before reset backup will be saved."] or L["Reset %s to the defaults? This cannot be undone."], tostring(store.ProfileName())),
					acceptLabel = L["Reset"],
					onAccept = function()
						Report(store.ResetProfile())
					end,
				})
			end,
		} },
	})
	Append(items, Model.SchemaItems("ProfileTools", K.Options.Get("ProfileTools"), "Profiles"))
	add({ kind = "header", level = 1, label = L["Share"] })
	local scopes = { { value = "everything", label = L["Everything"] }, { value = "layout", label = L["Layout only"] },
		{ value = "modules", label = L["Selected modules"] } }
	for _, name in ipairs(ShareModules()) do
		scopes[#scopes + 1] = { value = name, label = Pages.ModuleLabel(name) }
	end
	if K.Store.Module("ProfileTools").review then
	add({ kind = "dropdown", label = L["Share scope"], help = L["Share everything, a layout, or selected modules; imports keep the other settings."], options = scopes,
		get = function() return Pages.shareScope or "everything" end, set = function(value) Pages.shareScope = value end })
	if Pages.shareScope == "modules" then
		Pages.shareModules = Pages.shareModules or {}
		add({ kind = "button", label = L["Selected modules"], buttons = {
			{ label = L["Select all"], onClick = function()
				for _, name in ipairs(ShareModules()) do Pages.shareModules[name] = true end
			end },
			{ label = L["Clear"], onClick = function() Pages.shareModules = {} end },
		} })
		for _, name in ipairs(ShareModules()) do
			local module = name
			add({ kind = "toggle", label = Pages.ModuleLabel(module), help = L["Include this module when sharing selected modules."],
				get = function() return Pages.shareModules[module] == true end,
				set = function(on) Pages.shareModules[module] = on end })
		end
	end
	end
	if K.Store.Module("ProfileTools").review then
	add({ kind = "toggle", label = L["Include layout"], help = L["Share element positions and saved layouts with the profile. Off shares settings only."],
		get = function() return Pages.includeLayout ~= false end, set = function(value) Pages.includeLayout = value end,
		disableWhen = function() return Pages.shareScope ~= nil and Pages.shareScope ~= "everything" and Pages.shareScope ~= "modules" end })
	add({ kind = "toggle", label = L["Include specialization assignments"], help = L["Shares which specializations use this profile; imports assign them again."],
		get = function() return Pages.shareSpecs == true end, set = function(value) Pages.shareSpecs = value end })
	add({ kind = "toggle", label = L["Include Edit Mode layout"], help = L["Shares your active Edit Mode layout; imports add it after combat and switch to it."],
		get = function() return Pages.shareEditMode == true end, set = function(value) Pages.shareEditMode = value end })
	end
	if K.Store.Module("ProfileTools").backups then
	add({ kind = "button", label = L["Restore backup"], help = K.Store.Account().restoreProfile or L["No backup is available."],
		disabled = K.Store.Account().restoreProfile == nil, buttons = { { label = L["Restore"], onClick = function() Report(K.Profiles.Restore()) end } } })
	end
	add({
		kind = "button", label = L["Export"], help = L["Shows this profile as a string you can copy and share."],
		buttons = { { label = L["Export"], onClick = Pages.ExportProfile } },
	})
	add({ kind = "button", label = L["Export every profile"], help = L["Shows all your profiles and character choices as one string to copy."],
		buttons = { { label = L["Export"], onClick = function()
			local text, why = K.Profiles.ExportAccount()
			if not text then return Notify(L["Export failed"], tostring(why)) end
			SelectLater(K.Widgets.Popup({ title = L["Export every profile"], text = L["Press Ctrl+C to copy this string, then share it."],
				editBox = { text = text }, buttons = { { label = L["Close"], primary = true } } }))
		end } } })
	add({
		kind = "button", label = L["Import"], help = L["Adds a profile from a string, then switches this character to it."],
		buttons = { {
			label = L["Import"],
			onClick = function()
				K.Widgets.Popup({
					title = L["Import profile"],
					text = L["Paste a KstyleUI profile string."],
					editBox = { placeholder = "KSUI1:" },
					buttons = {
						{ label = L["Cancel"] },
						{
							label = L["Import"], primary = true,
							onClick = function(handle)
								Pages.ReviewImport(handle:GetText())
							end,
						},
					},
				})
			end,
		} },
	})
	add({ kind = "header", level = 1, label = L["Profile hotkeys"] })
	add({ kind = "note", label = L["Bind each hotkey under KstyleUI in the game's Key Bindings; it switches after combat."] })
	for i = 1, K.Profiles.HOTKEYS do
		local binding = type(GetBindingKey) == "function" and GetBindingKey("CLICK KstyleUI_Profile" .. i .. ":LeftButton")
		add({ kind = "dropdown", label = format(L["Switch to profile hotkey %d"], i), help = type(binding) == "string" and binding or L["Not bound"],
			options = function()
				local choices = AllProfiles()
				table.insert(choices, 1, { value = NONE, label = L["None"] })
				return choices
			end, get = function() return K.Profiles.Hotkey(i) end, set = function(name) K.Profiles.SetHotkey(i, name); ns.Changed() end })
	end
	add({ kind = "header", level = 1, label = L["Characters"] })
	local characters = store.Characters()
	local keys = {}
	for key in pairs(characters) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local me = store.CharacterKey and store.CharacterKey()
	for _, key in ipairs(keys) do
		add({
			kind = "dropdown", label = key,
			help = key == me and L["This character. Choosing a profile switches to it now."] or L["Switches at that character's next login."],
			options = AllProfiles,
			get = function()
				return store.Characters()[key]
			end,
			set = function(name)
				Report(store.AssignCharacter(key, name))
			end,
		})
	end
	return items
end

local COMMANDS = {
	{ "/kstyle", L["open the settings"] },
	{ "/kstyle layout", L["enter or leave Layout Mode"] },
	{ "/kstyle setup", L["run the first-run setup again"] },
	{ "/kstyle test", L["run the smoke checks and write the devlog"] },
	{ "/kstyle profile", L["list and manage profiles"] },
}

local function Version()
	local version = K.VERSION
	if type(version) ~= "string" or version:find("^@") then
		return L["development build"]
	end
	return version
end

local cpuTicker
function Pages.Cpu(metric)
	local api = type(C_AddOnProfiler) == "table" and C_AddOnProfiler or {}
	local enabled, on = pcall(api.IsEnabled)
	if not (enabled and on == true and type(api.GetAddOnMetric) == "function") then
		return L["The game's addon profiler is off, so there is no CPU readout."]
	end
	local total, names = 0, { KstyleUI = true, KstyleUI_Options = true }
	for _, name in ipairs(K.Modules.List()) do names["KstyleUI_" .. name] = true end
	for name in pairs(names) do
		local ok, value = pcall(api.GetAddOnMetric, name, metric)
		if ok and type(value) == "number" and not K.Widgets.IsSecret(value) then total = total + value end
	end
	if not cpuTicker and C_Timer and C_Timer.NewTicker then
		cpuTicker = C_Timer.NewTicker(1, function()
			local win = ns.Window.Frame()
			if win and win:IsShown() and ns.Window.State().page == "About" and K.Store.Account().optionsCpuMetric then return ns.Changed() end
			cpuTicker:Cancel()
			cpuTicker = nil
		end)
	end
	return format(L["KstyleUI: %.2f ms"], total)
end

local function AboutItems()
	local items = {}
	local function add(item)
		item.page = "About"
		items[#items + 1] = item
	end
	add({ kind = "header", level = 1, label = "KstyleUI" })
	add({ kind = "note", label = format(L["Version %s"], Version()) })
	add({ kind = "note", label = L["A complete interface for World of Warcraft: Forever, by korallis. All rights reserved."] })
	add({ kind = "header", level = 1, label = L["Commands"] })
	for _, command in ipairs(COMMANDS) do
		add({ kind = "note", label = command[1] .. " - " .. command[2] })
	end
	add({ kind = "header", level = 1, label = L["Tools"] })
	add({
		kind = "button", label = L["Smoke checks"], help = L["Runs /kstyle test and writes the results to the devlog."],
		buttons = { {
			label = L["Run"],
			onClick = function()
				K.Call(K.DevTest.Run)
			end,
		} },
	})
	local setup = K.Setup
	add({
		kind = "button", label = L["First-run setup"], help = L["Opens the setup again to pick a layout and modules."],
		disabled = not (type(setup) == "table" and type(setup.Open) == "function"),
		buttons = { {
			label = L["Open"],
			onClick = function()
				local s = K.Setup
				if type(s) == "table" and type(s.Open) == "function" then
					K.Call(s.Open)
				end
			end,
		} },
	})
	add({
		kind = "button", label = L["What's new"], help = L["Shows the link to every version's release notes, ready to copy."],
		buttons = { { label = L["Show"], onClick = function()
			SelectLater(K.Widgets.Popup({ title = L["What's new"], text = L["Press Ctrl+C to copy this link, then open it in your browser."],
				editBox = { text = "https://github.com/korallis/KstyleUI/releases" }, buttons = { { label = L["Close"], primary = true } } }))
		end } },
	})
	local metrics = { { value = "", label = L["Off"] }, { value = 0, label = L["Session average"] }, { value = 1, label = L["Recent average"] },
		{ value = 2, label = L["Encounter average"] }, { value = 3, label = L["Last frame"] } }
	add({ kind = "dropdown", label = L["CPU readout"], help = L["Shows how long KstyleUI takes each frame, refreshed while this page is open."], options = metrics,
		get = function() return K.Store.Account().optionsCpuMetric or "" end,
		set = function(value) K.Store.Account().optionsCpuMetric = value ~= "" and value or nil; ns.Changed() end })
	local metric = K.Store.Account().optionsCpuMetric
	if metric then add({ kind = "note", label = Pages.Cpu(metric) }) end
	add({ kind = "header", level = 1, label = L["Credits"] })
	add({ kind = "note", label = L["Fonts: Source Sans 3 and Inter, under the SIL Open Font Licence."] })
	return items
end

local function ModuleNames()
	local seen, names = {}, {}
	local function add(name)
		if not seen[name] and not HIDDEN_MODULES[name] and not IsGeneral(name) and name ~= Pages.ELEMENTS_SECTION then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	local registered = {}
	for _, name in ipairs(K.Options.List()) do
		registered[name] = true
	end
	for _, name in ipairs(K.Modules.List()) do
		registered[name] = true
	end
	for _, name in ipairs(MODULE_ORDER) do
		if registered[name] then
			add(name)
		end
	end
	local rest = {}
	for name in pairs(registered) do
		rest[#rest + 1] = name
	end
	table.sort(rest)
	for _, name in ipairs(rest) do
		add(name)
	end
	return names
end

local function GeneralPreview(section)
	local cfg = K.Store.Module("Integrations")
	if section == L["Existing addons"] and (cfg.timerLane or cfg.announcementLane) then return K.Setup.Integrations.Preview end
	return ns.Preview and ns.Preview.Sample
end

Pages.TASKS = {
	{ label = L["Change HUD"], help = L["Choose Frames, Orbs or Medallions."], page = "General", module = "HudStyle", key = "style" },
	{ label = L["Choose role"], help = L["Open setup to choose a damage, tank or healer layout."], page = "About", labelTarget = L["First-run setup"] },
	{ label = L["Readable text"], help = L["Grow text and its rows with the Readable preset."], page = "General", module = "Readability", key = "preset" },
	{ label = L["Bind keys"], help = L["Open Action Bars to assign your keybinds."], page = "ActionBars", labelTarget = L["Bind keys"] },
	{ label = L["Healing clicks"], help = L["Find the click casting settings for party and raid frames."], page = "GroupFrames", module = "GroupFrames", key = "clickCast.hint" },
	{ label = L["Existing addons"], help = L["Choose how KstyleUI works with your other addons."], page = "General", module = "Integrations", key = "notices" },
}

local function TasksItems()
	local items = {}
	for _, task in ipairs(Pages.TASKS) do
		items[#items + 1] = { kind = "task", label = task.label, help = task.help, page = "Tasks", onClick = function() ns.Window.Jump(task) end }
	end
	return items
end

function Pages.List()
	local pages = {
		{ id = "General", label = L["General"], Items = GeneralItems, reset = ResetGeneral, builtinPreview = GeneralPreview },
		{
			id = "Elements", label = L["Elements"], Items = ElementsItems,
			reset = function()
				ResetElements(nil)
			end,
		},
	}
	if K.Store.Module("OptionsPresentation").tasks then
		table.insert(pages, 1, { id = "Tasks", label = L["Tasks"], Items = TasksItems, builtinPreview = function() return ns.Preview.Sample end })
	end
	for _, module in ipairs(ModuleNames()) do
		pages[#pages + 1] = { id = module, module = module, label = Pages.ModuleLabel(module), Items = ModuleItems, reset = ResetModule }
	end
	pages[#pages + 1] = { id = "Profiles", label = L["Profiles"], Items = ProfileItems }
	pages[#pages + 1] = { id = "About", label = L["About"], Items = AboutItems }
	return pages
end

function Pages.Find(pages, id)
	if type(id) ~= "string" then
		return nil
	end
	local wanted = id:lower()
	for _, page in ipairs(pages) do
		if page.id:lower() == wanted then
			return page
		end
	end
	for _, page in ipairs(pages) do
		for _, section in ipairs(Pages.GENERAL_SECTIONS) do
			if page.id == "General" and section:lower() == wanted then
				return page
			end
		end
	end
	return nil
end
