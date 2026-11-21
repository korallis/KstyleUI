-- Auras.lua: frame auras on the AuraContainer engine, sorted by the engine (yours, then priority, then time left), capped at rows by columns with a "+N" overflow chip one tile tall (over the last tile, or after it where timers sit under the tiles, so no aura's timer sits under the count), each timer under its tile or in a corner badge, with aura buttons touched only while C_Secrets.ShouldAurasBeSecret says aura data is readable.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings = ns.Settings
local Overflow = ns.Overflow

local Auras = {}
ns.Auras = Auras

local MODULE = Settings.MODULE
local OWNER = MODULE .. ":auras"
local TEMPLATE = "CustomAuraContainerTemplate"
local ENGINE_ADDON = "Blizzard_AuraContainer"
local GROUPS = { "debuffs", "buffs" }
local FILTERS = {
	mine = { debuffs = "HARMFUL|PLAYER" },
	debuffs = { debuffs = "HARMFUL" },
	buffs = { buffs = "HELPFUL" },
	both = { debuffs = "HARMFUL", buffs = "HELPFUL" },
}
local START_FILTER = { debuffs = "HARMFUL", buffs = "HELPFUL" }
local GROWTH = {
	RIGHT_DOWN = { "TOPLEFT", "Right", "Down" },
	RIGHT_UP = { "BOTTOMLEFT", "Right", "Up" },
	LEFT_DOWN = { "TOPRIGHT", "Left", "Down" },
	LEFT_UP = { "BOTTOMRIGHT", "Left", "Up" },
}
local POSITION = {
	CENTER = { "TOP", "BOTTOM", 0, -1, false, centred = true },
	BELOW = { "TOPLEFT", "BOTTOMLEFT", 0, -1, true },
	ABOVE = { "BOTTOMLEFT", "TOPLEFT", 0, 1, true },
	RIGHT = { "TOPLEFT", "TOPRIGHT", 1, 0, false },
	LEFT = { "TOPRIGHT", "TOPLEFT", -1, 0, false },
	SIDE = { "TOPLEFT", "TOPRIGHT", 1, 0, false, below = true },
}
local GAP = 2
local ICON_INSET_LINES = 2
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local COUNT_INSET = 1
local SWIPE_ALPHA = 0.65
local DISPEL_SUBLEVEL = 7
local TIMER_BELOW_GAP = 1
local COLUMN_TIMER_GAP = 4
local TIMER_ROOM_EXTRA = 3
local BADGE_PAD, BADGE_ALPHA = 1, 0.62
local TEXT_FLOOR, TEXT_LINE = 10, 1.2
local CHIP_LEVEL = 8
local SLAB_ICON_INSET, SLAB_UNDERLINE = 2, 1.5
local SORT = "Expiration"
local LANES = { { "buffDefensive", "BIG_DEFENSIVE" }, { "buffDispellable", "DISPELLABLE" } }
local LOCKOUTS = { [57723] = true, [57724] = true, [80354] = true, [95809] = true, [160455] = true, [264689] = true, [390435] = true }
local TRACK = OWNER .. ":track"
local FIXED_UNIT = { player = true, pet = true }

local issecretvalue = issecretvalue or function()
	return false
end

local function PoolStyle(view)
	return Settings.AuraRows(view.kind) and "medallionsRows" or K.HudStyle.Current()
end

local views = {}
local pending = {}
local waiting = false
local running = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

function Auras.Open()
	if InCombatLockdown() then
		return false
	end
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		if not ok or issecretvalue(secret) then
			return false
		end
		return secret ~= true
	end
	LogOnce("gate", "frame auras: C_Secrets.ShouldAurasBeSecret is missing; aura buttons restyle only out of combat")
	return true
end

local function Value(view, key)
	return Settings.Value(view.kind, key)
end

local function TextSize(kind, size)
	local tile = Settings.Value(kind, "auraSize")
	local room = math.floor((tile - 2 * COUNT_INSET) / (2 * TEXT_LINE))
	return math.max(size, math.min(TEXT_FLOOR, room))
end

local STYLE_KEYS = { "auraCountSize", "auraCountPoint", "auraCountX", "auraCountY", "auraTimerX", "auraTimerY", "auraDispel", "auraBuffDispel", "auraStealable" }

local function TextStyle(view)
	if view.auraStyle then return view.auraStyle end
	local path, size, flags = Settings.Font(view.kind, "aura")
	local style = { path, TextSize(view.kind, size), flags }
	for _, key in ipairs(STYLE_KEYS) do
		style[key] = Settings.Value(view.kind, key)
	end
	if view.auras then view.auraStyle = style end
	return style
end

local function Off(region, units)
	return units ~= 0 and Widgets.Snap(region, units) or 0
end

local function StyleTexts(count, timer, style)
	local path, size, flags = unpack(style)
	local countSize = style.auraCountSize
	for _, text in ipairs({ count, timer }) do
		local own = text == count and countSize > 0 and math.max(6, countSize) * K.Theme.FontScale() or size
		if not Widgets.ApplyFont(text, path, own, flags) then
			Widgets.ApplyFont(text, (Tokens.Font("number")), own, flags)
		end
		pcall(text.SetTextColor, text, Tokens.Color("textEmphasis"))
	end
end

local function Snap(view, units)
	return Widgets.Snap(view.auras.host, units)
end

function Auras.SampleTile(parent)
	local tile = Auras.NewTile(parent)
	local over = CreateFrame("Frame", nil, tile.skin)
	over:SetAllPoints(tile.skin)
	over:SetFrameLevel(tile.skin:GetFrameLevel() + 2)
	local count = Widgets.Fitted(Widgets.FontString(over, "OVERLAY"))
	count:SetPoint("TOPRIGHT", tile.skin, "TOPRIGHT", COUNT_INSET, COUNT_INSET)
	count:SetJustifyH("RIGHT")
	tile.count, tile.timer = count, Widgets.Fitted(Widgets.FontString(over, "OVERLAY"))
	tile.badge = over:CreateTexture(nil, "BACKGROUND")
	tile.countBadge = Auras.Badge(over, count)
	return tile
end

function Auras.Zoom(entry, kind)
	local zoom = entry.buff and Settings.Value(kind, "auraBuffZoom") or -1
	if zoom < 0 then zoom = Settings.Value(kind, "auraZoom") end
	entry.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	local button = entry.button
	if button and button.SetHideTooltipInCombat then
		button:SetHideTooltipInCombat(not Settings.Value(kind, "auraTooltipCombat"))
	end
end

local function PlaceCount(count, skin, style)
	local point = style.auraCountPoint
	local inset = Widgets.Snap(skin, COUNT_INSET)
	local side = point == "TOPLEFT" and -inset or point == "TOPRIGHT" and inset or 0
	count:ClearAllPoints()
	count:SetPoint(point, skin, point, side + Off(skin, style.auraCountX), (point == "CENTER" and 0 or inset) + Off(skin, style.auraCountY))
	if point ~= "TOPRIGHT" or count.countPoint then
		count.countPoint = point
		count:SetJustifyH(point == "TOPLEFT" and "LEFT" or point == "TOPRIGHT" and "RIGHT" or "CENTER")
	end
end

function Auras.StyleSample(tile, kind, role)
	local style = TextStyle({ kind = kind })
	Auras.Zoom(tile, kind)
	PlaceCount(tile.count, tile.skin, style)
	StyleTexts(tile.count, tile.timer, style)
	Auras.PlaceTimer(tile.timer, tile.skin, kind, tile.badge, style)
	local buff = role ~= "debuff"
	local edge = role and FILTERS[Settings.Value(kind, "auraFilter")][buff and "buffs" or "debuffs"] and style[buff and "auraBuffDispel" or "auraDispel"] and not (role == "buff" and style.auraStealable)
	if edge and not tile.dispel then
		tile.dispel = Widgets.NineSlice(tile.skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
		Widgets.LayoutSlice(tile.dispel, tile.skin, tile.chrome:Chamfer(), 0)
		Widgets.ColorSlice(tile.dispel, Tokens.Color("magic"))
	end
	if tile.dispel then Widgets.ShowSlice(tile.dispel, edge and true or false) end
end

function Auras.NewTile(parent, chrome)
	local skin = CreateFrame("Frame", nil, parent)
	chrome = chrome or Widgets.IconChrome(skin)
	local icon = skin:CreateTexture(nil, "ARTWORK")
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	return { skin = skin, chrome = chrome, restyleChrome = chrome.Restyle, icon = icon, mask = mask }
end

function Auras.LayoutTile(tile, skipChrome, sharedInset)
	local skin = tile.skin
	if tile.slab then
		Widgets.LayoutSlice(tile.slab, skin, select(3, Tokens.Texture("medAuraBorder")))
		local inset = Widgets.Snap(skin, SLAB_ICON_INSET)
		tile.icon:ClearAllPoints()
		tile.icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
		tile.icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
		tile.underline:SetHeight(math.max(Widgets.Border(skin), Widgets.Snap(skin, SLAB_UNDERLINE)))
		return
	end
	if not skipChrome then
		tile.restyleChrome(tile.chrome)
		tile.chrome:SetRimAccent(Settings.Accent())
	end
	local inset = sharedInset or Widgets.Border(skin) * ICON_INSET_LINES
	tile.icon:ClearAllPoints()
	tile.icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	tile.icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	if tile.dispel then
		Widgets.LayoutSlice(tile.dispel, skin, tile.chrome:Chamfer(), 0)
	end
end

local function Centred(kind)
	if Settings.Form(kind) == "bar" then
		return true
	end
	local position = POSITION[Settings.Value(kind, "auraPosition")]
	return position ~= nil and position.centred == true
end

local function TimerBelow(kind)
	if Settings.AuraRows(kind) then return Settings.Value(kind, "auraTimer") == true end
	local position = POSITION[Settings.Value(kind, "auraPosition")]
	local below = Centred(kind) or position ~= nil and position.below == true
	return below and Settings.Value(kind, "auraTimer") == true and Settings.Value(kind, "auraRows") == 1
end

local function TimerRoom(kind)
	if not TimerBelow(kind) then
		return 0
	end
	local _, fontSize = Settings.Font(kind, "aura")
	local gap = Settings.Form(kind) == "column" and COLUMN_TIMER_GAP or TIMER_BELOW_GAP
	return gap + TextSize(kind, fontSize) + TIMER_ROOM_EXTRA
end

function Auras.TimerRoom(kind)
	return TimerRoom(kind)
end

function Auras.PlaceTimer(timer, skin, kind, badge, style)
	timer:ClearAllPoints()
	local below = TimerBelow(kind)
	style = style or TextStyle({ kind = kind })
	local dx, dy = Off(skin, style.auraTimerX), Off(skin, style.auraTimerY)
	if below then
		local gap = Settings.Form(kind) == "column" and COLUMN_TIMER_GAP or TIMER_BELOW_GAP
		timer:SetPoint("TOP", skin, "BOTTOM", dx, dy - Widgets.Snap(skin, gap))
		timer:SetJustifyH("CENTER")
	else
		local inset = Widgets.Snap(skin, COUNT_INSET)
		timer:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", dx - inset, dy + inset)
		timer:SetJustifyH("RIGHT")
	end
	if badge then
		local pad = Widgets.Snap(skin, BADGE_PAD)
		badge:ClearAllPoints()
		badge:SetPoint("TOPLEFT", timer, "TOPLEFT", -pad, pad)
		badge:SetPoint("BOTTOMRIGHT", timer, "BOTTOMRIGHT", pad, -pad)
		badge:SetColorTexture(Widgets.Rgba("black", BADGE_ALPHA))
		badge:SetShown(not below)
	end
end

function Auras.Badge(parent, text)
	local badge = parent:CreateTexture(nil, "BACKGROUND")
	local pad = Widgets.Snap(parent, BADGE_PAD)
	badge:SetPoint("TOPLEFT", text, "TOPLEFT", -pad, pad)
	badge:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", pad, -pad)
	badge:SetColorTexture(Widgets.Rgba("black", BADGE_ALPHA))
	return badge
end

local dispelOptions
local function DispelOptions()
	if dispelOptions == nil then
		local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
		if styles and styles.PreserveAsset then
			dispelOptions = { style = styles.PreserveAsset, showWhenHarmful = true, showWithoutDispelType = true }
		else
			dispelOptions = false
			LogOnce("dispel", "frame auras: Enum.CustomAuraButtonDispelTypeTextureStyle is missing; debuffs show no dispel colour")
		end
	end
	return dispelOptions or nil
end

local function Dispel(entry, style)
	local options, button, buff = DispelOptions(), entry.button, entry.key == "buffs"
	local mode = options and style[buff and "auraBuffDispel" or "auraDispel"] and (buff and style.auraStealable and "steal" or "on") or false
	local steal = Enum and Enum.CustomAuraButtonDispelTypeStealableFilter
	if mode == "steal" and not (steal and steal.Stealable) then
		LogOnce("steal", "frame auras: Enum.CustomAuraButtonDispelTypeStealableFilter is missing; buffs show no stealable edge")
		mode = false
	end
	if (entry.dispelMode or false) == mode then
		return
	end
	if not (button.AddDispelTypeTexture and button.RemoveDispelTypeTexture) then
		LogOnce("dispel-api", "frame auras: Add or RemoveDispelTypeTexture is missing; auras show no dispel edges")
		return
	end
	local parts = entry.dispelParts
	if entry.dispelMode then
		for _, part in ipairs(parts) do
			button:RemoveDispelTypeTexture(part)
			part:Hide()
		end
	end
	entry.dispelMode = mode
	if not mode then
		return
	end
	if not parts then
		parts = entry.slab and { entry.underline } or Widgets.NineSlice(entry.skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
		if not entry.slab then
			Widgets.ShowSlice(parts, false)
			entry.dispel = parts
		end
		entry.dispelParts = parts
	end
	local add = options
	if buff then
		add = { style = options.style, showWhenHelpful = true, showWithoutDispelType = false, stealableFilter = mode == "steal" and steal.Stealable or nil }
	elseif entry.slab then
		add = { style = options.style, showWhenHarmful = options.showWhenHarmful, showWithoutDispelType = false }
	end
	for _, part in ipairs(parts) do
		button:AddDispelTypeTexture(part, add)
	end
end

local function StyleButton(view, entry, style)
	style = style or TextStyle(view)
	local size = Snap(view, Value(view, "auraSize"))
	entry.button:SetSize(size, size)
	Dispel(entry, style)
	Auras.LayoutTile(entry)
	Auras.Zoom(entry, view.kind)
	PlaceCount(entry.count, entry.skin, style)
	StyleTexts(entry.count, entry.timer, style)
	Auras.PlaceTimer(entry.timer, entry.skin, view.kind, entry.badge, style)
	entry.timer:SetShown(Value(view, "auraTimer"))
	entry.badge:SetShown(not TimerBelow(view.kind) and Value(view, "auraTimer") == true)
end

local formatters = {}
local function Formatter(minutes)
	if minutes <= 0 then return nil end
	if formatters[minutes] == nil then
		local util, curves, enum = C_StringUtil, C_CurveUtil, Enum
		local ok, made = pcall(function()
			local f = util.CreateSecondsFormatter()
			local units, bands = curves.CreateCurve(), curves.CreateCurve()
			units:SetType(enum.LuaCurveType.Step)
			units:AddPoint(0, 2)
			units:AddPoint(minutes * 60 + 1, 1)
			bands:SetType(enum.LuaCurveType.Step)
			bands:AddPoint(0, enum.SecondsFormatterInterval.Seconds)
			bands:AddPoint(91, enum.SecondsFormatterInterval.Minutes)
			bands:AddPoint(5401, enum.SecondsFormatterInterval.Hours)
			bands:AddPoint(129601, enum.SecondsFormatterInterval.Days)
			f:SetDefaultAbbreviation(enum.SecondsFormatterAbbreviation.OneLetter)
			f:SetRounding(enum.SecondsFormatterRounding.Truncate)
			f:SetCanRoundUpLastUnit(true)
			f:SetMinInterval(enum.SecondsFormatterInterval.Seconds)
			f:SetMaxIntervalCurve(bands)
			f:SetDesiredUnitCountCurve(units)
			return f
		end)
		formatters[minutes] = ok and made or false
		if not ok then LogOnce("precise", "frame auras: the seconds formatter is unavailable (" .. tostring(made) .. "); timers keep the short form") end
	end
	return formatters[minutes] or nil
end

local function Precise(view, entry)
	local f = view.auras.formatter
	if entry.precise ~= f then
		entry.precise = f
		entry.button:SetDurationText(entry.timer, f and { textFormatter = f } or nil)
	end
end

local function Flush()
	if not Auras.Open() then
		return false
	end
	local work = pending
	pending = {}
	for view in pairs(work) do
		if not view.auras or view.auras.style ~= PoolStyle(view) or ns.Fan.Wanted(view) and not view.auras.fan then
			K.Call(Auras.Apply, view)
		else
			view.auraStyle = nil
			local style = TextStyle(view)
			for _, entry in ipairs(view.auras.buttons) do
				K.Call(StyleButton, view, entry, style)
				K.Call(Precise, view, entry)
			end
			ns.Fan.Restyle(view)
		end
	end
	return true
end

local function StopWaiting()
	waiting = false
	K.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED")
	K.Events.Unregister(OWNER, "ADDON_RESTRICTION_STATE_CHANGED")
end

local function OnGate()
	if Flush() then
		StopWaiting()
	end
end

local function Wait(view)
	pending[view] = true
	if waiting then
		return
	end
	waiting = true
	K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", OnGate)
	pcall(K.Events.Register, OWNER, "ADDON_RESTRICTION_STATE_CHANGED", OnGate)
	Log("frame auras: aura buttons are restricted now; their restyle waits until aura data is readable")
end

local function Dress(view, key, button, buttons)
	local entry = Auras.NewTile(button)
	local skin = entry.skin
	skin:SetAllPoints(button)
	entry.buff = key == "buffs"
	if Settings.Form(view.kind) == "slab" and not Settings.AuraRows(view.kind) then
		entry.slab = Widgets.NineSlice(skin, "medAuraBorder", "BACKGROUND", 1)
		entry.chrome:SetShown(false)
		entry.lineFrame = CreateFrame("Frame", nil, skin)
		entry.lineFrame:SetAllPoints(skin)
		entry.underline = entry.lineFrame:CreateTexture(nil, "OVERLAY")
		entry.underline:SetTexture((Tokens.Texture("barFlat")))
		entry.underline:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT")
		entry.underline:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT")
		entry.underline:Hide()
	end
	entry.chrome.Restyle = function(chrome)
		if Auras.Open() then
			return entry.restyleChrome(chrome)
		end
		Wait(view)
	end
	local cooldown = CreateFrame("Cooldown", nil, skin, "CooldownFrameTemplate")
	cooldown:SetAllPoints(entry.icon)
	cooldown:SetSwipeTexture((Tokens.Texture("iconMask")))
	cooldown:SetSwipeColor(Widgets.Rgba("black", SWIPE_ALPHA))
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	local over = CreateFrame("Frame", nil, skin)
	over:SetAllPoints(skin)
	over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = Widgets.Fitted(Widgets.FontString(over, "OVERLAY"))
	count:SetPoint("TOPRIGHT", skin, "TOPRIGHT", COUNT_INSET, COUNT_INSET)
	count:SetJustifyH("RIGHT")
	local timer = Widgets.Fitted(Widgets.FontString(over, "OVERLAY"))
	entry.badge = over:CreateTexture(nil, "BACKGROUND")
	entry.countBadge = Auras.Badge(over, count)
	entry.button, entry.count, entry.timer, entry.key = button, count, timer, key
	StyleButton(view, entry)
	button:SetIcon(entry.icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	button:SetDurationText(timer)
	Precise(view, entry)
	buttons[#buttons + 1] = entry
end

local function Restyle(view)
	if view.auras and #view.auras.buttons > 0 then
		pending[view] = true
		if not Flush() then
			Wait(view)
		end
	end
end

local function EngineReady()
	local addons = C_AddOns
	if addons and type(addons.IsAddOnLoaded) == "function" and not addons.IsAddOnLoaded(ENGINE_ADDON) and type(addons.LoadAddOn) == "function" then
		pcall(addons.LoadAddOn, ENGINE_ADDON)
	end
end

local function GroupLayout(view, key)
	local size, spacing = Snap(view, Value(view, "auraSize")), Snap(view, Value(view, "auraSpacing"))
	return {
		elementWidth = size,
		elementHeight = size,
		elementSpacing = spacing,
		lineSpacing = spacing + Snap(view, TimerRoom(view.kind)) + Snap(view, Value(view, "auraRowGap")),
		forceNewLine = key == "buffs" and Value(view, "auraFilter") == "both",
	}
end

local function Capacity(view)
	return Value(view, "auraRows") * Value(view, "auraColumns")
end

local function Sort(view)
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if type(methods) == "table" and type(directions) == "table" and methods[SORT] ~= nil and directions.Normal ~= nil then
		return K.Options.AuraSort(view and Value(view, "auraFilters").sort, methods[SORT], directions.Normal)
	end
	LogOnce("sort", "frame auras: AuraContainerSortMethod." .. SORT .. " is missing; the engine keeps its default order")
	return nil
end

local function BuildOverflow(view, a)
	a.overflow = {}
	for _, key in ipairs(GROUPS) do
		local chip, why = Overflow.New(a.host, view.unit, START_FILTER[key], Capacity(view))
		if chip then
			a.overflow[key] = chip
		else
			LogOnce("overflow", "frame auras: the overflow chip has no counting container (" .. tostring(why) .. "); a full row shows no +N")
		end
	end
end

local function MirrorHolder(view, host)
	local holder = view.uf.holder
	hooksecurefunc(holder, "SetAlpha", function(_, alpha)
		host:SetAlpha(alpha)
	end)
	hooksecurefunc(holder, "SetFrameStrata", function(_, strata)
		host:SetFrameStrata(strata)
	end)
	host:SetAlpha(holder:GetAlpha())
	local strata = holder:GetFrameStrata()
	if not issecretvalue(strata) and type(strata) == "string" and strata ~= "" then
		host:SetFrameStrata(strata)
	end
end

local function BuildStyle(view)
	local a, style = view.auras, PoolStyle(view)
	if a.container then
		for _, key in ipairs(GROUPS) do
			a.container:SetAuraGroupEnabled(key, false)
		end
		a.container:SetEnabled(false)
		a.container:Hide()
	end
	local cached = a.styles[style]
	a.style = style
	if cached then
		a.container, a.buttons, a.candidates = cached.container, cached.buttons, cached.candidates
		a.container:Show()
		return
	end
	a.buttons, a.candidates = {}, {}
	local buttons = a.buttons
	EngineReady()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, a.host, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		a.failed = true
		LogOnce("engine", "frame auras: the AuraContainer engine is not available (" .. tostring(ok and "no " .. TEMPLATE or container) .. "); frames show no auras")
		return a
	end
	a.container = container
	container:SetUnit(view.unit)
	local method, direction = Sort()
	for _, key in ipairs(GROUPS) do
		local added, err = pcall(container.AddAuraGroup, container, key, START_FILTER[key], {
			maxFrameCount = Capacity(view),
			sortMethod = method,
			sortDirection = direction,
			layout = GroupLayout(view, key),
			initializeFrame = function(button)
				K.Call(Dress, view, key, button, buttons)
			end,
		})
		if not added then
			a.failed = true
			LogOnce("group", "frame auras: AuraContainer refused a group (" .. tostring(err) .. "); frames show no auras")
			a.host:Hide()
			return a
		end
	end
	a.styles[style] = { container = container, buttons = buttons, candidates = a.candidates }
end

local function Build(view)
	local a = { buttons = {}, styles = {} }
	view.auras = a
	views[#views + 1] = view
	local host = CreateFrame("Frame", nil, K.Scale.Root())
	host:Hide()
	a.host = host
	BuildStyle(view)
	if a.failed then
		return a
	end
	BuildOverflow(view, a)
	MirrorHolder(view, host)
	LogOnce("built", "frame auras: the AuraContainer engine with " .. #a.buttons .. " buttons ready on the first frame")
	return a
end

local function Active(view)
	return running and view.uf.active and Settings.AURAS[view.kind]
end

local function Wanted(view)
	return Active(view) and Value(view, "auras")
end

local function Visible(frame)
	local shown = frame:IsVisible()
	return issecretvalue(shown) or shown == true
end

function Auras.Sync(view)
	local a = view.auras
	if not (a and a.container) then
		return
	end
	a.host:SetShown(Wanted(view) and Visible(view.button))
	ns.Fan.Sync(view, Active(view) and Visible(view.button))
end

function Auras.LastCell(kind, frame, first, after)
	local size, spacing = Settings.Value(kind, "auraSize"), Settings.Value(kind, "auraSpacing")
	local columns, rows = Settings.Value(kind, "auraColumns"), Settings.Value(kind, "auraRows")
	local room, gap = TimerRoom(kind), rows > 1 and Settings.Value(kind, "auraRowGap") or 0
	if frame then
		size, spacing, room, gap = Widgets.Snap(frame, size), Widgets.Snap(frame, spacing), Widgets.Snap(frame, room), Widgets.Snap(frame, gap)
	end
	local _, _, corner, _, growth = Auras.Footprint(kind, frame)
	local right, down = growth[2] == "Right", growth[3] == "Down"
	local x = (after and columns or columns - 1) * (size + spacing)
	if not right then
		x = -(x + size)
	end
	if first then
		local y = (rows - 1) * (size + spacing + room + gap)
		return corner, x, down and -y or y + size, size
	end
	return (down and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), x, down and size or 0, size
end

local function Assist(view)
	if FIXED_UNIT[view.kind] then return true end
	local ok = type(UnitCanAssist) == "function" and UnitCanAssist("player", view.unit, true, true)
	return not issecretvalue(ok) and ok == true
end

local tracking = false
local function Retrack()
	for _, view in ipairs(views) do
		local a = view.auras
		if a and a.assist ~= nil and Wanted(view) and a.assist ~= Assist(view) then
			K.Call(Auras.Apply, view)
		end
	end
end

local function Track()
	if tracking then return end
	tracking = true
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_FACTION" }) do
		K.Events.Register(TRACK, event, Retrack)
	end
end

local function Lanes(view, filter)
	for _, lane in ipairs(LANES) do
		local mode = Value(view, lane[1])
		if mode ~= "" then filter = filter .. (mode == "hide" and "|!" or "|") .. lane[2] end
	end
	return filter
end

local function Candidates(view, key)
	local c, buffs = nil, key == "buffs"
	if Value(view, "auraTimed") then c = { maxDuration = math.huge } end
	local steal = buffs and Value(view, "buffStealable") or ""
	if steal ~= "" then
		c = c or {}
		c.isStealable = steal == "only"
	end
	local tracked = buffs and Value(view, "auraTrackedOnly") and Value(view, "auraTracked") or ""
	if buffs then
		view.auras.assist = nil
		if tracked ~= "" and not FIXED_UNIT[view.kind] then
			view.auras.assist = Assist(view)
			Track()
			if not view.auras.assist then tracked = "" end
		end
	end
	c = K.Options.AuraCandidates({ allowSpells = tracked, blockSpells = Value(view, "auraHidden") }, c)
	if not buffs and Value(view, "auraHideLockout") then
		c = c or {}
		local exclude = c.excludeSpellIDs or {}
		for id in pairs(LOCKOUTS) do exclude[id] = true end
		c.excludeSpellIDs = exclude
	end
	return c
end

local function SetCandidates(view, key, candidates)
	local a, container = view.auras, view.auras.container
	if candidates == nil and a.candidates[key] == nil then return end
	a.candidates[key] = candidates
	if type(container.SetAuraGroupCandidateFilters) == "function" then
		container:SetAuraGroupCandidateFilters(key, candidates)
	else
		LogOnce("candidates", "frame auras: SetAuraGroupCandidateFilters is missing; duration, stealable and spell ID filters do nothing")
	end
end

local function ApplyOverflow(view, filter, want)
	local a = view.auras
	if not a.overflow then
		return
	end
	local level = a.host:GetFrameLevel() + CHIP_LEVEL
	local after, capacity = TimerRoom(view.kind) > 0, Capacity(view)
	for _, key in ipairs(GROUPS) do
		local chip = a.overflow[key]
		if chip then
			local on = want and filter[key] ~= nil
			local point, x, y, cell = Auras.LastCell(view.kind, a.host, key == "debuffs" or not filter.debuffs, after)
			Overflow.Apply(chip, {
				enabled = on, groups = { { filter = filter[key], candidates = a.candidates[key] } }, cap = capacity, cell = cell, after = after,
				rel = a.container, relPoint = point, x = x, y = y, level = level, accent = Settings.Accent,
			})
		end
	end
end

local function ApplyContainer(view, fan)
	local a = view.auras
	local container = a.container
	local filter = {}
	local base = FILTERS[Value(view, "auraFilter")] or FILTERS.mine
	local settings = Value(view, "auraFilters")
	for key, value in pairs(base) do
		filter[key] = K.Options.AuraFilterString(settings, value)
	end
	if filter.buffs then filter.buffs = Lanes(view, filter.buffs) end
	if fan then
		filter.debuffs = not settings.onlyMine and base.debuffs == "HARMFUL" and filter.debuffs .. "|!PLAYER" or nil
	end
	a.formatter = Formatter(Value(view, "auraPrecise"))
	local method, direction = Sort(view)
	local capacity = Capacity(view)
	for _, key in ipairs(GROUPS) do
		local on = filter[key] ~= nil
		container:SetAuraGroupEnabled(key, on)
		if on then
			container:SetAuraGroupFilterString(key, filter[key])
		end
		SetCandidates(view, key, on and Candidates(view, key) or nil)
		container:SetAuraGroupLayout(key, GroupLayout(view, key))
		container:SetAuraGroupMaxFrameCount(key, capacity)
		if method ~= nil and type(container.SetAuraGroupSortMethod) == "function" then
			container:SetAuraGroupSortMethod(key, method, direction)
		end
	end
	local width, height, corner, line, growth = Auras.Footprint(view.kind, a.host)
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	container:SetFlowLayoutAnchorPoint(corner)
	if directions then
		container:SetFlowLayoutGrowthDirection(directions[growth[2]], directions[growth[3]])
	end
	container:SetFlowLayoutMaximumLineSize(line)
	a.host:SetSize(width, height)
	container:ClearAllPoints()
	if Centred(view.kind) then
		container:SetPoint("TOP", a.host, "TOP", 0, 0)
	else
		container:SetPoint(corner, a.host, corner, 0, 0)
	end
	ApplyOverflow(view, filter, true)
	Auras.Place(view)
end

function Auras.Parts(view)
	local a = view.auras
	local parts = a.parts
	if not parts then
		parts = {}
		a.parts = parts
	end
	for i = #parts, 1, -1 do
		parts[i] = nil
	end
	parts[1] = a.container
	for _, key in ipairs(GROUPS) do
		local chip = a.overflow and a.overflow[key]
		if chip then
			parts[#parts + 1] = chip.window
		end
	end
	return parts
end

local function EnableOverflow(view, on)
	local a = view.auras
	for _, key in ipairs(GROUPS) do
		local chip = a.overflow and a.overflow[key]
		if chip then
			Overflow.Enable(chip, on and chip.window:IsShown())
		end
	end
end

function Auras.Footprint(kind, frame)
	local size, spacing = Settings.Value(kind, "auraSize"), Settings.Value(kind, "auraSpacing")
	if frame then
		size, spacing = Widgets.Snap(frame, size), Widgets.Snap(frame, spacing)
	end
	local columns = Settings.Value(kind, "auraColumns")
	local filter = FILTERS[Settings.Value(kind, "auraFilter")] or FILTERS.mine
	local groups = filter.debuffs and filter.buffs and 2 or 1
	local rows = Settings.Value(kind, "auraRows") * groups
	local line = columns * size + (columns - 1) * spacing
	local growth = GROWTH[Settings.Value(kind, "auraGrowth")] or GROWTH.RIGHT_DOWN
	local timerRoom, gap = TimerRoom(kind), rows > 1 and Settings.Value(kind, "auraRowGap") or 0
	if frame then
		timerRoom, gap = Widgets.Snap(frame, timerRoom), Widgets.Snap(frame, gap)
	end
	local height = rows * (size + timerRoom) + (rows - 1) * (spacing + gap)
	if Centred(kind) then
		growth = GROWTH.RIGHT_DOWN
	end
	return math.max(1, line), math.max(1, height), growth[1], line, growth
end

function Auras.Anchor(host, frame, kind, panelX, spot)
	local position = POSITION[Settings.Value(kind, "auraPosition")] or POSITION.BELOW
	local dx, dy = Off(host, Settings.Value(kind, "auraX")), Off(host, Settings.Value(kind, "auraY"))
	host:ClearAllPoints()
	if spot and spot.outer and Settings.AuraRows(kind) and Settings.Value(kind, "auraPosition") == "ABOVE" then
		local side = kind == "target" and "RIGHT" or "LEFT"
		host:SetPoint("BOTTOM" .. side, frame, "TOPLEFT", Widgets.Snap(host, spot.x) + dx, dy - Widgets.Snap(host, spot.y))
		return
	end
	if spot and spot.centred then
		host:SetPoint("TOP", frame, "TOPLEFT", Widgets.Snap(host, spot.x) + dx, dy - Widgets.Snap(host, spot.y))
		return
	end
	if spot and Settings.Value(kind, "auraPosition") == "SIDE" then
		host:SetPoint("TOPLEFT", frame, "TOPLEFT", Widgets.Snap(host, spot.x) + dx, dy - Widgets.Snap(host, spot.y))
		return
	end
	local x = position[5] and Widgets.Snap(host, panelX) or 0
	local gap = Widgets.Snap(host, GAP)
	host:SetPoint(position[1], frame, position[2], x + position[3] * gap + dx, position[4] * gap + dy)
end

function Auras.Place(view)
	local a = view.auras
	if a and a.container then
		Auras.Anchor(a.host, view.button, view.kind, view.geometry and view.geometry.panel.x or 0, view.geometry and view.geometry.aura)
	end
end

function Auras.Apply(view)
	if not Settings.AURAS[view.kind] then
		return
	end
	view.auraStyle = nil
	local want = Wanted(view)
	if not view.auras then
		if not want and not (Active(view) and ns.Fan.Wanted(view)) then
			return
		end
		if not Auras.Open() then
			Wait(view)
			return
		end
		Build(view)
	end
	local a = view.auras
	if not a.failed and a.style ~= PoolStyle(view) then
		if not Auras.Open() then
			Wait(view)
			return
		end
		BuildStyle(view)
	end
	if a.failed then
		return
	end
	a.container:SetEnabled(want and true or false)
	local fan = ns.Fan.Apply(view, Active(view))
	if want then
		K.Call(ApplyContainer, view, fan)
	end
	if want or Active(view) and ns.Fan.Wanted(view) then
		Restyle(view)
	end
	EnableOverflow(view, want)
	Auras.Sync(view)
end

function Auras.Enable()
	running = true
end

function Auras.Disable()
	running = false
	for _, view in ipairs(views) do
		local a = view.auras
		if a.container then
			ns.Fan.Apply(view, false)
			a.container:SetEnabled(false)
			EnableOverflow(view, false)
			a.host:Hide()
		end
	end
	pending = {}
	StopWaiting()
	if tracking then
		tracking = false
		K.Events.UnregisterAll(TRACK)
	end
end
