-- Swing.lua: the swing timer: one bar per hand from PLAYER_SWING, in place of Blizzard's swing timers, which it holds at alpha 0 while it runs.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme = K.Widgets, K.Tokens, K.Theme
local Logic = ns.Logic

local KEY = "meters.swing"
local OUT_OF_RANGE_ALPHA = 0.4
local LIMITS = { minWidth = 40, maxWidth = 800, minHeight = 2, maxHeight = 64 }
local EVENTS = {
	"PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"PLAYER_ENTERING_WORLD", "WEAPON_SLOT_CHANGED", "UNIT_ATTACK_SPEED", "UNIT_INVENTORY_CHANGED",
}
local BLIZZARD = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }

local types = Enum and Enum.PlayerSwingType or {}
local MAIN, OFF, RANGED = types.MainHand or 0, types.OffHand or 1, types.Ranged or 2
local SLOTS = {
	{ type = MAIN, key = "mainHand" },
	{ type = OFF, key = "offHand" },
	{ type = RANGED, key = "ranged" },
}
local SLOT = {}
for _, slot in ipairs(SLOTS) do
	SLOT[slot.type] = slot
end

local Swing = { section = "swing", key = KEY, bars = {}, state = {}, weapons = {}, combat = false, count = 0, dirty = true }
ns.Swing = Swing

local WEAK = { __mode = "k" }
local held = setmetatable({}, WEAK)
local hooked = setmetatable({}, WEAK)
local wanted = setmetatable({}, WEAK)
local busy = false

local function Rehold(frame, alpha)
	if busy then
		return
	end
	if not Logic.IsSecret(alpha) then
		wanted[frame] = alpha
	end
	if not held[frame] then
		return
	end
	busy = true
	pcall(frame.SetAlpha, frame, 0)
	busy = false
end

local function Hold(name)
	local frame = _G[name]
	if frame == nil then
		ns.LogOnce("noBlizzard:" .. name, name .. " is missing on this client; nothing to replace")
		return
	end
	if held[frame] then
		return
	end
	local alpha = Logic.Plain(frame:GetAlpha())
	if alpha then
		wanted[frame] = alpha
	end
	held[frame] = true
	if not hooked[frame] then
		hooked[frame] = true
		hooksecurefunc(frame, "SetAlpha", Rehold)
		ns.LogOnce("swingHold:" .. name, name .. " is held at alpha 0 while KstyleUI's swing timer runs")
	end
	busy = true
	pcall(frame.SetAlpha, frame, 0)
	busy = false
end

local function Release(name)
	local frame = _G[name]
	if frame == nil or not held[frame] then
		return
	end
	held[frame] = nil
	busy = true
	pcall(frame.SetAlpha, frame, wanted[frame] or 1)
	busy = false
end

local function Enabled(slot)
	return ns.Get("swing." .. slot.key) == true
end

local function Speed(slotType)
	if type(UnitAttackSpeed) ~= "function" then
		return nil
	end
	local main, off, ranged = UnitAttackSpeed("player")
	local speed = main
	if slotType == OFF then
		speed = off
	elseif slotType == RANGED then
		speed = ranged
	end
	speed = Logic.Plain(speed)
	if speed and speed > 0 then
		return speed
	end
	return nil
end

local function UpdateWeapons()
	local weapons = Swing.weapons
	weapons[MAIN] = true
	weapons[OFF] = Speed(OFF) ~= nil
	weapons[RANGED] = Speed(RANGED) ~= nil
end

local function Visible(slot)
	if not Enabled(slot) then
		return false
	end
	local st = Swing.state[slot.type]
	return Swing.weapons[slot.type] == true or st.running or st.engine
end

local function AnyRunning()
	for _, slot in ipairs(SLOTS) do
		local st = Swing.state[slot.type]
		if st.running then
			return true
		end
	end
	return false
end

local function Arrange()
	local holder = Swing.holder
	local mask = 0
	for _, slot in ipairs(SLOTS) do
		if Visible(slot) then
			mask = mask + 2 ^ slot.type
		end
	end
	if mask == Swing.mask and not Swing.dirty then
		return
	end
	Swing.mask, Swing.dirty = mask, false
	local width, height = ns.Footprint(KEY)
	width = Logic.Plain(holder:GetWidth()) or width
	height = Logic.Plain(holder:GetHeight()) or height
	local vertical = ns.Get("swing.orientation") == "VERTICAL"
	local gap = Widgets.Snap(holder, ns.Get("swing.spacing"))
	local count = 0
	for _, slot in ipairs(SLOTS) do
		if Visible(slot) then
			count = count + 1
		end
	end
	Swing.count = count
	local size = Logic.Split(vertical and width or height, count, gap)
	local index = 0
	for _, slot in ipairs(SLOTS) do
		local bar = Swing.bars[slot.type]
		if Visible(slot) then
			local offset = Widgets.Snap(holder, index * (size + gap))
			index = index + 1
			bar.opts.width = vertical and size or width
			bar.opts.height = vertical and height or size
			bar:Restyle()
			bar:ClearAllPoints()
			if vertical then
				bar:SetPoint("BOTTOMLEFT", Swing.content, "BOTTOMLEFT", offset, 0)
			else
				bar:SetPoint("TOPLEFT", Swing.content, "TOPLEFT", 0, -offset)
			end
			bar:Show()
		else
			bar:Hide()
		end
	end
