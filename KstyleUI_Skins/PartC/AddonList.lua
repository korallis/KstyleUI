-- AddonList.lua: the addon list skin: the window on glass, its controls restyled, and each addon row with a KstyleUI check box and an accent highlight.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "addonList"
local LINE_ALPHA = 0.5
local BUTTONS = { "CancelButton", "OkayButton", "EnableAllButton", "DisableAllButton" }

local rows = setmetatable({}, { __mode = "k" })

local function Category(row)
	if not rows[row] then
		rows[row] = true
		Kit.Highlight(row)
		Parts.AccentLine(row, { alpha = LINE_ALPHA })
	end
	Style.Text(row.Title, "caption", "textEmphasis")
end

local function Entry(row)
	if not rows[row] then
		rows[row] = true
		Kit.Highlight(row)
		if type(row.Enabled) == "table" then
			Kit.CheckBox(row.Enabled)
			Kit.TriState(row.Enabled)
		end
		if type(row.LoadAddonButton) == "table" then
			Kit.Button(row.LoadAddonButton)
		end
	end
	if row.Title then
		Style.Text(row.Title, "body")
	end
	if row.Status then
		Style.Text(row.Status, "caption")
	end
	if row.Reload then
		Style.Text(row.Reload, "caption")
	end
end

local function Row(row)
	if type(row.CollapseExpand) == "table" and row.Title then
		Category(row)
	else
		Entry(row)
	end
end

local function Performance(perf)
	Kit.Texts(perf, "body")
	if perf.Header then
		Style.Text(perf.Header, "caption", "text")
	end
	Parts.Divider(perf, perf.Divider)
end

local function Apply()
	local frame = Kit.Frame(KEY, "AddonList")
	if not frame then
		return
	end
	Kit.Window(frame)
	local drop = Kit.Child(KEY, frame, "Dropdown")
	if drop then
		Parts.Dropdown(drop)
	end
	local force = Kit.Child(KEY, frame, "ForceLoad")
	if force then
		Kit.CheckBox(force)
		Kit.Texts(force, "body")
	end
	local search = Kit.Child(KEY, frame, "SearchBox")
	if search then
		Kit.EditBox(search, { "searchIcon" })
	end
	local perf = Kit.Child(KEY, frame, "Performance")
	if perf then
		Performance(perf)
	end
	Kit.Each(KEY, frame, BUTTONS, Kit.Button)
	local bar = Kit.Child(KEY, frame, "ScrollBar")
	if bar then
		Kit.ScrollBar(bar)
	end
	local box = Kit.Child(KEY, frame, "ScrollBox")
	if box then
		Parts.EachRow(box, Row)
	end
end

Skins.Add({
	key = KEY,
	label = L["Addon list"],
	help = L["Restyles the addon list: its rows, check boxes, search and buttons."],
	addon = "Blizzard_AddOnList",
	frame = "AddonList",
	Apply = Apply,
})
