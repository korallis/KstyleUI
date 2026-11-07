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

local function slider(key, label, help, limit, disableWhen)
	return { type = "slider", key = key, label = label, help = help, min = limit.min, max = limit.max, step = limit.step, disableWhen = disableWhen }
end

local function groupRows(schema, name)
	local rows = {
		slider(name .. ".iconSize", L["Icon size"], L["How large each icon is, in units at 1080p."], LIMITS.iconSize),
		slider(name .. ".spacing", L["Spacing"], L["The gap between icons in a row."], LIMITS.spacing),
		slider(name .. ".rowSpacing", L["Row spacing"], L["The gap between rows."], LIMITS.spacing),
		slider(name .. ".rows", L["Rows"], L["How many rows of icons show before the rest are left out."], LIMITS.rows),
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
	}
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

local schema = {
	{ type = "header", label = L["Panel"] },
	{
		type = "toggle", key = "hideBlizzard", label = L["Hide Blizzard's buff frames"],
		help = L["Hides the default buff and debuff frames while this panel shows your auras."],
	},
	{ type = "header", label = L["Buffs"] },
}
groupRows(schema, "buffs")
schema[#schema + 1] = {
	type = "toggle", key = "buffs.enchants", label = L["Weapon enchantments"],
	help = L["Shows temporary weapon enchantments, such as poisons and oils, before your buffs."],
}
schema[#schema + 1] = {
	type = "toggle", key = "buffs.cancel", label = L["Right-click to cancel"],
	help = L["Right-clicking a buff or weapon enchantment removes it."],
}
schema[#schema + 1] = { type = "header", label = L["Debuffs"] }
groupRows(schema, "debuffs")
schema[#schema + 1] = {
	type = "toggle", key = "debuffs.dispel", label = L["Colour by debuff type"],
	help = L["Borders each debuff in its type's colour: magic, curse, disease, poison or none."],
}

local rest = {
	{ type = "header", label = L["Timers"] },
	{
		type = "dropdown", key = "timer.format", label = L["Timer format"], options = Model.TIMER_FORMATS,
		help = L["How the time left on each aura is written."],
	},
	{
		type = "dropdown", key = "timer.position", label = L["Timer position"], options = Model.TIMER_POSITIONS,
		help = L["Puts the timer under the icon or on its lower edge."], disableWhen = timerHidden,
	},
	{ type = "font", key = "timer.font", label = L["Timer font"], help = L["The typeface of the timers."], disableWhen = timerHidden },
	slider("timer.size", L["Timer size"], L["The text size of the timers."], LIMITS.timerSize, timerHidden),
	{
		type = "dropdown", key = "timer.outline", label = L["Timer outline"], options = Model.OUTLINES,
		help = L["A soft shadow, or an outline that reads well over bright scenes."], disableWhen = timerHidden,
	},
	slider("timer.expiring", L["Warn under"], L["Seconds left when a timer turns red. 0 turns the warning off."], LIMITS.expiring, timerHidden),
	{ type = "header", label = L["Stack counts"] },
	{ type = "font", key = "count.font", label = L["Stack font"], help = L["The typeface of the stack counts on the icons."] },
	slider("count.size", L["Stack size"], L["The text size of the stack counts."], LIMITS.countSize),
	{
		type = "dropdown", key = "count.outline", label = L["Stack outline"], options = Model.OUTLINES,
		help = L["A soft shadow, or an outline that reads well over bright icons."],
	},
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

K.Options.Register(MODULE, schema)

K.DevTest.AddCheck(MODULE, function()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	return Panel.Status()
end)
