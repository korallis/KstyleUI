-- CastBar.lua: cast bars for the player, target, focus and boss frames, run by duration objects through StatusBar:SetTimerDuration.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Motion, L = K.Widgets, K.Tokens, K.Motion, K.L
local Settings, Style = ns.Settings, ns.Style

local CastBars = {}
ns.CastBars = CastBars

local MODULE = Settings.MODULE
local HOLD = 0.6
local TIMER_STEP = 0.05
local ICON_GAP = 2
local TEXT_PAD = 4
local TIMER_FORMAT = "%.1f"
local MS = 1000
local LIMITS = { minWidth = 6, minHeight = 6, maxWidth = 640, maxHeight = 640 }
local ORIENTATION = Style.ORIENTATION

local EVENTS = {
	UNIT_SPELLCAST_START = "Cast",
	UNIT_SPELLCAST_CHANNEL_START = "Channel",
	UNIT_SPELLCAST_DELAYED = "Cast",
	UNIT_SPELLCAST_CHANNEL_UPDATE = "Channel",
	UNIT_SPELLCAST_STOP = "Stop",
	UNIT_SPELLCAST_CHANNEL_STOP = "Stop",
	UNIT_SPELLCAST_FAILED = "Failed",
	UNIT_SPELLCAST_INTERRUPTED = "Interrupted",
	UNIT_SPELLCAST_INTERRUPTIBLE = "Interruptible",
	UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "Interruptible",
}

local issecretvalue = issecretvalue or function()
	return false
end

local bars = {}
local holders = {}
local hiddenByModule = {}
local running = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function Direction(channel)
	local enum = Enum and Enum.StatusBarTimerDirection
	if channel then
		return enum and enum.RemainingTime or 1
	end
	return enum and enum.ElapsedTime or 0
end

local function Interpolation()
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.Immediate or 0
end

local function NewText(owner, justify)
	local text = owner:CreateFontString(nil, "OVERLAY")
	text:SetWordWrap(false)
	text:SetJustifyV("MIDDLE")
	text:SetJustifyH(justify)
	return text
end

local function Tick(frame, elapsed)
	local cb = frame.cb
	cb.elapsed = cb.elapsed + elapsed
	if cb.elapsed < TIMER_STEP then
		return
	end
	cb.elapsed = 0
	local duration = cb.duration
	if duration then
		cb.timer:SetFormattedText(TIMER_FORMAT, duration:GetRemainingDuration())
		return
	end
	local now = GetTime()
	local left = cb.finish - now
	if left < 0 then
		left = 0
	end
	cb.timer:SetFormattedText(TIMER_FORMAT, left)
	if cb.channel then
		cb.bar:SetValue(left)
	else
		cb.bar:SetValue(cb.total - left)
	end
end

local function StopTimer(cb)
	cb.frame:SetScript("OnUpdate", nil)
end

local function Hide(cb, instant)
	cb.active = false
	cb.token = (cb.token or 0) + 1
	StopTimer(cb)
	cb.duration = nil
	if instant or not cb.frame:IsShown() then
		cb.frame:Hide()
		return
	end
	Motion.FadeOut(cb.frame, Tokens.Duration("fade"))
end

