-- Menus.lua: KstyleUI's micro menu and bag bar: secure buttons in Layout holders that click Blizzard's own buttons, with Blizzard's two bars hidden through Safe.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens
local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format

local Menus = {}
ns.Menus = Menus

local PAD = 3
local DOCK_LEVEL = 2

local MICRO_ASPECT = 0.75
local ICON_CROP = 0.07
local PORTRAIT_CROP = (1 - MICRO_ASPECT) / 2
local ORDER = { "micro", "bags" }

local GROUPS = {
	micro = {
		key = "databars.micro",
		hide = "MicroMenuContainer",
		owner = "MicroMenu",
		inMenu = true,
		aspect = MICRO_ASPECT,
		buttons = {
			{ name = "CharacterMicroButton", label = L["Character"], portrait = true, compact = true },
			{ name = "ProfessionMicroButton", label = L["Professions"], compact = true },
			{ name = "PlayerSpellsMicroButton", label = L["Spells and talents"], compact = true },
			{ name = "SpellbookMicroButton", label = L["Spellbook"], compact = true },
			{ name = "TalentMicroButton", label = L["Talents"], compact = true },
			{ name = "AchievementMicroButton", label = L["Achievements"] },
			{ name = "LegacyMicroButton", label = L["Legacy"] },
			{ name = "QuestLogMicroButton", label = L["Quest log"], compact = true },
			{ name = "HousingMicroButton", label = L["Housing"] },
			{ name = "GuildMicroButton", label = L["Guild and communities"], compact = true },
			{ name = "LFDMicroButton", label = L["Group finder"], compact = true },
			{ name = "CollectionsMicroButton", label = L["Collections"] },
			{ name = "EJMicroButton", label = L["Adventure guide"] },
			{ name = "HelpMicroButton", label = L["Help"] },
			{ name = "StoreMicroButton", label = L["Shop"] },
			{ name = "MainMenuMicroButton", label = L["Game menu"], gameMenu = true, compact = true },
		},
	},
	bags = {
		key = "databars.bags",
		hide = "BagsBar",
		owner = "BagsBar",
		aspect = 1,
		crop = true,
		buttons = {
			{ name = "KeyRingButton", kind = "keyring" },
			{ name = "CharacterReagentBag0Slot", kind = "bag", bag = 5 },
			{ name = "CharacterBag3Slot", kind = "bag", bag = 4 },
			{ name = "CharacterBag2Slot", kind = "bag", bag = 3 },
			{ name = "CharacterBag1Slot", kind = "bag", bag = 2 },
			{ name = "CharacterBag0Slot", kind = "bag", bag = 1 },
			{ name = "MainMenuBarBackpackButton", kind = "backpack", bag = 0 },
		},
	},
}
Menus.GROUPS = GROUPS

local bars = {}
local entryOf = setmetatable({}, { __mode = "k" })
local queued, soon, hidden = {}, {}, {}
local running, enabling, hooked = false, false, false

local function Frame(name)
	local frame = _G[name]
	if type(frame) == "table" and type(frame.GetObjectType) == "function" then
		return frame
	end
	return nil
end

local function Flag(value, default)
	if ns.IsSecret(value) or value == nil then
		return default
	end
	return value == true
end

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function Settings(id)
	return ns.Settings()[id]
end

local function Active(id)
	local s = Settings(id)
	return running and s ~= nil and s.enabled == true
end

local function Visible(id)
	return Active(id) and Settings(id).shown == true
end
Menus.Visible = Visible

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if ok then
		return a, b
	end
	return nil
end

local function InvSlot(bag)
	local slot = Call(C_Container and C_Container.ContainerIDToInventoryID, bag)
	return ns.IsNumber(slot) and slot or nil
end

local function TotalFree()
	local free = Call(C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots)
	return ns.IsNumber(free) and free or nil
end

local function BagSlots(bag)
	local free = Call(C_Container and C_Container.GetContainerNumFreeSlots, bag)
	local total = Call(C_Container and C_Container.GetContainerNumSlots, bag)
	if ns.IsNumber(free) and ns.IsNumber(total) and total > 0 then
		return free, total
	end
	return nil
end

