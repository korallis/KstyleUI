-- Text.lua: shared text settings, cached tag painters that pass restricted values straight to text setters, and the short key labels keybind text uses (SHIFT-1 reads S1).
local _, ns = ...
local W, L = ns.Widgets, ns.L
local placementPoints, textColors

function W.TextColors()
	textColors = textColors or { { value = "", label = L["Current style"] }, { value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] }, { value = "accent", label = L["Accent"] }, { value = "custom", label = L["Custom colour"] } }
	return textColors
end

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
		help = L["Keep the current style, or choose class, reaction, accent or a custom colour."], options = W.TextColors() })
	add({ type = "color", key = "color", label = L["Custom text colour"],
		help = L["The text colour when its colour mode is custom."], showWhen = opts.custom })
	add({ type = "text", key = "textFormat", label = L["Text format"], maxLetters = 160,
		help = opts.placement and L["Blank hides it. Tags: [name] [hp:pct] [pp:abr] [level] [absorb] [target] [group] [c:ff8800]x[/c]."]
			or L["Blank uses the preset. Tags: [name] [hp] [hp:pct] [hp:abr] [pp] [level] [absorb] [c:ff8800]x[/c]."] })
	if opts.placement then
		placementPoints = placementPoints or {
			{ value = "CENTER", label = L["Centre"] },
			{ value = "TOPLEFT", label = L["Top left"] }, { value = "TOP", label = L["Top"] }, { value = "TOPRIGHT", label = L["Top right"] },
			{ value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] },
			{ value = "BOTTOMLEFT", label = L["Bottom left"] }, { value = "BOTTOM", label = L["Bottom"] }, { value = "BOTTOMRIGHT", label = L["Bottom right"] },
		}
		add({ type = "dropdown", key = "position", label = L["Place"], help = L["Where this text sits on the frame."], options = placementPoints })
		add({ type = "slider", key = "x", label = L["Horizontal offset"], help = L["Moves this text left or right."], min = -200, max = 200, step = 1 })
		add({ type = "slider", key = "y", label = L["Vertical offset"], help = L["Moves this text up or down."], min = -200, max = 200, step = 1 })
	end
	if opts.width then
		add({ type = "slider", key = "width", label = L["Text width"], help = L["How much of the frame's width this text may use, in percent."], min = 20, max = 100, step = 5 })
	end
end

local TEXT_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local function Offset(value)
	return type(value) == "number" and value == value and math.max(-200, math.min(200, value)) or 0
end

function W.PlaceText(text, cfg, parent, anchor, width)
	local on = type(cfg.textFormat) == "string" and cfg.textFormat ~= ""
	if on then
		if not text then
			text = W.FontString(parent, "OVERLAY")
			text:SetWordWrap(false)
		end
		local position = TEXT_POINTS[cfg.position] and cfg.position or "CENTER"
		local path = ns.Theme.IsFontPath(cfg.font) and cfg.font or (ns.Tokens.Font("number"))
		local size = type(cfg.size) == "number" and math.max(6, math.min(32, cfg.size)) or 12
		W.ApplyFont(text, path, size * ns.Theme.FontScale(), cfg.outline == "NONE" and "" or cfg.outline == "THICKOUTLINE" and "THICKOUTLINE" or "OUTLINE")
		text:SetTextColor(ns.Tokens.Color("textEmphasis"))
		text:ClearAllPoints()
		text:SetPoint(position, anchor, position, W.Snap(anchor, Offset(cfg.x)), W.Snap(anchor, Offset(cfg.y)))
		width = width or anchor:GetWidth()
		if type(cfg.width) == "number" and cfg.width >= 20 and cfg.width < 100 then width = width * cfg.width / 100 end
		text:SetWidth(W.Snap(anchor, width))
		text:SetJustifyH(position:find("LEFT") and "LEFT" or position:find("RIGHT") and "RIGHT" or "CENTER")
	end
	if text then text:SetShown(on) end
	return text
end