local function New(parent, kind, unit)
	local cb = { kind = kind, unit = unit, elapsed = 0, colors = {}, holds = 0 }
	cb.release = function()
		cb.holds = cb.holds - 1
		if cb.holds <= 0 and cb.token == cb.hold then
			cb.holds = 0
			Hide(cb)
		end
	end
	local frame = CreateFrame("Frame", nil, parent)
	frame.cb = cb
	frame:Hide()
	cb.frame = frame
	local iconFrame = CreateFrame("Frame", nil, frame)
	cb.iconFrame = iconFrame
	cb.iconChrome = Widgets.Chrome(iconFrame, { shape = "tile", fill = "raised", shadow = false })
	cb.icon = iconFrame:CreateTexture(nil, "ARTWORK")
	cb.iconMask = iconFrame:CreateMaskTexture()
	cb.iconMask:SetTexture((Tokens.Texture("iconMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	cb.iconMask:SetAllPoints(cb.icon)
	cb.icon:AddMaskTexture(cb.iconMask)
	cb.bar = Widgets.StatusBar(frame, { sheen = true, spark = true, border = true })
	local over = CreateFrame("Frame", nil, cb.bar)
	over:SetAllPoints(cb.bar)
	over:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
	cb.text = NewText(over, "LEFT")
	cb.timer = NewText(over, "RIGHT")
	return cb
end

local function Snap(cb, units)
	return Widgets.Snap(cb.frame, units)
end

local function PlaceTexts(cb, bar, tall)
	local pad = Snap(cb, TEXT_PAD)
	local text, timer = cb.text, cb.timer
	text:ClearAllPoints()
	timer:ClearAllPoints()
	if tall then
		text:SetJustifyH("CENTER")
		timer:SetJustifyH("CENTER")
		text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -pad)
		text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -pad)
		timer:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, pad)
		timer:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, pad)
	else
		text:SetJustifyH("LEFT")
		timer:SetJustifyH("RIGHT")
		timer:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
		text:SetPoint("LEFT", bar, "LEFT", pad, 0)
		text:SetPoint("RIGHT", timer, "LEFT", -pad, 0)
	end
end

function CastBars.Layout(cb, width, height)
	local tall = height > width
	local thick = tall and width or height
	local offset = 0
	if Settings.Value(cb.kind, "castbarIcon") then
		local inset = Widgets.Border(cb.frame)
		cb.iconFrame:ClearAllPoints()
		cb.iconFrame:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", 0, 0)
		Widgets.Size(cb.iconFrame, thick, thick)
		cb.iconChrome:Restyle()
		cb.icon:ClearAllPoints()
		cb.icon:SetPoint("TOPLEFT", cb.iconFrame, "TOPLEFT", inset, -inset)
		cb.icon:SetPoint("BOTTOMRIGHT", cb.iconFrame, "BOTTOMRIGHT", -inset, inset)
		cb.iconFrame:Show()
		offset = thick + ICON_GAP
	else
		cb.iconFrame:Hide()
	end
	local bar = cb.bar
	bar:ClearAllPoints()
	if tall then
		bar.opts.width, bar.opts.height = width, math.max(0, height - offset)
		bar:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", 0, -Snap(cb, offset))
	else
		bar.opts.width, bar.opts.height = math.max(0, width - offset), height
		bar:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", Snap(cb, offset), 0)
	end
	bar:Restyle()
	PlaceTexts(cb, bar, tall)
	cb.text:SetShown(Settings.Value(cb.kind, "castbarText"))
	cb.timer:SetShown(Settings.Value(cb.kind, "castbarTimer"))
end

local function Reaction(cb)
	if cb.unit == nil then
		return cb.sampleReaction
	end
	if not UnitReaction then
		LogOnce("reaction-api", "cast bars: UnitReaction is missing; reaction cast bars use the class accent")
		return nil
	end
	local reaction = UnitReaction(cb.unit, "player")
	if issecretvalue(reaction) then
		LogOnce("reaction-secret", "cast bars: the caster's reaction is secret; the bar uses the class accent")
		return nil
	end
	return reaction
end

local function BarColor(cb)
	local source = Settings.Value(cb.kind, "castbarColor")
	if source == "custom" then
		local c = Settings.Value(cb.kind, "castbarCustom")
		return c.r, c.g, c.b
	elseif source == "reaction" then
		local reaction = Reaction(cb)
		if type(reaction) == "number" then
			return K.Theme.ReactionColor(reaction)
		end
	end
	return K.Theme.Accent()
end

local function Paint(cb, r, g, b, a)
	if cb.pr == r and cb.pg == g and cb.pb == b and cb.pa == a then
		return
	end
	cb.pr, cb.pg, cb.pb, cb.pa = r, g, b, a
	if a == nil then
		cb.bar:SetBarColor(r, g, b)
	else
		cb.bar:SetBarColor(r, g, b, a)
	end
end

