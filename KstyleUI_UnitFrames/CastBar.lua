-- CastBar.lua: cast bars for the player, target, focus and boss frames: a chamfered icon square and a glass bar, run by duration objects through StatusBar:SetTimerDuration.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Motion, L = K.Widgets, K.Tokens, K.Motion, K.L
local Settings, Style, Lumen = ns.Settings, ns.Style, ns.Lumen

local CastBars = {}
ns.CastBars = CastBars

local MODULE = Settings.MODULE
local HOLD = 0.6
local TIMER_STEP = 0.05
local GAP_SHARE = 0.21
local GAP_MIN = 2
local TEXT_PAD = 4
local PAD_SHARE = 0.5
local PAD_LIMIT = 0.1
local BOTTOM_SHARE = 0.22
local LINES = 2
local ROW_GAP = 1
local BAR_MIN = 3
local BAR_SHARE = 0.22
local TEXT_EXTRA = 3
local TIMER_COLUMN = 3
local TRACK = "buttonFill"
local TIMER_FORMAT = "%.1fs"
local MS = 1000
local LIMITS = { minWidth = 6, minHeight = 6, maxWidth = 640, maxHeight = 640 }
local LINE_BAR = 4
local LINE_BAR_SHARE = 0.375
local LINE_LABEL_GAP = 5
local LINE_BAR_GAP = 8
local LINE_BAR_MIN = 24
local LINE_LABEL_EM = 4.2
local LINE_NAME_EM = 12
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
local inline = {}
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
	local text = Widgets.FontString(owner, "OVERLAY")
	text:SetWordWrap(false)
	text:SetJustifyV("MIDDLE")
	text:SetJustifyH(justify)
	return text
end

function CastBars.SetName(cb, text)
	if issecretvalue(text) or type(text) ~= "string" or not Settings.Value(cb.kind, "castbarCaps") then
		cb.text:SetText(text)
	else
		cb.text:SetText(ns.Unit.Tracked(text, (Settings.Font(cb.kind, "cast"))))
	end
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

local function Notify(cb)
	if cb.notify then
		cb.notify(cb.active == true)
	end
end

