-- Keybind.lua: hover overlays edit a pending set of real game bindings; only Save writes them, so combat and Discard leave the player's bindings intact.
local _, ns = ...

local K = KstyleUI
local Widgets, L = K.Widgets, K.L
local Mode = { overlays = {} }
ns.Keybind = Mode
local OWNER = "ActionBarsKeybind"
local MOUSE = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local MODIFIER = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, SHIFT = true, CTRL = true, ALT = true, META = true }

local function Message(text)
	K.Print(text)
end

local function Keys(command)
	local keys, seen = {}, {}
	local function Add(key)
		if not ns.IsSecret(key) and type(key) == "string" and key ~= "" and not seen[key] then
			seen[key] = true
			if Mode.pending[key] == nil or Mode.pending[key] == command then keys[#keys + 1] = key end
		end
	end
	local function Existing(...)
		for i = 1, select("#", ...) do Add(select(i, ...)) end
	end
	Existing(GetBindingKey(command))
	for key, action in pairs(Mode.pending) do
		if action == command then Add(key) end
	end
	table.sort(keys)
	return keys
end

function Mode.Refresh()
	if not Mode.active then return end
	local selected = Mode.selected
	if selected then
		local keys = Keys(selected.command)
		for i, key in ipairs(keys) do
			local text = type(GetBindingText) == "function" and GetBindingText(key)
			if not ns.IsSecret(text) and type(text) == "string" then keys[i] = text end
		end
		Mode.panel.current:SetText(selected.label .. "\n" .. (#keys > 0 and table.concat(keys, ", ") or L["Not bound"]))
	else
		Mode.panel.current:SetText(L["Hover a button to see its bindings."])
	end
end

local function Select(overlay)
	if Mode.confirmation then return end
	if Mode.selected then
		Mode.selected.chrome:SetEdge("accent", 0.4)
		Mode.selected.chrome:SetFill("accent", 0.08)
	end
	Mode.selected = overlay
	if overlay then
		overlay.chrome:SetEdge("textEmphasis", 1)
		overlay.chrome:SetFill("accent", 0.4)
	end
	Mode.panel:SetPropagateKeyboardInput(overlay == nil)
	Mode.Refresh()
end

function Mode.Exit()
	Mode.active = false
	for _, list in ipairs({ ns.actionButtons, ns.petButtons, ns.stanceButtons }) do
		for _, button in ipairs(list) do ns.Button.UpdateAlpha(button) end
	end
	Mode.selected, Mode.pending = nil, nil
	if Mode.confirmation then Mode.confirmation:Close(); Mode.confirmation = nil end
	Mode.confirmed = nil
	K.Events.UnregisterAll(OWNER)
	for _, overlay in pairs(Mode.overlays) do overlay:Hide() end
	if Mode.panel then
		Mode.panel:EnableKeyboard(false)
		Mode.panel:Hide()
	end
end

local function Combat()
	if Mode.active then
		Mode.Exit()
		Message(L["Keybinding mode closed for combat. Unsaved bindings were discarded."])
	end
end

function Mode.Input(input)
	if not Mode.active then return end
	if InCombatLockdown() then Combat(); return end
	local selected = Mode.selected
	if not selected or MODIFIER[input] or Mode.confirmation then return end
	if input == "ESCAPE" then
		for _, key in ipairs(Keys(selected.command)) do Mode.pending[key] = false end
	else
		local key = MOUSE[input] or input
		local number = input:match("^Button(%d+)$")
		if number then key = "BUTTON" .. number end
		if key == "BUTTON1" or key == "BUTTON2" or key == "UNKNOWN" then return end
		if type(CreateKeyChordStringUsingMetaKeyState) == "function" then
			key = CreateKeyChordStringUsingMetaKeyState(key)
		else
			if type(IsMetaKeyDown) == "function" and IsMetaKeyDown() then key = "META-" .. key end
			if IsShiftKeyDown() then key = "SHIFT-" .. key end
			if IsControlKeyDown() then key = "CTRL-" .. key end
			if IsAltKeyDown() then key = "ALT-" .. key end
		end
		Mode.pending[key] = selected.command
	end
	Mode.Refresh()
end

function Mode.Save()
	if not Mode.active then return end
	if InCombatLockdown() then Combat(); return end
	local account = Mode.initialSet == 2 and Mode.bindingSet == 1
	if account and not Mode.confirmed then
		if Mode.confirmation then return end
		Select(nil)
		Mode.confirmation = Widgets.Confirm({
			title = L["Character bindings"],
			text = CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS or L["Switch to account bindings? Character bindings will be deleted."],
			onAccept = function()
				if not Mode.active then return end
				Mode.confirmation = nil
				Mode.confirmed = true
				Mode.Save()
			end,
			onCancel = function()
				Mode.confirmation = nil
				Mode.bindingSet = Mode.initialSet
				Mode.panel.character:SetValue(true, true)
			end,
		})
		return
	end
	if account and LoadBindings(1) == false then
		Message(L["Could not save that binding. Choose another key and try again."])
		return
	end
	local previous, changed = {}, {}
	local function Restore()
		for _, key in ipairs(changed) do SetBinding(key, previous[key] or nil) end
		if account then LoadBindings(Mode.initialSet) end
	end
	for key, command in pairs(Mode.pending) do
		local action = GetBindingAction(key)
		previous[key] = action ~= "" and action or false
		if not SetBinding(key, command or nil) then
			Restore()
			Message(L["Could not save that binding. Choose another key and try again."])
			return
		end
		changed[#changed + 1] = key
	end
	if SaveBindings(Mode.bindingSet) == false then
		Restore()
		Message(L["Could not save that binding. Choose another key and try again."])
		return
	end
	Mode.Exit()
	ns.ApplyBindings()
end

local function BuildPanel()
	local panel = Widgets.Panel(K.Scale.Root(), { title = L["Hover keybindings"], width = 460, height = 270, strata = "DIALOG", hidden = true })
	panel:SetPoint("TOP", K.Scale.Root(), "TOP", 0, -100)
	panel:EnableMouse(true)
	local help = Widgets.Text(panel, "body", "text")
	help:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -55)
	help:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -55)
	help:SetWordWrap(true)
	help:SetText(L["Hover a button and press a key or mouse button. Modifiers work. Escape clears its bindings. Save applies your changes."])
	panel.current = Widgets.Text(panel, "body", "textEmphasis")
	panel.current:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -115)
	panel.current:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -115)
	panel.current:SetWordWrap(true)
	panel.character = Widgets.Toggle(panel, { label = L["Character bindings"], onChange = function(on) Mode.bindingSet = on and 2 or 1 end })
	panel.character:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 68)
	panel.save = Widgets.Button(panel, { text = L["Save"], primary = true, onClick = Mode.Save })
	panel.save:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 22)
	panel.discard = Widgets.Button(panel, { text = L["Discard"], onClick = Mode.Exit })
	panel.discard:SetPoint("RIGHT", panel.save, "LEFT", -12, 0)
	panel:SetScript("OnKeyDown", function(_, key) Mode.Input(key) end)
	return panel