local function StyleText(text, path, size, flags)
	if text:SetFont(path, size, flags) == false then
		text:SetFont((Tokens.Font("body")), size, flags)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

local function Orient(cb)
	local o = ORIENTATION[Settings.Value(cb.kind, "castbarOrientation")] or ORIENTATION.RIGHT
	local bar = cb.bar
	bar:SetOrientation(o[1])
	bar:SetReverseFill(o[2])
	local vertical = o[1] == "VERTICAL"
	local turned = bar.vertical ~= vertical
	bar.vertical = vertical
	if bar.spark then
		bar.spark:ClearAllPoints()
		bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), o[4])
	end
	if turned then
		bar:Restyle()
	end
end

function CastBars.Restyle(cb)
	local path, size, flags = Settings.Font(cb.kind, "cast")
	StyleText(cb.text, path, size, flags)
	StyleText(cb.timer, path, size, flags)
	cb.text:SetTextColor(Tokens.Color("textEmphasis"))
	cb.timer:SetTextColor(Tokens.Color("text"))
	cb.bar:SetBarTexture(Settings.Value(cb.kind, "castbarTexture"))
	Orient(cb)
	cb.styled = true
	cb.pr = nil
	Paint(cb, BarColor(cb))
end

local function ColorObjects(cb, r, g, b)
	local create = CreateColor
	if not create then
		return nil
	end
	local c = cb.colors
	if c.r ~= r or c.g ~= g or c.b ~= b then
		c.r, c.g, c.b = r, g, b
		c.normal = create(r, g, b, 1)
	end
	local lr, lg, lb = Tokens.Color("textDisabled")
	if c.lr ~= lr or c.lg ~= lg or c.lb ~= lb then
		c.lr, c.lg, c.lb = lr, lg, lb
		c.locked = create(lr, lg, lb, 1)
	end
	return c.locked, c.normal
end

local function Locked(cb, notInterruptible)
	if issecretvalue(notInterruptible) then
		local texture = cb.bar:GetStatusBarTexture()
		if texture and texture.SetVertexColorFromBoolean then
			local locked, normal = ColorObjects(cb, BarColor(cb))
			if locked then
				texture:SetVertexColorFromBoolean(notInterruptible, locked, normal)
				cb.pr = nil
				return
			end
		end
		LogOnce("locked", "cast bars: no SetVertexColorFromBoolean or CreateColor; a secret uninterruptible cast keeps the normal colour")
		Paint(cb, BarColor(cb))
	elseif notInterruptible then
		Paint(cb, Tokens.Color("textDisabled"))
	else
		Paint(cb, BarColor(cb))
	end
end

local function Icon(cb, texture)
	if issecretvalue(texture) then
		cb.icon:SetTexture(texture)
	elseif cb.unit == "player" and K.Icons and K.Icons.Apply then
		K.Icons.Apply(cb.icon, texture)
	else
		cb.icon:SetTexture(texture)
	end
end

local function Duration(cb, channel)
	local fn = channel and UnitChannelDuration or UnitCastingDuration
	if not fn then
		return nil
	end
	local ok, duration = pcall(fn, cb.unit)
	if ok then
		return duration
	end
	return nil
end

local function RunDuration(cb, channel)
	local duration = Duration(cb, channel)
	if type(duration) == "nil" then
		return false
	end
	local ok = pcall(cb.bar.SetTimerDuration, cb.bar, duration, Interpolation(), Direction(channel))
	if not ok then
		LogOnce("timer-refused", "cast bars: SetTimerDuration refused a duration; using the cast times")
		return false
	end
	LogOnce("timer", "cast bars: duration objects through SetTimerDuration")
	if issecretvalue(duration) then
		cb.duration = nil
		cb.timer:SetText("")
	else
		cb.duration = duration
	end
	return true
end

local function RunTimes(cb, channel, startMs, endMs)
	if not issecretvalue(startMs) and not issecretvalue(endMs) and type(startMs) == "number" and type(endMs) == "number" then
		cb.total = (endMs - startMs) / MS
		cb.finish = endMs / MS
		cb.channel = channel
		cb.bar:SetMinMaxValues(0, cb.total)
		cb.bar:SetValue(channel and cb.total or 0)
		LogOnce("times", "cast bars: no duration object; the bar runs on the cast times")
		return true
	end
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(1)
	cb.timer:SetText("")
	LogOnce("static", "cast bars: secret cast times and no duration object; the bar shows full")
	return false