function Menus.Grid(count, rows)
	count = max(1, count or 1)
	rows = min(count, max(1, floor(rows or 1)))
	local cols = ceil(count / rows)
	return cols, ceil(count / cols)
end

local function Wanted(bar, entry, s)
	local target = entry.target
	if bar.group.inMenu and target:GetParent() ~= Frame(bar.group.owner) then
		return false
	end
	if bar.group.inMenu and s.set ~= "full" and not entry.def.compact then
		return false
	end
	return Flag(target:IsShown(), true)
end

local function OwnerShown(bar)
	local group = bar.group
	local owner = Frame(group.owner)
	if owner == nil or not Flag(owner:IsShown(), true) then
		return false
	end
	if group.inMenu and owner:GetParent() ~= Frame(group.hide) then
		return false
	end
	return true
end

local function Rank(entry)
	local index = entry.target.layoutIndex
	if ns.IsNumber(index) then
		return index
	end
	return 1000 + entry.index
end

local function ByRank(a, b)
	return a.rank < b.rank
end

local function Mirror(button, source, crop)
	local icon = button.icon
	if not IsTexture(source) then
		icon:SetTexture(nil)
		return
	end
	local atlas = source:GetAtlas()
	if not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
		icon:SetAtlas(atlas)
		return
	end
	local file = source:GetTexture()
	if file == nil or ns.IsSecret(file) then
		icon:SetTexture(nil)
		return
	end
	icon:SetTexture(file)
	if crop then
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	else
		icon:SetTexCoord(0, 1, 0, 1)
	end
end

local function Portrait(entry)
	if type(SetPortraitTexture) ~= "function" then
		ns.LogOnce("menus-portrait", "SetPortraitTexture is missing; the character button shows no portrait")
		return
	end
	local icon = entry.button.icon
	local ok, err = pcall(SetPortraitTexture, icon, "player", true)
	if not ok then
		ns.LogOnce("menus-portrait-error", "SetPortraitTexture failed: " .. tostring(err))
		return
	end
	icon:SetTexCoord(PORTRAIT_CROP, 1 - PORTRAIT_CROP, 0, 1)
end

local function Pulsing(target)
	local pulsing = Call(target.IsPulsing, target)
	local notified = Call(target.HasNotification, target)
	return Flag(pulsing, false) or Flag(notified, false)
end

local function PaintMicro(entry, s)
	local button, target, def = entry.button, entry.target, entry.def
	local tint = s.tint
	if def.portrait then
		button.kDesaturate = false
		button:SetTint()
	else
		local normal = type(target.GetNormalTexture) == "function" and target:GetNormalTexture() or nil
		Mirror(button, normal, false)
		button.kDesaturate = tint == "accent" or tint == "white"
		if tint == "accent" then
			button:SetTint(ns.Accent())
		elseif tint == "white" or not IsTexture(normal) then
			button:SetTint()
		else
			button:SetTint(normal:GetVertexColor())
		end
	end
	local state = target:GetButtonState()
	button:SetSelected(not ns.IsSecret(state) and state == "PUSHED")
	local pulsing = Pulsing(target)
	if button.proc ~= pulsing then
		button:SetProc(pulsing)
	end
end

local function BagTexture(def)
	if def.kind ~= "bag" then
		return nil
	end
	local slot = InvSlot(def.bag)
	local texture = slot and Call(GetInventoryItemTexture, "player", slot)
	if texture == nil or ns.IsSecret(texture) then
		return nil
	end
	return texture
end

local function PaintBag(entry, s)
	local button, def = entry.button, entry.def
	local texture = BagTexture(def)
	if texture then
		button.icon:SetTexture(texture)
		button.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	else
		Mirror(button, entry.target.icon, true)
	end
	button.kDesaturate = false
	if def.kind == "backpack" then
		local free = s.freeSlots and TotalFree() or nil
		button:SetCount(free and tostring(free) or nil)
	end
end

