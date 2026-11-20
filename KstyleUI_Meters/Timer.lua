-- Timer.lua: the standalone combat timer, how long the current or last fight has lasted, counted by one ticker that runs only in combat.
local _, ns = ...

local K = KstyleUI

local KEY = "meters.timer"
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local Timer = { section = "timer", key = KEY }
ns.Timer = Timer

function Timer.Format(seconds, decimal)
	local tenths = math.floor(math.max(0, seconds) * 10 + 1e-6)
	local minutes = math.floor(tenths / 600)
	if decimal then
		return string.format("%d:%04.1f", minutes, (tenths - minutes * 600) / 10)
	end
	return string.format("%d:%02d", minutes, math.floor((tenths - minutes * 600) / 10))
end

local function Paint()
	local seconds = Timer.last or 0
	if Timer.start then seconds = GetTime() - Timer.start end
	Timer.text:SetText(Timer.Format(seconds, Timer.decimal))
end

local function Color()
	local c = ns.Get("timer.color")
	local r, g, b = c.r, c.g, c.b
	if not Timer.start and ns.Get("timer.desat") then
		local grey = r * 0.3 + g * 0.59 + b * 0.11
		r, g, b = grey, grey, grey
	end
	Timer.text:SetTextColor(r, g, b)
end

local function Show()
	local hidden = ns.Get("timer.toggle") and ns.windowsHidden
	Timer.text:SetShown(not hidden and (Timer.start ~= nil or ns.Get("timer.ooc")))
	Color()
	Paint()
end

local function Run()
	if Timer.ticker then Timer.ticker:Cancel() end
	Timer.ticker = nil
	if Timer.start and Timer.text:IsShown() then
		Timer.ticker = C_Timer.NewTicker(Timer.decimal and 0.1 or 1, Paint)
	end
end

function Timer:OnEvent(event)
	local fighting = event == "PLAYER_REGEN_DISABLED" or (event == "PLAYER_ENTERING_WORLD" and InCombatLockdown() == true)
	if fighting and not self.start then
		self.start = GetTime()
	elseif not fighting and self.start then
		self.last, self.start = GetTime() - self.start, nil
	end
	Show()
	Run()
end

local function Build()
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(80, 28)
	Timer.text = K.Widgets.FontString(holder, "OVERLAY")
	Timer.text:SetAllPoints(holder)
	Timer.text:SetWordWrap(false)
	Timer.holder = holder
	K.Layout.Register(holder, KEY, { anchor = "TOPRIGHT", x = -280, y = -150 }, {
		label = K.L["Combat timer"], module = ns.MODULE, resizable = true, minWidth = 40, maxWidth = 200, minHeight = 16, maxHeight = 80,
	})
end

function Timer:Apply()
	if not ns.IsRunning() then return end
	local shown = ns.Get("timer.shown") and type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function"
	ns.SetLive(KEY, shown)
	if not shown then
		self:Stop()
		return
	end
	if not self.holder then Build() end
	self.holder:Show()
	self.decimal = ns.Get("timer.decimal")
	ns.ApplyFont(self.text, "timer", nil, "timer")
	self.text:SetJustifyH(ns.Get("timer.align"))
	for _, event in ipairs(EVENTS) do ns.Watch(self, event) end
	self:OnEvent(InCombatLockdown() == true and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end
Timer.Start = Timer.Apply

function Timer:Stop()
	if not self.holder then return end
	ns.UnwatchAll(self)
	if self.ticker then self.ticker:Cancel() end
	self.ticker, self.start = nil, nil
	self.holder:Hide()
end