end

local function Start(cb, channel)
	local _, text, texture, startMs, endMs, isTradeSkill, notInterruptible, castBarID
	if channel then
		_, text, texture, startMs, endMs, isTradeSkill, notInterruptible, _, _, _, castBarID = UnitChannelInfo(cb.unit)
	else
		_, text, texture, startMs, endMs, isTradeSkill, _, notInterruptible, _, castBarID = UnitCastingInfo(cb.unit)
	end
	if type(isTradeSkill) ~= "boolean" or cb.noRoom then
		Hide(cb, true)
		return
	end
	cb.active, cb.channel = true, channel
	cb.castBarID = nil
	if not issecretvalue(castBarID) and type(castBarID) == "number" then
		cb.castBarID = castBarID
	end
	cb.token = (cb.token or 0) + 1
	cb.duration = nil
	Motion.FadeIn(cb.frame, Tokens.Duration("fade"))
	cb.text:SetText(text)
	Icon(cb, texture)
	if not cb.styled then
		CastBars.Restyle(cb)
	end
	Locked(cb, notInterruptible)
	cb.elapsed = TIMER_STEP
	cb.total = nil
	local tick
	if RunDuration(cb, channel) then
		tick = cb.duration ~= nil and Settings.Value(cb.kind, "castbarTimer")
	else
		tick = RunTimes(cb, channel, startMs, endMs)
	end
	if tick then
		cb.frame:SetScript("OnUpdate", Tick)
	else
		StopTimer(cb)
	end
	if not cb.bar.vertical then
		cb.bar:PlaySheen(false)
	end
end

local function Finish(cb, message)
	if not cb.active then
		return
	end
	cb.active = false
	StopTimer(cb)
	cb.duration = nil
	cb.text:SetText(message)
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(1)
	Paint(cb, Tokens.Color("hostile"))
	local token = (cb.token or 0) + 1
	cb.token, cb.hold = token, token
	cb.holds = cb.holds + 1
	C_Timer.After(HOLD, cb.release)
end

local function Casting(unit)
	local _, _, _, _, _, castTrade = UnitCastingInfo(unit)
	if type(castTrade) == "boolean" then
		return true
	end
	local _, _, _, _, _, channelTrade = UnitChannelInfo(unit)
	return type(channelTrade) == "boolean"
end

local BAR_ID_ARG = { UNIT_SPELLCAST_INTERRUPTED = 5, UNIT_SPELLCAST_CHANNEL_STOP = 5 }

local function Matches(cb, event, ...)
	local barID = select(BAR_ID_ARG[event] or 4, ...)
	if type(barID) == "number" and cb.castBarID then
		return barID == cb.castBarID
	end
	return not Casting(cb.unit)
end

