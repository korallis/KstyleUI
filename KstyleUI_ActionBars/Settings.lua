-- Settings.lua: the action bars' defaults and the schema the settings window builds the Action Bars page from.
local _, ns = ...

local K = KstyleUI
local L, Tokens = K.L, K.Tokens

local SIZE_MIN, SIZE_MAX = 16, 64
local SPACING_MAX = 16
local FADE_STEP = 0.05
local FONT_MIN, FONT_MAX = 6, 24
local HOTKEY_TEXT, COOLDOWN_TEXT = 12, 19
local PAGING_LETTERS = 255
local ON_BY_DEFAULT = { bar1 = true, bar2 = true, bar4 = true, bar5 = true, pet = true, stance = true }

ns.TEXTS = {
	{ key = "hotkey", role = "number", label = L["Keybind text"] },
	{ key = "count", role = "number", label = L["Count text"] },
	{ key = "macro", role = "caption", label = L["Macro name text"] },
	{ key = "cooldown", role = "number", label = L["Cooldown numbers"] },
}

local function Color(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local function BarDefaults(def)
	local action = def.kind == "action"
	local grid = K.Setup.Layouts.Grid(def.element) or {}
	local out = {
		enabled = ON_BY_DEFAULT[def.key] == true,
		buttons = def.max,
		rows = action and (grid.rows or 1) or 0,
		orientation = "HORIZONTAL",
		growth = grid.growth or "RIGHTDOWN",
		size = grid.size,
		spacing = action and (grid.spacing or Tokens.Size("actionGap")) or -1,
		fade = false,
		fadeAlpha = 0,
		hotkey = true,
		cooldown = true,
		backing = false,
	}
	if def.kind ~= "stance" then
		out.showEmpty = def.key ~= "bar4" and def.key ~= "bar5"
	end
	if action then
		out.count = true
		out.macro = false
		out.paging = ""
		out.split = def.key == "bar2" and "auto" or "off"
	end
	if def.paged then
		out.pageForms = true
		out.pageStealth = true
		out.pagePossess = true
		out.pageKeys = true
	end
	return out
end

local defaults = {
	overlapBindings = false,
	safeDragging = true,
	hubNumber = true,
	editBar = "bar1",
	bindingHints = true,
	accent = "quiet",
	accentColor = Color("accentDefault"),
	rangeColor = Color("hostile"),
	powerColor = Color(ns.Socket.TOKENS.cool),
	tooltips = "always",
	ranks = "ask",
	newSpells = "ask",
	tray = true,
	useTray = true,
	slab = true,
	extraBarsLayout = "off",
	extraBarsApplied = "off",
	extraBarsPrevious = {},
	trayColumn = true,
	quietSockets = true,
	quietCooldown = true,
	readableCountdown = true,
	seatedCrest = true,
	crestTravel = true,
	procTransitions = true,
	inputContinuity = true,
	bezelModels = true,
	text = {
		hotkey = { font = "", size = HOTKEY_TEXT, outline = "NONE" },
		count = { font = "", size = Tokens.Size("number"), outline = "NONE" },
		macro = { font = "", size = Tokens.Size("caption"), outline = "NONE" },
		cooldown = { font = "", size = COOLDOWN_TEXT, outline = "NONE" },
	},
}
for _, def in ipairs(ns.BARS) do
	defaults[def.key] = BarDefaults(def)
	if def.key == "bar3" then defaults[def.key].finished = true end
end
ns.defaults = defaults

local function Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = Copy(child) end
	return out
end

function ns.ApplyExtraBars()
	local settings = K.Store.Module("ActionBars")
	local wanted = settings.extraBarsLayout
	if wanted == settings.extraBarsApplied then return false end
	if InCombatLockdown() then
		ns.QueueApply()
		return false
	end
	local preset = K.Setup.Layouts.ExtraBarsPreset(wanted, K.Scale.Aspect())
	if wanted ~= "off" and not preset then return false end
	local positions = K.Store.Layout()
	local previous = settings.extraBarsPrevious
	for _, key in ipairs({ "bar4", "bar5" }) do
		local element = "actionbars." .. key
		if preset then
			if settings.extraBarsApplied == "off" then
				previous[key] = { settings = Copy(settings[key]), position = Copy(positions[element]), styled = Copy(positions["medallions:" .. element]) }
			end
			for field, value in pairs(preset) do settings[key][field] = value end
			positions["medallions:" .. element] = nil
		elseif previous[key] then
			settings[key] = Copy(previous[key].settings)
			positions[element] = Copy(previous[key].position)
			positions["medallions:" .. element] = Copy(previous[key].styled)
		end
	end
	settings.extraBarsApplied = wanted
	if preset then
		local layouts, rootWidth = K.Setup.Layouts, K.Layout.RootSize()
		local _, _, _, gap = layouts.ActionBarGrid("medallions", K.Scale.Aspect(), "actionbars.bar1")
		for i, key in ipairs({ "bar4", "bar5" }) do
			local parent = i == 1 and "actionbars.bar1" or "actionbars.bar2"
			local x, y, w, h = K.Layout.Rect(parent)
			if x then
				local bw, bh = layouts.ActionBarFootprint("medallions", K.Scale.Aspect(), "actionbars." .. key)
				local scale = wanted == "rows" and K.Layout.Get(parent).scale or 1
				local center = x + w / 2 - rootWidth / 2
				if wanted == "beside" then center = center + (i == 1 and -1 or 1) * (w / 2 + 2 * layouts.MEDALLIONS_SLAB.pad + gap + bw / 2) end
				positions["medallions:actionbars." .. key] = { anchor = "BOTTOM", x = center, y = wanted == "rows" and y + h + gap or y + h - bh, scale = scale }
			end
		end
	end
	if not preset then settings.extraBarsPrevious = {} end
	K.Callbacks.Fire("SettingChanged", "ActionBars", "extraBarsApplied", wanted)
	return wanted
end

function ns.ClearExtraChat()
	local saved = K.Store.Layout()["chat.main"]
	if not (saved and (saved.anchor or saved.x or saved.y)) then return end
	local l, b, w, h = K.Layout.Rect("chat.main")
	local x, y, bw, bh = K.Layout.Rect("actionbars.bar4")
	if not (l and x) then return end
	local pad = K.Setup.Layouts.MEDALLIONS_SLAB.pad
	if x - pad < l + w and l < x + bw + pad and y - pad < b + h and b < y + bh + pad then
		local position = K.Layout.Get("actionbars.bar4")
		local _, _, _, gap = K.Setup.Layouts.ActionBarGrid("medallions", K.Scale.Aspect(), "actionbars.bar1")
		K.Layout.Set("actionbars.bar4", "y", position.y + b + h + pad + gap - y)
	end
end

local function Label(def)
	local element = K.Setup and K.Setup.Layouts and K.Setup.Layouts.Element(def.element)
	return element and element.label or def.key
end
ns.Label = Label

local function FontOptions()
	local out = { { value = "", label = L["Interface font"] } }
	local media = K.Widgets.MediaOptions and K.Widgets.MediaOptions("font") or {}
	for _, option in ipairs(media) do
		out[#out + 1] = option
	end
	return out
end

local OUTLINE_OPTIONS = {
	{ value = "NONE", label = L["Soft shadow"] },
	{ value = "OUTLINE", label = L["Thin outline"] },
	{ value = "THICK", label = L["Thick outline"] },
}
local ORIENTATION_OPTIONS = {
	{ value = "HORIZONTAL", label = L["Along rows first"] },
	{ value = "VERTICAL", label = L["Down columns first"] },
}
local SPLIT_OPTIONS = {
	{ value = "auto", label = L["With the Orbs HUD style"] },
	{ value = "on", label = L["Always"] },
	{ value = "off", label = L["Never"] },
}
local GROWTH_OPTIONS = {
	{ value = "RIGHTDOWN", label = L["Right, then down"] },
	{ value = "RIGHTUP", label = L["Right, then up"] },
	{ value = "LEFTDOWN", label = L["Left, then down"] },
	{ value = "LEFTUP", label = L["Left, then up"] },
}

local function Editing(key)
	return function(settings)
		return settings.editBar == key
	end
end

local function BarRows(schema, def)
	local key = def.key
	if key == "bar3" then
		schema[#schema + 1] = { type = "toggle", key = "bar3.finished", label = L["Finished third bar"], help = L["Seats bar 3 clear of the HUD, with a Medallions slab. Off restores its old place and finish."], showWhen = Editing(key) }
	end
	local editing = Editing(key)
	local function Off(settings)
		return not settings[key].enabled
	end
	local scope = { key = "editBar", value = key }
	local function add(row)
		row.showWhen = row.showWhen or editing
		if key == "bar1" or key == "bar2" then
			local field = row.key and row.key:match("%.(.+)$")
			if field == "rows" or field == "orientation" or field == "growth" or field == "spacing" or field == "split" or field == "showEmpty" or field == "backing" then
				row.showWhen = function(settings) return editing(settings) and not (K.HudStyle.Current() == "medallions" and settings.slab ~= false) end
			end
		end
		row.scope = scope
		if row.type ~= "header" and row.key ~= key .. ".enabled" then
			row.disableWhen = Off
		end
		schema[#schema + 1] = row
	end
	add({ type = "header", label = Label(def) })
	local help = key == "bar3" and L["Turns this bar on or off. Beside the party frames it lowers the largest HUD size."] or L["Turns this bar on or off."]
	add({ type = "toggle", key = key .. ".enabled", label = L["Show this bar"], help = help })
	if key == "bar1" or key == "bar2" then
		add({ type = "note", label = L["The slab keeps one row of up to 12 buttons per side, with fixed socket spacing and backing. Button size scales both sides. Turn off Use the Medallions slab to arrange these bars freely."], showWhen = function(settings) return editing(settings) and K.HudStyle.Current() == "medallions" and settings.slab ~= false end })
	end
	add({ type = "slider", key = key .. ".buttons", label = L["Buttons"], help = L["How many buttons the bar shows."], min = 1, max = def.max, step = 1 })
	add({ type = "slider", key = key .. ".rows", label = L["Rows"], help = def.kind == "action" and L["12 buttons in 2 rows gives 6 buttons per row."] or L["12 buttons in 2 rows gives 6 buttons per row. 0 keeps the HUD style's default rows."], min = def.kind == "action" and 1 or 0, max = def.max, step = 1 })
	add({ type = "dropdown", key = key .. ".orientation", label = L["Fill order"], help = L["Whether buttons fill each row or each column first."], options = ORIENTATION_OPTIONS })
	add({ type = "dropdown", key = key .. ".growth", label = L["Growth"], help = L["The direction the buttons grow from the first one."], options = GROWTH_OPTIONS })
	add({ type = "slider", key = key .. ".size", label = L["Button size"], help = L["The size of each button."], min = SIZE_MIN, max = SIZE_MAX, step = 0.1 })
	add({ type = "slider", key = key .. ".spacing", label = L["Spacing"], help = def.kind == "action" and L["The gap between buttons."] or L["The gap between buttons. -1 keeps the HUD style's default spacing."], min = def.kind == "action" and 0 or -1, max = SPACING_MAX, step = 0.1 })
	if def.kind == "action" then
		add({ type = "dropdown", key = key .. ".split", label = L["Split in two"], help = L["Parts each row into two halves with a gap between them."], options = SPLIT_OPTIONS })
	end
	if def.kind ~= "stance" then
		add({ type = "toggle", key = key .. ".showEmpty", label = L["Show empty buttons"], help = L["Shows slots with no action as empty tiles."] })
	end
	add({ type = "toggle", key = key .. ".backing", label = L["Backing strip"], help = L["Draws a strip of smoked glass behind the bar's buttons."] })
	add({ type = "toggle", key = key .. ".fade", label = L["Fade until hovered"], help = L["Fades the bar until the pointer is over it."] })
	add({
		type = "slider", key = key .. ".fadeAlpha", label = L["Faded opacity"], help = L["How visible the bar stays while faded."],
		min = 0, max = 1, step = FADE_STEP,
		showWhen = function(settings)
			return settings.editBar == key and settings[key].fade
		end,
	})
	add({ type = "toggle", key = key .. ".hotkey", label = L["Keybind text"], help = L["Shows the key bound to each button."] })
	if def.kind == "action" then
		add({ type = "toggle", key = key .. ".count", label = L["Count text"], help = L["Shows item counts and spell charges."] })
		add({ type = "toggle", key = key .. ".macro", label = L["Macro names"], help = L["Shows the name of each macro."] })
	end
	add({ type = "toggle", key = key .. ".cooldown", label = L["Cooldown numbers"], help = L["Shows the time left on each cooldown."] })
	if def.paged then
		local function Custom(settings)
			return settings[key].paging ~= ""
		end
		add({ type = "header", label = L["Paging"] })
		add({ type = "toggle", key = key .. ".pageForms", label = L["Stances and forms"], help = L["Swaps the bar when you change stance or form."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pageStealth", label = L["Stealth"], help = L["Swaps the bar while you are stealthed or prowling."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pagePossess", label = L["Possess and vehicles"], help = L["Shows possess, vehicle and override actions on this bar."], disableWhen = Custom })
		add({ type = "toggle", key = key .. ".pageKeys", label = L["Page keys"], help = L["Follows the keys that change the action page."], disableWhen = Custom })
	end
	if def.kind == "action" then
		add({
			type = "text", key = key .. ".paging", label = L["Custom paging"], maxLetters = PAGING_LETTERS,
			help = L["Macro conditions such as [mod:alt] 2; 1. Empty uses the rules above."],
		})
	end
end

local function EditOptions()
	local out = {}
	for i, def in ipairs(ns.BARS) do
		out[i] = { value = def.key, label = Label(def) }
	end
	return out
end

function ns.Schema()
	local schema = {
		{ type = "header", label = L["Slab and cooldowns"] },
		{ type = "toggle", key = "slab", label = L["Use the Medallions slab"], help = L["Seats bars 1 and 2 in the connected slab. Off gives both bars every arrangement option."], showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "dropdown", key = "extraBarsLayout", label = L["Extra bars layout"], help = L["Places bars 4 and 5 once; all controls stay editable. Off restores their previous settings."], showWhen = function() return K.HudStyle.Current() == "medallions" end,
			options = { { value = "off", label = L["Off"] }, { value = "rows", label = L["Two rows on the slab"] }, { value = "beside", label = L["Beside the slab"] } } },
		{ type = "toggle", key = "quietSockets", label = L["Quiet empty sockets"], help = L["Dims empty Medallions buttons until you drag an action, bind keys or enter Layout Mode."] },
		{ type = "toggle", key = "quietCooldown", label = L["Quieter cooldowns"], help = L["Removes the bright edge from the global cooldown and keeps cooling icons readable."] },
		{ type = "toggle", key = "readableCountdown", label = L["Readable countdowns"], help = L["Centres outlined timers and dims larger key labels during real cooldowns."] },
		{ type = "toggle", key = "seatedCrest", label = L["Seat the crest"], help = L["Fits the Medallions crest inside its opening with a small metal lip. Off restores the larger crest."] },
		{ type = "toggle", key = "crestTravel", label = L["Crest travel clicks"], help = L["Left click the crest to hearth; right click for your travel spells, items and mounts."], showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "hubNumber", label = L["Clear hub level"],
			help = L["Use the number face on a larger Medallions level badge. Off restores the original badge."] },
		{ type = "note", label = L["Type /kb to hover a button and press a key to bind it. Save for your account or this character, or Discard your changes."] },
		{ type = "header", label = L["Tray"], showWhen = function() return K.HudStyle.Current() ~= "medallions" end },
		{ type = "toggle", key = "useTray", label = L["Use the tray"], help = L["Frames bars 1 and 2 in their HUD tray. Off frees the bars and removes the tray's button sizing."], showWhen = function() return K.HudStyle.Current() ~= "medallions" end },
		{ type = "toggle", key = "tray", label = L["Tray card"], help = L["Frames bar 1 and bar 2 in one card while bar 2 stands straight above bar 1."], showWhen = function(settings) return settings.useTray ~= false and K.HudStyle.Current() == "frames" end },
		{ type = "toggle", key = "trayColumn", label = L["Tray on the centre column"], help = L["Frames: bars 1 and 2 shrink so their buttons line up with the unit bars above."], showWhen = function(settings) return settings.useTray ~= false and K.HudStyle.Current() == "frames" end },
		{ type = "header", label = L["Bars"] },
		{ type = "toggle", key = "safeDragging", label = L["Safe dragging"], help = L["Clicks cast on release; keys keep their timing. Off makes clicks follow the key setting."] },
		{ type = "toggle", key = "bindingHints", label = L["Binding helpers"], help = L["Shows Bind keys buttons and a dash on unbound actions. Off keeps the usual binding display."] },
		{ type = "dropdown", key = "editBar", label = L["Bar to edit"], help = L["Choose the bar the settings below change."], options = EditOptions() },
	}
	for _, def in ipairs(ns.BARS) do
		BarRows(schema, def)
	end
	schema[#schema + 1] = { type = "header", label = L["Text"] }
	for _, text in ipairs(ns.TEXTS) do
		local base = "text." .. text.key
		schema[#schema + 1] = { type = "dropdown", key = base .. ".font", label = text.label .. ": " .. L["font"], help = L["The font of this text on every bar."], options = FontOptions }
		schema[#schema + 1] = { type = "slider", key = base .. ".size", label = text.label .. ": " .. L["size"], help = L["The size of this text, before the interface text size."], min = FONT_MIN, max = FONT_MAX, step = 1 }
		schema[#schema + 1] = { type = "dropdown", key = base .. ".outline", label = text.label .. ": " .. L["outline"], help = L["A soft shadow, or an outline for busy scenes."], options = OUTLINE_OPTIONS }
	end
	local function NotCustom(settings)
		return settings.accent ~= "custom"
	end
	local list = {
		{ type = "header", label = L["Motion"] },
		{ type = "toggle", key = "procTransitions", label = L["Soft proc and ready glow"], help = L["Fade and soften proc glows and ready flashes. Turn off for the previous glow."] },
		{ type = "toggle", key = "inputContinuity", label = L["Smooth hover and held press"], help = L["Finish hover fades and light held buttons. Turn off for the previous response."] },
		{ type = "toggle", key = "bezelModels", label = L["Models behind the crest"], help = L["Space 3D flashes behind the crest and fade replacements. Turn off for the previous effects."] },
		{ type = "header", label = L["Colours"] },
		{
			type = "dropdown", key = "accent", label = L["Accent"], help = L["The colour of the button edges and proc glows."],
			options = {
				{ value = "quiet", label = L["Quiet rim"] },
				{ value = "theme", label = L["Interface accent"] },
				{ value = "class", label = L["Class colour"] },
				{ value = "custom", label = L["Custom colour"] },
			},
		},
		{ type = "color", key = "accentColor", label = L["Custom accent"], help = L["The accent used when Accent is set to custom."], disableWhen = NotCustom },
		{ type = "color", key = "rangeColor", label = L["Out of range"], help = L["Tints an action whose target is out of range."] },
		{ type = "color", key = "powerColor", label = L["Not enough power"], help = L["Tints an action you lack the mana, rage or energy for."] },
		{ type = "header", label = L["Tooltips"] },
		{
			type = "dropdown", key = "tooltips", label = L["Action tooltips"], help = L["When hovering a button shows its tooltip."],
			options = {
				{ value = "always", label = L["Always"] },
				{ value = "noCombat", label = L["Out of combat only"] },
				{ value = "never", label = L["Never"] },
			},
		},
		{ type = "header", label = L["Spell ranks"] },
		{
			type = "dropdown", key = "ranks", label = L["New spell ranks"], help = L["What happens when you learn a higher rank of a spell on your bars."],
			options = {
				{ value = "ask", label = L["Ask"] },
				{ value = "auto", label = L["Update automatically"] },
				{ value = "off", label = L["Off"] },
			},
		},
		{
			type = "dropdown", key = "newSpells", label = L["New spells"], help = L["What happens when you learn an active spell that is not on your bars."],
			options = {
				{ value = "ask", label = L["Ask"] },
				{ value = "auto", label = L["Always add"] },
				{ value = "off", label = L["Never"] },
			},
		},
	}
	for _, row in ipairs(list) do
		schema[#schema + 1] = row
	end
	return schema
end
