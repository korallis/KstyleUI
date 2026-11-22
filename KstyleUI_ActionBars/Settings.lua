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

local function TextDefaults(out)
	out.desaturateCooldown, out.swipeOpacity, out.rarityBorder, out.moverOptions = false, ns.Socket.SWIPE_ALPHA, true, true
	out.placement = {}
	for _, spec in ipairs(ns.TEXTS) do out.placement[spec.key] = { anchor = "", x = 0, y = 0 } end
	return out
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
		visibility = "",
		visibilityBuilder = ns.VisibilityDefaults(),
		clickThrough = false,
		reverse = false,
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
		out.split = "off"
	end
	if def.paged then
		out.pageForms = true
		out.pageStealth = true
		out.pagePossess = true
		out.pageKeys = true
	end
	return TextDefaults(out)
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
	crestJewels = true,
	crestJewelGlow = true,
	crestHawks = true,
	totemBar = true,
	crestStorm = true,
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
defaults.consumables = { enabled = true, attached = true, buttons = 12, visibility = "", rows = 2, size = 19, orientation = "HORIZONTAL", growth = "LEFTUP", spacing = -1, fade = false, fadeAlpha = 0, count = true, hotkey = false, cooldown = true, combat = true, idle = true, hideEmpty = true, other = true, backing = true }
defaults.consumables.visibilityBuilder = ns.VisibilityDefaults()
defaults.consumables.clickThrough, defaults.consumables.reverse = false, false
TextDefaults(defaults.consumables)
for _, kind in ipairs(ns.Consumables.kinds) do defaults.consumables[kind.key] = true end
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
			for field, value in pairs(defaults[key]) do if settings[key][field] == nil then settings[key][field] = Copy(value) end end
			positions[element] = Copy(previous[key].position)
			positions["medallions:" .. element] = Copy(previous[key].styled)
		end
	end
	settings.extraBarsApplied = wanted
	if preset then
		local layouts, rootWidth = K.Setup.Layouts, K.Layout.RootSize()
		local _, _, _, gap = layouts.ActionBarGrid(K.Scale.Aspect(), "actionbars.bar1", nil, "medallions")
		for i, key in ipairs({ "bar4", "bar5" }) do
			local parent = i == 1 and "actionbars.bar1" or "actionbars.bar2"
			local x, y, w, h = K.Layout.Rect(parent)
			if x then
				local bw, bh = layouts.ActionBarFootprint(K.Scale.Aspect(), "actionbars." .. key, "medallions")
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
		local _, _, _, gap = K.Setup.Layouts.ActionBarGrid(K.Scale.Aspect(), "actionbars.bar1", nil, "medallions")
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
	{ value = "on", label = L["Always"] },
	{ value = "off", label = L["Never"] },
}
local GROWTH_OPTIONS = {
	{ value = "RIGHTDOWN", label = L["Right, then down"] },
	{ value = "RIGHTUP", label = L["Right, then up"] },
	{ value = "LEFTDOWN", label = L["Left, then down"] },
	{ value = "LEFTUP", label = L["Left, then up"] },
}

local TEXT_ANCHORS = {
	{ value = "", label = L["Current style"] },
	{ value = "TOPLEFT", label = L["Top left"] }, { value = "TOP", label = L["Top centre"] }, { value = "TOPRIGHT", label = L["Top right"] },
	{ value = "LEFT", label = L["Left centre"] }, { value = "CENTER", label = L["Centre"] }, { value = "RIGHT", label = L["Right centre"] },
	{ value = "BOTTOMLEFT", label = L["Bottom left"] }, { value = "BOTTOM", label = L["Bottom centre"] }, { value = "BOTTOMRIGHT", label = L["Bottom right"] },
}

local function Editing(key)
	return function(settings)
		return settings.editBar == key
	end
end