local function Paint(bar)
	if not bar then
		return
	end
	local s = Settings(bar.id)
	bar.glass:SetShown(s.backdrop ~= false and bar.dock == nil)
	local round = s.shape ~= "tile"
	for _, entry in ipairs(bar.entries) do
		local button = entry.button
		if bar.id == "micro" then
			PaintMicro(entry, s)
		else
			PaintBag(entry, s)
		end
		button:SetUsable(Flag(entry.target:IsEnabled(), true))
		button.chrome:SetShown(not round)
		button.crystal:SetShown(round)
		button.crystal:Paint()
		if round and not button.kRound then
			button.kRound = true
			button.icon:AddMaskTexture(button.roundMask)
		elseif not round and button.kRound then
			button.kRound = false
			button.icon:RemoveMaskTexture(button.roundMask)
		end
	end
end

local Arrange

local function Later(bar)
	if queued[bar.id] then
		return
	end
	queued[bar.id] = true
	K.Combat.Queue(function()
		queued[bar.id] = nil
		Arrange(bar)
	end)
end

function Arrange(bar)
	if InCombatLockdown() and not enabling then
		Later(bar)
		return
	end
	local s = Settings(bar.id)
	local holder, content = bar.holder, bar.content
	local wanted = {}
	for _, entry in ipairs(bar.entries) do
		if Wanted(bar, entry, s) then
			entry.rank = Rank(entry)
			wanted[#wanted + 1] = entry
		end
	end
	table.sort(wanted, ByRank)
	local list = Visible(bar.id) and OwnerShown(bar) and wanted or {}
	local size = bar.dockSize and min(s.size, bar.dockSize) or s.size
	local height = Widgets.Snap(holder, size)
	local width = s.shape ~= "tile" and height or Widgets.Snap(holder, size * bar.group.aspect)
	local gap = Widgets.Snap(holder, s.spacing)
	local pad = Widgets.Snap(holder, PAD)
	local cols, rows = Menus.Grid(#wanted > 0 and #wanted or #bar.entries, bar.dockRows or s.rows)
	local parts = { width, height, gap, pad, cols }
	for _, entry in ipairs(list) do
		parts[#parts + 1] = entry.index
	end
	parts[#parts + 1] = bar.dock and "docked" or "free"
	local signature = table.concat(parts, ",")
	if signature == bar.signature then
		return
	end
	bar.signature = signature
	local place, shown = {}, {}
	for i, entry in ipairs(list) do
		place[entry] = i
		shown[i] = entry.button
	end
	for _, entry in ipairs(bar.entries) do
		local button, i = entry.button, place[entry]
		if i then
			local col, row = (i - 1) % cols, floor((i - 1) / cols)
			button.kWidth, button.kHeight = width, height
			button.opts.size = height
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", pad + col * (width + gap), -(pad + row * (height + gap)))
			button:Restyle()
		end
		button:SetShown(i ~= nil)
	end
	bar.shown = shown
	holder:SetSize(max(1, cols * width + (cols - 1) * gap + 2 * pad), max(1, rows * height + (rows - 1) * gap + 2 * pad))
	content:SetShown(#shown > 0)
	if bar.dock then
		bar.dock(content, holder:GetWidth(), holder:GetHeight())
	elseif bar.registered and type(K.Layout.Restore) == "function" then
		K.Layout.Restore(bar.group.key)
	end
end


local function SetLive(bar)
	if bar.registered and type(K.Layout.SetLive) == "function" then
		K.Layout.SetLive(bar.group.key, bar.dock == nil and Settings(bar.id).shown == true)
	end
end

local function Sync(bar)
	if bar then
		SetLive(bar)
		Arrange(bar)
		Paint(bar)
	end
end

function Menus.SetDock(id, dock, parent, size, rows)
	local bar = bars[id]
	if not bar or (bar.dock == dock and bar.dockParent == parent and bar.dockSize == size and bar.dockRows == rows) then
		return
	end
	if InCombatLockdown() then
		K.Combat.Queue(function()
			Menus.SetDock(id, dock, parent, size, rows)
		end)
		return
	end
	bar.dock, bar.dockParent, bar.dockSize, bar.dockRows = dock, parent, size, rows
	local holder, content = bar.holder, bar.content
	holder:SetShown(dock == nil)
	content:ClearAllPoints()
	if dock == nil then
		content:SetParent(holder)
		content:SetAllPoints(holder)
	elseif bar.dockParent then
		content:SetParent(bar.dockParent)
		content:SetFrameLevel(bar.dockParent:GetFrameLevel() + DOCK_LEVEL)
	end
	bar.signature = nil
	Sync(bar)
end

local function Soon(id)
	if soon[id] then
		return
	end
	soon[id] = true
	local function run()
		soon[id] = nil
		if running then
			Sync(bars[id])
		end
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, run)
	else
		run()
	end
end

local function SyncBlizzard(id)
	local name = GROUPS[id].hide
	local frame = Frame(name)
	if not frame then
		return
	end
	local hide = Active(id)
	if hide then
		K.Safe.HideBlizzard(frame)
	else
		K.Safe.RestoreBlizzard(frame)
	end
	if hidden[id] ~= hide and (hide or hidden[id]) then
		hidden[id] = hide
		ns.Log(name .. (hide and " is hidden through Safe; KstyleUI's " .. id .. " bar takes its place" or " is restored through Safe"))
	end
end

local function Fit(button)
	if button.kWidth and Widgets.MayMove(button) then
		Widgets.Size(button, button.kWidth, button.kHeight)
	end
end

local function GameMenu()
	if InCombatLockdown() then
		ns.LogOnce("menus-gamemenu-combat", "the micro menu's game menu button waits for combat to end; Escape opens the game menu in combat")
		return
	end
	local menu = Frame("GameMenuFrame")
	if not menu or type(ShowUIPanel) ~= "function" or type(HideUIPanel) ~= "function" then
		ns.LogOnce("menus-gamemenu", "GameMenuFrame or ShowUIPanel is missing; the game menu button does nothing")
		return
	end
	if Flag(menu:IsShown(), false) then
		HideUIPanel(menu)
	else
		ShowUIPanel(menu)
	end
end

local function MicroTooltip(entry, tip)
	local target = entry.target
	local title = target.tooltipText
	if ns.IsSecret(title) or type(title) ~= "string" or title == "" then
		title = entry.def.label
	end
	tip:AddTitle(title)
	if not Flag(target:IsEnabled(), true) then
		local level = target.minLevel
		if ns.IsNumber(level) then
			tip:AddLine(format(L["Opens at level %d."], level), "textDisabled")
		end
		local reason = target.disabledTooltip
		if not ns.IsSecret(reason) and type(reason) == "string" and reason ~= "" then
			tip:AddLine(reason, "textDisabled")
		end
	end
	if entry.def.gameMenu and InCombatLockdown() then
		tip:AddLine(L["In combat, Escape opens the game menu."], "textDisabled")
	end
end

local function BagTooltip(entry, tip)
	local def = entry.def
	if def.kind == "keyring" then
		tip:AddTitle(L["Key ring"])
		tip:AddDivider()
		tip:AddLine(L["Click: open your key ring."], "text")
		return
	end
	if def.kind == "backpack" then
		tip:AddTitle(L["Backpack"])
		local free = TotalFree()
		if free then
			tip:AddLine(format(L["%d free slots in all your bags"], free), "text")
		end
	else
		local slot = InvSlot(def.bag)
		local link = slot and Call(GetInventoryItemLink, "player", slot)
		if ns.IsSecret(link) or type(link) ~= "string" then
			tip:AddTitle(L["Empty bag slot"])
			tip:AddLine(L["Drop a bag here to equip it."], "text")
			return
		end
		tip:AddTitle(link)
		local free, total = BagSlots(def.bag)
		if free then
			tip:AddLine(format(L["%d of %d slots free"], free, total), "text")
		end
	end
	tip:AddDivider()
	tip:AddLine(L["Click: open this bag."], "text")
end

local function OnEnter(button)
	local entry = entryOf[button]
	if not entry or not running then
		return
	end
	local tip = Widgets.Tooltip()
	tip:SetOwner(button, "ANCHOR_TOP")
	K.Call(entry.bar.id == "micro" and MicroTooltip or BagTooltip, entry, tip)
	tip:Show()
end

local function OnLeave(button)
	local tip = Widgets.Tooltip()
	if tip:IsOwned(button) then
		tip:Hide()
	end
end

local function OnReceiveDrag(button)
	local entry = entryOf[button]
	local has = entry and Call(CursorHasItem)
	if not Flag(has, false) then
		return
	end
	if entry.def.kind == "backpack" then
		Call(PutItemInBackpack)
	elseif entry.def.kind == "keyring" then
		if not InCombatLockdown() then
			Call(PutKeyInKeyRing)
		end
	elseif entry.def.kind == "bag" then
		local slot = InvSlot(entry.def.bag)
		if slot then
			Call(PutItemInBag, slot)
		end
	end
end

local function OnDragStart(button)
	local entry = entryOf[button]
	if not entry or entry.def.kind ~= "bag" or InCombatLockdown() then
		return
	end
	local slot = InvSlot(entry.def.bag)
	if slot then
		Call(PickupBagFromSlot, slot)
	end
end

local function NewButton(bar, def, target)
	local button = Widgets.IconButton(bar.content, {
		template = "SecureActionButtonTemplate", size = Settings(bar.id).size, crop = bar.group.crop == true, silent = true,
	})
	button:RegisterForClicks("AnyUp")
	button.crystal = Widgets.CrystalDisc(button)
	button.roundMask = button:CreateMaskTexture()
	button.roundMask:SetTexture((Tokens.Texture("dot")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	button.roundMask:SetAllPoints(button.icon)
	button:SetAttribute("clickbutton", target)
	button:SetAttribute("useOnKeyDown", false)
	if def.gameMenu then
		button.onClick = GameMenu
	else
		button:SetAttribute("type", "click")
	end
	local restyle, paint = button.Restyle, button.Paint
	function button.Restyle(self)
		restyle(self)
		Fit(self)
	end
	function button.Paint(self)
		paint(self)
		if self.kDesaturate then
			self.icon:SetDesaturated(true)
		end
	end
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
	if bar.id == "bags" then
		if def.kind == "bag" then
			button:RegisterForDrag("LeftButton")
		end
		button:HookScript("OnDragStart", OnDragStart)
		button:HookScript("OnReceiveDrag", OnReceiveDrag)
	end
	return button
end

local function Footprint(key)
	local layouts = K.Setup and K.Setup.Layouts
	local element = layouts and layouts.Element(key)
	if element then
		return element.label, layouts.Default(key)
	end
	ns.LogOnce("footprint:" .. key, key .. " has no footprint in Setup.Layouts; using the fallback position")
	return key, { anchor = "BOTTOMRIGHT", x = -16, y = 60 }
end

local function RepaintMicro()
	if running then
		Paint(bars.micro)
	end
end

local MICRO_EVENTS = { "OnBeginPulse", "OnEndPulse", "OnEnable", "OnDisable", "OnNewNotification", "OnDismissedNotification" }

local function Observe(entry)
	local target = entry.target
	if type(target.RegisterCallback) ~= "function" then
		ns.LogOnce("menus-callbacks", "micro buttons have no callback registry; their alerts update with UpdateMicroButtons only")
		return
	end
	for _, event in ipairs(MICRO_EVENTS) do
		local ok = pcall(target.RegisterCallback, target, event, RepaintMicro, entry)
		if not ok then
			ns.LogOnce("menus-callback:" .. event, entry.def.name .. " has no " .. event .. " callback")
		end
	end
end

local function Build(id)
	local group = GROUPS[id]
	if not Frame(group.owner) then
		ns.LogOnce("menus-missing:" .. id, group.owner .. " is missing on this client; KstyleUI's " .. id .. " bar has nothing to click")
		return nil
	end
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	local glass = CreateFrame("Frame", nil, content)
	glass:SetAllPoints(content)
	glass:SetFrameLevel(content:GetFrameLevel())
	glass.chrome = Widgets.Chrome(glass, { shape = "tile", fill = "surface", shadow = true })
	local bar = { id = id, group = group, holder = holder, content = content, glass = glass, entries = {}, shown = {} }
	for index, def in ipairs(group.buttons) do
		local target = Frame(def.name)
		if target then
			local entry = { bar = bar, def = def, target = target, index = index }
			entry.button = NewButton(bar, def, target)
			entryOf[entry.button] = entry
			bar.entries[#bar.entries + 1] = entry
			if def.portrait then
				bar.portrait = entry
			end
			if group.inMenu then
				Observe(entry)
			end
		end
	end
	bars[id] = bar
	Arrange(bar)
	local label, position = Footprint(group.key)
	K.Layout.Register(holder, group.key, position, { label = label, module = ns.MODULE, scalable = true })
	bar.registered = true
	ns.Log("KstyleUI's " .. id .. " bar is built with " .. #bar.entries .. " secure buttons that click Blizzard's")
	return bar
end

local function UpdatePortrait()
	local bar = bars.micro
	if running and bar and bar.portrait then
		Portrait(bar.portrait)
	end
end

local function SyncAll()
	if running then
		for _, id in ipairs(ORDER) do
			Sync(bars[id])
		end
	end
end

local function Hook(name, fn)
	if type(_G[name]) == "function" then
		hooksecurefunc(name, fn)
		return
	end
	ns.LogOnce("menus-hook:" .. name, name .. " is missing; KstyleUI's bars do not follow it")
end

local function InstallHooks()
	if hooked or type(hooksecurefunc) ~= "function" then
		return
	end
	hooked = true
	Hook("UpdateMicroButtons", function()
		if running then
			Sync(bars.micro)
		end
	end)
	Hook("MicroButtonPulse", RepaintMicro)
	Hook("MicroButtonPulseStop", RepaintMicro)
	Hook("LoadMicroButtonTextures", RepaintMicro)
	Hook("PaperDollItemSlotButton_Update", function(target)
		local bar = bars.bags
		if running and bar then
			for _, entry in ipairs(bar.entries) do
				if entry.target == target then
					Paint(bar)
					return
				end
			end
		end
	end)
	for _, name in ipairs({ "MainActionBar_InitializeGamepad", "MainActionBar_InitializeMKB", "MainActionBar_UnInitializeMKB" }) do
		Hook(name, SyncAll)
	end
end

function Menus.Enable()
	running = true
	enabling = true
	InstallHooks()
	for _, id in ipairs(ORDER) do
		local bar = bars[id] or Build(id)
		Sync(bar)
		SyncBlizzard(id)
	end
	UpdatePortrait()
	enabling = false
	if ns.Strip and ns.Strip.view then
		ns.Strip.Refresh()
	end
end

function Menus.Disable()
	running = false
	for _, id in ipairs(ORDER) do
		local bar = bars[id]
		if bar then
			for _, entry in ipairs(bar.entries) do
				OnLeave(entry.button)
			end
			Sync(bar)
		end
		SyncBlizzard(id)
	end
end

function Menus.Setting(key)
	if key == "accentSource" or key == "accentColor" then
		RepaintMicro()
		return
	end
	local id, field = key:match("^(%a+)%.(.+)$")
	if not GROUPS[id] then
		return
	end
	Sync(bars[id])
	if field == "enabled" then
		SyncBlizzard(id)
	end
	if bars[id] and bars[id].dock and ns.Strip then
		ns.Strip.Refresh()
	end
end

function Menus.Shown(id)
	local bar = bars[id]
	return bar and bar.shown or {}
end

function Menus.All(id)
	local out = {}
	for _, entry in ipairs(bars[id] and bars[id].entries or {}) do
		out[#out + 1] = entry.button
	end
	return out
end

function Menus.Holder(id)
	return bars[id] and bars[id].holder
end

function Menus.Content(id)
	return bars[id] and bars[id].content
end

function Menus.Glass(id)
	return bars[id] and bars[id].glass
end

ns.Listen("PLAYER_ENTERING_WORLD", function()
	SyncAll()
	UpdatePortrait()
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
	ns.Listen(event, function()
		Soon("bags")
	end)
end
ns.Listen("PORTRAITS_UPDATED", UpdatePortrait)
ns.Listen("UNIT_PORTRAIT_UPDATE", function(_, unit)
	if not ns.IsSecret(unit) and unit == "player" then
		UpdatePortrait()
	end
end)

ns.Subscribe("LayoutChanged", function(key)
	if not running then
		return
	end
	for _, id in ipairs(ORDER) do
		local bar = bars[id]
		if bar and key == bar.group.key then
			Arrange(bar)
		end
	end
end)

ns.AddPart({
	Enable = Menus.Enable,
	Disable = Menus.Disable,
	Setting = Menus.Setting,
	Refresh = function()
		for _, id in ipairs(ORDER) do
			Sync(bars[id])
			SyncBlizzard(id)
		end
	end,
})
