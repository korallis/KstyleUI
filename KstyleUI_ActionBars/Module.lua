-- Module.lua: registers the ActionBars module and runs it: Enable, Disable, events, settings changes and gamepad transitions.
local _, ns = ...

local K = KstyleUI
local Events = K.Events

local MODULE = "ActionBars"

ns.bars = {}
ns.actionButtons, ns.petButtons, ns.stanceButtons = {}, {}, {}
ns.running, ns.enabling, ns.gamepad, ns.grid, ns.layout = false, false, false, 0, false

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
		ns.Slab.Dress(button)
	end
	return bar
end

local function RefreshTray()
	ns.trayHeld = false
	local main = ns.bars.bar1
	if main then
		main:RefreshTray(true)
	end
end

local function HoldTray(fn)
	ns.trayHeld = true
	local ok, err = pcall(fn)
	RefreshTray()
	if not ok then
		error(err, 0)
	end
end

local function ApplyBars(geometryOnly)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Apply(geometryOnly)
		elseif ns.running and ns.Config(def.key).enabled then
			Build(def)
		end
	end
end

local function ApplyAll(geometryOnly)
	applyQueued = false
	if InCombatLockdown() and not ns.enabling then
		ns.QueueApply()
		return
	end
	local extra = ns.ApplyExtraBars()
	HoldTray(function() ApplyBars(geometryOnly) end)
	if extra == "beside" then ns.ClearExtraChat() end
	if ns.flyout and ns.flyout.frame then
		local frame = ns.flyout.frame
		frame:SetAttribute("gap", K.Widgets.Snap(frame, K.Tokens.Size("actionGap")))
	end
	if not geometryOnly then ns.ApplyBindings() end
	ns.Vehicle.Update()
end

function ns.QueueApply()
	if applyQueued then
		return
	end
	applyQueued = true
	K.Combat.Queue(ApplyAll)
end

local function RefreshBars()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Refresh()
		end
	end
end

local function RefreshVisuals()
	HoldTray(RefreshBars)
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
	local main = ns.bars.bar1
	if main then main:RefreshTray() end
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

local function UpdateChangedSlot(button)
	button.gcd = nil
	ns.Button.Update(button)
end

local function OnSlotChanged(_, slot)
	if ns.IsSecret(slot) or type(slot) ~= "number" or slot == 0 then
		ForActions(UpdateChangedSlot)
		ns.Flyout.QueueRefresh()
	else
		ns.Flyout.SlotChanged(slot)
		ForSlot(slot, UpdateChangedSlot)
	end
end

local function OnSpells()
	ns.Flyout.QueueRefresh()
	ns.SlabHawks.Recheck()
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

local function RefreshShown()
	EachButton(ns.Button.UpdateAlpha)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:RefreshFade()
		end
	end
end

local function OnGrid(event)
	gridShown[grids[event]] = event == "ACTIONBAR_SHOWGRID" or event == "PET_BAR_SHOWGRID"
	ns.grid = (gridShown.action or gridShown.pet) and 1 or 0
	RefreshShown()
end

local layoutHooked = false

local function OnLayoutMode()
	local on = ns.running and K.Layout.IsActive() == true
	if on ~= ns.layout then
		ns.layout = on
		RefreshShown()
		if ns.Consumables.header then ns.Consumables:RefreshFade() end
	end
end

local function HookLayoutMode()
	local Layout = K.Layout
	if layoutHooked or type(hooksecurefunc) ~= "function" or type(Layout.Enter) ~= "function" or type(Layout.Exit) ~= "function" then
		return
	end
	layoutHooked = true
	hooksecurefunc(Layout, "Enter", OnLayoutMode)
	hooksecurefunc(Layout, "Exit", OnLayoutMode)
end

local function OnCooldown()
	ForActions(ns.Button.UpdateCooldown)
end

local function UpdateTrustedCooldown(button)
	ns.Button.UpdateCooldown(button, true)
end