end

local function Add(button, command, label)
	if not button or not button:IsVisible() then return end
	local overlay = Mode.overlays[button]
	if not overlay then
		overlay = CreateFrame("Frame", nil, K.Scale.Root())
		overlay:SetFrameStrata("DIALOG")
		overlay:EnableMouse(true)
		overlay:EnableMouseWheel(true)
		overlay.chrome = Widgets.Chrome(overlay, { shape = "tile", fill = "accent", shadow = false })
		overlay.chrome:SetFill("accent", 0.08)
		overlay:SetScript("OnEnter", function(self) Select(self) end)
		overlay:SetScript("OnLeave", function(self) if Mode.selected == self then Select(nil) end end)
		overlay:SetScript("OnMouseDown", function(self, mouse) Select(self); Mode.Input(mouse) end)
		overlay:SetScript("OnMouseWheel", function(self, delta) Select(self); Mode.Input(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
		Mode.overlays[button] = overlay
	end
	overlay.command, overlay.label = command, label
	overlay.chrome:SetEdge("accent", 0.4)
	overlay.chrome:SetFill("accent", 0.08)
	if Widgets.Cover(overlay, button) then overlay:Show() else overlay:Hide() end
end

function Mode.Enter()
	if InCombatLockdown() then Message(L["Keybinds cannot change in combat; try again after the fight."]); return false end
	if not ns.running or ns.gamepad then Message(L["Enable KstyleUI action bars with keyboard controls to use /kb."]); return false end
	for _, name in ipairs({ "GetBindingKey", "GetBindingAction", "SetBinding", "SaveBindings", "LoadBindings", "GetCurrentBindingSet", "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown" }) do
		if type(_G[name]) ~= "function" then Message(L["Keybinding mode is unavailable on this client."]); return false end
	end
	if Mode.active then Mode.Exit(); return false end
	Mode.panel = Mode.panel or BuildPanel()
	Mode.pending, Mode.active = {}, true
	for _, list in ipairs({ ns.actionButtons, ns.petButtons, ns.stanceButtons }) do
		for _, button in ipairs(list) do ns.Button.UpdateAlpha(button) end
	end
	local set = GetCurrentBindingSet()
	Mode.bindingSet = not ns.IsSecret(set) and set == 2 and 2 or 1
	Mode.initialSet = Mode.bindingSet
	Mode.panel.character:SetValue(Mode.bindingSet == 2, true)
	for _, def in ipairs(ns.BARS) do
		local bar = ns.bars[def.key]
		if bar and bar:Shown() then
			for i = 1, bar.count do Add(bar.buttons[i], def.binding .. i, ns.Label(def) .. " " .. i) end
		end
	end
	if PossessActionBar and PossessActionBar.actionButtons then
		for _, button in ipairs(PossessActionBar.actionButtons) do
			local name = button:GetName()
			if name then Add(button, "CLICK " .. name .. ":LeftButton", L["Possess"] .. " " .. button:GetID()) end
		end
	end
	for i, button in ipairs(ns.Consumables.buttons or {}) do
		Add(button, "CLICK " .. button:GetName() .. ":LeftButton", L["Consumables bar"] .. " " .. i)
	end
	if ns.leaveButton then Add(ns.leaveButton, "VEHICLEEXIT", L["Leave vehicle"]) end
	if ExtraActionButton1 and not (ActionButtonUtil and type(ActionButtonUtil.IsExtraActionButtonDisabled) == "function" and ActionButtonUtil.IsExtraActionButtonDisabled()) then
		Add(ExtraActionButton1, "EXTRAACTIONBUTTON1", L["Extra action"])
	end
	K.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Combat)
	K.Events.Register(OWNER, "INPUT_DEVICE_INTERFACE_TRANSITION", Mode.Exit)
	Mode.panel:Show()
	Mode.panel:EnableKeyboard(true)
	Select(nil)
	return true
end

local function Owned(alias)
	for name, value in pairs(_G) do
		if type(name) == "string" and name ~= "SLASH_KSTYLEKB1" and name ~= "SLASH_KSTYLEKB2"
			and name:match("^SLASH_.+%d+$") and type(value) == "string" and value:lower() == alias then return true end
	end
end

function Mode.Enable()
	local kb, bb = not Owned("/kb"), not Owned("/bb")
	SLASH_KSTYLEKB1 = kb and "/kb" or bb and "/bb" or nil
	SLASH_KSTYLEKB2 = kb and bb and "/bb" or nil
	SlashCmdList.KSTYLEKB = Mode.Enter
	if not kb then Message(L["Another addon owns /kb. Use /kstyle kb to bind KstyleUI buttons."]) end
end
