-- Module.lua: registers the Auras module, its settings page and live preview, and its smoke check.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Model, Panel, Preview = ns.Model, ns.Panel, ns.Preview
local LIMITS = Model.LIMITS
local MODULE = Model.MODULE

K.Modules.Register({
	name = MODULE,
	defaults = Model.defaults,
	Enable = function()
		Panel.Enable()
	end,
	Disable = function()
		Panel.Disable()
	end,
})

local function BuildSchema()
	local function slider(key, label, help, limit, disableWhen)
		return { type = "slider", key = key, label = label, help = help, min = limit.min, max = limit.max, step = limit.step, disableWhen = disableWhen }
	end

	local function swipeOff(settings, name)
		local group = settings[name]
		return type(group) ~= "table" or group.swipe ~= true
	end

	local function groupRows(schema, name)
		local rows = {
			{ type = "dropdown", key = name .. ".show", label = L["Show"], options = Model.SHOW_OPTIONS[name], help = L["Every aura, or only one of Blizzard's aura categories."] },
			{ type = "toggle", key = name .. ".timed", label = L["Only ones with a duration"], help = L["Hides auras that never run out, such as stances and passives."] },
			slider(name .. ".iconSize", L["Icon size"], L["How large each icon is, in units at 1080p."], LIMITS.iconSize),
			slider(name .. ".spacing", L["Spacing"], L["The gap between icons in a row."], LIMITS.spacing),
			slider(name .. ".rowSpacing", L["Row spacing"], L["The gap between rows."], LIMITS.spacing),
			slider(name .. ".rows", L["Rows"], L["How many rows of icons show before the rest count as +N on the last icon."], LIMITS.rows),
			slider(name .. ".columns", L["Icons per row"], L["How many icons fit in one row before the next row starts."], LIMITS.columns),
			{
				type = "dropdown", key = name .. ".growth", label = L["Growth"], options = Model.GROWTH_OPTIONS,
				help = L["Which way new icons are added, and where the next row starts."],
			},
			{
				type = "dropdown", key = name .. ".sort", label = L["Sort by"], options = Model.SORT_OPTIONS,
				help = L["The order the icons are shown in."],
			},
			{
				type = "toggle", key = name .. ".reverse", label = L["Reverse order"],
				help = L["Flips the sort order, so the last icon comes first."],
			},
			{ type = "toggle", key = name .. ".swipe", label = L["Duration swipe"], help = L["Show the shaded duration sweep on each icon."] },
			{
				type = "toggle", key = name .. ".swipeReverse", label = L["Reverse swipe"], help = L["The shade clears as time runs out. Off fills the icon instead."],
				disableWhen = function(settings) return swipeOff(settings, name) end,
			},
			{ type = "dropdown", key = name .. ".tooltips", label = L["Tooltips"], options = Model.TOOLTIP_OPTIONS, help = L["When hovering an icon shows its tooltip."] },
			{ type = "toggle", key = name .. ".refresh", label = L["Mark when refreshable"], help = L["A gold line under an aura you can refresh without losing time."] },
		}
		K.Options.AuraFilterRows(schema, name, { sort = false })
		for _, row in ipairs(rows) do
			schema[#schema + 1] = row
		end
	end

	local function customAccent(settings)
		local accent = settings.accent
		return type(accent) == "table" and accent.source == "custom"
	end

	local function timerHidden(settings)
		local timer = settings.timer
		return type(timer) == "table" and timer.format == "none"
	end

	local function countHidden(settings)
		return settings.count.shown == false
	end

	local function plainTimer(settings)
		local format = type(settings.timer) == "table" and settings.timer.format
		return format ~= "short" and format ~= "decimal"
	end

	local function typeIconOff(settings)
		return type(settings.debuffs) ~= "table" or settings.debuffs.typeIcon == "none"
	end

	local function colorRows(section, label, hidden)
		return {
			type = "toggle", key = section .. ".customColor", label = L["Custom colour"], help = L["Pick a colour for this text instead of the kit's."], disableWhen = hidden,
		}, {
			type = "color", key = section .. ".color", label = label, help = L["The colour of this text."],
			disableWhen = function(settings) return hidden(settings) or settings[section].customColor ~= true end,
		}
	end

	local schema = {
		{ type = "toggle", key = "medallionsIcons", label = L["Match Medallions sockets"], help = L["Uses a dark metal rim around aura tiles in Medallions. Off restores the black rim."] },
		{ type = "header", label = L["Rows"] },
		slider("iconZoom", L["Icon zoom"], L["How much of the icon's edge is cropped."], LIMITS.iconZoom),
		slider("hiddenAlpha", L["Opacity when hidden"], L["How visible the rows stay while their Shown rule hides them. 0 hides them."], LIMITS.hiddenAlpha),
		{
			type = "toggle", key = "hideBlizzard", label = L["Hide Blizzard's buff frames"],
			help = L["Hides the default buff and debuff frames while these rows show your auras."],
		},
		{ type = "header", label = L["Buffs"] },
	}
	groupRows(schema, "buffs")
	schema[#schema + 1] = {
		type = "dropdown", key = "buffs.tracked", label = L["Buffs the Cooldown Manager tracks"], options = Model.TRACKED_OPTIONS,
		help = L["A buff the Cooldown Manager already tracks is left out of this row, so it shows in one place."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "buffs.enchants", label = L["Weapon enchantments"],
		help = L["Shows temporary weapon enchantments, such as poisons and oils, before your buffs."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "buffs.cancel", label = L["Right-click to cancel"],
		help = L["Right-clicking a buff or weapon enchantment removes it."],
	}
	schema[#schema + 1] = {
		type = "text", key = "buffs.allowSpells", label = L["Only these spells"], maxLetters = 240,
		help = L["Spell IDs of buffs to show, separated by commas or spaces. Blank shows every buff."],
	}
	schema[#schema + 1] = {
		type = "text", key = "buffs.blockSpells", label = L["Hide these spells"], maxLetters = 240,
		help = L["Spell IDs of buffs to hide, separated by commas or spaces. Hiding wins."],
	}
	schema[#schema + 1] = { type = "header", label = L["Debuffs"] }
	groupRows(schema, "debuffs")
	schema[#schema + 1] = {
		type = "toggle", key = "debuffs.dispel", label = L["Colour by debuff type"],
		help = L["Borders each debuff in its type's colour: magic, curse, disease, poison or none."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "debuffs.typeIcon", label = L["Type icon"], options = Model.TYPE_ICON_OPTIONS,
		help = L["Shows the magic, curse, disease, poison or bleed symbol in a corner of each debuff."],
	}
	schema[#schema + 1] = slider("debuffs.typeIconSize", L["Type icon size"], L["How large the type symbol is."], LIMITS.typeIconSize, typeIconOff)

	local timerToggle, timerColor = colorRows("timer", L["Timer colour"], timerHidden)
	local countToggle, countColor = colorRows("count", L["Stack colour"], countHidden)
	local rest = {
		{ type = "header", label = L["Timers"] },
		{
			type = "dropdown", key = "timer.format", label = L["Timer format"], options = Model.TIMER_FORMATS,
			help = L["How the time left on each aura is written."],
		},
		{
			type = "dropdown", key = "timer.position", label = L["Timer position"], options = Model.TIMER_POSITIONS,
			help = L["Puts the timer under the icon, or on its lower edge, top edge or centre."], disableWhen = timerHidden,
		},
		slider("timer.x", L["Horizontal offset"], L["Move this text left or right."], LIMITS.offset, timerHidden),
		slider("timer.y", L["Vertical offset"], L["Move this text up or down."], LIMITS.offset, timerHidden),
		{ type = "font", key = "timer.font", label = L["Timer font"], help = L["The typeface of the timers."], options = K.Widgets.InheritedFontOptions, disableWhen = timerHidden },
		slider("timer.size", L["Timer size"], L["The text size of the timers."], LIMITS.timerSize, timerHidden),
		{
			type = "dropdown", key = "timer.outline", label = L["Timer outline"], options = Model.OUTLINES,
			help = L["A soft shadow, or an outline that reads well over bright scenes."], disableWhen = timerHidden,
		},
		slider("timer.expiring", L["Warn under"], L["Seconds left when a timer turns red. 0 turns the warning off."], LIMITS.expiring, timerHidden),
		{ type = "toggle", key = "timer.seconds", label = L["Seconds suffix"], help = L["Writes 24s rather than 24."], disableWhen = plainTimer },
		slider("timer.precise", L["Minutes and seconds under"], L["Below this many minutes, timers read 4:05. 0 turns it off."], LIMITS.precise, plainTimer),
		timerToggle, timerColor,
		{ type = "header", label = L["Stack counts"] },
		{ type = "toggle", key = "count.shown", label = L["Show stack counts"], help = L["Show the number of applications on aura icons."] },
		{ type = "font", key = "count.font", label = L["Stack font"], help = L["The typeface of the stack counts on the icons."], options = K.Widgets.InheritedFontOptions },
		slider("count.size", L["Stack size"], L["The text size of the stack counts."], LIMITS.countSize),
		{
			type = "dropdown", key = "count.outline", label = L["Stack outline"], options = Model.OUTLINES,
			help = L["A soft shadow, or an outline that reads well over bright icons."],
		},
		slider("count.x", L["Horizontal offset"], L["Move this text left or right."], LIMITS.offset, countHidden),
		slider("count.y", L["Vertical offset"], L["Move this text up or down."], LIMITS.offset, countHidden),
		{ type = "dropdown", key = "count.position", label = L["Stack position"], options = Model.CORNERS, help = L["Which corner of the icon the stack count sits in."], disableWhen = countHidden },
		countToggle, countColor,
		{ type = "header", label = L["Accent"] },
		{
			type = "dropdown", key = "accent.source", label = L["Buff border colour"], options = Model.ACCENT_SOURCES,
			help = L["Your class colour, or a colour you pick, for the thin line around each buff."],
		},
		{
			type = "color", key = "accent.color", label = L["Custom colour"], showWhen = customAccent,
			help = L["The colour of the line around each buff."],
		},
	}
	for _, row in ipairs(rest) do
		schema[#schema + 1] = row
	end
	schema.preview = Preview.Build

	return schema
end

K.Options.Register(MODULE, BuildSchema)

K.DevTest.AddCheck(MODULE, function()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	return Panel.Status()
end)
