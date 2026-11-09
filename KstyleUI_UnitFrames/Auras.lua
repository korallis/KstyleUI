-- Auras.lua: frame auras on the AuraContainer engine, sorted by the engine (yours, then priority, then time left), capped at rows by columns with a "+N" overflow chip, each timer under its tile or in a corner badge, with aura buttons touched only while C_Secrets.ShouldAurasBeSecret says aura data is readable.
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
}
local GAP = 2
local ICON_CROP = 0.07
local ICON_INSET_LINES = 2
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local COUNT_INSET = 1
local SWIPE_ALPHA = 0.65
local DISPEL_SUBLEVEL = 7
local TIMER_BELOW_GAP = 1
local TIMER_ROOM_EXTRA = 3
local BADGE_PAD, BADGE_ALPHA = 1, 0.62
local TEXT_FLOOR, TEXT_LINE = 10, 1.2
local CHIP_LEVEL = 8
local SORT = "Expiration"

local issecretvalue = issecretvalue or function()
	return false
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

local function StyleText(text, view)
	local path, size, flags = Settings.Font(view.kind, "aura")
	size = TextSize(view.kind, size)
	if text:SetFont(path, size, flags) == false then
		local fallback = Tokens.Font("number")
		text:SetFont(fallback, size, flags)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
	pcall(text.SetTextColor, text, Tokens.Color("textEmphasis"))
end

local function Snap(view, units)
	return Widgets.Snap(view.auras.host, units)
end

function Auras.NewTile(parent)
	local skin = CreateFrame("Frame", nil, parent)
	local chrome = Widgets.IconChrome(skin)
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	return { skin = skin, chrome = chrome, restyleChrome = chrome.Restyle, icon = icon, mask = mask }
end

function Auras.LayoutTile(tile)
	local skin = tile.skin
	tile.restyleChrome(tile.chrome)
	tile.chrome:SetRimAccent(Settings.Accent())
	local inset = Widgets.Border(skin) * ICON_INSET_LINES
	tile.icon:ClearAllPoints()
	tile.icon:SetPoint("TOPLEFT", skin, "TOPLEFT", inset, -inset)
	tile.icon:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -inset, inset)
	if tile.dispel then
		Widgets.LayoutSlice(tile.dispel, skin, tile.chrome:Chamfer(), 0)
	end
end

local function Centred(kind)
	local position = POSITION[Settings.Value(kind, "auraPosition")]
	return position ~= nil and position.centred == true
end

local function TimerBelow(kind)
	return Centred(kind) and Settings.Value(kind, "auraTimer") == true and Settings.Value(kind, "auraRows") == 1
end

local function TimerRoom(kind)
	if not TimerBelow(kind) then
		return 0
	end
	local _, fontSize = Settings.Font(kind, "aura")
	return TIMER_BELOW_GAP + TextSize(kind, fontSize) + TIMER_ROOM_EXTRA
end

function Auras.PlaceTimer(timer, skin, kind, badge)
	timer:ClearAllPoints()
	local below = TimerBelow(kind)
	if below then
		timer:SetPoint("TOP", skin, "BOTTOM", 0, -Widgets.Snap(skin, TIMER_BELOW_GAP))
		timer:SetJustifyH("CENTER")
	else
		timer:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -COUNT_INSET, COUNT_INSET)
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

local function StyleButton(view, entry)
	local size = Snap(view, Value(view, "auraSize"))
	entry.button:SetSize(size, size)
	Auras.LayoutTile(entry)
	StyleText(entry.count, view)
	StyleText(entry.timer, view)
	Auras.PlaceTimer(entry.timer, entry.skin, view.kind, entry.badge)
	entry.timer:SetShown(Value(view, "auraTimer"))
	entry.badge:SetShown(entry.badge:IsShown() and Value(view, "auraTimer") == true)
end

local function Flush()
	if not Auras.Open() then
		return false
	end
	for view in pairs(pending) do
		pending[view] = nil
		for _, entry in ipairs(view.auras.buttons) do
			K.Call(StyleButton, view, entry)
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

local function Dispel(entry, button)
	local options = DispelOptions()
	if not options then
		return
	end
	local slice = Widgets.NineSlice(entry.skin, "chamferTile", "BORDER", DISPEL_SUBLEVEL)
	Widgets.ShowSlice(slice, false)
	entry.dispel = slice
	for i = 1, #slice do
		button:AddDispelTypeTexture(slice[i], options)
	end
end