end

local function PaintRange()
	local check = ns.Get("swing.range")
	for _, slot in ipairs(SLOTS) do
		local st = Swing.state[slot.type]
		local dim = check and st.outOfRange and not st.running
		Swing.bars[slot.type]:SetAlpha(dim and OUT_OF_RANGE_ALPHA or 1)
	end
end

local function Refresh()
	if not Swing.holder then
		return
	end
	Arrange()
	local shown = ns.Get("swing.shown") and Swing.count > 0
	if shown and ns.Get("swing.hideIdle") then
		shown = Swing.combat or AnyRunning()
	end
	Swing.content:SetShown(shown)
	PaintRange()
end

local function Clear(slot)
	local st, bar = Swing.state[slot.type], Swing.bars[slot.type]
	st.running, st.engine = false, false
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar.time:SetText("")
end

local function OnUpdate()
	local now = GetTime()
	local any = false
	local showTime = Swing.showTime
	for _, slot in ipairs(SLOTS) do
		local st = Swing.state[slot.type]
		if st.running then
			local fraction, left, done = Logic.SwingProgress(st.start, st.duration, now)
			if not fraction or done then
				Clear(slot)
			else
				local bar = Swing.bars[slot.type]
				bar:SetValue(fraction)
				if showTime then
					bar.time:SetText(Logic.FormatSeconds(left))
				end
				any = true
			end
		end
	end
	if not any then
		Swing.driver:SetScript("OnUpdate", nil)
		Refresh()
	end
end

local function StartEngine(slot, duration)
	local st, bar = Swing.state[slot.type], Swing.bars[slot.type]
	local util = C_DurationUtil
	if not (util and type(util.CreateDuration) == "function") then
		ns.LogOnce("swingSecret", "a swing arrived with a secret duration and C_DurationUtil is missing; that swing is not shown")
		return
	end
	st.durationObject = st.durationObject or util.CreateDuration()
	local ok = pcall(st.durationObject.SetTimeFromStart, st.durationObject, GetTime(), duration)
	if ok and bar:SetBarDuration(st.durationObject) then
		st.running, st.engine = false, true
		ns.LogOnce("swingEngine", "a swing arrived with a secret duration; the engine fills the bar from a duration object")
	else
		ns.LogOnce("swingEngineFailed", "a swing arrived with a secret duration that a duration object refused; that swing is not shown")
	end
end

local function OnSwing(duration, swingType)
	if Logic.IsSecret(swingType) then
		ns.LogOnce("swingType", "PLAYER_SWING sent a secret swing type; that swing is not shown")
		return
	end
	local slot = SLOT[swingType]
	if not slot or not Enabled(slot) then
		return
	end
	local st = Swing.state[slot.type]
	st.outOfRange = false
	if Logic.IsSecret(duration) then
		StartEngine(slot, duration)
		Refresh()
		return
	end
	duration = Logic.Plain(duration)
	if not duration or duration <= 0 then
		return
	end
	local bar = Swing.bars[slot.type]
	st.start, st.duration, st.running, st.engine = GetTime(), duration, true, false
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	if Swing.showTime then
		bar.time:SetText(Logic.FormatSeconds(duration))
	end
	Swing.driver:SetScript("OnUpdate", OnUpdate)
	Refresh()
end

local function RestartForWeapons()
	local now = GetTime()
	for _, slot in ipairs(SLOTS) do
		local st = Swing.state[slot.type]
		if st.running then
			local speed = Speed(slot.type)
			if speed then
				st.start, st.duration = now, speed
			else
				Clear(slot)
			end
		end
	end
end

local function CheckRange()
	local timer = C_SwingTimer
	local query = timer and timer.IsTargetWithinSwingRange
	for _, slot in ipairs(SLOTS) do
		local st = Swing.state[slot.type]
		st.outOfRange = false
		if type(query) == "function" then
			local ok, inRange = pcall(query, slot.type)
			st.outOfRange = ok and not Logic.IsSecret(inRange) and inRange == false
		end
	end
end