local function VisibilityRows(add, key)
	local function Advanced(settings) return ns.ParseVisibility(settings[key].visibility) == nil end
	add({ type = "header", label = L["Visibility conditions"] })
	add({ type = "note", label = L["Any ticked condition matches. The builder writes Custom visibility below. Clear an advanced macro to use it."] })
	add({ type = "dropdown", key = key .. ".visibilityBuilder.mode", label = L["When a condition matches"],
		help = L["Show or hide this bar when any ticked condition matches."], disableWhen = Advanced,
		options = { { value = "show", label = L["Show"] }, { value = "hide", label = L["Hide"] } } })
	for _, condition in ipairs(ns.VISIBILITY_CONDITIONS) do
		add({ type = "toggle", key = key .. ".visibilityBuilder." .. condition[1], label = condition[3],
			help = L["Adds this condition to Custom visibility."], disableWhen = Advanced })
	end
	add({ type = "text", key = key .. ".visibility", label = L["Custom visibility"], help = L["Macro conditions: [combat] show; hide. Empty keeps the usual visibility rules."], maxLetters = PAGING_LETTERS })
	add({ type = "note", label = L["Bind Toggle Action Bar in Blizzard's Key Bindings under KstyleUI."] })
end

local function BarRows(schema, def)
	local key = def.key
	local editing = Editing(key)
	local scope = { key = "editBar", value = key }
	local function add(row)
		row.showWhen = row.showWhen or editing
		local shown = row.showWhen
		if row.type ~= "header" and row.key ~= key .. ".enabled" then
			row.showWhen = function(settings) return shown(settings) and settings[key].enabled end
		end
		if key == "bar1" or key == "bar2" then
			local field = row.key and row.key:match("%.(.+)$")
			if field == "rows" or field == "orientation" or field == "growth" or field == "spacing" or field == "split" or field == "showEmpty" or field == "backing" or field == "reverse" then
				row.showWhen = function(settings) return editing(settings) and settings[key].enabled and not (K.HudStyle.Current() == "medallions" and settings.slab ~= false) end
			end
		end
		if key == "consumables" and row.key and row.key:find(".placement.", 1, true) then
			row.disableWhen = function()
				local _, size = K.Setup.Layouts.ConsumableGrid()
				return size < 30
			end
		end
		row.scope = scope
		schema[#schema + 1] = row
	end
	add({ type = "header", label = Label(def) })
	local help = key == "bar3" and L["Turns this bar on or off. Beside the party frames it lowers the largest HUD size."] or L["Turns this bar on or off."]
	add({ type = "toggle", key = key .. ".enabled", label = L["Show this bar"], help = help })
	if key == "bar3" then add({ type = "toggle", key = "bar3.finished", label = L["Finished third bar"], help = L["Seats bar 3 clear of the HUD, with a Medallions slab. Off restores its old place and finish."] }) end
	if key == "bar1" or key == "bar2" then
		add({ type = "note", label = L["The slab joins bars 1 and 2 into one row each, with fixed spacing and backing. Turn off Use the Medallions slab above to unlock rows, spacing, growth and split. Button size scales both sides."], showWhen = function(settings) return editing(settings) and K.HudStyle.Current() == "medallions" and settings.slab ~= false end })
		add({ type = "note", label = L["The slab fixes button order. Turn it off above to reverse these bars."], showWhen = function(settings) return editing(settings) and K.HudStyle.Current() == "medallions" and settings.slab ~= false end })
	end
	add({ type = "slider", key = key .. ".buttons", label = L["Buttons"], help = L["How many buttons the bar shows."], min = 1, max = def.max, step = 1 })
	add({ type = "slider", key = key .. ".rows", label = L["Rows"], help = (def.kind == "action" or def.kind == "consumable") and L["12 buttons in 2 rows gives 6 buttons per row."] or L["12 buttons in 2 rows gives 6 buttons per row. 0 keeps the HUD style's default rows."], min = (def.kind == "action" or def.kind == "consumable") and 1 or 0, max = def.max, step = 1 })
	add({ type = "dropdown", key = key .. ".orientation", label = L["Fill order"], help = L["Whether buttons fill each row or each column first."], options = ORIENTATION_OPTIONS })
	add({ type = "dropdown", key = key .. ".growth", label = L["Growth"], help = L["The direction the buttons grow from the first one."], options = GROWTH_OPTIONS })
	add({ type = "toggle", key = key .. ".reverse", label = L["Reverse button order"], help = L["Places the first slot at the other end. Each key stays bound to its original slot."] })
	add({ type = "slider", key = key .. ".size", label = L["Button size"], help = L["The size of each button."], min = SIZE_MIN, max = SIZE_MAX, step = 0.1 })
	add({ type = "slider", key = key .. ".spacing", label = L["Spacing"], help = def.kind == "action" and L["The gap between buttons."] or L["The gap between buttons. -1 keeps the HUD style's default spacing."], min = def.kind == "action" and 0 or -1, max = SPACING_MAX, step = 0.1 })
	if def.kind == "action" then
		add({ type = "dropdown", key = key .. ".split", label = L["Split in two"], help = L["Parts each row into two halves with a gap between them."], options = SPLIT_OPTIONS })
	end
	if def.kind ~= "stance" and def.kind ~= "consumable" then
		add({ type = "toggle", key = key .. ".showEmpty", label = L["Show empty buttons"], help = L["Shows slots with no action as empty tiles."] })
	end
	add({ type = "toggle", key = key .. ".backing", label = L["Backing strip"], help = L["Draws a strip of smoked glass behind the bar's buttons."] })
	add({ type = "toggle", key = key .. ".clickThrough", label = L["Click through"], help = L["Ignores the mouse while keys still work. Move the bar with its Layout Mode handle."] })
	add({ type = "toggle", key = key .. ".fade", label = L["Fade until hovered"], help = L["Fades the bar until the pointer is over it."] })
	add({
		type = "slider", key = key .. ".fadeAlpha", label = L["Faded opacity"], help = L["How visible the bar stays while faded."],
		min = 0, max = 1, step = FADE_STEP,
		showWhen = function(settings)
			return settings.editBar == key and settings[key].fade
		end,
	})
	add({ type = "toggle", key = key .. ".hotkey", label = L["Keybind text"], help = def.kind == "consumable" and L["Shows the bound key. Below 30 units, it shows only when Count text is off."] or L["Shows the key bound to each button."] })
	if def.kind == "action" or def.kind == "consumable" then
		add({ type = "toggle", key = key .. ".count", label = L["Count text"], help = L["Shows item counts and spell charges."] })
		if def.kind == "action" then add({ type = "toggle", key = key .. ".macro", label = L["Macro names"], help = L["Shows the name of each macro."] }) end
	end
	add({ type = "toggle", key = key .. ".cooldown", label = L["Cooldown numbers"], help = L["Shows the time left on each cooldown."] })
	add({ type = "toggle", key = key .. ".desaturateCooldown", label = L["Desaturate on cooldown"], help = L["Greys icons during real cooldowns, keeping the global cooldown in colour."] })
	add({ type = "slider", key = key .. ".swipeOpacity", label = L["Swipe opacity"], help = L["Opacity of cooldown sweeps. Quiet global cooldowns stay proportionally softer."], min = 0, max = 1, step = FADE_STEP })
	if def.kind == "action" then
		add({ type = "toggle", key = key .. ".rarityBorder", label = L["Item quality borders"], help = L["Colours the border of buttons holding an uncommon or better item."] })
	end
	add({ type = "toggle", key = key .. ".moverOptions", label = L["Double-click mover for settings"], help = L["Opens this bar in Options from Layout Mode. Click selects; right-click resets."] })
	if def.kind == "consumable" then add({ type = "note", label = L["Below 30 units, consumables keep count and cooldown apart."], showWhen = function(settings) return editing(settings) and settings[key].enabled and select(2, K.Setup.Layouts.ConsumableGrid()) < 30 end }) end
	for _, spec in ipairs(ns.TEXTS) do
		if spec.key == "hotkey" or spec.key == "cooldown" or spec.key == "count" and (def.kind == "action" or def.kind == "consumable") or spec.key == "macro" and def.kind == "action" then
			local path = key .. ".placement." .. spec.key
			add({ type = "header", label = spec.label })
			add({ type = "dropdown", key = path .. ".anchor", label = L["Text position"], help = L["Current style keeps the usual position. Offsets move text within the button."], options = TEXT_ANCHORS })
			add({ type = "slider", key = path .. ".x", label = L["Horizontal offset"], help = L["Moves the text horizontally."], min = -12, max = 12, step = 1 })
			add({ type = "slider", key = path .. ".y", label = L["Vertical offset"], help = L["Moves the text vertically."], min = -12, max = 12, step = 1 })
		end
	end
	if def.kind == "consumable" then
		for _, option in ipairs({ { "attached", L["Attach to the player frame"] }, { "combat", L["Show in combat"] }, { "idle", L["Show out of combat"] }, { "hideEmpty", L["Hide when empty"] }, { "other", L["Other usable consumables"] } }) do
			add({ type = "toggle", key = key .. "." .. option[1], label = option[2], help = L["Controls when and where consumables appear."],
				disableWhen = (option[1] == "combat" or option[1] == "idle") and function(settings) return settings[key].visibility ~= "" end or nil })
		end
		for _, kind in ipairs(ns.Consumables.kinds) do add({ type = "toggle", key = key .. "." .. kind.key, label = kind.label, help = L["Shows the best carried item of this kind."] }) end
	end
	VisibilityRows(add, key)
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
	local labels = { L["Bar 1"], L["Bar 2"], L["Bar 3"], L["Bar 4"], L["Bar 5"], L["Bar 6"] }
	for i, def in ipairs(ns.BARS) do
		out[i] = { value = def.key, label = labels[i] or Label(def) }
	end
	out[#out + 1] = { value = "consumables", label = L["Consumables bar"] }
	return out
end

function ns.Schema()
	ns.SyncVisibilities()
	K.Callbacks.Register("SettingChanged", "ActionBarsVisibility", ns.VisibilityChanged)
	K.Callbacks.Register("ProfileChanged", "ActionBarsVisibility", ns.SyncVisibilities)
	local schema = {
		{ type = "segmented", key = "editBar", pin = true, label = L["Bar to edit"], help = L["Choose the bar the settings below change."], options = EditOptions() },
		{ type = "toggle", key = "slab", label = L["Use the Medallions slab"], help = L["Seats bars 1 and 2 in the connected slab. Off gives both bars every arrangement option."], showWhen = function(settings) return (settings.editBar == "bar1" or settings.editBar == "bar2") and K.HudStyle.Current() == "medallions" end },
	}
	for _, def in ipairs(ns.BARS) do BarRows(schema, def) end
	BarRows(schema, ns.Consumables.def)
	local shared = {
		{ type = "header", label = L["Slab and cooldowns"] },
		{ type = "dropdown", key = "extraBarsLayout", label = L["Extra bars layout"], help = L["Places bars 4 and 5 once; all controls stay editable. Off restores their previous settings."], showWhen = function() return K.HudStyle.Current() == "medallions" end,
			options = { { value = "off", label = L["Off"] }, { value = "rows", label = L["Two rows on the slab"] }, { value = "beside", label = L["Beside the slab"] } } },
		{ type = "toggle", key = "quietSockets", label = L["Quiet empty sockets"], help = L["Dims empty Medallions buttons until you drag an action, bind keys or enter Layout Mode."] },
		{ type = "toggle", key = "quietCooldown", label = L["Quieter cooldowns"], help = L["Removes the bright edge from the global cooldown and keeps cooling icons readable."] },
		{ type = "toggle", key = "readableCountdown", label = L["Readable countdowns"], help = L["Centres outlined timers and dims larger key labels during real cooldowns."] },
		{ type = "toggle", key = "seatedCrest", label = L["Seat the crest"], help = L["Fits the Medallions crest inside its opening with a small metal lip. Off restores the larger crest."] },
		{ type = "toggle", key = "crestTravel", label = L["Crest travel clicks"], help = L["Left click the crest to hearth; right click for your travel spells, items and mounts."], showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "crestJewels", label = L["Crest resource jewels"], help = L["Lights combo points, holy power or soul shards as jewels on the Medallions crest ring."], showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "crestJewelGlow", label = L["Glow at max"], help = L["Lights the whole crest ring in the resource's colour while the jewels are full."], showWhen = function(settings) return settings.crestJewels ~= false and K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "crestHawks", label = L["Hawk perches"], help = L["Shows each Summon Hawk hawk and its time left as a perch on the Medallions crest ring."], showWhen = function() return K.HudStyle.Current() == "medallions" end },
		{ type = "toggle", key = "totemBar", label = L["Shaman totem bar"], help = L["Replaces Blizzard's totem bar: element sockets, spires timing each totem, Ghost Wolf and Call."], showWhen = function() return ns.class == "SHAMAN" end },
		{ type = "toggle", key = "crestStorm", label = L["Lightning Shield on the crest"], help = L["Shows each Lightning Shield charge as a storm orb circling the Medallions crest."], showWhen = function() return ns.class == "SHAMAN" and K.HudStyle.Current() == "medallions" end },
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
	}
	for _, row in ipairs(shared) do schema[#schema + 1] = row end
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