local function OnSpellCooldown()
	ForActions(UpdateTrustedCooldown)
	for _, button in ipairs(ns.petButtons) do
		ns.Button.Update(button, true)
	end
	for _, button in ipairs(ns.stanceButtons) do
		ns.Button.Update(button, true)
	end
	ns.Flyout.UpdateCooldown()
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
	ns.Vehicle.Update()
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
	if key == "enabled" and ns.Config("enabled") then
		K.Store.Module(MODULE).overlapBindings = #K.Setup.Integrations.Detected(MODULE) > 0
		ns.ApplyBindings()
		return
	end
	if key == "extraBarsLayout" then
		ns.QueueApply()
		return
	elseif key == "extraBarsApplied" then
		return
	end
	if key == "bindingHints" then ns.UpdateHotkeys() end
	if key == "ranks" and ns.Config("ranks") == "off" then
		ns.Ranks.Stop()
	end
	local barKey, field = key:match("^(%w+)%.(.+)$")
	if field and field:match("^visibilityBuilder%.") then return end
	if barKey and field == "size" and (barKey == "bar1" or barKey == "bar2") and ns.Slab.Grouped(ns.BAR[barKey]) then
		local other = barKey == "bar1" and "bar2" or "bar1"
		if ns.Config(other).size ~= ns.Config(barKey).size then
			K.Options.Write(MODULE, other .. ".size", ns.Config(barKey).size)
			return
		end
		ApplyAll()
		return
	elseif key == "trayColumn" or key == "useTray" or key == "slab" or key == "safeDragging" then
		ApplyAll()
		return
	elseif barKey and ns.BAR[barKey] then
		if field == "showEmpty" or field == "fade" or field == "fadeAlpha" or field == "hotkey" or field == "count" or field == "macro" or field == "cooldown" then
			RefreshVisuals()
			return
		end
		local bar = ns.bars[barKey]
		if bar then
			bar:Apply()
			ns.ApplyBindings()
			ns.Vehicle.Update()
		else
			ApplyAll()
		end
		return
	end
	RefreshVisuals()
end

local function OnProfile()
	ns.SyncVisibilities()
	OnLayoutMode()
	ApplyAll()
	RefreshVisuals()
end

local function OnLayout(_, key, reason)
	if reason == "scale" then return end
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar and def.element == key then
			bar:Apply()
			ns.Vehicle.Update()
		end
	end
end

local EVENTS = {
	PLAYER_ENTERING_WORLD = UpdateAll,
	GET_ITEM_INFO_RECEIVED = ns.Button.ItemInfoReceived,
	ACTIONBAR_SLOT_CHANGED = OnSlotChanged,
	ACTIONBAR_UPDATE_COOLDOWN = OnCooldown,
	SPELL_UPDATE_COOLDOWN = OnSpellCooldown,
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
	SPELL_UPDATE_ICON = function()
		ForActions(ns.Button.Update)
		ns.Flyout.QueueRefresh()
	end,
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
	SPELL_FLYOUT_UPDATE = ns.Flyout.QueueRefresh,
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
	ns.SyncVisibilities()
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
	K.Callbacks.Register("ScaleChanged", MODULE, function() ApplyAll(true) end)
	HookLayoutMode()
	OnLayoutMode()
	ns.Flyout.Build()
	ApplyAll()
	ns.Vehicle.Build()
	ns.Vehicle.Update()
	ns.Flyout.Refresh()
	ns.HideBlizzard()
	ns.StylePossess()
	UpdateAll()
	ns.Slab.Enable()
	ns.Travel.Enable()
	ns.SlabEffects.Enable()
	ns.SlabJewels.SetEnabled(true)
	ns.SlabHawks.SetEnabled(true)
	ns.SlabCrown.SetEnabled(true)
	ns.enabling = false
	ns.Keybind.Enable()
	ns.Consumables.Enable()
	ns.Log("running for class " .. tostring(ns.class) .. (ns.gamepad and " in gamepad mode: the bars stay hidden" or "") .. "; Blizzard's keyboard bars are hidden through Safe")
end

local function Disable()
	ns.Keybind.Exit()
	ns.enabling = false
	ns.running = false
	ns.Consumables.Disable()
	ApplyAll()
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar then
			bar:Release()
		end
	end
	ns.Flyout.Close()
	ns.SlabEffects.Disable()
	ns.SlabJewels.SetEnabled(false)
	ns.SlabHawks.SetEnabled(false)
	ns.SlabCrown.SetEnabled(false)
	ns.Slab.Disable()
	ns.Travel.Disable()
	ns.Ranks.Stop()
	ns.RestoreBlizzard()
	gridShown.action, gridShown.pet, ns.grid, ns.layout = false, false, 0, false
end

ns.Enable, ns.Disable = Enable, Disable

K.Modules.Register({ name = MODULE, defaults = ns.defaults, Enable = Enable, Disable = Disable })

K.Options.Register(MODULE, function()
	local schema = ns.Schema()
	schema.preview = function(parent)
		return ns.Preview(parent)
	end
	return schema
end)

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
