-- Panel.lua: the buff and debuff rows: one AuraContainer each on the engine, each its own Layout element that the rows grow from, weapon enchantments on the buff row, the Cooldown Manager's tracked buffs left out through the engine's spell filter, a "+N" socket on the last cell counted by the engine's own layout (so it stays true in combat), the aura-secrecy gate, and Blizzard's frames, which return in the gamepad interface.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Overflow = Widgets.Overflow
local Model, Button, Tracked = ns.Model, ns.Button, ns.Tracked
local format, concat, min = string.format, table.concat, math.min

local Panel = {}
ns.Panel = Panel

local MODULE = Model.MODULE
local TEMPLATE = "CustomAuraContainerTemplate"
local UNIT = "player"
local HOST_LEVEL = 2
local CHIP_LEVEL = 4
local TILE_EDGE = "black"
local GATE_EVENTS = { "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }
local ENCHANT_EVENTS = { "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD" }
local INPUT_EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"
local CALLBACKS = { "SettingChanged", "ThemeChanged", "ScaleChanged", "ProfileChanged", "LayoutChanged" }
local EDGE_TOKENS = { buffs = "edgeInner", debuffs = "hostile" }
local LAYOUT_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local FALLBACK = {
	buffs = { position = { anchor = "TOPRIGHT", x = -28, y = -390 }, label = K.L["Buffs"] },
	debuffs = { position = { anchor = "TOPRIGHT", x = -28, y = -494 }, label = K.L["Debuffs"] },
}

local groups = {}
local listeners = {}
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
		Log("gamepad interface on: Blizzard's buff frames return for the gamepad's View buffs, and KstyleUI's aura rows hide")
	else
		Log("gamepad interface off: KstyleUI's aura rows return, and Blizzard's buff frames follow the hide setting")
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

local function Dispatch(event, ...)
	local list = listeners[event]
	if not list then
		return
	end
	for i = 1, #list do
		K.Call(list[i], event, ...)
	end
end

local function Listen(event, fn)
	local list = listeners[event]
	if list then
		list[#list + 1] = fn
		return true
	end
	local ok, err = pcall(K.Events.Register, MODULE, event, Dispatch)
	if not ok then
		LogOnce("event:" .. event, "could not listen for " .. event .. ": " .. tostring(err))
		return false
	end
	listeners[event] = { fn }
	return true
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

local flushQueued, enchantsQueued = false, false

local function QueuedFlush()
	flushQueued = false
	Panel.Flush()
end

local function OnGateEvent()
	if waiting and not flushQueued then
		flushQueued = true
		C_Timer.After(0, QueuedFlush)
	end
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
		c:AddPoint(expiring, CreateColor(Tokens.Color("timerText")))
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

local function EdgeColor()
	local r, g, b = Tokens.Color(TILE_EDGE)
	return { r, g, b, 1 }
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
		lineSize = Model.LineSize(group, timer, snap),
		edge = EdgeColor(),
		timerOptions = { textFormatter = Formatter(timer.format), textColor = ExpiringColor(timer.expiring) },
		dispelOptions = group.dispel and DispelOptions() or nil,
	}
	ctx.width, ctx.height = Model.ElementSize(group, timer, snap)
	ctx.spacing, ctx.rowSpacing = Model.Gaps(group, timer, snap)
	ctx.foot = ctx.height - ctx.icon
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

local function Candidates(desc)
	local group = desc.ctx.group
	if group.tracked ~= "cdm" then
		return nil
	end
	local set, why = Tracked.Set()
	if not set then
		LogOnce("tracked:" .. tostring(why), "the buff row shows every buff: " .. tostring(why))
		return nil
	end
	return { excludeSpellIDs = set }
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

local function Capacity(desc)
	return Model.Capacity(desc.ctx.group, ActiveEnchants(desc))
end

local function ChipStyle(ctx)
	return function(text)
		Button.StyleText(text, ctx.count)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("MIDDLE")
	end
end

local function ApplyChip(desc, candidates)
	local chip = desc.chip
	if not chip then
		return
	end
	local ctx, host = desc.ctx, desc.host
	local corner = Model.LastCell(ctx.group.growth)
	Overflow.Apply(chip, {
		enabled = true,
		groups = { { filter = Model.FILTERS[desc.name], candidates = candidates, cap = Capacity(desc), labels = Model.LABELS[desc.name] } },
		cap = Capacity(desc), cell = ctx.icon, foot = ctx.foot, width = ctx.icon,
		point = corner, rel = host, relPoint = corner, x = 0, y = 0,
		level = host:GetFrameLevel() + CHIP_LEVEL, style = ChipStyle(ctx),
		accent = function()
			return Tokens.Color(EDGE_TOKENS[desc.name])
		end,
	})
end

local function ApplyGroup(desc)
	local ctx, container, key = desc.ctx, desc.container, desc.name
	local method, direction = SortEnums(ctx.group)
	container:SetAuraGroupLayout(key, GroupLayout(ctx))
	if method ~= nil and direction ~= nil then
		container:SetAuraGroupSortMethod(key, method, direction)
	end
	container:SetAuraGroupMaxFrameCount(key, Capacity(desc))
	local candidates = Candidates(desc)
	if type(container.SetAuraGroupCandidateFilters) == "function" then
		container:SetAuraGroupCandidateFilters(key, candidates)
	end
	ApplyChip(desc, candidates)
end

local function Init(desc, button)
	local entry = Button.Create(button, desc.name == "debuffs")
	desc.buttons[#desc.buttons + 1] = entry
	Button.Style(entry, desc.ctx)
end

function Panel.Group(name)
	return groups[name]
end

local function ShowHost(desc)
	desc.host:SetShown(desc.holder:IsShown() and not gamepad)
end

local function LayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, LAYOUT_TEMPLATE)
	if ok and type(frame) == "table" then
		return frame
	end
	LogOnce("layout-template", LAYOUT_TEMPLATE .. " is missing; the rows anchor to the engine's containers without it")
	return CreateFrame("Frame", nil, parent)
end

local function Follow(desc)
	local host, holder = desc.host, desc.holder
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	host:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
	host:SetScale(holder:GetScale())
	host:SetAlpha(holder:GetAlpha())
	host:SetFrameStrata(holder:GetFrameStrata())
	host:SetFrameLevel(holder:GetFrameLevel() + HOST_LEVEL)
	ShowHost(desc)
end

local function Mirror(desc)
	Follow(desc)
	for _, method in ipairs({ "SetScale", "SetAlpha", "SetFrameStrata", "Show", "Hide", "SetShown" }) do
		hooksecurefunc(desc.holder, method, function()
			Follow(desc)
		end)
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

local function NewChip(desc)
	local capacity = Capacity(desc)
	local spec = { filter = Model.FILTERS[desc.name], cap = capacity, labels = Model.LABELS[desc.name] }
	local chip, why = Overflow.New(desc.host, UNIT, { spec }, capacity)
	if not chip then
		LogOnce("chip", "the " .. desc.name .. " row has no counting container (" .. tostring(why) .. "); a full row shows no +N")
	end
	return chip
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
	container:SetUnit(UNIT)
	local method, direction = SortEnums(desc.ctx.group)
	local added, err = pcall(container.AddAuraGroup, container, name, Model.FILTERS[name], {
		maxFrameCount = Model.Capacity(desc.ctx.group, 0),
		sortMethod = method,
		sortDirection = direction,
		layout = GroupLayout(desc.ctx),
		candidateFilters = Candidates(desc),
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
	desc.chip = NewChip(desc)
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
	local hang = Model.Hang(ctx.group.growth)
	container:SetPoint(hang, desc.host, hang, 0, 0)
	ApplyGroup(desc)
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
	local w, h = holder:GetSize()
	if w ~= ctx.footWidth or h ~= ctx.footHeight then
		holder:SetSize(ctx.footWidth, ctx.footHeight)
		relayout = true
	end
	if relayout and K.Layout and K.Layout.Restore then
		K.Layout.Restore(Model.KEYS[desc.name])
	end
	RestyleButtons(desc)
end

local function ApplyAll(relayout)
	for _, name in ipairs(Model.GROUPS) do
		local desc = groups[name]
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

local function ApplyEnchants()
	enchantsQueued = false
	local desc = groups.buffs
	if running and desc and not desc.failed then
		K.Call(ApplyGroup, desc)
	end
end

local function OnEnchant()
	if not enchantsQueued then
		enchantsQueued = true
		C_Timer.After(0, ApplyEnchants)
	end
end

local function OnTracked()
	local desc = groups.buffs
	if running and desc and not desc.failed then
		K.Call(ApplyGroup, desc)
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
	listeners = {}
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
	for _, event in ipairs(GATE_EVENTS) do
		Listen(event, OnGateEvent)
	end
	Tracked.Listen(OnTracked, Listen)
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
