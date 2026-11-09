-- Panel.lua: the Blessings card: the buff and debuff containers on the AuraContainer engine, the card and its cap on the buff element, the debuff row docked under a hairline or free as its own element, weapon enchantments, the aura-secrecy gate, and Blizzard's frames, which return in the gamepad interface.
local _, ns = ...

local K = KstyleUI
local L, Widgets, Tokens = K.L, K.Widgets, K.Tokens
local Model, Button = ns.Model, ns.Button
local format, concat, min = string.format, table.concat, math.min

local Panel = {}
ns.Panel = Panel

local MODULE = Model.MODULE
local TEMPLATE = "CustomAuraContainerTemplate"
local UNIT = "player"
local HOST_LEVEL = 2
local REST_EDGE_ALPHA = 0.5
local GATE_EVENTS = { "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED" }
local ENCHANT_EVENTS = { "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD" }
local INPUT_EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"
local CALLBACKS = { "SettingChanged", "ThemeChanged", "ScaleChanged", "ProfileChanged", "LayoutChanged" }
local EDGE_TOKENS = { buffs = "edgeInner", debuffs = "hostile" }
local CARD_GROUP, DOCKED_GROUP = "buffs", "debuffs"
local FALLBACK = {
	buffs = { position = { anchor = "TOPRIGHT", x = -287, y = -16 }, label = K.L["Buffs"] },
	debuffs = { position = { anchor = "TOPRIGHT", x = -287, y = -126 }, label = K.L["Debuffs"] },
}

local groups = {}
local running, pending, waiting, gamepad = false, false, false, false
local logged = {}
local formatters = {}

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
	if waiting then
		waiting = false
		for _, event in ipairs(GATE_EVENTS) do
			pcall(K.Events.Unregister, MODULE, event)
		end
	end
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

local function OnGateEvent()
	C_Timer.After(0, Panel.Flush)
end

function Panel.Wait()
	pending = true
	if waiting or not running then
		return
	end
	waiting = true
	Log("restyling the aura buttons waits until aura data is no longer secret")
	for _, event in ipairs(GATE_EVENTS) do
		Listen(event, OnGateEvent)
	end
end

local function Formatter(timerFormat)
	if timerFormat == "short" then
		return nil
	end
	local cached = formatters[timerFormat]
	if cached ~= nil then
		return cached or nil
	end
	local util, E = C_StringUtil, Enum
	local made = false
	if util and type(util.CreateSecondsFormatter) == "function" and E and E.SecondsFormatterAbbreviation and E.SecondsFormatterRounding and E.SecondsFormatterInterval then
		local ok, result = pcall(function()
			local f = util.CreateSecondsFormatter()
			f:SetDefaultAbbreviation(E.SecondsFormatterAbbreviation.OneLetter)
			f:SetRounding(E.SecondsFormatterRounding.Truncate)
			f:SetCanRoundUpLastUnit(true)
			f:SetMinInterval(E.SecondsFormatterInterval.Seconds)
			if timerFormat == "long" then
				f:SetDesiredUnitCount(2)
			else
				f:SetDesiredUnitCount(1)
				f:SetMillisecondsThreshold(Model.DECIMAL_BELOW)
			end
			return f
		end)
		if ok then
			made = result
			Log("the " .. timerFormat .. " timer format uses a C_StringUtil seconds formatter")
		else
			Log("the " .. timerFormat .. " timer format failed (" .. tostring(result) .. "); timers use the engine's default format")
		end
	else
		Log("C_StringUtil.CreateSecondsFormatter is missing; timers use the engine's default format")
	end
	formatters[timerFormat] = made
	return made or nil
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
		elementWidth = ctx.width,
		elementHeight = ctx.height,
	}
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

local function UpdateCapacity(desc)
	desc.container:SetAuraGroupMaxFrameCount(desc.name, Model.Capacity(desc.ctx.group, ActiveEnchants(desc)))
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

local function ShowHost(desc)
	local source = Source(desc)
	desc.host:SetShown(source:IsShown() and not gamepad)
end

local function Follow(desc)
	local host = desc.host
	local source, anchor = Source(desc)
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	host:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
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
	}
	card.rule:SetColorTexture(Tokens.Color("white"))
	Widgets.LumenTint(card.rule, "hairline")
	card.rule:Hide()
	desc.card = card
end

local function Docked()
	return Model.Docked(K.Store.Module(MODULE))
end

local function LayoutCard(desc, docked)
	local host, card, ctx = desc.host, desc.card, desc.ctx
	local other = groups[DOCKED_GROUP]
	local debuffs = docked and other and not other.failed and other.dock ~= nil and { width = other.ctx.footWidth, height = other.ctx.footHeight } or nil
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
	desc.content:ClearAllPoints()
	desc.content:SetPoint("TOPLEFT", host, "TOPLEFT", snap(pad), -snap(shape.contentTop))
	desc.content:SetSize(ctx.footWidth, ctx.footHeight)
	local rule = card.rule
	rule:ClearAllPoints()
	if debuffs then
		rule:SetPoint("TOPLEFT", host, "TOPLEFT", snap(pad), -snap(shape.ruleTop))
		rule:SetPoint("TOPRIGHT", host, "TOPRIGHT", -snap(pad), -snap(shape.ruleTop))
		rule:SetHeight(Widgets.Border(host))
		Widgets.LumenTint(rule, "hairline")
		rule:Show()
		local dock = other.dock
		dock:ClearAllPoints()
		dock:SetPoint("TOPLEFT", desc.holder, "TOPLEFT", snap(pad), -snap(shape.debuffTop))
		dock:SetSize(other.ctx.footWidth, other.ctx.footHeight)
	else
		rule:Hide()
	end
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

local function Build(name)
	local root = K.Scale.Root()
	local host = CreateFrame("Frame", nil, root)
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
	local method, direction = SortEnums(desc.ctx.group)
	container:SetUnit(UNIT)
	local added, err = pcall(container.AddAuraGroup, container, name, Model.FILTERS[name], {
		maxFrameCount = Model.Capacity(desc.ctx.group, 0),
		sortMethod = method,
		sortDirection = direction,
		layout = GroupLayout(desc.ctx),
		initializeFrame = function(button)
			K.Call(Init, desc, button)
		end,
	})
	if not added then
		host:Hide()
		desc.failed = true
		Log("AuraContainer refused the " .. name .. " group (" .. tostring(err) .. "); Blizzard's frame stays")
		return desc
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
			desc.dock = CreateFrame("Frame", nil, card.holder)
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
	container:SetAuraGroupLayout(desc.name, GroupLayout(ctx))
	local method, direction = SortEnums(ctx.group)
	if method ~= nil and direction ~= nil then
		container:SetAuraGroupSortMethod(desc.name, method, direction)
	end
	UpdateCapacity(desc)
	local slots = EnchantSlots(desc)
	for i, enchant in ipairs(desc.enchants) do
		container:SetItemEnchantmentEnabled(enchant.slot, i <= slots)
	end
	if #desc.enchants > 0 then
		container:SetItemEnchantmentLayout(EnchantLayout(ctx))
	end
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
	ApplyAll(true)
	Blizzard()
	for _, event in ipairs(ENCHANT_EVENTS) do
		Listen(event, OnEnchant)
	end
	Listen(INPUT_EVENT, OnTransition)
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
