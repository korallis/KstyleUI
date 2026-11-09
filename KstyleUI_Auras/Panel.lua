-- Panel.lua: the Blessings card: the buff and debuff containers on the AuraContainer engine, the card and its cap on the buff element, the debuff rows (dispellable first) docked under a hairline or free as their own element, weapon enchantments, the cap's "+N" (counted by the engine's own layout, so it stays true in combat) and the cap's route to the full list (hover to peek, click to pin), the aura-secrecy gate, and Blizzard's frames, which return in the gamepad interface.
local _, ns = ...

local K = KstyleUI
local L, Widgets, Tokens = K.L, K.Widgets, K.Tokens
local Overflow = Widgets.Overflow
local Model, Button = ns.Model, ns.Button
local format, concat, min = string.format, table.concat, math.min

local Panel = {}
ns.Panel = Panel

local MODULE = Model.MODULE
local TEMPLATE = "CustomAuraContainerTemplate"
local UNIT = "player"
local HOST_LEVEL = 2
local REST_EDGE_ALPHA = 0.5
local GATE_EVENTS = { "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }
local AURA_EVENT = "UNIT_AURA"
local ENCHANT_EVENTS = { "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD" }
local INPUT_EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"
local CALLBACKS = { "SettingChanged", "ThemeChanged", "ScaleChanged", "ProfileChanged", "LayoutChanged" }
local EDGE_TOKENS = { buffs = "edgeInner", debuffs = "hostile" }
local CARD_GROUP, DOCKED_GROUP = "buffs", "debuffs"
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local DISPEL_GROUP, REST_GROUP = "dispel", "debuffs"
local MORE_CLOSE_DELAY = 0.5
local MORE_GAP = Tokens.Size("gapMedium")
local SLOT_PAGE = 40
local COUNT_RESERVE = "+00"
local COUNT_WIDTH = 28
local BUTTON_LEVEL = 4
local FALLBACK = {
	buffs = { position = { anchor = "TOPRIGHT", x = -287, y = -16 }, label = K.L["Buffs"] },
	debuffs = { position = { anchor = "TOPRIGHT", x = -287, y = -126 }, label = K.L["Debuffs"] },
}

local groups = {}
local running, pending, waiting, gamepad = false, false, false, false
local logged = {}

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Answer(fn)
	local ok, value = pcall(fn)
	if ok and not IsSecret(value) then
		return true, value
	end
	return false
end

function Panel.Gamepad()
	local input = InputUtil
	if type(input) == "table" and type(input.IsGamepadUIEnabled) == "function" then
		local ok, enabled = Answer(input.IsGamepadUIEnabled)
		if ok then
			return enabled == true
		end
	end
	local style, types = C_InputInterfaceStyle, Enum and Enum.InputDeviceInterfaceType
	if type(style) == "table" and type(style.GetCurrentStyle) == "function" and types and types.Gamepad ~= nil then
		local ok, current = Answer(style.GetCurrentStyle)
		if ok then
			return current == types.Gamepad
		end
	end
	LogOnce("input", "the interface style cannot be read; the auras take the keyboard and mouse path")
	return false
end

local function SetGamepad(now)
	if now == gamepad then
		return
	end
	gamepad = now
	if now then
		Log("gamepad interface on: Blizzard's buff frames return for the gamepad's View buffs, and KstyleUI's aura panels hide")
	else
		Log("gamepad interface off: KstyleUI's aura panels return, and Blizzard's buff frames follow the hide setting")
	end
end

function Panel.Open()
	if InCombatLockdown() then
		return false
	end
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		if not ok or IsSecret(secret) then
			return false
		end
		return secret ~= true
	end
	LogOnce("gate", "C_Secrets.ShouldAurasBeSecret is missing; aura buttons restyle only out of combat")
	return true
end

local function Listen(event, fn)
	local ok, err = pcall(K.Events.Register, MODULE, event, fn)
	if not ok then
		LogOnce("event:" .. event, "could not listen for " .. event .. ": " .. tostring(err))
	end
	return ok
end

local function StopWaiting()
	waiting = false
end

local function RestyleButtons(desc)
	if not Panel.Open() then
		Panel.Wait()
		return
	end
	for _, entry in ipairs(desc.buttons) do
		K.Call(Button.Style, entry, desc.ctx)
	end
end

function Panel.Flush()
	if not (running and pending) then
		StopWaiting()
		return
	end
	if not Panel.Open() then
		return
	end
	pending = false
	StopWaiting()
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		if desc and not desc.failed then
			RestyleButtons(desc)
		end
	end
end

local Fit, BuildMoreButton, Recount

local function OnGateEvent(event)
	if waiting then
		C_Timer.After(0, Panel.Flush)
	end
	Fit(event == "PLAYER_REGEN_DISABLED")
end

function Panel.Wait()
	pending = true
	if waiting or not running then
		return
	end
	waiting = true
	Log("restyling the aura buttons waits until aura data is no longer secret")
end

local function Formatter(timerFormat)
	if timerFormat == "short" then
		return nil
	end
	local formatter = Widgets.Duration.Formatter(timerFormat)
	if formatter then
		LogOnce("formatter:" .. timerFormat, "the " .. timerFormat .. " timer format uses the kit's seconds formatter")
	else
		LogOnce("formatter:" .. timerFormat, "C_StringUtil.CreateSecondsFormatter is missing or failed; timers use the engine's default format")
	end
	return formatter
end

local function ExpiringColor(expiring)
	if expiring <= 0 then
		return nil
	end
	local util, E = C_CurveUtil, Enum
	if not (util and type(util.CreateColorCurve) == "function" and type(CreateColor) == "function" and E and E.DurationTextBindingProperty) then
		LogOnce("curve", "colour curves are missing; timers keep one colour")
		return nil
	end
	local ok, curve = pcall(function()
		local c = util.CreateColorCurve()
		if E.LuaCurveType then
			c:SetType(E.LuaCurveType.Step)
		end
		c:AddPoint(0, CreateColor(Tokens.Color("hostile")))
		c:AddPoint(expiring, CreateColor(Tokens.Color("textEmphasis")))
		return c
	end)
	if not ok then
		LogOnce("curve", "the timer colour curve failed (" .. tostring(curve) .. "); timers keep one colour")
		return nil
	end
	return { curve = curve, property = E.DurationTextBindingProperty.RemainingDuration }
end

local function DispelOptions()
	local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	if not (styles and styles.PreserveAsset) then
		LogOnce("dispel", "Enum.CustomAuraButtonDispelTypeTextureStyle is missing; debuffs show no dispel colour")
		return nil
	end
	return { style = styles.PreserveAsset, showWhenHarmful = true, showWithoutDispelType = true }
end

local function EdgeColor(name, settings)
	local r, g, b
	if EDGE_TOKENS[name] == "accent" then
		r, g, b = Model.AccentColor(settings)
	else
		r, g, b = Tokens.Color(EDGE_TOKENS[name])
	end
	return { r, g, b, REST_EDGE_ALPHA }
end

local function Context(desc)
	local settings = K.Store.Module(MODULE)
	local group, timer, count = Model.Group(settings, desc.name), Model.Timer(settings), Model.Count(settings)
	local textScale = Model.TextScale()
	timer.size, count.size = timer.size * textScale, count.size * textScale
	local host = desc.host
	local function snap(units)
		return Widgets.Snap(host, units)
	end
	local ctx = {
		group = group,
		timer = timer,
		count = count,
		icon = snap(group.iconSize),
		spacing = snap(group.spacing),
		rowSpacing = snap(group.rowSpacing),
		lineSize = Model.LineSize(group, timer, snap),
		edge = EdgeColor(desc.name, settings),
		timerOptions = { textFormatter = Formatter(timer.format), textColor = ExpiringColor(timer.expiring) },
		dispelOptions = group.dispel and DispelOptions() or nil,
	}
	ctx.width, ctx.height = Model.ElementSize(group, timer, snap)
	ctx.footWidth, ctx.footHeight = Model.Footprint(group, timer, snap)
	return ctx
end

local function GroupLayout(ctx)
	return {
		elementSpacing = ctx.spacing,
		lineSpacing = ctx.rowSpacing,
		groupSpacing = ctx.spacing,
		groupLineSpacing = ctx.rowSpacing,
		elementWidth = ctx.width,
		elementHeight = ctx.height,
	}
end

local function Keys(desc)
	if desc.name == "debuffs" then
		return { DISPEL_GROUP, REST_GROUP }
	end
	return { desc.name }
end

local function Active(desc, key)
	return key ~= DISPEL_GROUP or desc.ctx.group.dispelFirst == true
end

local function DispelSet()
	local set = {}
	for _, kind in ipairs(Model.DISPEL_TYPES) do
		set[kind] = true
	end
	return set
end

local function Candidates(desc, key)
	if key == DISPEL_GROUP then
		return { includeDispelTypes = DispelSet() }
	elseif key == REST_GROUP and desc.ctx.group.dispelFirst then
		return { excludeDispelTypes = DispelSet() }
	end
	return nil
end

local function EnchantLayout(ctx)
	local layout = GroupLayout(ctx)
	local placement = CustomAuraContainerItemEnchantmentPlacement
	if type(placement) == "table" then
		layout.placement = placement.BeforeAuraGroups
	end
	return layout
end

local function SortEnums(group)
	local methods, directions = AuraContainerSortMethod, AuraContainerSortDirection
	if type(methods) ~= "table" or type(directions) ~= "table" then
		LogOnce("sort", "AuraContainerSortMethod is missing; auras keep the engine's order")
		return nil, nil
	end
	local method, direction = Model.Sort(group.sort, group.reverse)
	return methods[method] or methods.Default, directions[direction] or directions.Normal
end

local function EnchantSlots(desc)
	local group = desc.ctx.group
	if not group.enchants then
		return 0
	end
	return min(#desc.enchants, Model.Capacity(group, 0))
end

local function ActiveEnchants(desc)
	local slots = EnchantSlots(desc)
	if slots == 0 then
		return 0
	end
	local api = C_PaperDollInfo
	if not (api and type(api.GetTemporaryEnchantmentInfo) == "function") then
		return 0
	end
	local n = 0
	for i = 1, slots do
		local enchant = desc.enchants[i]
		if type(enchant.inventory) == "number" then
			local ok, info = pcall(api.GetTemporaryEnchantmentInfo, enchant.inventory)
			if ok and (IsSecret(info) or info ~= nil) then
				n = n + 1
			end
		end
	end
	return n
end

local function ApplyGroups(desc, container, ctx, capacity)
	local method, direction = SortEnums(ctx.group)
	for _, key in ipairs(desc.keys) do
		container:SetAuraGroupLayout(key, GroupLayout(ctx))
		if method ~= nil and direction ~= nil then
			container:SetAuraGroupSortMethod(key, method, direction)
		end
		container:SetAuraGroupMaxFrameCount(key, capacity)
		if #desc.keys > 1 then
			container:SetAuraGroupEnabled(key, Active(desc, key))
			if type(container.SetAuraGroupCandidateFilters) == "function" then
				container:SetAuraGroupCandidateFilters(key, Candidates(desc, key))
			end
		end
	end
end

local function UpdateCapacity(desc)
	local capacity = Model.Capacity(desc.ctx.group, ActiveEnchants(desc))
	for _, key in ipairs(desc.keys) do
		desc.container:SetAuraGroupMaxFrameCount(key, capacity)
	end
	return capacity
end

local function Init(desc, button)
	local entry = Button.Create(button, desc.name == "debuffs")
	desc.buttons[#desc.buttons + 1] = entry
	Button.Style(entry, desc.ctx)
end

function Panel.Group(name)
	return groups[name]
end

local function Source(desc)
	if desc.docked then
		return groups[CARD_GROUP].holder, desc.dock
	end
	return desc.holder, desc.holder
end

local function Empty(desc)
	local card = groups[CARD_GROUP]
	if desc.docked then
		desc = card
	end
	return desc == card and desc.card ~= nil and desc.card.empty == true
end

local function ShowHost(desc)
	local source = Source(desc)
	desc.host:SetShown(source:IsShown() and not gamepad and not Empty(desc))
end

local function LayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, LAYOUT_TEMPLATE)
	if ok and type(frame) == "table" then
		return frame
	end
	LogOnce("layout-template", LAYOUT_TEMPLATE .. " is missing; the card anchors to the engine's containers without it")
	return CreateFrame("Frame", nil, parent)
end

local function Follow(desc)
	local host = desc.host
	local source, anchor = Source(desc)
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	if desc.card and desc.card.fitted then
		host:SetPoint("BOTTOMRIGHT", desc.card.edge, "BOTTOMRIGHT", 0, 0)
	else
		host:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	end
	host:SetScale(source:GetScale())
	host:SetAlpha(source:GetAlpha())
	host:SetFrameStrata(source:GetFrameStrata())
	host:SetFrameLevel(source:GetFrameLevel() + HOST_LEVEL)
	ShowHost(desc)
end

local function Watch(desc, holder)
	local function follow()
		if Source(desc) == holder then
			Follow(desc)
		end
	end
	for _, method in ipairs({ "SetScale", "SetAlpha", "SetFrameStrata", "Show", "Hide", "SetShown" }) do
		hooksecurefunc(holder, method, follow)
	end
end

local function Mirror(desc)
	Follow(desc)
	Watch(desc, desc.holder)
end

local function BuildCard(desc)
	local host = desc.host
	local card = {
		chrome = Widgets.Chrome(host, { shape = "panel" }),
		cap = Widgets.RailCap(host, { title = L["Blessings"] }),
		rule = host:CreateTexture(nil, "ARTWORK"),
		fit = LayoutFrame(host),
		tail = LayoutFrame(host),
		edge = LayoutFrame(host),
	}
	card.rule:SetColorTexture(Tokens.Color("white"))
	Widgets.LumenTint(card.rule, "hairline")
	card.rule:Hide()
	desc.card = card
	BuildMoreButton(desc)
end

local function Docked()
	return Model.Docked(K.Store.Module(MODULE))
end

local function LayoutCard(desc, docked)
	local host, card, ctx = desc.host, desc.card, desc.ctx
	local other = groups[DOCKED_GROUP]
	local docking = docked and other and not other.failed and other.dock ~= nil
	local debuffs = docking and card.band ~= false and { width = other.ctx.footWidth, height = other.ctx.footHeight } or nil
	local pad, gap = Model.CARD_PAD, Model.CARD_GAP
	local shape = Model.Card({ width = ctx.footWidth, height = ctx.footHeight }, debuffs, pad, gap)
	desc.shape = shape
	local snap = function(units)
		return Widgets.Snap(host, units)
	end
	card.cap.frame:ClearAllPoints()
	card.cap.frame:SetPoint("TOPLEFT", host, "TOPLEFT", snap(pad), -snap(pad))
	card.cap.frame:SetPoint("TOPRIGHT", host, "TOPRIGHT", -snap(pad), -snap(pad))
	card.cap:Restyle()
	local content, holder, container = desc.content, desc.holder, desc.container
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", holder, "TOPLEFT", snap(pad), -snap(shape.contentTop))
	content:SetSize(ctx.footWidth, ctx.footHeight)
	local fit, tail, edge, rule = card.fit, card.tail, card.edge, card.rule
	fit:ClearAllPoints()
	fit:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	fit:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
	rule:ClearAllPoints()
	tail:ClearAllPoints()
	if debuffs then
		rule:SetPoint("TOPLEFT", fit, "BOTTOMLEFT", 0, -snap(gap))
		rule:SetSize(shape.width - 2 * snap(pad), Widgets.Border(host))
		Widgets.LumenTint(rule, "hairline")
		rule:Show()
	else
		rule:Hide()
	end
	if docking then
		local dock = other.dock
		dock:ClearAllPoints()
		dock:SetPoint("TOPLEFT", fit, "BOTTOMLEFT", 0, debuffs and -snap(shape.debuffTop - shape.ruleTop + gap) or 0)
		dock:SetSize(other.ctx.footWidth, other.ctx.footHeight)
		tail:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
		tail:SetPoint("BOTTOMRIGHT", other.container, "BOTTOMRIGHT", 0, 0)
	else
		tail:SetPoint("TOPLEFT", fit, "TOPLEFT", 0, 0)
		tail:SetPoint("BOTTOMRIGHT", fit, "BOTTOMRIGHT", 0, 0)
	end
	edge:ClearAllPoints()
	edge:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
	edge:SetPoint("BOTTOMLEFT", tail, "BOTTOMLEFT", -snap(pad), -snap(pad))
	card.fitted = true
	Follow(desc)
	return shape.width, shape.height
end

local function Dock(desc, docked)
	docked = docked == true
	local changed = desc.docked ~= docked
	desc.docked = docked
	desc.holder:SetShown(not docked)
	local Layout = K.Layout
	if Layout and type(Layout.SetLive) == "function" then
		Layout.SetLive(Model.KEYS[desc.name], not docked)
	end
	if changed then
		Follow(desc)
	end
end

local function AddEnchants(desc)
	local container, slots = desc.container, AuraContainerItemEnchantmentSlot
	if type(container.AddItemEnchantment) ~= "function" or type(slots) ~= "table" then
		Log("weapon enchantments are not available on this client")
		return
	end
	local wanted = {
		{ "MainHand", INVSLOT_MAINHAND },
		{ "OffHand", INVSLOT_OFFHAND },
		{ "Ranged", INVSLOT_RANGED },
	}
	for _, slot in ipairs(wanted) do
		local id = slots[slot[1]]
		if id ~= nil then
			local ok, err = pcall(container.AddItemEnchantment, container, id, {
				initializeFrame = function(button)
					K.Call(Init, desc, button)
				end,
			})
			if ok then
				desc.enchants[#desc.enchants + 1] = { slot = id, inventory = slot[2] }
			else
				Log("the " .. slot[1] .. " weapon enchantment slot failed: " .. tostring(err))
			end
		end
	end
	Log(format("%d weapon enchantment slots join the buffs", #desc.enchants))
end

local function Register(desc)
	local key = Model.KEYS[desc.name]
	local Layouts = K.Setup and K.Setup.Layouts
	local position, label = FALLBACK[desc.name].position, FALLBACK[desc.name].label
	if Layouts and Layouts.Default and Layouts.Element then
		local ok, default = pcall(Layouts.Default, key)
		local element = Layouts.Element(key)
		if ok and default then
			position = default
		end
		if element and element.label then
			label = element.label
		end
	end
	desc.holder:SetSize(desc.ctx.footWidth, desc.ctx.footHeight)
	Widgets.Place(desc.holder, key, position, { label = label, module = MODULE, scalable = true })
end

local function AddGroup(container, desc, key, capacity, ctx, init)
	local method, direction = SortEnums(ctx.group)
	return pcall(container.AddAuraGroup, container, key, Model.FILTERS[desc.name], {
		maxFrameCount = capacity,
		sortMethod = method,
		sortDirection = direction,
		layout = GroupLayout(ctx),
		candidateFilters = Candidates(desc, key),
		initializeFrame = init,
	})
end

local function Build(name)
	local root = K.Scale.Root()
	local host = LayoutFrame(root)
	local desc = { name = name, host = host, buttons = {}, enchants = {} }
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, host, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		host:Hide()
		desc.failed = true
		Log("the AuraContainer engine is not available for " .. name .. " (" .. tostring(ok and "no " .. TEMPLATE or container) .. "); Blizzard's frame stays")
		return desc
	end
	desc.container = container
	desc.ctx = Context(desc)
	desc.keys = Keys(desc)
	container:SetUnit(UNIT)
	for _, key in ipairs(desc.keys) do
		local added, err = AddGroup(container, desc, key, Model.Capacity(desc.ctx.group, 0), desc.ctx, function(button)
			K.Call(Init, desc, button)
		end)
		if not added then
			host:Hide()
			desc.failed = true
			Log("AuraContainer refused the " .. key .. " group (" .. tostring(err) .. "); Blizzard's frame stays")
			return desc
		end
	end
	if name == "buffs" then
		AddEnchants(desc)
	end
	desc.holder = CreateFrame("Frame", nil, root)
	desc.content = CreateFrame("Frame", nil, host)
	desc.content:SetAllPoints(host)
	if name == CARD_GROUP then
		BuildCard(desc)
	elseif name == DOCKED_GROUP then
		local card = groups[CARD_GROUP]
		if card and not card.failed then
			desc.dock = LayoutFrame(card.holder)
			Watch(desc, card.holder)
		end
	end
	Mirror(desc)
	Register(desc)
	Log(format("%s: %d aura buttons on the AuraContainer engine", name, #desc.buttons))
	return desc
end

local function ApplyContainer(desc)
	local ctx, container = desc.ctx, desc.container
	local anchor, horizontal, vertical = Model.Growth(ctx.group.growth)
	local directions = AnchorUtil.FlowDirection
	container:SetFlowLayoutAnchorPoint(anchor)
	container:SetFlowLayoutGrowthDirection(directions[horizontal], directions[vertical])
	container:SetFlowLayoutMaximumLineSize(ctx.lineSize)
	container:ClearAllPoints()
	local edge = Model.ContainerAnchor(ctx.group.growth)
	container:SetPoint(edge, desc.content, edge, 0, 0)
	ApplyGroups(desc, container, ctx, Model.Capacity(ctx.group, ActiveEnchants(desc)))
	local slots = EnchantSlots(desc)
	for i, enchant in ipairs(desc.enchants) do
		container:SetItemEnchantmentEnabled(enchant.slot, i <= slots)
	end
	if #desc.enchants > 0 then
		container:SetItemEnchantmentLayout(EnchantLayout(ctx))
	end
end

local function Page(ok, token, ...)
	if not ok or IsSecret(token) then
		return nil
	end
	local n = select("#", ...)
	for i = 1, n do
		if issecretvalue((select(i, ...))) then
			return nil
		end
	end
	return n, token
end

local function Count(filter)
	if not Panel.Open() then
		return nil
	end
	local api = C_UnitAuras
	if not (api and type(api.GetAuraSlots) == "function") then
		LogOnce("slots", "C_UnitAuras.GetAuraSlots is missing; the card keeps its full footprint")
		return nil
	end
	local total, token = 0, nil
	repeat
		local n
		n, token = Page(pcall(api.GetAuraSlots, UNIT, filter, SLOT_PAGE, token))
		if not n then
			return nil
		end
		total = total + n
	until token == nil or total >= Model.MORE.buffs
	return total
end

local function CountSpecs(docked, buffCap, debuffCap)
	local other = groups[DOCKED_GROUP]
	local group = other and not other.failed and other.ctx.group
	local first = group and group.dispelFirst == true
	local dispel = DispelSet()
	local more = Model.MORE
	return {
		{ filter = Model.FILTERS.buffs, cap = buffCap, labels = more.buffs },
		{ filter = Model.FILTERS.debuffs, candidates = { includeDispelTypes = dispel }, cap = debuffCap, labels = more.debuffs, off = not (docked and first) },
		{ filter = Model.FILTERS.debuffs, candidates = first and { excludeDispelTypes = dispel } or nil, cap = debuffCap, labels = more.debuffs, off = not (docked and group) },
	}
end

local function NewCounter(host)
	local chip, why = Overflow.New(host, UNIT, CountSpecs(true, 0, 0), 0, { face = false })
	if not chip then
		LogOnce("counter", "the cap's +N has no counting container (" .. tostring(why) .. "); the full list stays a click away")
	end
	return chip
end

local function CountStyle(source)
	return function(text)
		local font, size, flags = source:GetFont()
		if font then
			text:SetFont(font, size, flags)
		end
		Widgets.TextColor(text, "muted")
		text:SetJustifyH("RIGHT")
		text:SetJustifyV("MIDDLE")
	end
end

local function ApplyCounter(chip, cap, specs)
	if not chip then
		return
	end
	local frame = cap.frame
	frame:SetCount(COUNT_RESERVE)
	frame.count:SetAlpha(0)
	local width = math.max(Widgets.Snap(frame, COUNT_WIDTH), Widgets.TextWidth(frame.count, 0))
	Overflow.Apply(chip, {
		enabled = true, groups = specs, cap = 0, cell = Widgets.Snap(frame, Widgets.SECTION_CAP_HEIGHT), width = width, after = true,
		point = "RIGHT", rel = frame, relPoint = "RIGHT", x = 0, y = 0, level = frame:GetFrameLevel() + 2, style = CountStyle(frame.count),
	})
end

local function MoreContext(desc, host)
	local ctx, more = desc.ctx, Model.MORE
	local out = {}
	for k, v in pairs(ctx) do
		out[k] = v
	end
	local function snap(units)
		return Widgets.Snap(host, units)
	end
	local group = {}
	for k, v in pairs(ctx.group) do
		group[k] = v
	end
	group.iconSize, group.spacing, group.columns = more.iconSize, more.spacing, more.columns
	out.group = group
	out.icon, out.spacing = snap(more.iconSize), snap(more.spacing)
	out.width, out.height = Model.ElementSize(group, ctx.timer, snap)
	out.lineSize = Model.LineSize(group, ctx.timer, snap)
	return out
end

local function MoreGroup(desc, name)
	local card = desc.card
	local source = groups[name]
	if not source or source.failed then
		return nil
	end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, card.more, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		return nil
	end
	local entry = { name = name, container = container, buttons = {}, enchants = {}, host = card.more }
	entry.ctx = MoreContext(source, card.more)
	entry.keys = Keys(source)
	container:SetUnit(UNIT)
	for _, key in ipairs(entry.keys) do
		local added, err = AddGroup(container, entry, key, Model.MORE[name], entry.ctx, function(button)
			K.Call(Init, entry, button)
		end)
		if not added then
			Log("the full list could not add the " .. key .. " group: " .. tostring(err))
			return nil
		end
	end
	local directions = AnchorUtil.FlowDirection
	container:SetFlowLayoutAnchorPoint("TOPLEFT")
	container:SetFlowLayoutGrowthDirection(directions.Right, directions.Down)
	ApplyGroups(entry, container, entry.ctx, Model.MORE[name])
	container:SetFlowLayoutMaximumLineSize(entry.ctx.lineSize)
	return entry
end

local function BuildMore(desc)
	local card, host = desc.card, desc.host
	local more = LayoutFrame(host)
	more:EnableMouse(true)
	more:Hide()
	card.more = more
	card.moreSheet = LayoutFrame(host)
	card.moreSheet:SetClampedToScreen(true)
	card.moreChrome = Widgets.Chrome(more, { shape = "panel" })
	card.moreCap = Widgets.RailCap(more, { title = L["All auras"] })
	card.moreSplit = LayoutFrame(more)
	card.moreRule = card.moreSplit:CreateTexture(nil, "ARTWORK")
	card.moreRule:SetAllPoints(card.moreSplit)
	card.moreRule:SetColorTexture(Tokens.Color("white"))
	Widgets.LumenTint(card.moreRule, "hairline")
	card.moreFoot = LayoutFrame(more)
	card.moreGroups = { buffs = MoreGroup(desc, "buffs"), debuffs = MoreGroup(desc, "debuffs") }
	card.moreCounter = NewCounter(more)
	more:SetScript("OnEnter", function()
		card.moreLeft = nil
	end)
	more:SetScript("OnLeave", function()
		Panel.LeaveMore(desc)
	end)
end

local function MoreReach(list, columns, pad, gap, snap)
	local reach = pad + snap(Widgets.SECTION_CAP_HEIGHT) + gap + gap + gap + pad
	for name, entry in pairs(list) do
		local rows = math.ceil(Model.MORE[name] * #entry.keys / columns)
		reach = reach + rows * entry.ctx.height + math.max(0, rows - 1) * entry.ctx.rowSpacing
	end
	return reach
end

local function LayoutMore(desc)
	local card = desc.card
	local more, sheet = card.more, card.moreSheet
	local function snap(units)
		return Widgets.Snap(more, units)
	end
	local pad, gap = snap(Model.CARD_PAD), snap(Model.CARD_GAP)
	local list = card.moreGroups
	local full = list.buffs or list.debuffs
	local columns = Model.MORE.columns
	local tile = full and full.ctx.width or snap(Model.MORE.iconSize)
	local spacing = full and full.ctx.spacing or snap(Model.MORE.spacing)
	local inner = columns * tile + (columns - 1) * spacing
	sheet:ClearAllPoints()
	sheet:SetPoint("TOPRIGHT", desc.host, "TOPLEFT", -snap(MORE_GAP), 0)
	sheet:SetSize(inner + 2 * pad, 1)
	sheet:SetClampRectInsets(0, 0, 0, -MoreReach(list, columns, pad, gap, snap))
	local cap = card.moreCap
	cap.frame:ClearAllPoints()
	cap.frame:SetPoint("TOPLEFT", sheet, "TOPLEFT", pad, -pad)
	cap.frame:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -pad, -pad)
	cap:Restyle()
	local above, point, y = sheet, "TOPLEFT", -(pad + snap(Widgets.SECTION_CAP_HEIGHT) + gap)
	local x = pad
	if list.buffs then
		local container = list.buffs.container
		container:ClearAllPoints()
		container:SetPoint("TOPLEFT", above, point, x, y)
		container:Show()
		above, point, x, y = container, "BOTTOMLEFT", 0, -gap
	end
	local split = card.moreSplit
	split:ClearAllPoints()
	split:SetPoint("TOPLEFT", above, point, x, y)
	split:SetSize(inner, Widgets.Border(more))
	Widgets.LumenTint(card.moreRule, "hairline")
	split:SetShown(list.buffs ~= nil and list.debuffs ~= nil)
	above, point, x, y = split, "BOTTOMLEFT", 0, -gap
	if list.debuffs then
		local container = list.debuffs.container
		container:ClearAllPoints()
		container:SetPoint("TOPLEFT", above, point, x, y)
		container:Show()
		above, point, x, y = container, "BOTTOMLEFT", 0, 0
	end
	local foot = card.moreFoot
	foot:ClearAllPoints()
	foot:SetPoint("TOPLEFT", above, point, x - pad, y)
	foot:SetSize(1, pad)
	more:ClearAllPoints()
	more:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", 0, 0)
	more:SetPoint("BOTTOMLEFT", foot, "BOTTOMLEFT", 0, 0)
	card.moreChrome:SetEdge("edgeInner")
	ApplyCounter(card.moreCounter, cap, CountSpecs(true, Model.MORE.buffs, Model.MORE.debuffs))
end

local function ApplyMore(desc)
	local card = desc.card
	if not (card and card.moreGroups) then
		return
	end
	for name, entry in pairs(card.moreGroups) do
		local source = groups[name]
		if source and not source.failed then
			entry.ctx = MoreContext(source, card.more)
			ApplyGroups(entry, entry.container, entry.ctx, Model.MORE[name])
			entry.container:SetFlowLayoutMaximumLineSize(entry.ctx.lineSize)
			RestyleButtons(entry)
		end
	end
	LayoutMore(desc)
end

function Panel.OpenMore(desc)
	local card = desc.card
	if not card.more then
		BuildMore(desc)
		LayoutMore(desc)
	end
	card.moreLeft = nil
	for _, entry in pairs(card.moreGroups) do
		RestyleButtons(entry)
	end
	card.more:Show()
end

function Panel.LeaveMore(desc)
	local card = desc.card
	if card.pinned or not card.more or not card.more:IsShown() then
		return
	end
	local token = {}
	card.moreLeft = token
	C_Timer.After(MORE_CLOSE_DELAY, function()
		if card.moreLeft == token and not card.pinned then
			card.more:Hide()
		end
	end)
end

function Panel.PinMore(desc)
	local card = desc.card
	card.pinned = not card.pinned
	if card.pinned then
		Panel.OpenMore(desc)
	elseif card.more then
		card.moreLeft = nil
		card.more:Hide()
	end
end

function BuildMoreButton(desc)
	local card = desc.card
	local button = CreateFrame("Button", nil, desc.host)
	button:SetAllPoints(card.cap.frame)
	button:SetFrameLevel(card.cap.frame:GetFrameLevel() + BUTTON_LEVEL)
	button:SetScript("OnEnter", function()
		Panel.OpenMore(desc)
	end)
	button:SetScript("OnLeave", function()
		Panel.LeaveMore(desc)
	end)
	button:SetScript("OnClick", function()
		Panel.PinMore(desc)
	end)
	card.moreButton = button
	card.counter = NewCounter(desc.host)
end

function Recount(desc)
	local card = desc.card
	if not card then
		return
	end
	local other = groups[DOCKED_GROUP]
	local debuffCap = other and not other.failed and Model.Capacity(other.ctx.group, 0) or 0
	ApplyCounter(card.counter, card.cap, CountSpecs(Docked(), Model.Capacity(desc.ctx.group, ActiveEnchants(desc)), debuffCap))
end

function Fit(unknown)
	local desc = groups[CARD_GROUP]
	if not (running and desc and not desc.failed and desc.card) then
		return
	end
	local card = desc.card
	local buffs, debuffs
	if not unknown then
		buffs, debuffs = Count(Model.FILTERS.buffs), Count(Model.FILTERS.debuffs)
	end
	local docked = Docked()
	local band, empty = card.band ~= false, false
	if buffs ~= nil and debuffs ~= nil then
		local enchants = ActiveEnchants(desc)
		band = debuffs > 0 and (buffs > 0 or enchants > 0)
		empty = buffs == 0 and enchants == 0 and (not docked or debuffs == 0)
	end
	if card.band == band and card.empty == empty then
		return
	end
	card.band, card.empty = band, empty
	LayoutCard(desc, docked)
	local other = groups[DOCKED_GROUP]
	if other and not other.failed then
		ShowHost(other)
	end
end

local function OnAura()
	Fit()
end

local function Apply(desc, relayout)
	desc.ctx = Context(desc)
	local ctx, holder = desc.ctx, desc.holder
	K.Call(ApplyContainer, desc)
	local wantW, wantH = ctx.footWidth, ctx.footHeight
	if desc.card then
		wantW, wantH = LayoutCard(desc, Docked())
	elseif desc.dock then
		Dock(desc, Docked())
		desc.content:ClearAllPoints()
		desc.content:SetAllPoints(desc.host)
	end
	local w, h = holder:GetSize()
	if w ~= wantW or h ~= wantH then
		holder:SetSize(wantW, wantH)
		relayout = true
	end
	if relayout and K.Layout and K.Layout.Restore then
		K.Layout.Restore(Model.KEYS[desc.name])
	end
	RestyleButtons(desc)
	if desc.card then
		desc.card.band, desc.card.empty = nil, nil
		Fit()
		Recount(desc)
	end
	local card = groups[CARD_GROUP] and groups[CARD_GROUP].card
	if card and card.moreGroups and card.moreGroups[desc.name] then
		ApplyMore(groups[CARD_GROUP])
	end
end

local function ApplyAll(relayout)
	for i = #Model.GROUPS, 1, -1 do
		local desc = groups[Model.GROUPS[i]]
		if desc and not desc.failed then
			Apply(desc, relayout)
		end
	end
end

local function BlizzardFrame(name)
	if name == "buffs" then
		return BuffFrame
	end
	return DebuffFrame
end

local function Blizzard()
	local hide = running and not gamepad and K.Store.Module(MODULE).hideBlizzard ~= false
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		local frame = BlizzardFrame(name)
		if hide and desc and not desc.failed then
			K.Safe.HideBlizzard(frame)
		else
			K.Safe.RestoreBlizzard(frame)
		end
	end
end

local function OnSetting(_, module, key)
	if module ~= MODULE or key == "enabled" then
		return
	end
	if key == "hideBlizzard" then
		Blizzard()
		return
	end
	ApplyAll(false)
end

local OWN_KEYS = {}
for _, key in pairs(Model.KEYS) do
	OWN_KEYS[key] = true
end

local HANDLERS = {
	SettingChanged = OnSetting,
	ThemeChanged = function()
		ApplyAll(false)
	end,
	ScaleChanged = function()
		ApplyAll(true)
	end,
	ProfileChanged = function()
		ApplyAll(true)
		Blizzard()
	end,
	LayoutChanged = function(_, key)
		if OWN_KEYS[key] then
			ApplyAll(false)
		end
	end,
}

local function OnEnchant()
	local desc = groups.buffs
	if desc and not desc.failed then
		K.Call(UpdateCapacity, desc)
		Fit()
		Recount(desc)
	end
end

local function Refresh()
	if not running then
		return
	end
	SetGamepad(Panel.Gamepad())
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		if desc and not desc.failed then
			ShowHost(desc)
		end
	end
	Blizzard()
end

local function OnTransition()
	K.Combat.Queue(Refresh)
end

function Panel.Enable()
	running = true
	pending = false
	SetGamepad(Panel.Gamepad())
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		if not desc then
			desc = Build(name)
			groups[name] = desc
		end
		if not desc.failed then
			desc.holder:Show()
		end
	end
	local card = groups[CARD_GROUP]
	if card and not card.failed and card.card and not card.card.more then
		BuildMore(card)
	end
	ApplyAll(true)
	Blizzard()
	for _, event in ipairs(ENCHANT_EVENTS) do
		Listen(event, OnEnchant)
	end
	Listen(INPUT_EVENT, OnTransition)
	for _, event in ipairs(GATE_EVENTS) do
		Listen(event, OnGateEvent)
	end
	local ok, err = pcall(K.Events.RegisterUnit, MODULE, AURA_EVENT, OnAura, UNIT)
	if not ok then
		LogOnce("event:" .. AURA_EVENT, "could not listen for " .. AURA_EVENT .. ": " .. tostring(err))
	end
	for _, name in ipairs(CALLBACKS) do
		K.Callbacks.Register(name, MODULE, HANDLERS[name])
	end
end

function Panel.Disable()
	running = false
	StopWaiting()
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		if desc and not desc.failed then
			desc.holder:Hide()
		end
	end
	Blizzard()
end

function Panel.Status()
	local built, failed = {}, {}
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
		if desc and desc.failed then
			failed[#failed + 1] = name
		elseif desc then
			built[#built + 1] = format("%s %d", name, #desc.buttons)
		end
	end
	if #failed > 0 then
		return false, "no AuraContainer for " .. concat(failed, ", ") .. "; Blizzard's frames kept"
	end
	local path = gamepad and "; gamepad interface, so Blizzard's frames show" or ""
	return true, "aura buttons: " .. concat(built, ", ") .. path
end