function W.BarRows(schema, key, opts)
	local function add(row)
		row.help = opts.help and opts.help[row.key] or row.help
		row.key = (key ~= "" and key .. "." or "") .. (opts.keys and opts.keys[row.key] or row.key)
		row.disableWhen = opts.disableWhen
		schema[#schema + 1] = opts.row and opts.row(row) or row
	end
	if opts.texture ~= false then
		add({ type = "texture", key = "texture", label = L["Bar texture"], help = L["The texture the bar is filled with."] })
	end
	if opts.colors ~= false then
		add({ type = "dropdown", key = "colorSource", label = L["Bar colour"], options = opts.options,
			help = L["Where the bar's colour comes from."] })
		add({ type = "color", key = "color", label = L["Custom bar colour"], showWhen = opts.custom,
			help = L["The bar's colour when its colour source is custom."] })
	end
	local h = opts.height
	if h then
		add({ type = "slider", key = h.key or "height", label = L["Bar height"], min = h[1], max = h[2], step = h[3],
			help = L["The height of each bar, in interface units."] })
	end
end

local parsed = {}
local SAMPLE_FIELDS = { UnitName = "name", UnitHealth = "health", UnitHealthMax = "healthMax",
	UnitPower = "power", UnitPowerMax = "powerMax", UnitLevel = "level", UnitGetTotalAbsorbs = "absorb", UnitPVPName = "pvpName" }
local TAGS = {
	name = { "UnitName", "Name" }, title = { "UnitPVPName", "Name", nil, "UnitName" }, hp = { "UnitHealth", "Health" },
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
		local spec, hex = TAGS[tag], tag:match("^c:(%x%x%x%x%x%x)$")
		plan[#plan + 1] = spec or hex and "|cff" .. hex or tag == "/c" and "|r" or format:sub(first, last - 1)
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
	if power then return W.ShortNumber(W.WholePercent(fn(unit, nil, false, curve))) .. "%" end
	return W.ShortNumber(W.WholePercent(fn(unit, true, curve))) .. "%"
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
				value = W.ShortNumber(W.WholePercent(max > 0 and (sample[power and "power" or "health"] or 0) / max * 100 or 0)) .. "%"
			else
				value = sample[SAMPLE_FIELDS[spec[1]]] or ""
				if spec[3] == "short" then value = W.ShortNumber(value) end
			end
		elseif spec[3] == "percent" then
			value = Percent(unit, spec[2] == "Power")
		elseif spec[1] == "group" then
			value = Group(unit)
		else
			local fn = _G[spec[1]] or spec[4] and _G[spec[4]]
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

local MODIFIERS = { { "ALT-", "A" }, { "CTRL-", "C" }, { "SHIFT-", "S" }, { "META-", "Cm" } }
local KEYS = {
	MIDDLEBUTTON = "M3", MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD", NUMPADPLUS = "N+", NUMPADMINUS = "N-",
	NUMPADMULTIPLY = "N*", NUMPADDIVIDE = "N/", NUMPADDECIMAL = "N.", SPACE = "Sp", PAGEUP = "PU", PAGEDOWN = "PD",
	BACKSPACE = "Bs", INSERT = "Ins", DELETE = "Del", HOME = "Hm", ["END"] = "End", CAPSLOCK = "Cap", TAB = "Tab",
	ENTER = "Ent", ESCAPE = "Esc", UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt",
}

function W.ShortKey(key, fallback)
	if type(key) ~= "string" or key == "" then
		return ""
	end
	local prefix, rest = "", key
	for _, modifier in ipairs(MODIFIERS) do
		local word, short = modifier[1], modifier[2]
		if rest:sub(1, #word) == word then
			prefix, rest = prefix .. short, rest:sub(#word + 1)
		end
	end
	local short = KEYS[rest]
	if not short then
		local mouse = rest:match("^BUTTON(%d+)$")
		local pad = rest:match("^NUMPAD(%d)$")
		if mouse then
			short = "M" .. mouse
		elseif pad then
			short = "N" .. pad
		elseif #rest <= 3 then
			short = rest
		elseif fallback then
			short = fallback(key)
			if type(short) ~= "string" then
				short = rest
			end
			return short
		else
			short = rest
		end
	end
	return prefix .. short
end
