-- Pages.lua: the settings window's pages, built from the registered schemas, the Layout elements, the profiles and the About text.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Model = ns.Model
local format, floor = string.format, math.floor

local Pages = {}
ns.Pages = Pages

Pages.WINDOW_KEY = "Options.Window"
Pages.GENERAL_SECTIONS = { "Appearance", "Widgets" }
Pages.ELEMENTS_SECTION = "Layout"
local APPLY_ON_RELEASE = { ["Appearance.uiScale"] = true }
local HIDDEN_MODULES = { Options = true }
local MODULE_ORDER = {
	"UnitFrames", "GroupFrames", "ActionBars", "Cooldowns", "Auras", "Nameplates", "CombatText",
	"Minimap", "Chat", "Bags", "Tooltips", "DataBars", "Meters", "Skins",
}
local MODULE_LABELS = {
	Options = L["Settings"],
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
	Appearance = L["Appearance"],
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

local function Percent(value)
	return floor(value * 100 + 0.5) .. "%"
end

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
	add({ kind = "header", level = level, label = element.label or opts.label or key })
	if not window and has("shown") then
		add({
			kind = "dropdown", label = L["Shown"], help = L["When the element shows."], options = Choices("SHOWN_OPTIONS", SHOWN),
			get = get("shown", FALLBACK.shown), set = set("shown"),
		})
	end
	if has("anchor") then
		add({
			kind = "dropdown", label = L["Anchor"], help = L["The point of the screen the element is placed from."], options = Choices("ANCHOR_OPTIONS", ANCHORS),
			get = get("anchor", FALLBACK.anchor), set = set("anchor"),
		})
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
				kind = "slider", label = L["Width"], help = L["The element's width in interface units."],
				min = minW, max = maxW, step = 1, format = Whole, get = get("width", minW), set = set("width"),
			})
		end
		if minH < maxH and has("height") then
			add({
				kind = "slider", label = L["Height"], help = L["The element's height in interface units."],
				min = minH, max = maxH, step = 1, format = Whole, get = get("height", minH), set = set("height"),
			})
		end
	end
	if opts.scalable and has("scale") then
		add({
			kind = "slider", label = L["Scale"], help = L["Makes the element larger or smaller."],
			min = Limit("SCALE_MIN", SCALE_MIN), max = Limit("SCALE_MAX", SCALE_MAX), step = Limit("SCALE_STEP", SCALE_STEP),
			format = Percent, get = get("scale", FALLBACK.scale), set = set("scale"),
		})
	end
	if has("alphaCombat") then
		add({
			kind = "slider", label = L["Opacity in combat"], help = L["How solid the element is while you fight."],
			min = minAlpha, max = 1, step = ALPHA_STEP, format = Percent, get = get("alphaCombat", FALLBACK.alphaCombat), set = set("alphaCombat"),
		})
	end
	if has("alphaIdle") then
		add({
			kind = "slider", label = L["Opacity out of combat"], help = L["How solid the element is the rest of the time."],
			min = minAlpha, max = 1, step = ALPHA_STEP, format = Percent, get = get("alphaIdle", FALLBACK.alphaIdle), set = set("alphaIdle"),
		})
	end
	if has("strata") then
		add({
			kind = "dropdown", label = L["Strata"], help = L["Which layer the element draws in, from back to front."], options = Choices("STRATA_OPTIONS", STRATA),
			get = get("strata", FALLBACK.strata), set = set("strata"),
		})
	end
	add({
		kind = "button", label = L["Reset this element"], help = L["Puts the element back where its module placed it."],
		buttons = {
			{
				label = L["Reset"],
				onClick = function()
					Pages.ResetElement(key)
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

local function GeneralItems()
	local items = {}
	for _, section in ipairs(Pages.GENERAL_SECTIONS) do
		local schema = K.Options.Get(section)
		if schema then
			Append(items, Model.SchemaItems(section, schema, "General"))
		end
	end
	for _, item in ipairs(items) do
		if item.module and item.key and APPLY_ON_RELEASE[item.module .. "." .. item.key] then
			item.defer = true
		end
	end
	return items
end

local function ResetGeneral()
	for _, section in ipairs(Pages.GENERAL_SECTIONS) do
		Model.ResetSchema(section, K.Options.Get(section))
	end
end

local function ElementsItems()
	local items = {}
	local schema = K.Options.Get(Pages.ELEMENTS_SECTION)
	if schema then
		Append(items, Model.SchemaItems(Pages.ELEMENTS_SECTION, schema, "Elements"))
	end
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

local function ModuleItems(page)
	local module = page.module
	local items = {}
	local schema = K.Options.Get(module)
	local defaults = K.Store.Defaults(module)
	if K.Features.modules[module] ~= nil and defaults and not HasKey(schema, "enabled") then
		local label = Pages.ModuleLabel(module)
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
		Append(items, Model.SchemaItems(module, schema, page.id))
	end
	ElementSection(items, module, page.id)
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

local function AskName(title, text, initial, onName)
	K.Widgets.Popup({
		title = title,
		text = text,
		editBox = { text = initial or "", placeholder = L["Profile name"], maxLetters = 48 },
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

local function AllProfiles()
	local out = {}
	for _, name in ipairs(K.Store.ListProfiles()) do
		out[#out + 1] = { value = name, label = name }
	end
	return out
end

function Pages.ExportProfile()
	local text, why = K.Store.Export()
	if not text then
		Notify(L["Export failed"], tostring(why))
		return nil
	end
	local handle = K.Widgets.Popup({
		title = L["Export profile"],
		text = L["Press Ctrl+C to copy this string, then share it."],
		editBox = { text = text },
		buttons = { { label = L["Close"], primary = true } },
	})
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			C_Timer.After(0, function()
				if handle:IsShown() and handle.editBox then
					handle.editBox:HighlightText()
				end
			end)
		end)
	end
	return text
end

function Pages.ImportProfile(text)
	local ok, result = K.Store.Import(text)
	ns.Changed()
	if ok then
		Notify(L["Profile imported"], format(L["Imported the profile as %s. This character now uses it."], tostring(result)))
	else
		Notify(L["Import failed"], tostring(result))
	end
	return ok, result
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
					text = format(L["Reset %s to the defaults? This cannot be undone."], tostring(store.ProfileName())),
					acceptLabel = L["Reset"],
					onAccept = function()
						Report(store.ResetProfile())
					end,
				})
			end,
		} },
	})
	add({ kind = "header", level = 1, label = L["Share"] })
	add({
		kind = "button", label = L["Export"], help = L["Shows this profile as a string you can copy and share."],
		buttons = { { label = L["Export"], onClick = Pages.ExportProfile } },
	})
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
								Pages.ImportProfile(handle:GetText())
							end,
						},
					},
				})
			end,
		} },
	})
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

local function GeneralPreview()
	return ns.Preview and ns.Preview.Sample
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
