-- Settings.lua: the Cooldowns defaults, the settings page schema, and clean reads of the saved values.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local floor, max, min = math.floor, math.max, math.min

local GAP = Tokens.Size("actionGap")
local Layouts = K.Setup.Layouts
local BUTTON = Layouts.BUTTON
local UTILITY_COLUMNS = 4
local ESSENTIAL_TIMER, ESSENTIAL_COUNT = 16.5, 10
local UTILITY_TIMER, UTILITY_COUNT = 11, 11
local BAR_WIDTH, BAR_HEIGHT = Layouts.Element("cooldowns.bars").width, Tokens.Size("barHeight")
local BAR_FILL_ALPHA = 0.15
local GROUPS = { "essential", "utility", "buffs", "bars" }
local ICON_GROUPS = { "essential", "utility", "buffs" }
local COOLDOWN_GROUPS = { essential = true, utility = true }
Settings.AURA_GROUPS = { buffs = true, bars = true }
Settings.GROUPS = GROUPS
Settings.ICON_GROUPS = ICON_GROUPS
Settings.COOLDOWN_GROUPS = COOLDOWN_GROUPS

local ICON_RANGE = {
	size = { 16, 64, 0.1 },
	iconZoom = { 0, 0.2, 0.01 },
	spacing = { 0, 12, 0.1 },
	columns = { 1, 12, 1 },
	rows = { 1, 4, 1 },
	timerSize = { 6, 32, 1 },
	countSize = { 6, 24, 1 },
	timerX = { -50, 50, 1 },
	timerY = { -50, 50, 1 },
	countX = { -50, 50, 1 },
	countY = { -50, 50, 1 },
	baseCount = { 0, 12, 1 },
	baseSize = { -20, 20, 1 },
	secondSize = { -20, 20, 1 },
	keybindX = { -50, 50, 1 },
	keybindY = { -50, 50, 1 },
}
local FADE_RANGE = { 0, 1, 0.05 }
local TENTHS_RANGE = { 1, 60, 1 }
local SWING_RANGE = { 0.1, 2, 0.1 }
local ESSENTIAL_TIMER_RANGE = { 6, 32, 0.5 }
local BAR_RANGE = {
	width = { 80, 400, 1 },
	iconZoom = { 0, 0.2, 0.01 },
	height = { 8, 40, 1 },
	spacing = { 0, 12, 1 },
	count = { 1, 12, 1 },
	nameSize = { 6, 24, 1 },
	timerSize = { 6, 24, 1 },
	countSize = { 6, 24, 1 },
	fillOpacity = { 0, 1, 0.05 },
	decimalBelow = TENTHS_RANGE,
	lineWidth = { 1, 10, 1 },
	shadeAlpha = { 0.05, 0.95, 0.05 },
}
local ICON_FLAGS = { "timer", "gcd", "desaturate", "usable", "readyGlow", "procGlow", "inactive", "showCount", "swipe", "edge", "vertical", "hideZero", "countOnly", "overflow", "numbersOnly", "keepPlace", "itemCount", "hideMissing", "trinkets", "keybind", "pressMirror", "itemQuality" }
local RULES = { "hideCooling", "hideReady", "hideUnusable", "spent", "fade", "grey", "colour", "reverse", "noSwipe", "tint", "noGcd", "noCount", "noEdge", "noCost", "glow", "range", "hide", "shift", "missing", "count", "timerColour", "activeGlow", "decimals", "names", "chargeSwipe", "chargeTimer", "threshold", "form", "swing", "swingGlow", "sound", "talent", "cdBars" }
Settings.RULES = RULES
local POSITION = { [""] = true, CENTER = true, TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local INACTIVE = { [""] = true, grey = true, colour = true }
local SOURCE = { class = true, custom = true }
local SIDE = { LEFT = true, RIGHT = true, TOP = true, BOTTOM = true }
Settings.SOUNDS = { warning = "RAID_WARNING", ready = "READY_CHECK" }
local MAX_RULE = 240
local BAR_FLAGS = { "reverse", "icon", "name", "timer", "inactive", "showCount", "fillUp", "smooth", "spark", "nameWrap", "decimals", "cdSmooth", "hashLines", "chargeShade" }

local PATH = { auto = true, mirror = true, reskin = true }
local GROWTH = { center = true, right = true, left = true, rightAligned = true }
local WRAP = { down = true, up = true }
local BAR_GROWTH = { up = true, down = true }
local OUTLINE = { INHERIT = true, none = true, OUTLINE = true, THICKOUTLINE = true }
local ACCENT = { quiet = true, class = true, custom = true }
local COLOR_SOURCE = { class = true, reaction = true, custom = true }
local ORIENTATION = { HORIZONTAL = true, VERTICAL = true }
local MAX_PATH = 260

local accentR, accentG, accentB = Tokens.Color("accentDefault")
local rangeR, rangeG, rangeB = Tokens.Color("hostile")
local textR, textG, textB = Tokens.Color("textEmphasis")
local blackR, blackG, blackB = Tokens.Color("black")
local DEFAULT_BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function IconDefaults(size, timerSize, countSize, cooldown, spacing, columns)
	local out = {
		size = size,
		iconZoom = 0.07,
		spacing = spacing or GAP,
		columns = cooldown and 0 or (columns or 6),
		rows = cooldown and 0 or 1,
		growth = "center",
		wrap = cooldown and "auto" or "up",
		timer = true,
		showCount = true,
		swipe = true,
		timerSize = timerSize,
		countSize = countSize,
		timerPosition = "",
		timerX = 0,
		timerY = 0,
		countX = 0,
		countY = 0,
		vertical = false,
		numbersOnly = false,
		baseCount = 0,
		baseSize = 0,
		secondSize = 0,
	}
	if cooldown then
		out.gcd, out.desaturate, out.usable, out.readyGlow, out.procGlow, out.edge = false, false, true, false, true, true
		out.hideZero, out.countOnly, out.overflow = false, false, false
		out.itemCount, out.hideMissing, out.trinkets = true, false, false
		out.keybind, out.keybindX, out.keybindY, out.pressMirror, out.itemQuality = false, 0, 0, false, false
	else
		out.inactive, out.inactiveShade, out.keepPlace = false, "", false
	end
	return out
end

local noRules = {}
for _, key in ipairs(RULES) do noRules[key] = "" end

local essential = IconDefaults(36.7, ESSENTIAL_TIMER, ESSENTIAL_COUNT, true, 4.6)
local buffs = IconDefaults(27.6, 9, 9, false, 3.4)
buffs.growth = "rightAligned"

Settings.defaults = {
	quietCooldown = true,
	readableCountdown = true,
	medallionsIcons = true,
	attached = true,
	path = "auto",
	accent = "quiet",
	accentColor = { r = accentR, g = accentG, b = accentB },
	tooltips = true,
	timerFont = "kit",
	timerOutline = "INHERIT",
	countFont = "kit",
	countOutline = "none",
	nameFont = "kit",
	nameOutline = "none",
	glowsInCombat = false,
	closeGaps = false,
	fadeAlpha = 0.5,
	tintSource = "class",
	tintColor = { r = accentR, g = accentG, b = accentB },
	glowSource = "class",
	glowColor = { r = accentR, g = accentG, b = accentB },
	rangeColor = { r = rangeR, g = rangeG, b = rangeB },
	timerSource = "class",
	timerColor = { r = textR, g = textG, b = textB },
	decimalBelow = 3,
	thresholdBelow = 5,
	thresholdColor = { r = rangeR, g = rangeG, b = rangeB },
	swingWindow = 0.5,
	readySound = "",
	textAboveGlow = false,
	focusSpell = "",
	focusSide = "LEFT",
	focusTarget = false,
	focusSound = "",
	focusReminder = false,
	rules = noRules,
	essential = essential,
	utility = IconDefaults(BUTTON, UTILITY_TIMER, UTILITY_COUNT, true, GAP, UTILITY_COLUMNS),
	buffs = buffs,
	bars = {
		width = BAR_WIDTH,
		iconZoom = 0.07,
		height = BAR_HEIGHT,
		spacing = GAP,
		count = 2,
		growth = "down",
		texture = DEFAULT_BAR_TEXTURE,
		colorSource = "class",
		color = { r = accentR, g = accentG, b = accentB },
		orientation = "HORIZONTAL",
		reverse = false,
		icon = true,
		name = true,
		timer = true,
		inactive = false,
		nameSize = 11,
		timerSize = 11,
		countSize = 9,
		showCount = true,
		fillOpacity = BAR_FILL_ALPHA,
		fillUp = false,
		smooth = false,
		spark = false,
		nameWrap = false,
		decimals = false,
		decimalBelow = 3,
		cdSmooth = false,
		hashLines = false,
		lineWidth = 1,
		lineColor = { r = blackR, g = blackG, b = blackB },
		chargeShade = false,
		shadeAlpha = 0.5,
	},
}

function Settings.Schema()
	local function FontOptions()
		local out = { { value = "kit", label = L["KstyleUI font"] } }
		local media = K.Widgets and K.Widgets.MediaOptions
		if media then
			local ok, list = pcall(media, "font")
			if ok and type(list) == "table" then
				for _, option in ipairs(list) do
					if type(option.value) == "string" then
						out[#out + 1] = { value = option.value, label = tostring(option.label) }
					end
				end
			end
		end
		return out
	end
	Settings.FontOptions = FontOptions

	local OUTLINE_OPTIONS = {
		{ value = "INHERIT", label = L["Use readability setting"] },
		{ value = "none", label = L["Soft shadow"] },
		{ value = "OUTLINE", label = L["Thin outline"] },
		{ value = "THICKOUTLINE", label = L["Thick outline"] },
	}
	local GROWTH_OPTIONS = {
		{ value = "center", label = L["Centred"] },
		{ value = "right", label = L["Left to right"] },
		{ value = "left", label = L["Right to left"] },
		{ value = "rightAligned", label = L["Left to right, aligned right"] },
	}
	local WRAP_OPTIONS = {
		{ value = "auto", label = L["Automatic"] },
		{ value = "down", label = L["New rows below"] },
		{ value = "up", label = L["New rows above"] },
	}
	local BAR_GROWTH_OPTIONS = {
		{ value = "up", label = L["Upward"] },
		{ value = "down", label = L["Downward"] },
	}
	local PATH_OPTIONS = {
		{ value = "auto", label = L["Automatic"] },
		{ value = "mirror", label = L["KstyleUI icons"] },
		{ value = "reskin", label = L["Restyle Blizzard's"] },
	}
	local COLOR_SOURCE_OPTIONS = {
		{ value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local ORIENTATION_OPTIONS = {
		{ value = "HORIZONTAL", label = L["Horizontal"] },
		{ value = "VERTICAL", label = L["Vertical"] },
	}

	local POSITION_OPTIONS = {
		{ value = "", label = L["Current style"] }, { value = "CENTER", label = L["Centre"] },
		{ value = "TOPLEFT", label = L["Top left"] }, { value = "TOP", label = L["Top"] }, { value = "TOPRIGHT", label = L["Top right"] },
		{ value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] },
		{ value = "BOTTOMLEFT", label = L["Bottom left"] }, { value = "BOTTOM", label = L["Bottom"] }, { value = "BOTTOMRIGHT", label = L["Bottom right"] },
	}
	local SOURCE_OPTIONS = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } }
	local SOUND_OPTIONS = { { value = "", label = L["None"] }, { value = "warning", label = L["Raid warning"] }, { value = "ready", label = L["Ready check"] } }
	local SIDE_OPTIONS = { { value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] }, { value = "TOP", label = L["Top"] }, { value = "BOTTOM", label = L["Bottom"] } }
	local INACTIVE_OPTIONS = { { value = "", label = L["Current style"] }, { value = "grey", label = L["Grey"] }, { value = "colour", label = L["Full colour"] } }

	local function Mirrors(group, settings)
		return not ns.Path.Restyles(group, settings.path) and ns.Path.Get(group) ~= "reskin"
	end

	local function Custom(key)
		return function(settings) return settings[key] == "custom" end
	end

	local function IsCustomBar(settings)
		return type(settings.bars) == "table" and settings.bars.colorSource == "custom"
	end

	local function Slider(group, key, label, help, range)
		range = group == "essential" and key == "timerSize" and ESSENTIAL_TIMER_RANGE or range[key]
		local row = { type = "slider", key = group .. "." .. key, label = label, help = help, min = range[1], max = range[2], step = range[3] }
		if COOLDOWN_GROUPS[group] and (key == "columns" or key == "rows") then
			row.shown = function(value) return value == 0 and Settings.Read()[group][key] or value end
		end
		return row
	end

	local function Toggle(group, key, label, help)
		return { type = "toggle", key = group .. "." .. key, label = label, help = help }
	end

	local function Add(schema, row, mirrorOnly)
		if mirrorOnly then
			local shown = row.showWhen
			row.showWhen = function(settings) return Mirrors(mirrorOnly, settings) and (not shown or shown(settings)) end
		end
		schema[#schema + 1] = row
	end

	local function Source(schema, key, label, help, colour, colourHelp, group)
		Add(schema, { type = "dropdown", key = key .. "Source", label = label, help = help, options = SOURCE_OPTIONS }, group)
		Add(schema, { type = "color", key = key .. "Color", label = colour, help = colourHelp, showWhen = Custom(key .. "Source") }, group)
	end

	local function IconRows(schema, group, title)
		Add(schema, { type = "header", label = title })
		Add(schema, Slider(group, "size", L["Icon size"], L["The width and height of each icon."], ICON_RANGE))
		Add(schema, Slider(group, "iconZoom", L["Icon zoom"], L["How much of the icon's edge is cropped."], ICON_RANGE))
		Add(schema, Slider(group, "spacing", L["Spacing"], L["The gap between icons."], ICON_RANGE))
		local perRow = COOLDOWN_GROUPS[group] and L["How many icons fit on one row."] or L["How many icons fit on one row. Point at the +N chip beside it to list the rest."]
		Add(schema, Slider(group, "columns", L["Icons per row"], perRow, ICON_RANGE))
		Add(schema, Slider(group, "rows", L["Rows"], L["How many rows the group may use."], ICON_RANGE))
		Add(schema, { type = "dropdown", key = group .. ".growth", label = L["Growth"], help = L["Where a short row starts."], options = GROWTH_OPTIONS })
		Add(schema, { type = "dropdown", key = group .. ".wrap", label = L["Wrap"], help = L["Whether extra rows go below or above the first."], options = WRAP_OPTIONS })
		Add(schema, Toggle(group, "timer", L["Timers"], L["Show the seconds left on each icon."]))
		Add(schema, Toggle(group, "swipe", L["Duration swipe"], L["Show the shaded duration sweep on each icon."]))
		Add(schema, Toggle(group, "showCount", L["Show charges and stacks"], L["Show charge or application counts on this group."]))
		Add(schema, Slider(group, "timerSize", L["Timer size"], L["The size of the countdown numbers."], ICON_RANGE))
		Add(schema, Slider(group, "countSize", L["Count size"], L["The size of the charge or stack count."], ICON_RANGE))
		Add(schema, { type = "dropdown", key = group .. ".timerPosition", label = L["Timer position"], help = L["Where the countdown sits on each icon."], options = POSITION_OPTIONS })
		Add(schema, Slider(group, "timerX", L["Timer horizontal offset"], L["Moves the countdown left or right."], ICON_RANGE))
		Add(schema, Slider(group, "timerY", L["Timer vertical offset"], L["Moves the countdown down or up."], ICON_RANGE))
		Add(schema, Slider(group, "countX", L["Count horizontal offset"], L["Moves the charge or stack count left or right."], ICON_RANGE))
		Add(schema, Slider(group, "countY", L["Count vertical offset"], L["Moves the charge or stack count down or up."], ICON_RANGE))
		Add(schema, Toggle(group, "vertical", L["Vertical"], L["Fill each column first. Attached rows keep their size; a detached or moved row stands upright."]), group)
		Add(schema, Toggle(group, "numbersOnly", L["Numbers only"], L["Show only the countdown, in an empty socket."]), group)
		Add(schema, Slider(group, "baseCount", L["Base row icons"], L["With two rows, how many icons the first row holds; 0 keeps Icons per row."], ICON_RANGE), group)
		Add(schema, Slider(group, "baseSize", L["Base row size"], L["With two rows, makes the first row's icons this much larger or smaller."], ICON_RANGE), group)
		Add(schema, Slider(group, "secondSize", L["Second row size"], L["With two rows, makes the second row's icons this much larger or smaller."], ICON_RANGE), group)
		if COOLDOWN_GROUPS[group] then
			Add(schema, Toggle(group, "hideZero", L["Hide 0 charges"], L["Hide the charge count while no charge is left."]), group)
			Add(schema, Toggle(group, "countOnly", L["Counts only"], L["Show only the charge or stack count, in an empty socket."]), group)
			Add(schema, Toggle(group, "overflow", L["Overflow to the other row"], L["Cooldowns past this row's grid join the other cooldown row."]), group)
			Add(schema, Toggle(group, "itemCount", L["Item counts"], L["Show how many potions or healthstones you carry."]), group)
			Add(schema, Toggle(group, "hideMissing", L["Hide missing items"], L["Hide a potion or healthstone while you carry none."]), group)
			Add(schema, Toggle(group, "trinkets", L["All trinkets"], L["Also show equipped trinkets that have no use effect."]), group)
			Add(schema, Toggle(group, "itemQuality", L["Item quality"], L["Show the crafted quality of potions, healthstones and trinkets as pips."]), group)
			Add(schema, Toggle(group, "keybind", L["Show keybind"], L["Show the key each spell is bound to on your action bars."]), group)
			Add(schema, Slider(group, "keybindX", L["Keybind horizontal offset"], L["Moves the keybind left or right."], ICON_RANGE), group)
			Add(schema, Slider(group, "keybindY", L["Keybind vertical offset"], L["Moves the keybind down or up."], ICON_RANGE), group)
			Add(schema, Toggle(group, "pressMirror", L["Mirror key presses"], L["Show a KstyleUI action button's press on its spell's icon."]), group)
			Add(schema, Toggle(group, "gcd", L["Global cooldown"], L["Sweep every icon during the global cooldown."]))
			Add(schema, Toggle(group, "edge", L["Cooldown edge"], L["Show the bright line that sweeps around a cooling icon."]))
			Add(schema, Toggle(group, "desaturate", L["Grey while cooling"], L["Show an icon in grey while its spell is on cooldown."]))
			Add(schema, Toggle(group, "usable", L["Dim unusable"], L["Dim an icon while you cannot cast its spell."]))
			Add(schema, Toggle(group, "readyGlow", L["Ready glow"], L["A soft accent glow around a spell that is ready."]))
			Add(schema, Toggle(group, "procGlow", L["Proc glow"], L["Pulse an icon while the game highlights its spell."]))
		else
			Add(schema, Toggle(group, "inactive", L["Show inactive"], L["Keep a dimmed icon while the buff is off you. Active buffs come first."]))
			Add(schema, { type = "dropdown", key = group .. ".inactiveShade", label = L["Inactive buffs"], help = L["Grey an inactive buff, keep it in colour, or keep the current style."], options = INACTIVE_OPTIONS })
			Add(schema, Toggle(group, "keepPlace", L["Keep buffs in place"], L["Each buff keeps its own slot, leaving a gap while it is off you."]), group)
		end
	end

	local function RuleRows(schema)
		local function Rule(key, label, help, mirrorOnly)
			Add(schema, { type = "text", key = "rules." .. key, label = label, help = help, maxLetters = MAX_RULE }, mirrorOnly == true and "essential" or mirrorOnly)
		end
		Add(schema, { type = "header", label = L["Spell rules"] })
		Add(schema, { type = "note", label = L["List spell names or IDs, separated by commas. Cooldown rules act on KstyleUI icons."] })
		Add(schema, { type = "note", label = L["A colour after a spell gives it its own, such as Fireball #FF8000."] })
		Rule("hide", L["Hide these"], L["Never show these icons or bars."], "essential")
		Rule("shift", L["Close gaps for these"], L["When these hide, the icons after them move up, even with Close gaps off."], true)
		Rule("missing", L["Show only while missing"], L["Show these tracked buffs only while they are off you, as a reminder."], "buffs")
		Rule("count", L["Show counts"], L["Show the charge or stack count of these spells, even with the group's counts off."])
		Rule("timerColour", L["Colour countdown"], L["Colour the countdown numbers of these spells."])
		Source(schema, "timer", L["Countdown colour"], L["Where the countdown colour comes from."], L["Custom countdown colour"], L["The countdown colour when it is custom."])
		Rule("decimals", L["Tenths below threshold"], L["Show tenths of a second below the threshold, or below a spell's own: Fireball=5."], true)
		Add(schema, { type = "slider", key = "decimalBelow", label = L["Tenths threshold"], help = L["Below this many seconds, listed countdowns show tenths."], min = TENTHS_RANGE[1], max = TENTHS_RANGE[2], step = TENTHS_RANGE[3] }, "essential")
		Rule("activeGlow", L["Glow while active"], L["Glow these tracked buffs while they are on you, in the glow tint."])
		Rule("hideCooling", L["Hide while cooling"], L["Hide these while they are on cooldown."], true)
		Rule("hideReady", L["Hide while ready"], L["Hide these while ready; a charge spell shows once a charge is spent."], true)
		Rule("spent", L["Hide until all charges are spent"], L["With Hide while ready, these stay hidden while any charge is left."], true)
		Rule("hideUnusable", L["Hide until usable"], L["Show these only while ready and usable. Low resources do not hide them."], true)
		Add(schema, { type = "toggle", key = "closeGaps", label = L["Close gaps"], help = L["Icons after a hidden one move up to fill its place."] }, "essential")
		Rule("fade", L["Fade while cooling"], L["Lower these icons' opacity while they are on cooldown."], true)
		Add(schema, { type = "slider", key = "fadeAlpha", label = L["Fade opacity"], help = L["How solid a faded icon stays."], min = FADE_RANGE[1], max = FADE_RANGE[2], step = FADE_RANGE[3] }, "essential")
		Rule("grey", L["Grey these"], L["Grey these cooldowns while cooling and these buffs while off you."])
		Rule("colour", L["Keep these in colour"], L["Keep these cooldowns in colour while cooling and these buffs while off you."])
		Rule("noCount", L["Hide counts"], L["Hide the charge or stack count of these spells."])
		Rule("noCost", L["Ignore resource cost"], L["Keep these in full colour while you lack the resource."], true)
		Rule("noGcd", L["Ignore the global cooldown"], L["Never sweep these for the global cooldown."], true)
		Rule("reverse", L["Reverse swipe"], L["Run the cooldown sweep of these spells the other way."], true)
		Rule("noSwipe", L["Hide swipe"], L["Hide the shaded cooldown sweep of these spells."], true)
		Rule("noEdge", L["Hide recharge edge"], L["Hide the bright line that sweeps while these spells recharge."], true)
		Rule("tint", L["Tint swipe"], L["Colour the cooldown sweep of these spells."], true)
		Source(schema, "tint", L["Swipe tint"], L["Where the swipe tint comes from."], L["Custom swipe tint"], L["The swipe tint when it is custom."], "essential")
		Rule("glow", L["Glow colour"], L["Colour the ready glow of these spells."], true)
		Source(schema, "glow", L["Glow tint"], L["Where the glow colour comes from."], L["Custom glow colour"], L["The glow colour when it is custom."])
		Rule("range", L["Out of range tint"], L["Tint these while your target is out of their range."], true)
		Add(schema, { type = "color", key = "rangeColor", label = L["Out of range"], help = L["The tint of a spell whose target is out of range."] }, "essential")
		Rule("names", L["Bar names"], L["Rename tracked buff bars, such as Rapid Fire=Haste."], "bars")
		Rule("chargeSwipe", L["Recharge swipe"], L["Shade these icons while a charge recharges."], true)
		Rule("chargeTimer", L["Recharge countdown"], L["Show the recharge countdown on these icons while charges remain."], true)
		Rule("threshold", L["Colour below threshold"], L["Colour the countdown of these spells below the threshold seconds."], true)
		Add(schema, { type = "slider", key = "thresholdBelow", label = L["Threshold seconds"], help = L["Below this many seconds, listed countdowns change colour."], min = TENTHS_RANGE[1], max = TENTHS_RANGE[2], step = TENTHS_RANGE[3] }, "essential")
		Add(schema, { type = "color", key = "thresholdColor", label = L["Threshold colour"], help = L["The countdown colour below the threshold."] }, "essential")
		Rule("form", L["Hide outside form"], L["Show these only in a form or stance, named after the spell: Shred=Cat Form."], true)
		Rule("swing", L["Swing timer"], L["Sweep these icons with your main hand swing, for attacks on your next swing."], true)
		Rule("swingGlow", L["Glow late in swing"], L["Glow these in the glow tint late in your main hand swing, unless already queued."], true)
		Add(schema, { type = "slider", key = "swingWindow", label = L["Seconds before swing"], help = L["How long before the swing the glow starts."], min = SWING_RANGE[1], max = SWING_RANGE[2], step = SWING_RANGE[3] }, "essential")
		Rule("sound", L["Sound when ready"], L["Play a sound when these spells come off cooldown."], true)
		Add(schema, { type = "dropdown", key = "readySound", label = L["Ready sound"], help = L["The sound listed spells play when ready."], options = SOUND_OPTIONS }, "essential")
		Rule("talent", L["Only with talent"], L["Show these only while you know a talent, named after the spell: Shred=Feral Instinct."], true)
		Rule("cdBars", L["Cooldown bars"], L["Also show these cooldowns as tracked bars that fill as they recover."], "bars")
	end

	local function BarRows(schema)
		local group = "bars"
		Add(schema, { type = "header", label = L["Tracked buff bars"] })
		Add(schema, Slider(group, "width", L["Bar width"], L["The width of each bar, icon included."], BAR_RANGE))
		Add(schema, Slider(group, "spacing", L["Spacing"], L["The gap between bars."], BAR_RANGE))
		Add(schema, Slider(group, "count", L["Bars"], L["How many bars show. Point at the +N more bar above them to list the rest."], BAR_RANGE))
		Add(schema, { type = "dropdown", key = "bars.growth", label = L["Growth"], help = L["Whether new bars stack upward or downward."], options = BAR_GROWTH_OPTIONS })
		K.Widgets.BarRows(schema, "bars", { options = COLOR_SOURCE_OPTIONS, custom = IsCustomBar, height = BAR_RANGE.height })
		Add(schema, { type = "dropdown", key = "bars.orientation", label = L["Orientation"], help = L["Whether the fill runs across or up the bar."], options = ORIENTATION_OPTIONS })
		Add(schema, Toggle(group, "reverse", L["Reverse fill"], L["Drain the fill from the other end."]))
		Add(schema, Toggle(group, "icon", L["Icon"], L["Show the buff's icon at the start of the bar."]))
		Add(schema, Slider(group, "iconZoom", L["Icon zoom"], L["How much of the icon's edge is cropped."], BAR_RANGE))
		Add(schema, Toggle(group, "name", L["Name"], L["Show the buff's name on the bar."]))
		Add(schema, Toggle(group, "timer", L["Timer"], L["Show the seconds left on the bar."]))
		Add(schema, Toggle(group, "showCount", L["Show stack counts"], L["Show the number of applications on aura icons."]))
		Add(schema, Toggle(group, "inactive", L["Show inactive"], L["Keep an empty bar while the buff is off you. Active bars come first."]))
		Add(schema, Slider(group, "fillOpacity", L["Fill opacity"], L["How strong the bar's coloured fill appears."], BAR_RANGE))
		Add(schema, Slider(group, "nameSize", L["Name size"], L["The size of the buff's name."], BAR_RANGE))
		Add(schema, Slider(group, "timerSize", L["Timer size"], L["The size of the seconds left."], BAR_RANGE))
		Add(schema, Slider(group, "countSize", L["Count size"], L["The size of the stack count."], BAR_RANGE))
		Add(schema, Toggle(group, "fillUp", L["Fill up"], L["Fill the bar as the buff runs instead of draining it."]), group)
		Add(schema, Toggle(group, "smooth", L["Smooth bars"], L["Ease the fill to a new value instead of snapping."]), group)
		Add(schema, Toggle(group, "spark", L["Spark"], L["Show a bright spark at the end of the fill."]), group)
		Add(schema, Toggle(group, "nameWrap", L["Wrap names"], L["Let a long name use a second line when the bar is tall enough."]), group)
		Add(schema, Toggle(group, "decimals", L["Tenths"], L["Show tenths of a second below the threshold."]), group)
		Add(schema, Slider(group, "decimalBelow", L["Tenths threshold"], L["Below this many seconds, the timer shows tenths."], BAR_RANGE), group)
		Add(schema, Toggle(group, "cdSmooth", L["Smooth cooldown bars"], L["Ease cooldown bars to a new value instead of snapping."]), group)
		Add(schema, Toggle(group, "hashLines", L["Charge hash lines"], L["Split a cooldown bar into one section per charge; the timer shows the next charge."]), group)
		Add(schema, Slider(group, "lineWidth", L["Line width"], L["The width of the charge lines, in pixels."], BAR_RANGE), group)
		Add(schema, { type = "color", key = "bars.lineColor", label = L["Line colour"], help = L["The colour of the charge lines."] }, group)
		Add(schema, Toggle(group, "chargeShade", L["Partial charge shade"], L["Darken the section still recharging the next charge."]), group)
		Add(schema, Slider(group, "shadeAlpha", L["Shade darkness"], L["How dark the recharging section is."], BAR_RANGE), group)
	end

	local schema = {
		{ type = "toggle", key = "quietCooldown", label = L["Quieter cooldowns"], help = L["Removes the bright edge from the global cooldown and keeps cooling icons readable."] },
		{ type = "toggle", key = "readableCountdown", label = L["Readable countdowns"], help = L["Uses the same bare seconds and minute labels as action buttons."] },
		{ type = "toggle", key = "medallionsIcons", label = L["Match Medallions sockets"], help = L["Uses the action slab's metal frame for cooldown and tracked buff icons in Medallions."] },
		{ type = "header", label = L["Cooldown Manager"] },
		{
			type = "dropdown", key = "path", label = L["Display"],
			help = L["Automatic uses KstyleUI icons where the game allows it in combat."],
			options = PATH_OPTIONS,
		},
		{
			type = "dropdown", key = "accent", label = L["Accent"],
			help = L["Keep hairlines quiet, or use your class colour or a colour you pick."],
			options = { { value = "quiet", label = L["Quiet"] }, { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
		},
		{ type = "color", key = "accentColor", label = L["Custom accent"], help = L["The colour of glows and hairlines when the accent is custom."], showWhen = Custom("accent") },
		{ type = "toggle", key = "tooltips", label = L["Tooltips"], help = L["Show a spell's tooltip when the pointer is over its icon."] },
		{ type = "toggle", key = "glowsInCombat", label = L["Glows only in combat"], help = L["Hide the ready and proc glows of cooldown icons out of combat."], showWhen = function(settings) return Mirrors("essential", settings) end },
		{ type = "toggle", key = "textAboveGlow", label = L["Numbers above glows"], help = L["Draw countdowns and counts over the proc glow."], showWhen = function(settings) return Mirrors("essential", settings) end },
		{ type = "header", label = L["Text"] },
		{ type = "dropdown", key = "timerFont", label = L["Timer font"], help = L["The font of the countdown numbers."], options = FontOptions },
		{ type = "dropdown", key = "timerOutline", label = L["Timer outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
		{ type = "dropdown", key = "countFont", label = L["Count font"], help = L["The font of charge and stack counts."], options = FontOptions },
		{ type = "dropdown", key = "countOutline", label = L["Count outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
		{ type = "dropdown", key = "nameFont", label = L["Name font"], help = L["The font of the names on buff bars."], options = FontOptions },
		{ type = "dropdown", key = "nameOutline", label = L["Name outline"], help = L["A soft shadow, or an outline for busy backgrounds."], options = OUTLINE_OPTIONS },
	}
	IconRows(schema, "essential", L["Essential cooldowns"])
	IconRows(schema, "utility", L["Utility cooldowns"])
	IconRows(schema, "buffs", L["Tracked buff icons"])
	BarRows(schema)
	RuleRows(schema)
	Add(schema, { type = "header", label = L["Focus interrupt"] })
	Add(schema, { type = "text", key = "focusSpell", label = L["Interrupt spell"], help = L["Your interrupt, by name or ID. Its icon shows on your focus's nameplate."], maxLetters = MAX_RULE })
	Add(schema, { type = "dropdown", key = "focusSide", label = L["Nameplate side"], help = L["Which side of the nameplate the icon sits on."], options = SIDE_OPTIONS })
	Add(schema, { type = "toggle", key = "focusTarget", label = L["Show on target"], help = L["Use your target's nameplate instead of your focus's."] })
	Add(schema, { type = "dropdown", key = "focusSound", label = L["Focus cast sound"], help = L["Plays when your focus starts a cast while your interrupt is ready, or on any cast without one."], options = SOUND_OPTIONS })
	Add(schema, { type = "toggle", key = "focusReminder", label = L["Focus reminder"], help = L["In dungeons, mark enemy casters while you have no focus."] })
	table.insert(schema, 1, { type = "toggle", key = "attached", label = L["Attach cooldowns to the HUD"], help = L["Keep rows by the HUD. Turn off for the previous placement. Custom positions are kept."] })
	schema.preview = ns.Preview.Build
	Settings.schema = schema
	return schema
end

local function Section()
	local Store = K.Store
	if Store and Store.IsLoaded and Store.IsLoaded() then
		local ok, section = pcall(Store.Module, ns.MODULE)
		if ok and type(section) == "table" then
			return section
		end
	end
	return Settings.defaults
end

local function Number(value, range, fallback)
	if type(value) ~= "number" or ns.IsSecret(value) or value ~= value then
		return fallback
	end
	value = min(range[2], max(range[1], value))
	return floor(value / range[3] + 0.5) / (1 / range[3])
end

local function Choice(value, allowed, fallback)
	if not ns.IsSecret(value) and allowed[value] then
		return value
	end
	return fallback
end

local function Bool(value, fallback)
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

local function Unit(value)
	return type(value) == "number" and not ns.IsSecret(value) and value >= 0 and value <= 1
end

local function Font(value)
	if K.Theme.FollowsKit(value) then
		return "kit"
	end
	if K.Theme.IsFontPath(value) then
		return value
	end
	return "kit"
end

local function TexturePath(value, fallback)
	if type(value) == "string" and value ~= "" and #value <= MAX_PATH and not value:find("[%c|]") then
		return value
	end
	return fallback
end

local function Color(out, prefix, value, fallback)
	if type(value) == "table" and Unit(value.r) and Unit(value.g) and Unit(value.b) then
		out[prefix .. "R"], out[prefix .. "G"], out[prefix .. "B"] = value.r, value.g, value.b
	else
		out[prefix .. "R"], out[prefix .. "G"], out[prefix .. "B"] = fallback.r, fallback.g, fallback.b
	end
end

local current = { essential = {}, utility = {}, buffs = {}, bars = { grid = {} } }
Settings.current = current

local function ReadIcons(out, saved, defaults, group)
	saved = type(saved) == "table" and saved or defaults
	for key, range in pairs(ICON_RANGE) do
		if group == "essential" and key == "timerSize" then
			range = ESSENTIAL_TIMER_RANGE
		end
		if not COOLDOWN_GROUPS[group] or key ~= "columns" and key ~= "rows" then
			out[key] = Number(saved[key], range, defaults[key])
		end
	end
	out.growth = Choice(saved.growth, GROWTH, defaults.growth)
	if group == "buffs" and out.growth == defaults.growth and K.HudStyle.Current() == "medallions" then out.growth = "center" end
	out.wrap = Choice(saved.wrap, WRAP, defaults.wrap)
	out.timerPosition = Choice(saved.timerPosition, POSITION, "")
	out.inactiveShade = Choice(saved.inactiveShade, INACTIVE, "")
	for _, key in ipairs(ICON_FLAGS) do
		out[key] = Bool(saved[key], defaults[key] == true)
	end
	out.cellWidth, out.cellHeight = out.size, out.size
	if group == "buffs" and out.timer then
		out.cellHeight = out.cellHeight + out.timerSize + 4
	end
end

local function ReadBars(out, saved, defaults)
	saved = type(saved) == "table" and saved or defaults
	for key, range in pairs(BAR_RANGE) do
		out[key] = Number(saved[key], range, defaults[key])
	end
	out.growth = Choice(saved.growth, BAR_GROWTH, defaults.growth)
	out.texture = TexturePath(saved.texture, defaults.texture)
	out.colorSource = Choice(saved.colorSource, COLOR_SOURCE, defaults.colorSource)
	out.orientation = Choice(saved.orientation, ORIENTATION, defaults.orientation)
	Color(out, "color", saved.color, defaults.color)
	Color(out, "lineColor", saved.lineColor, defaults.lineColor)
	for _, key in ipairs(BAR_FLAGS) do
		out[key] = Bool(saved[key], defaults[key])
	end
	local grid = out.grid
	grid.cellWidth, grid.cellHeight, grid.spacing = out.width, out.height, out.spacing
	grid.columns, grid.rows, grid.growth = 1, out.count, "right"
	grid.wrap = out.growth == "down" and "down" or "up"
end

function Settings.Read()
	local saved, defaults = Section(), Settings.defaults
	for _, key in ipairs({ "quietCooldown", "readableCountdown", "medallionsIcons" }) do current[key] = Bool(saved[key], true) end
	current.path = Choice(saved.path, PATH, defaults.path)
	current.accent = Choice(saved.accent, ACCENT, defaults.accent)
	Color(current, "accent", saved.accentColor, defaults.accentColor)
	current.tooltips = Bool(saved.tooltips, defaults.tooltips)
	current.glowsInCombat, current.closeGaps = saved.glowsInCombat == true, saved.closeGaps == true
	current.fadeAlpha = Number(saved.fadeAlpha, FADE_RANGE, defaults.fadeAlpha)
	for _, key in ipairs({ "tint", "glow", "timer" }) do current[key .. "Source"] = Choice(saved[key .. "Source"], SOURCE, "class") end
	current.decimalBelow = Number(saved.decimalBelow, TENTHS_RANGE, defaults.decimalBelow)
	current.thresholdBelow = Number(saved.thresholdBelow, TENTHS_RANGE, defaults.thresholdBelow)
	current.swingWindow = Number(saved.swingWindow, SWING_RANGE, defaults.swingWindow)
	current.readySound, current.focusSound = Choice(saved.readySound, Settings.SOUNDS, ""), Choice(saved.focusSound, Settings.SOUNDS, "")
	current.focusSide = Choice(saved.focusSide, SIDE, "LEFT")
	current.textAboveGlow, current.focusTarget, current.focusReminder = saved.textAboveGlow == true, saved.focusTarget == true, saved.focusReminder == true
	local spell = saved.focusSpell
	current.focusSpell = type(spell) == "string" and not ns.IsSecret(spell) and #spell <= MAX_RULE and spell or ""
	for _, key in ipairs({ "tint", "glow", "range", "timer", "threshold" }) do Color(current, key, saved[key .. "Color"], defaults[key .. "Color"]) end
	local rules, savedRules = current.rules or {}, type(saved.rules) == "table" and saved.rules or {}
	for _, key in ipairs(RULES) do
		local text = savedRules[key]
		rules[key] = type(text) == "string" and not ns.IsSecret(text) and #text:gsub("[\128-\191]", "") <= MAX_RULE and text or ""
	end
	current.rules = rules
	for _, kind in ipairs({ "timer", "count", "name" }) do
		current[kind .. "Font"] = Font(saved[kind .. "Font"])
		current[kind .. "Outline"] = Choice(saved[kind .. "Outline"], OUTLINE, defaults[kind .. "Outline"])
	end
	for _, group in ipairs(ICON_GROUPS) do
		ReadIcons(current[group], saved[group], defaults[group], group)
		if COOLDOWN_GROUPS[group] then
			local _, _, columns, rows = Layouts.CooldownGrid(K.HudStyle.Current(), "cooldowns." .. group)
			current[group].columns, current[group].rows = columns, rows
			if current[group].wrap == "auto" then current[group].wrap = saved.attached ~= false and "up" or "down" end
		end
	end
	ReadBars(current.bars, saved.bars, defaults.bars)
	ns.Rules.Reset()
	return current
end

function Settings.Free(group)
	local el = K.Layout and K.Layout.Element("cooldowns." .. group)
	local s, d = el and el.settings, el and el.default
	return Section().attached == false or s ~= nil and d ~= nil and (s.anchor ~= d.anchor or s.x ~= d.x or s.y ~= d.y)
end

function Settings.SourceColor(key)
	if current[key .. "Source"] ~= "class" then
		return current[key .. "R"], current[key .. "G"], current[key .. "B"]
	end
	local class = K.Theme.Class()
	if class then return K.Theme.ClassColor(class) end
	return K.Theme.Accent()
end

function Settings.Accent()
	if current.accent == "custom" and current.accentR then
		return current.accentR, current.accentG, current.accentB
	end
	return K.Theme.Accent()
end

local function BarRGB()
	local bars = current.bars
	if bars.colorSource == "custom" and bars.colorR then
		return bars.colorR, bars.colorG, bars.colorB
	elseif bars.colorSource == "reaction" then
		return K.Theme.ReactionColor(5)
	end
	local class = K.Theme.Class()
	if class then
		return K.Theme.ClassColor(class)
	end
	return K.Theme.Accent()
end

function Settings.BarColor()
	local r, g, b = BarRGB()
	return r, g, b, current.bars.fillOpacity
end