local function EnableRangeChecks()
	local timer = C_SwingTimer
	if not (timer and type(timer.EnableRangeCheck) == "function") then
		ns.LogOnce("noRangeCheck", "C_SwingTimer.EnableRangeCheck is missing; the swing timer checks range on target changes only")
		return
	end
	for _, slot in ipairs(SLOTS) do
		if Enabled(slot) then
			pcall(timer.EnableRangeCheck, slot.type, true)
		end
	end
end

function Swing:OnEvent(event, ...)
	if event == "PLAYER_SWING" then
		OnSwing(...)
	elseif event == "PLAYER_SWING_RANGE_UPDATE" then
		local swingType, inRange, checks = ...
		if Logic.IsSecret(swingType) or Logic.IsSecret(inRange) or Logic.IsSecret(checks) then
			return
		end
		local slot = SLOT[swingType]
		if slot then
			self.state[slot.type].outOfRange = checks == true and inRange == false
			PaintRange()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		CheckRange()
		PaintRange()
	elseif event == "PLAYER_REGEN_DISABLED" then
		self.combat = true
		Refresh()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.combat = false
		for _, slot in ipairs(SLOTS) do
			if self.state[slot.type].engine then
				Clear(slot)
			end
		end
		Refresh()
	elseif event == "WEAPON_SLOT_CHANGED" then
		UpdateWeapons()
		RestartForWeapons()
		Refresh()
	elseif event == "UNIT_ATTACK_SPEED" or event == "UNIT_INVENTORY_CHANGED" then
		if ... == "player" then
			UpdateWeapons()
			Refresh()
		end
	else
		UpdateWeapons()
		Refresh()
	end
end

local function Style()
	local orientation = ns.Get("swing.orientation")
	local reverse = ns.Get("swing.reverse")
	local showTime = ns.Get("swing.time")
	Swing.showTime = showTime
	Swing.dirty = true
	local r, g, b = ns.BarColor("swing", Theme.Class(), "friendly")
	for _, slot in ipairs(SLOTS) do
		local bar = Swing.bars[slot.type]
		bar:SetBarTexture(ns.Get("swing.texture"))
		bar:SetOrientation(orientation)
		bar.vertical = orientation == "VERTICAL"
		bar:SetReverseFill(reverse)
		bar:SetBarColor(r, g, b)
		ns.ApplyFont(bar.time, "swing")
		bar.time:ClearAllPoints()
		if bar.vertical then
			bar.time:SetPoint("BOTTOM", bar, "TOP", 0, Widgets.Snap(bar, Tokens.Size("gapTiny")))
		else
			bar.time:SetPoint("RIGHT", bar, "RIGHT", -Widgets.Snap(bar, Tokens.Size("gapSmall")), 0)
		end
		bar.time:SetShown(showTime)
		if not showTime then
			bar.time:SetText("")
		end
	end
end

local function Build()
	local width, height = ns.Footprint(KEY)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(width or 260, height or 8)
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	content:Hide()
	Swing.content = content
	Swing.driver = CreateFrame("Frame")
	for _, slot in ipairs(SLOTS) do
		local bar = Widgets.StatusBar(content, {
			texture = ns.Get("swing.texture"), background = "track", min = 0, max = 1, value = 0,
			width = width or 260, height = height or 8,
		})
		bar.time = bar:CreateFontString(nil, "OVERLAY")
		bar.time:SetJustifyH("RIGHT")
		bar:Hide()
		Swing.bars[slot.type] = bar
		Swing.state[slot.type] = { running = false, engine = false, outOfRange = false }
	end
	Swing.holder = holder
	holder:HookScript("OnSizeChanged", function()
		Swing:Resized()
	end)
	ns.Place(holder, KEY, LIMITS)
end

function Swing:Resized()
	self.dirty = true
	Refresh()
end

function Swing:Start()
	if not self.holder then
		Build()
	end
	self:Apply()
end

function Swing:Apply()
	if not self.holder or not ns.IsRunning() then
		return
	end
	ns.SetLive(KEY, ns.Get("swing.shown"))
	if not ns.Get("swing.shown") then
		self:Stop()
		return
	end
	self.holder:Show()
	for _, name in ipairs(BLIZZARD) do
		Hold(name)
	end
	for _, event in ipairs(EVENTS) do
		ns.Watch(self, event)
	end
	EnableRangeChecks()
	self.combat = InCombatLockdown() == true
	for _, slot in ipairs(SLOTS) do
		if not Enabled(slot) and self.state[slot.type].running then
			Clear(slot)
		end
	end
	Style()
	UpdateWeapons()
	CheckRange()
	Refresh()
end

function Swing:Stop()
	if not self.holder then
		return
	end
	ns.UnwatchAll(self)
	self.driver:SetScript("OnUpdate", nil)
	for _, slot in ipairs(SLOTS) do
		Clear(slot)
	end
	self.content:Hide()
	self.holder:Hide()
	for _, name in ipairs(BLIZZARD) do
		Release(name)
	end
end
