-- Text.lua: shared text settings and cached tag painters that pass restricted values straight to text setters.
local _, ns = ...
local W, L = ns.Widgets, ns.L

function W.TextRows(schema, key, opts)
	opts = opts or {}
	local function add(row)
		row.key = key .. "." .. row.key
		row.disableWhen = opts.disableWhen
		schema[#schema + 1] = opts.row and opts.row(row) or row
	end
	add({ type = opts.fontType or "font", key = "font", label = L["Font"], options = opts.fonts or W.InheritedFontOptions,
		help = L["Uses the role font unless you choose a font for this text."] })
	add({ type = "slider", key = "size", label = L["Text size"], min = 6, max = opts.max or 32, step = opts.step or 1,
		help = L["The size of this text, in interface units."] })
	add({ type = "dropdown", key = "outline", label = L["Outline"], options = opts.outlines,
		help = L["A soft shadow, or an outline for text over busy scenes."] })
	if not opts.tags then return end
	add({ type = "dropdown", key = "colorMode", label = L["Text colour"],
		help = L["Keep the current style, or choose class, reaction, accent or a custom colour."], options = {
		{ value = "", label = L["Current style"] }, { value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] }, { value = "accent", label = L["Accent"] },
		{ value = "custom", label = L["Custom colour"] },
	} })
	add({ type = "color", key = "color", label = L["Custom text colour"],
		help = L["The text colour when its colour mode is custom."], showWhen = opts.custom })
	add({ type = "text", key = "textFormat", label = L["Text format"], maxLetters = 160,
		help = L["Blank uses the preset. Tags: [name], [hp], [hp:pct], [hp:abr], [pp], [level], [absorb]."] })
end

local parsed = {}
local SAMPLE_FIELDS = { UnitName = "name", UnitHealth = "health", UnitHealthMax = "healthMax",
	UnitPower = "power", UnitPowerMax = "powerMax", UnitLevel = "level", UnitGetTotalAbsorbs = "absorb" }
local TAGS = {
	name = { "UnitName", "Name" }, hp = { "UnitHealth", "Health" },
	["hp:abr"] = { "UnitHealth", "Health", "short" }, ["hp:max"] = { "UnitHealthMax", "Health" },
	["hp:pct"] = { "UnitHealthPercent", "Health", "percent" }, pp = { "UnitPower", "Power" },
	["pp:abr"] = { "UnitPower", "Power", "short" }, ["pp:max"] = { "UnitPowerMax", "Power" },
	["pp:pct"] = { "UnitPowerPercent", "Power", "percent" }, level = { "UnitLevel", "Level" },
	absorb = { "UnitGetTotalAbsorbs", "Prediction" }, target = { "UnitName", "Target", "target" },
	group = { "group", "Group" },
}

function W.ParseText(format)
	local plan = parsed[format]
	if plan then return plan end
	plan = { events = {} }
	local pos = 1
	for first, tag, last in format:gmatch("()%[([^%]]+)%]()") do
		if first > pos then plan[#plan + 1] = format:sub(pos, first - 1) end
		local spec = TAGS[tag]
		plan[#plan + 1] = spec or format:sub(first, last - 1)
		if spec then plan.events[spec[2]] = true end
		pos = last
	end
	if pos <= #format then plan[#plan + 1] = format:sub(pos) end
	parsed[format] = plan
	return plan
end

local curve
local function Group(unit)
	if not (UnitInRaid and GetRaidRosterInfo) then return "" end
	local index = UnitInRaid(unit)
	if W.IsSecret(index) or not index then return "" end
	local _, _, subgroup = GetRaidRosterInfo(index)
	if not W.IsSecret(subgroup) and subgroup == nil then return "" end
	return subgroup
end

local function Percent(unit, power)
	local fn = power and UnitPowerPercent or UnitHealthPercent
	if type(fn) ~= "function" then return "" end
	if not curve then
		curve = CurveConstants and CurveConstants.ScaleTo100
		if not curve and C_CurveUtil and C_CurveUtil.CreateCurve then
			curve = C_CurveUtil.CreateCurve()
			curve:AddPoint(0, 0)
			curve:AddPoint(1, 100)
		end
	end
	if not curve then return "" end
	if power then return W.ShortNumber(fn(unit, nil, false, curve)) .. "%" end
	return W.ShortNumber(fn(unit, true, curve)) .. "%"
end

function W.TagText(text, format, unit, sample)
	local plan, result = W.ParseText(format), ""
	for i = 1, #plan do
		local spec, value = plan[i]
		if type(spec) == "string" then
			value = spec
		elseif sample then
			if spec[3] == "target" or spec[1] == "group" then
				value = sample[spec[3] == "target" and "targetName" or "group"] or ""
			elseif spec[3] == "percent" then
				local power = spec[2] == "Power"
				local max = sample[power and "powerMax" or "healthMax"] or 100
				value = W.ShortNumber(max > 0 and (sample[power and "power" or "health"] or 0) / max * 100 or 0) .. "%"
			else
				value = sample[SAMPLE_FIELDS[spec[1]]] or ""
				if spec[3] == "short" then value = W.ShortNumber(value) end
			end
		elseif spec[3] == "percent" then
			value = Percent(unit, spec[2] == "Power")
		elseif spec[1] == "group" then
			value = Group(unit)
		else
			local fn = _G[spec[1]]
			value = ""
			if type(fn) == "function" then value = fn(spec[3] == "target" and unit .. "target" or unit) end
			if spec[3] == "short" then value = W.ShortNumber(value) end
			if not W.IsSecret(value) and value == nil then value = "" end
		end
		result = result .. value
	end
	text:SetText(result)
end

function W.TextTint(text, mode, color, unit, sample)
	local player = sample and (sample.own or sample.isPlayer) or not sample and UnitIsPlayer and UnitIsPlayer(unit)
	if W.IsSecret(player) then player = false end
	if mode == "custom" then
		text:SetTextColor(color.r, color.g, color.b)
	elseif mode == "accent" then
		text:SetTextColor(ns.Theme.Accent())
	elseif mode == "class" and player then
		local class = sample and (sample.class or ns.Theme.Class()) or select(2, UnitClass(unit))
		text:SetTextColor(ns.Theme.ClassTextColorForWidget(class))
	elseif mode == "class" or mode == "reaction" then
		local reaction = sample and sample.reaction or UnitReaction and UnitReaction(unit, "player")
		text:SetTextColor(ns.Theme.ReactionColor(reaction))
	end
end