local HANDLERS = {
	Cast = function(cb)
		Start(cb, false)
	end,
	Channel = function(cb)
		Start(cb, true)
	end,
	Stop = function(cb, event, ...)
		if cb.active and Matches(cb, event, ...) then
			Hide(cb)
		end
	end,
	Failed = function(cb, event, ...)
		if Matches(cb, event, ...) then
			Finish(cb, L["Failed"])
		end
	end,
	Interrupted = function(cb, event, ...)
		if Matches(cb, event, ...) then
			Finish(cb, L["Interrupted"])
		end
	end,
	Interruptible = function(cb, event)
		if cb.active then
			Locked(cb, event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
		end
	end,
}

local function Owner(unit)
	return MODULE .. ":cast:" .. unit
end

local function Enabled(kind)
	return running and Settings.Value(kind, "castbar") and (Settings.CAST_ELEMENTS[kind] ~= nil or Settings.Value(kind, "enabled"))
end

function CastBars.Refresh(kind)
	local list = bars[kind]
	if not list then
		return
	end
	for _, cb in ipairs(list) do
		if Enabled(kind) and UnitExists(cb.unit) then
			local _, _, _, _, _, castTrade = UnitCastingInfo(cb.unit)
			local _, _, _, _, _, channelTrade = UnitChannelInfo(cb.unit)
			if type(castTrade) == "boolean" then
				Start(cb, false)
			elseif type(channelTrade) == "boolean" then
				Start(cb, true)
			else
				Hide(cb, true)
			end
		else
			Hide(cb, true)
		end
	end
end

local function Listen(cb)
	local owner = Owner(cb.unit)
	K.Events.UnregisterAll(owner)
	if not Enabled(cb.kind) then
		Hide(cb, true)
		return
	end
	if not cb.handler then
		cb.handler = function(event, ...)
			local name = EVENTS[event]
			if name and Enabled(cb.kind) then
				HANDLERS[name](cb, event, ...)
			end
		end
	end
	for event in pairs(EVENTS) do
		K.Events.RegisterUnit(owner, event, cb.handler, cb.unit)
	end
end

local function Element(kind)
	local key = Settings.CAST_ELEMENTS[kind]
	local element = K.Setup.Layouts.Element(key)
	local position = K.Setup.Layouts.Default(key)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(element.width, element.height)
	holder:SetPoint(position.anchor, K.Scale.Root(), position.anchor, position.x, position.y)
	local cb = New(holder, kind, kind)
	cb.frame:SetAllPoints(holder)
	cb.holder = holder
	bars[kind] = { cb }
	holders[kind] = holder
	holder:HookScript("OnSizeChanged", function()
		CastBars.LayoutElement(kind)
	end)
	if K.Layout and K.Layout.Register then
		K.Layout.Register(holder, key, position, {
			label = element.label,
			module = MODULE,
			resizable = true,
			minWidth = LIMITS.minWidth,
			minHeight = LIMITS.minHeight,
			maxWidth = LIMITS.maxWidth,
			maxHeight = LIMITS.maxHeight,
		})
	end
	return cb
end

function CastBars.LayoutElement(kind)
	local holder = holders[kind]
	if not holder then
		return
	end
	local w, h = holder:GetSize()
	if issecretvalue(w) or issecretvalue(h) or type(w) ~= "number" or type(h) ~= "number" then
		return
	end
	CastBars.Layout(bars[kind][1], w, h)
end

function CastBars.Attach(view)
	local kind = view.kind
	bars[kind] = bars[kind] or {}
	local cb = New(view.button, kind, view.unit)
	view.castbar = cb
	bars[kind][#bars[kind] + 1] = cb
	return cb
end

function CastBars.Build()
	for kind in pairs(Settings.CAST_ELEMENTS) do
		if not bars[kind] then
			Element(kind)
		end
	end
end

function CastBars.NewBar(parent, kind)
	return New(parent, kind, nil)
end

function CastBars.Get(kind)
	return bars[kind]
end

function CastBars.Holder(kind)
	return holders[kind]
end

function CastBars.Apply()
	for kind, list in pairs(bars) do
		for _, cb in ipairs(list) do
			Listen(cb)
			CastBars.Restyle(cb)
		end
		if holders[kind] then
			CastBars.LayoutElement(kind)
			local Layout = K.Layout
			if Layout and Layout.SetLive then
				Layout.SetLive(Settings.CAST_ELEMENTS[kind], Enabled(kind) and true or false)
			end
		end
		CastBars.Refresh(kind)
	end
end

function CastBars.Enable()
	running = true
	CastBars.Build()
	for kind, holder in pairs(holders) do
		if hiddenByModule[kind] then
			hiddenByModule[kind] = nil
			holder:Show()
		end
	end
	CastBars.Apply()
end

function CastBars.Disable()
	running = false
	for _, list in pairs(bars) do
		for _, cb in ipairs(list) do
			K.Events.UnregisterAll(Owner(cb.unit))
			Hide(cb, true)
		end
	end
	for kind, holder in pairs(holders) do
		holder:Hide()
		hiddenByModule[kind] = true
	end
end