local function Hide(cb, instant)
	cb.active = false
	Notify(cb)
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
	cb.iconChrome = Widgets.IconChrome(iconFrame)
	cb.icon = iconFrame:CreateTexture(nil, "ARTWORK")
	cb.iconMask = iconFrame:CreateMaskTexture()
	cb.iconMask:SetTexture((Tokens.Texture("iconMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	cb.iconMask:SetAllPoints(cb.icon)
	cb.icon:AddMaskTexture(cb.iconMask)
	cb.panel = CreateFrame("Frame", nil, frame)
	cb.chrome = Widgets.Chrome(cb.panel, { shape = "panel", fill = "surface", shadow = true })
	cb.bar = Widgets.StatusBar(cb.panel, { sheen = true, spark = true, background = TRACK })
	local over = CreateFrame("Frame", nil, cb.bar)
	over:SetAllPoints(cb.bar)
	over:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
	cb.text = NewText(over, "LEFT")
	cb.timer = NewText(over, "RIGHT")
	cb.label = NewText(over, "LEFT")
	cb.label:SetText(L["Casting"])
	cb.lock = NewText(over, "LEFT")
	cb.lock:SetText(L["Locked"])
	cb.lock:Hide()
	return cb
end

local function Snap(cb, units)
	return Widgets.Snap(cb.frame, units)
end

local function Rect(x, y, w, h)
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

local function TextRect(x, w, slotY, slotH, size)
	local h = size + TEXT_EXTRA
	return Rect(x, slotY + slotH / 2 - h / 2, w, h)
end

local function Inline(out, bar, tall, timer, size)
	local h = size + TEXT_EXTRA
	if tall then
		out.text = Rect(bar.x, bar.y + TEXT_PAD, bar.w, h)
		out.timer = Rect(bar.x, bar.y + bar.h - TEXT_PAD - h, bar.w, h)
		return
	end
	local x, w = bar.x + TEXT_PAD, bar.w - 2 * TEXT_PAD
	local timerW = timer and math.min(math.ceil(TIMER_COLUMN * size), math.floor(w / 2)) or 0
	out.timer = TextRect(x + w - timerW, timerW, bar.y, bar.h, size)
	out.text = TextRect(x, w - (timer and timerW + TEXT_PAD or 0), bar.y, bar.h, size)
end

function CastBars.Geometry(width, height, icon, timer, size)
	local out = { tall = height > width }
	local thick = out.tall and width or height
	local offset = 0
	if icon then
		out.icon = Rect(0, 0, thick, thick)
		offset = thick + math.max(GAP_MIN, math.floor(thick * GAP_SHARE + 0.5))
	end
	local panel
	if out.tall then
		panel = Rect(0, offset, width, height - offset)
	else
		panel = Rect(offset, 0, width - offset, height)
	end
	out.panel = panel
	local bottom = math.max(LINES, math.floor(panel.h * BOTTOM_SHARE + 0.5))
	local room = panel.h - LINES - bottom
	if out.tall or room < size + ROW_GAP + BAR_MIN then
		out.stacked = false
		out.bar = Rect(panel.x + LINES, panel.y + LINES, panel.w - 2 * LINES, panel.h - 2 * LINES)
		Inline(out, out.bar, out.tall, timer, size)
		return out
	end
	out.stacked = true
	local barH = math.min(room - size - ROW_GAP, math.max(BAR_MIN, math.floor(panel.h * BAR_SHARE)))
	local pad = math.max(LINES, math.min(math.floor(panel.h * PAD_SHARE + 0.5), math.floor(panel.w * PAD_LIMIT)))
	local x, w = panel.x + pad, panel.w - 2 * pad
	local barY = panel.y + panel.h - bottom - barH
	out.bar = Rect(x, barY, w, barH)
	local rowY = panel.y + LINES
	local rowH = barY - ROW_GAP - rowY
	local timerW = timer and math.min(math.ceil(TIMER_COLUMN * size), math.floor(w / 2)) or 0
	out.timer = TextRect(x + w - timerW, timerW, rowY, rowH, size)
	out.text = TextRect(x, w - (timer and timerW + TEXT_PAD or 0), rowY, rowH, size)
	return out
end

local function Place(cb, region, rect)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", Snap(cb, rect.x), -Snap(cb, rect.y))
	region:SetSize(Snap(cb, rect.w), Snap(cb, rect.h))
end

local function Lined(cb)
	return cb.attached == true and Settings.Form(cb.kind) ~= "plate"
end

local function Anchor(cb, region, point, relative, relPoint, x)
	region:ClearAllPoints()
	region:SetPoint(point, relative, relPoint, Snap(cb, x), 0)
end

local function ShowLock(cb)
	local label, lock, value = cb.label, cb.lock, cb.locked
	if not cb.line then
		label:Hide()
		lock:Hide()
		return
	end
	if issecretvalue(value) then
		label:Show()
		lock:Show()
		label:SetAlphaFromBoolean(value, 0, 1)
		lock:SetAlphaFromBoolean(value, 1, 0)
		return
	end
	label:SetAlpha(1)
	lock:SetAlpha(1)
	label:SetShown(value ~= true)
	lock:SetShown(value == true)
end

local function LayoutLine(cb, width, height)
	cb.geometry = { line = true }
	cb.iconFrame:Hide()
	cb.chrome:SetShadow(false)
	cb.chrome:SetShown(false)
	cb.panel:ClearAllPoints()
	cb.panel:SetAllPoints(cb.frame)
	local frame, timerOn = cb.frame, Settings.Value(cb.kind, "castbarTimer")
	local h = Snap(cb, height)
	Anchor(cb, cb.label, "LEFT", frame, "LEFT", 0)
	cb.label:SetHeight(h)
	cb.label:SetWidth(0)
	Anchor(cb, cb.lock, "LEFT", frame, "LEFT", 0)
	cb.lock:SetHeight(h)
	cb.lock:SetWidth(0)
	ShowLock(cb)
	Anchor(cb, cb.text, "LEFT", cb.label, "RIGHT", LINE_LABEL_GAP)
	cb.text:SetHeight(h)
	cb.text:SetWidth(0)
	cb.text:SetJustifyH("LEFT")
	cb.text:SetShown(Settings.Value(cb.kind, "castbarText"))
	local size = Settings.FontSize(cb.kind, "cast")
	local timerW = timerOn and math.min(math.ceil(TIMER_COLUMN * size), math.floor(width / 3)) or 0
	local room = width - math.ceil(LINE_LABEL_EM * size) - LINE_LABEL_GAP - LINE_BAR_GAP - LINE_BAR_MIN
	if timerOn and room - timerW - LINE_LABEL_GAP < LINE_NAME_EM * size then
		timerOn, timerW = false, 0
	elseif timerOn then
		room = room - timerW - LINE_LABEL_GAP
	end
	if room < LINE_NAME_EM * size then
		cb.text:SetWidth(Snap(cb, math.max(0, room)))
	end
	Anchor(cb, cb.timer, "RIGHT", frame, "RIGHT", 0)
	cb.timer:SetSize(Snap(cb, timerW), h)
	cb.timer:SetJustifyH("RIGHT")
	cb.timer:SetShown(timerOn)
	local bar = cb.bar
	bar.opts.width, bar.opts.height = width, math.min(height, math.max(LINE_BAR, math.floor(height * LINE_BAR_SHARE)))
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("LEFT", cb.text:IsShown() and cb.text or cb.label, "RIGHT", Snap(cb, LINE_BAR_GAP), 0)
	if timerOn then
		bar:SetPoint("RIGHT", cb.timer, "LEFT", -Snap(cb, LINE_LABEL_GAP), 0)
	else
		bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	end
	bar:SetSparkShown(false)
end

function CastBars.Layout(cb, width, height)
	cb.line = Lined(cb)
	if cb.line then
		LayoutLine(cb, width, height)
		return
	end
	ShowLock(cb)
	cb.chrome:SetShadow(true)
	cb.chrome:SetShown(true)
	cb.bar:SetSparkShown(true)
	local g = CastBars.Geometry(width, height, Settings.Value(cb.kind, "castbarIcon"), Settings.Value(cb.kind, "castbarTimer"), Settings.FontSize(cb.kind, "cast"))
	cb.geometry = g
	if g.icon then
		local inset = Widgets.Border(cb.frame)
		Place(cb, cb.iconFrame, g.icon)
		cb.iconChrome:Restyle()
		cb.icon:ClearAllPoints()
		cb.icon:SetPoint("TOPLEFT", cb.iconFrame, "TOPLEFT", inset, -inset)
		cb.icon:SetPoint("BOTTOMRIGHT", cb.iconFrame, "BOTTOMRIGHT", -inset, inset)
		cb.iconFrame:Show()
	else
		cb.iconFrame:Hide()
	end
	Place(cb, cb.panel, g.panel)
	cb.chrome:Restyle()
	local bar = cb.bar
	bar.opts.width, bar.opts.height = g.bar.w, g.bar.h
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", Snap(cb, g.bar.x), -Snap(cb, g.bar.y))
	bar:Restyle()
	Place(cb, cb.text, g.text)
	Place(cb, cb.timer, g.timer)
	cb.text:SetJustifyH(g.tall and "CENTER" or "LEFT")
	cb.timer:SetJustifyH(g.tall and "CENTER" or "RIGHT")
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
	elseif source == "gold" then
		return Lumen.Color("cast")
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
	cb.line = Lined(cb)
	StyleText(cb.text, path, size, flags)
	StyleText(cb.timer, path, size, flags)
	StyleText(cb.label, path, size, flags)
	StyleText(cb.lock, path, size, flags)
	cb.label:SetTextColor(Lumen.Color("muted"))
	cb.lock:SetTextColor(Tokens.Color("hostile"))
	if cb.line then
		cb.text:SetTextColor(Lumen.Color("cast"))
		cb.timer:SetTextColor(Lumen.Color("muted"))
	else
		cb.text:SetTextColor(Tokens.Color("textEmphasis"))
		cb.timer:SetTextColor(Tokens.Color("text"))
	end
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

local function Tint(cb, notInterruptible)
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

local function Locked(cb, notInterruptible)
	if not issecretvalue(notInterruptible) then
		notInterruptible = notInterruptible == true
	end
	cb.locked = notInterruptible
	Tint(cb, notInterruptible)
	ShowLock(cb)
end

local function Icon(cb, texture)
	cb.icon:SetTexture(texture)
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
	Notify(cb)
	CastBars.SetName(cb, text)
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
	if not cb.bar.vertical and not cb.line then
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
	cb.locked = false
	ShowLock(cb)
	CastBars.SetName(cb, message)
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

local function Owner(cb)
	return MODULE .. ":cast:" .. cb.unit .. (cb.inline and ":frame" or "")
end

local function Enabled(cb)
	local kind = cb.kind
	if not (running and Settings.Value(kind, "castbar")) then
		return false
	end
	local plate = Settings.Form(kind) == "plate"
	if cb.inline then
		return not plate and Settings.Value(kind, "enabled")
	end
	if Settings.CAST_ELEMENTS[kind] then
		return plate or not Settings.Value(kind, "enabled")
	end
	return Settings.Value(kind, "enabled")
end

local function Each(kind, fn)
	for _, list in ipairs({ bars[kind] or {}, inline[kind] or {} }) do
		for _, cb in ipairs(list) do
			fn(cb)
		end
	end
end

local function RefreshOne(cb)
	if Enabled(cb) and UnitExists(cb.unit) then
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

function CastBars.Refresh(kind)
	Each(kind, RefreshOne)
end

local function Listen(cb)
	local owner = Owner(cb)
	K.Events.UnregisterAll(owner)
	if not Enabled(cb) then
		Hide(cb, true)
		return
	end
	if not cb.handler then
		cb.handler = function(event, ...)
			local name = EVENTS[event]
			if name and Enabled(cb) then
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
	local cb = New(view.body or view.button, kind, view.unit)
	cb.attached = true
	view.castbar = cb
	local list = bars
	if Settings.CAST_ELEMENTS[kind] then
		cb.inline = true
		list = inline
	end
	list[kind] = list[kind] or {}
	list[kind][#list[kind] + 1] = cb
	return cb
end

function CastBars.Build()
	for kind in pairs(Settings.CAST_ELEMENTS) do
		if not bars[kind] then
			Element(kind)
		end
	end
end

function CastBars.NewBar(parent, kind, attached)
	local cb = New(parent, kind, nil)
	cb.attached = attached == true
	return cb
end

function CastBars.Get(kind)
	return bars[kind]
end

function CastBars.Inline(kind)
	return inline[kind]
end

function CastBars.ElementLive(kind)
	local list = holders[kind] and bars[kind]
	return list ~= nil and Enabled(list[1]) == true
end

function CastBars.Holder(kind)
	return holders[kind]
end

function CastBars.Apply()
	for _, kind in ipairs(Settings.KINDS) do
		Each(kind, function(cb)
			Listen(cb)
			CastBars.Restyle(cb)
		end)
		if holders[kind] then
			CastBars.LayoutElement(kind)
			local Layout = K.Layout
			if Layout and Layout.SetLive then
				Layout.SetLive(Settings.CAST_ELEMENTS[kind], CastBars.ElementLive(kind))
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
	for _, kind in ipairs(Settings.KINDS) do
		Each(kind, function(cb)
			K.Events.UnregisterAll(Owner(cb))
			Hide(cb, true)
		end)
	end
	for kind, holder in pairs(holders) do
		holder:Hide()
		hiddenByModule[kind] = true
	end
end
