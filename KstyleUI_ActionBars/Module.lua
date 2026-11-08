-- Module.lua: registers the ActionBars module and runs it: Enable, Disable, events, settings changes and gamepad transitions.
local _, ns = ...

local K = KstyleUI
local Events = K.Events

local MODULE = "ActionBars"

ns.bars = {}
ns.actionButtons, ns.petButtons, ns.stanceButtons = {}, {}, {}
ns.running, ns.enabling, ns.gamepad, ns.grid = false, false, false, 0

function ns.Config(key)
	return K.Store.Module(MODULE)[key]
end

local applyQueued = false

local function Accent()
	local mode = ns.Config("accent")
	if mode == "custom" then
		local c = ns.Config("accentColor")
		if type(c) == "table" and type(c.r) == "number" then
			return c.r, c.g, c.b
		end
	elseif mode == "class" then
		local r, g, b = K.Theme.ClassColor(K.Theme.Class())
		return r, g, b
	end
end

ns.AccentRGB = Accent

local function EachButton(fn)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			for _, b in ipairs(bar.buttons) do
				fn(b)
			end
		end
	end
end

local function ApplyAccent()
	local r, g, b = Accent()
	EachButton(function(button)
		ns.Button.SetAccent(button, r, g, b)
	end)
end

local function Build(def)
	local bar = ns.NewBar(def)
	ns.bars[def.key] = bar
	local list = def.kind == "action" and ns.actionButtons or (def.kind == "pet" and ns.petButtons or ns.stanceButtons)
	for _, b in ipairs(bar.buttons) do
		list[#list + 1] = b
	end
	local r, g, b = Accent()
	for _, button in ipairs(bar.buttons) do
		ns.Button.SetAccent(button, r, g, b)
	end
	return bar
end

local function ApplyAll()
	applyQueued = false
	if InCombatLockdown() and not ns.enabling then
		ns.QueueApply()
		return
	end
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Apply()
		elseif ns.running and ns.Config(def.key).enabled then
			Build(def)
		end
	end
	ns.ApplyBindings()
	ns.Vehicle.Update()
end

function ns.QueueApply()
	if applyQueued then
		return
	end
	applyQueued = true
	K.Combat.Queue(ApplyAll)
end

local function RefreshVisuals()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Refresh()
		end
	end
	ApplyAccent()
end

local function ForSlot(slot, fn, a, b2)
	local list = ns.actionButtons
	for i = 1, #list do
		local button = list[i]
		if button.slot == slot then
			fn(button, a, b2)
		end
	end
end

local function ForActions(fn)
	local list = ns.actionButtons
	for i = 1, #list do
		fn(list[i])
	end
end

local function UpdatePets()
	local list = ns.petButtons
	for i = 1, #list do
		ns.Button.Update(list[i])
	end
end

local function UpdateStances()
	local list = ns.stanceButtons
	for i = 1, #list do
		ns.Button.Update(list[i])
	end
end

local function UpdateAll()
	ForActions(ns.Button.Update)
	UpdatePets()
	UpdateStances()
end

local function OnSlotChanged(_, slot)
	if ns.IsSecret(slot) or type(slot) ~= "number" or slot == 0 then
		ForActions(ns.Button.Update)
		ns.Flyout.QueueRefresh()
	else
		ns.Flyout.SlotChanged(slot)
		ForSlot(slot, ns.Button.Update)
	end
end

local function OnSpells()
	ns.Flyout.QueueRefresh()
end

local function OnLearned(_, spellID)
	ns.Flyout.QueueRefresh()
	ns.Ranks.Learned(spellID)
end

local function OnSpellLoaded(_, spellID, success)
	ns.Ranks.Loaded(spellID, success)
end

local function OnUsableChanged(_, changes)
	if ns.IsSecret(changes) or type(changes) ~= "table" then
		ForActions(ns.Button.UpdateUsable)
		return
	end
	for i = 1, #changes do
		local change = changes[i]
		local slot = type(change) == "table" and change.slot
		if type(slot) == "number" and not ns.IsSecret(slot) then
			ForSlot(slot, ns.Button.UpdateUsable, change.usable, change.noMana)
		end
	end
end

local function OnRange(_, slot, inRange, checksRange)
	if ns.IsSecret(slot) or type(slot) ~= "number" then
		return
	end
	ForSlot(slot, ns.Button.UpdateRange, inRange, checksRange)
end

local function OnProc(event, spellID)
	if ns.IsSecret(spellID) or type(spellID) ~= "number" then
		ForActions(ns.Button.UpdateProc)
		return
	end
	local on = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
	local list = ns.actionButtons
	for i = 1, #list do
		local button = list[i]
		if button.spellID == spellID then
			ns.Button.SetProc(button, on)
		end
	end
end

local grids = { ACTIONBAR_SHOWGRID = "action", ACTIONBAR_HIDEGRID = "action", PET_BAR_SHOWGRID = "pet", PET_BAR_HIDEGRID = "pet" }
local gridShown = { action = false, pet = false }

local function OnGrid(event)
	gridShown[grids[event]] = event == "ACTIONBAR_SHOWGRID" or event == "PET_BAR_SHOWGRID"
	ns.grid = (gridShown.action or gridShown.pet) and 1 or 0
	EachButton(ns.Button.UpdateAlpha)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:RefreshFade()
		end
	end
end

local function OnCooldown()
	ForActions(ns.Button.UpdateCooldown)
end

local function OnCharges()
	ForActions(ns.Button.UpdateCount)
	ForActions(ns.Button.UpdateCooldown)
end

local function OnState()
	ForActions(ns.Button.UpdateState)
end

local function OnTarget()
	ForActions(ns.Button.UpdateRange)
	UpdatePets()
end

local function OnForms()
	local bar = ns.bars.stance
	if bar and bar:FormsChanged() then
		bar:Apply()
		ns.ApplyBindings()
	end
	UpdateStances()
end

local function OnForm()
	ForActions(ns.Button.Update)
	UpdateStances()
end

local function OnTransition()
	local gamepad = ns.IsGamepad()
	if gamepad ~= ns.gamepad then
		ns.gamepad = gamepad
		ns.Log(gamepad and "gamepad interface on: KstyleUI's bars hide and drop their bindings" or "gamepad interface off: KstyleUI's bars return")
	end
	ApplyAll()
end

local function OnSetting(_, module, key)
	if module ~= MODULE or type(key) ~= "string" or key == "editBar" or key == "tooltips" then
		return
	end
	if key == "ranks" and ns.Config("ranks") == "off" then
		ns.Ranks.Stop()
	end
	local barKey, field = key:match("^(%w+)%.(.+)$")
	if barKey and ns.BAR[barKey] then
		if field ~= "showEmpty" and field ~= "fade" and field ~= "fadeAlpha" and field ~= "hotkey" and field ~= "count" and field ~= "macro" and field ~= "cooldown" then
			ApplyAll()
		end
	end
	RefreshVisuals()
end

local function OnProfile()
	ApplyAll()
	RefreshVisuals()
end

local function OnLayout(_, key)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar and def.element == key then
			bar:Apply()
		end
	end
end

local EVENTS = {
	PLAYER_ENTERING_WORLD = UpdateAll,
	ACTIONBAR_SLOT_CHANGED = OnSlotChanged,
	ACTIONBAR_UPDATE_COOLDOWN = OnCooldown,
	SPELL_UPDATE_COOLDOWN = OnCooldown,
	SPELL_UPDATE_CHARGES = OnCharges,
	BAG_UPDATE_DELAYED = OnCharges,
	ACTIONBAR_UPDATE_STATE = OnState,
	START_AUTOREPEAT_SPELL = OnState,
	STOP_AUTOREPEAT_SPELL = OnState,
	PLAYER_ENTER_COMBAT = OnState,
	PLAYER_LEAVE_COMBAT = OnState,
	ACTIONBAR_UPDATE_USABLE = OnUsableChanged,
	ACTION_USABLE_CHANGED = OnUsableChanged,
	ACTION_RANGE_CHECK_UPDATE = OnRange,
	PLAYER_TARGET_CHANGED = OnTarget,
	SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = OnProc,
	SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = OnProc,
	SPELL_UPDATE_ICON = OnSlotChanged,
	UPDATE_MACROS = OnSlotChanged,
	UPDATE_BINDINGS = function()
		ns.ApplyBindings()
	end,
	ACTIONBAR_SHOWGRID = OnGrid,
	ACTIONBAR_HIDEGRID = OnGrid,
	PET_BAR_SHOWGRID = OnGrid,
	PET_BAR_HIDEGRID = OnGrid,
	UPDATE_SHAPESHIFT_FORMS = OnForms,
	UPDATE_SHAPESHIFT_FORM = OnForm,
	UPDATE_SHAPESHIFT_USABLE = UpdateStances,
	UPDATE_SHAPESHIFT_COOLDOWN = UpdateStances,
	PET_BAR_UPDATE = UpdatePets,
	PET_BAR_UPDATE_COOLDOWN = UpdatePets,
	PET_BAR_UPDATE_USABLE = UpdatePets,
	PET_UI_UPDATE = UpdatePets,
	PLAYER_CONTROL_LOST = UpdatePets,
	PLAYER_CONTROL_GAINED = UpdatePets,
	INPUT_DEVICE_INTERFACE_TRANSITION = OnTransition,
	SPELLS_CHANGED = OnSpells,
	LEARNED_SPELL_IN_SKILL_LINE = OnLearned,
	SPELL_DATA_LOAD_RESULT = OnSpellLoaded,
	SPELL_FLYOUT_UPDATE = OnSpells,
	VEHICLE_UPDATE = ns.Vehicle.Update,
	UPDATE_BONUS_ACTIONBAR = ns.Vehicle.Update,
	UPDATE_OVERRIDE_ACTIONBAR = ns.Vehicle.Update,
	UPDATE_VEHICLE_ACTIONBAR = ns.Vehicle.Update,
}

local function Enable()
	ns.enabling = true
	ns.running = true
	ns.class = select(2, UnitClass("player"))
	ns.gamepad = ns.IsGamepad()
	if not (C_ActionBar and type(C_ActionBar.HasAction) == "function" and type(C_ActionBar.GetActionTexture) == "function") then
		ns.enabling = false
		error("C_ActionBar is missing on this client; the action bars cannot run")
	end
	for event, fn in pairs(EVENTS) do
		Events.Register(MODULE, event, fn)
	end
	Events.RegisterUnit(MODULE, "UNIT_PET", UpdatePets, "player")
	Events.RegisterUnit(MODULE, "UNIT_FLAGS", UpdatePets, "pet")
	Events.RegisterUnit(MODULE, "UNIT_ENTERED_VEHICLE", ns.Vehicle.Update, "player")
	Events.RegisterUnit(MODULE, "UNIT_EXITED_VEHICLE", ns.Vehicle.Update, "player")
	K.Callbacks.Register("SettingChanged", MODULE, OnSetting)
	K.Callbacks.Register("ProfileChanged", MODULE, OnProfile)
	K.Callbacks.Register("ThemeChanged", MODULE, RefreshVisuals)
	K.Callbacks.Register("ClassChanged", MODULE, ApplyAccent)
	K.Callbacks.Register("LayoutChanged", MODULE, OnLayout)
	K.Callbacks.Register("ScaleChanged", MODULE, ApplyAll)
	ns.Flyout.Build()
	ApplyAll()
	ns.Vehicle.Build()
	ns.Vehicle.Update()
	ns.Flyout.Refresh()
	ns.HideBlizzard()
	UpdateAll()
	ns.enabling = false
	ns.Log("running for class " .. tostring(ns.class) .. (ns.gamepad and " in gamepad mode: the bars stay hidden" or "") .. "; Blizzard's keyboard bars are hidden through Safe")
end

local function Disable()
	ns.enabling = false
	ns.running = false
	ApplyAll()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Release()
		end
	end
	ns.Flyout.Close()
	ns.Ranks.Stop()
	ns.RestoreBlizzard()
	gridShown.action, gridShown.pet, ns.grid = false, false, 0
end

ns.Enable, ns.Disable = Enable, Disable

K.Modules.Register({ name = MODULE, defaults = ns.defaults, Enable = Enable, Disable = Disable })

local schema = ns.Schema()
schema.preview = function(parent)
	return ns.Preview(parent)
end
K.Options.Register(MODULE, schema)

K.DevTest.AddCheck("actionbars", function()
	if not K.Modules.IsRunning(MODULE) then
		return true, "off"
	end
	local built, bound = 0, 0
	for _, def in ipairs(ns.BARS) do
		if ns.bars[def.key] then
			built = built + 1
		end
	end
	if type(GetBindingKey) == "function" and GetBindingKey("ACTIONBUTTON1") then
		bound = 1
	end
	if built == 0 then
		return false, "no bars were built"
	end
	return true, built .. " bars built" .. (ns.gamepad and ", gamepad mode" or "") .. (bound > 0 and ", keybinds mirrored" or "")
end)