local function Dress(view, key, button)
	local entry = Auras.NewTile(button)
	local skin = entry.skin
	skin:SetAllPoints(button)
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
	local count = Widgets.FontString(over, "OVERLAY")
	count:SetPoint("TOPRIGHT", skin, "TOPRIGHT", COUNT_INSET, COUNT_INSET)
	count:SetJustifyH("RIGHT")
	local timer = Widgets.FontString(over, "OVERLAY")
	entry.badge = over:CreateTexture(nil, "BACKGROUND")
	entry.countBadge = Auras.Badge(over, count)
	entry.button, entry.count, entry.timer = button, count, timer
	if key == "debuffs" then
		Dispel(entry, button)
	end
	StyleButton(view, entry)
	button:SetIcon(entry.icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	button:SetDurationText(timer)
	local a = view.auras
	a.buttons[#a.buttons + 1] = entry
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
		lineSpacing = spacing + Snap(view, TimerRoom(view.kind)),
		forceNewLine = key == "buffs" and Value(view, "auraFilter") == "both",
	}
end

local function Capacity(view)
	return Value(view, "auraRows") * Value(view, "auraColumns")
end

local function Sort()
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if type(methods) == "table" and type(directions) == "table" and methods[SORT] ~= nil and directions.Normal ~= nil then
		return methods[SORT], directions.Normal
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

local function Build(view)
	local a = { buttons = {} }
	view.auras = a
	views[#views + 1] = view
	local host = CreateFrame("Frame", nil, K.Scale.Root())
	host:Hide()
	a.host = host
	EngineReady()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, host, TEMPLATE)
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
				K.Call(Dress, view, key, button)
			end,
		})
		if not added then
			a.failed = true
			LogOnce("group", "frame auras: AuraContainer refused a group (" .. tostring(err) .. "); frames show no auras")
			host:Hide()
			return a
		end
	end
	BuildOverflow(view, a)
	MirrorHolder(view, host)
	LogOnce("built", "frame auras: the AuraContainer engine with " .. #a.buttons .. " buttons ready on the first frame")
	return a
end

local function Wanted(view)
	return running and view.uf.active and Settings.AURAS[view.kind] and Value(view, "auras")
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
end

function Auras.LastCell(kind, frame, first)
	local size, spacing = Settings.Value(kind, "auraSize"), Settings.Value(kind, "auraSpacing")
	local room = TimerRoom(kind)
	if frame then
		size, spacing, room = Widgets.Snap(frame, size), Widgets.Snap(frame, spacing), Widgets.Snap(frame, room)
	end
	local columns, rows = Settings.Value(kind, "auraColumns"), Settings.Value(kind, "auraRows")
	local _, _, corner, _, growth = Auras.Footprint(kind, frame)
	local right, down = growth[2] == "Right", growth[3] == "Down"
	local x = (columns - 1) * (size + spacing)
	if not right then
		x = -(x + size)
	end
	if first then
		local y = (rows - 1) * (size + spacing + room)
		return corner, x, down and -y or y + size, size
	end
	return (down and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), x, down and size or 0, size
end

local function ApplyOverflow(view, filter, want)
	local a = view.auras
	if not a.overflow then
		return
	end
	local level = a.host:GetFrameLevel() + CHIP_LEVEL
	for _, key in ipairs(GROUPS) do
		local chip = a.overflow[key]
		if chip then
			local on = want and filter[key] ~= nil
			local point, x, y, cell = Auras.LastCell(view.kind, a.host, key == "debuffs" or not filter.debuffs)
			Overflow.Apply(chip, {
				enabled = on, filter = filter[key], cap = Capacity(view), cell = cell,
				rel = a.container, relPoint = point, x = x, y = y, level = level, accent = Settings.Accent,
			})
		end
	end
end

local function ApplyContainer(view)
	local a = view.auras
	local container = a.container
	local filter = FILTERS[Value(view, "auraFilter")] or FILTERS.mine
	local method, direction = Sort()
	for _, key in ipairs(GROUPS) do
		local on = filter[key] ~= nil
		container:SetAuraGroupEnabled(key, on)
		if on then
			container:SetAuraGroupFilterString(key, filter[key])
		end
		container:SetAuraGroupLayout(key, GroupLayout(view, key))
		container:SetAuraGroupMaxFrameCount(key, Capacity(view))
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
	local parts = { a.container }
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
	local timerRoom = TimerRoom(kind)
	if frame then
		timerRoom = Widgets.Snap(frame, timerRoom)
	end
	local height = rows * (size + timerRoom) + (rows - 1) * spacing
	if Centred(kind) then
		growth = GROWTH.RIGHT_DOWN
	end
	return math.max(1, line), math.max(1, height), growth[1], line, growth
end

function Auras.Anchor(host, frame, kind, panelX)
	local position = POSITION[Settings.Value(kind, "auraPosition")] or POSITION.BELOW
	local x = position[5] and Widgets.Snap(host, panelX) or 0
	local gap = Widgets.Snap(host, GAP)
	host:ClearAllPoints()
	host:SetPoint(position[1], frame, position[2], x + position[3] * gap, position[4] * gap)
end

function Auras.Place(view)
	local a = view.auras
	if a and a.container then
		Auras.Anchor(a.host, view.button, view.kind, view.geometry and view.geometry.panel.x or 0)
	end
end

function Auras.Apply(view)
	if not Settings.AURAS[view.kind] then
		return
	end
	local want = Wanted(view)
	if not view.auras then
		if not want then
			return
		end
		Build(view)
	end
	local a = view.auras
	if a.failed then
		return
	end
	a.container:SetEnabled(want and true or false)
	if want then
		K.Call(ApplyContainer, view)
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
			a.container:SetEnabled(false)
			EnableOverflow(view, false)
			a.host:Hide()
		end
	end
	pending = {}
	StopWaiting()
end
