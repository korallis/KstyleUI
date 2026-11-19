-- Consumables.lua: a secure auto-filled item bar, fixed during combat, with the action bars' sockets and options.
local _, ns = ...

local K, C = KstyleUI, setmetatable(ns.Consumables, { __index = ns.BarClass })
local OWNER, KEY = "ActionBarsConsumables", "consumables.bar"
local holder, header, backing
local buttons, selected, counts = {}, {}, {}
local queued, applying, dirty = false, false, true
C.buttons = buttons

local function Config() return ns.Config("consumables") end

C.hovered, C.alpha, C.target = 0, 1, 1
C.setAlpha = function(frame, value) frame:SetAlpha(value); C.alpha = value end
C.checkFade = function() C:CheckFade() end

function C.Bindings()
	for _, b in ipairs(buttons) do
		b.key = ns.FirstKey(b.binding)
		b:SetHotkey(b.itemID and Config().hotkey ~= false and ns.ShortKey(b.key) or "")
	end
end

function C.Counts()
	for i, record in ipairs(selected) do
		local b, count = buttons[i], counts[record.id] or 0
		b:SetUsable(count > 0)
		b.count:SetText(Config().count ~= false and tostring(count) or "")
	end
end

function C.Update()
	local item = C_Item
	for i, record in ipairs(selected) do
		local b = buttons[i]
		if item and item.GetItemCooldown then
			local start, duration = item.GetItemCooldown(record.id)
			if ns.IsSecret(start) or ns.IsSecret(duration) then
				b.cooldown:SetCooldown(start, duration)
			elseif C.Plain(start, "number") and C.Plain(duration, "number") then
				b:SetCooldown(start, duration)
			end
		end
	end
end

function C.Dock()
	if not holder or InCombatLockdown() or not Config().attached then return end
	local style = K.HudStyle.Current()
	local key = style == "orbs" and "actionbars.bar1" or "unitframes.player"
	local player = K.Layout.Element(key)
	if not player then return end
	local layouts, class, name = K.Setup.Layouts, K.Scale.Aspect(), K.Layout.Setting("preset")
	local position = layouts.Attached(style, name, KEY, class)
	local reference = layouts.Place(name, style, class, key)
	if not position or not reference then return end
	local width = layouts.ConsumableFootprint(style, class)
	local frame = player.frame
	local defaultWidth = style == "orbs" and layouts.ActionBarFootprint(style, class, key) or
		(layouts.Aspect(class, style, name, key) or layouts.Style(style, name, key) or layouts.Element(key)).width
	holder:ClearAllPoints()
	holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", position.x + width / 2 - reference.x + defaultWidth / 2, position.y - reference.y)
end

local function Build()
	if not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		header = CreateFrame("Frame", nil, holder, "SecureHandlerStateTemplate")
		header:Hide()
		C.holder, C.header, C.buttons = holder, header, buttons
	end
	if #buttons > 0 or #selected == 0 and Config().hideEmpty ~= false then return end
	backing = CreateFrame("Frame", nil, header)
	backing:SetAllPoints(header)
	backing.chrome = K.Widgets.Chrome(backing, { shape = "tile", fill = "buttonFill", shadow = false })
	for i = 1, 12 do
		local b = K.Widgets.Slot(header, { name = "KstyleUI_Consumable" .. i, template = "SecureActionButtonTemplate", silent = true, primary = true })
		ns.Socket.Decorate(b)
		b.kind = "consumable"
		b.binding = "CLICK " .. b:GetName() .. ":LeftButton"
		b.key = ns.FirstKey(b.binding)
		b.macroText = K.Widgets.FontString(b.overlay, "OVERLAY")
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:SetAttribute("type", "item")
		b:HookScript("OnEnter", function()
			C:SetHovered(true)
			ns.Button.ShowTooltip(b)
		end)
		b:HookScript("OnLeave", function() C:SetHovered(false); ns.Button.HideTooltip(b) end)
		buttons[i] = b
	end
end

function C.Apply()
	if InCombatLockdown() then
		if not queued then queued = true; K.Combat.Queue(C.Apply) end
		return
	end
	queued = false
	if applying then return end
	applying = true
	local cfg = Config()
	if not holder and (not ns.running or not cfg.enabled) then applying = false; return end
	if dirty then selected, counts = C.Scan(cfg); dirty = false end
	C.selected, C.counts = selected, counts
	if not holder and #selected == 0 and cfg.hideEmpty then applying = false; return end
	Build()
	local style, layouts = K.HudStyle.Current(), K.Setup.Layouts
	local rows, size, gap = layouts.ConsumableGrid(style)
	local width, height, columns, used = ns.GridSize(12, rows, size, gap)
	holder:SetSize(width, height)
	K.Layout.Register(holder, KEY, layouts.Default(KEY), { label = K.L["Consumables bar"], module = "ActionBars", scalable = true, plate = true })
	K.Layout.SetLive(KEY, ns.running and cfg.enabled)
	C.Dock()
	if #buttons == 0 then applying = false; return end
	local growth = cfg.growth
	local left, up = growth:find("LEFT") ~= nil, growth:find("UP") ~= nil
	local corner = (up and "BOTTOM" or "TOP") .. (left and "RIGHT" or "LEFT")
	local occupied = #selected == 0 and cfg.hideEmpty == false and 12 or math.max(1, #selected)
	local liveColumns = cfg.orientation == "VERTICAL" and math.ceil(occupied / used) or math.min(columns, occupied)
	local liveRows = cfg.orientation == "VERTICAL" and math.min(used, occupied) or math.ceil(occupied / columns)
	header:ClearAllPoints()
	header:SetPoint(corner, holder, corner)
	header:SetSize(liveColumns * (size + gap) - gap, liveRows * (size + gap) - gap)
	for i, b in ipairs(buttons) do
		b.opts.size = size
		b.opts.hideNumbers = cfg.cooldown == false
		b.opts.procTransitions, b.opts.inputContinuity = ns.Config("procTransitions"), ns.Config("inputContinuity")
		ns.StyleTextsFor(b, "consumables")
		b:Restyle()
		b:SetAccent(ns.AccentRGB())
		K.Widgets.MedallionsIcon(b, style == "medallions")
		local col, row
		if cfg.orientation == "VERTICAL" then row, col = (i - 1) % used, math.floor((i - 1) / used)
		else col, row = (i - 1) % columns, math.floor((i - 1) / columns) end
		b:ClearAllPoints()
		b:SetPoint(corner, header, corner, (left and -1 or 1) * col * (size + gap), (up and 1 or -1) * row * (size + gap))
		local record = selected[i]
		b.itemID, b.hasAction = record and record.id, record ~= nil
		b:SetAttribute("item", record and "item:" .. record.id or nil)
		b:SetIcon(record and record.icon)
		b:SetHotkey(record and cfg.hotkey ~= false and ns.ShortKey(b.key) or "")
		if not record then b.count:SetText(""); b.hotkey:SetText(""); b:ClearCooldown(); b:SetUsable(false) end
		b:SetShown(record ~= nil or #selected == 0 and cfg.hideEmpty == false)
	end
	backing:SetShown(cfg.backing == true)
	local show = ns.running and cfg.enabled and (#selected > 0 or not cfg.hideEmpty)
	local driver = not show and "hide" or cfg.combat and cfg.idle and "show" or cfg.combat and "[combat] show; hide" or cfg.idle and "[combat] hide; show" or "hide"
	if RegisterStateDriver then RegisterStateDriver(header, "visibility", driver) else header:SetShown(show) end
	C:RefreshFade()
	C.Counts()
	C.Update()
	applying = false
end

function C.Refresh()
	if not ns.running then return end
	dirty = true
	local cfg = Config()
	if not InCombatLockdown() then C.Apply(); return end
	local _, found = C.Scan(cfg)
	counts = found
	C.counts = counts
	C.Counts()
	C.Update()
	if not queued then queued = true; K.Combat.Queue(C.Apply) end
end

function C.Enable()
	dirty = true
	K.Events.Register(OWNER, "BAG_UPDATE_DELAYED", C.Refresh)
	for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do K.Events.Register(OWNER, event, C.Update) end
	K.Events.Register(OWNER, "UPDATE_BINDINGS", C.Bindings)
	K.Events.Register(OWNER, "GET_ITEM_INFO_RECEIVED", C.TravelChanged)
	K.Events.Register(OWNER, "SPELLS_CHANGED", C.TravelChanged)
	K.Callbacks.Register("ModuleChanged", OWNER, function(_, name) if name == "UnitFrames" then C.Apply() end end)
	K.Callbacks.Register("SettingChanged", OWNER, function(_, module) if module == "ActionBars" then C.Refresh() end end)
	K.Callbacks.Register("ProfileChanged", OWNER, C.Refresh)
	for _, event in ipairs({ "HudStyleChanged", "ScaleChanged", "ThemeChanged" }) do K.Callbacks.Register(event, OWNER, C.Apply) end
	K.Callbacks.Register("LayoutChanged", OWNER, function(_, key)
		if key == "unitframes.player" or key == "actionbars.bar1" or key == KEY then K.Combat.Queue(C.Dock) end
	end)
	C.Bindings()
	C.Apply()
end

function C.Disable()
	K.Events.UnregisterAll(OWNER)
	K.Callbacks.UnregisterAll(OWNER)
	K.Combat.Queue(C.Apply)
end
