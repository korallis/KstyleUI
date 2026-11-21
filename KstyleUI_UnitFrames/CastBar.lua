-- CastBar.lua: duration-driven cast bars for player, target, focus and bosses, with icon-free Medallions slabs.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Motion, L = K.Widgets, K.Tokens, K.Motion, K.L
local Settings, Style, Lumen = ns.Settings, ns.Style, ns.Lumen

local CastBars = {}
ns.CastBars = CastBars

local MODULE = Settings.MODULE
local HOLD = 0.6
local function Outcomes()
	return K.Store.Module(MODULE).castOutcomes ~= false
end
CastBars.Outcomes = Outcomes
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
local ELAPSED_FORMAT = "%.1f / %.1f"
local REMAINING_FORMAT = "%.1f"
local LAG_SUFFIX, LAG_EM, FIT_FLOOR = " (%dms)", 3.5, 0.6
local LAGGED = { [TIMER_FORMAT] = TIMER_FORMAT .. LAG_SUFFIX, [ELAPSED_FORMAT] = ELAPSED_FORMAT .. LAG_SUFFIX, [REMAINING_FORMAT] = REMAINING_FORMAT .. LAG_SUFFIX }
local CAPTION_BAR = { above = 14, below = 14, inside = 14 }
local CAPTION_OFFSET = { above = 0, below = 0.5, inside = 0 }
local CAPTION_GAP = { above = 1, below = 3.5, inside = 0 }
local CAPTION_TIMER_EM = { elapsed = 6.2, remaining = 3 }
local CAPTION_ROOM = 180
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
local LANDED_ALPHA, STOPPED_ALPHA = 0.6, 0.55
local CAPTION_ICON_GAP = 7
local FLASH_LEVEL = 2
local LIT_ALPHA, SHADE_ALPHA = 0.6, 0.45
local MEDAL_INSET, MEDAL_TEXT_PAD = 3, 5
local SPARK = { 227 / 255, 232 / 255, 238 / 255, 1 }
local RANGE_STEP = 0.2
local BATCH_GAP = 2
local GCD_MAX = 1.5

local EVENTS = {
	UNIT_SPELLCAST_START = "Cast",
	UNIT_SPELLCAST_CHANNEL_START = "Channel",
	UNIT_SPELLCAST_DELAYED = "Delayed",
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

local function Interpolation(cb)
	local enum = Enum and Enum.StatusBarInterpolation
	if cb and cb.kind == "player" and Settings.Value("player", "castbarSmooth") and enum and enum.ExponentialEaseOut then return enum.ExponentialEaseOut end
	return enum and enum.Immediate or 0
end

local function NewText(owner, justify)
	local text = Widgets.FontString(owner, "OVERLAY")
	text:SetWordWrap(false)
	text:SetJustifyV("MIDDLE")
	text:SetJustifyH(justify)
	return text
end

local function Caption(cb)
	local form = Settings.Form(cb.kind)
	if form == "column" then
		if Settings.Value(cb.kind, "castbarInside") and (cb.attached or K.HudStyle.Current() == "frames") then
			return "inside"
		end
		return cb.attached and "below" or "above"
	end
	if form ~= "plate" and not cb.attached then
		return "above"
	end
	return nil
end

local function Elapsed(cb)
	return cb.showTotal or cb.mode == "above" or cb.mode == "inside" and not cb.attached
end

local function WriteTimer(cb, elapsed, total, remaining)
	local lag, batch = cb.lag, cb.batch
	if batch then
		remaining = math.max(0, batch - GetTime())
	end
	if Elapsed(cb) and not batch then
		if lag then cb.timer:SetFormattedText(LAGGED[ELAPSED_FORMAT], elapsed, total, lag) else cb.timer:SetFormattedText(ELAPSED_FORMAT, elapsed, total) end
		return
	end
	local fmt = (cb.mode == "below" or cb.mode == "inside" or cb.medal) and REMAINING_FORMAT or TIMER_FORMAT
	if lag then cb.timer:SetFormattedText(LAGGED[fmt], remaining, lag) else cb.timer:SetFormattedText(fmt, remaining) end
end

CastBars.WriteTimer = WriteTimer

local function Tick(frame, elapsed)
	local cb = frame.cb
	cb.elapsed = cb.elapsed + elapsed
	if cb.elapsed < TIMER_STEP then
		return
	end
	cb.elapsed = 0
	local duration = cb.duration
	if duration then
		if Elapsed(cb) then
			WriteTimer(cb, duration:GetElapsedDuration(), duration:GetTotalDuration())
		else
			WriteTimer(cb, nil, nil, duration:GetRemainingDuration())
		end
		return
	end
	local now = GetTime()
	local left = cb.finish - now
	if left < 0 then
		left = 0
	end
	WriteTimer(cb, cb.total - left, cb.total, left)
	if cb.channel then
		cb.bar:SetValue(left)
	else
		cb.bar:SetValue(cb.total - left)
	end
end

local function StopFlash(cb)
	cb.flash.group:Stop()
	cb.flash:Hide()
end

local function Flash(cb, colorName, alpha)
	local on = Outcomes()
	cb.flash.wash:SetBlendMode(on and "BLEND" or "ADD")
	cb.flash.wash:Show()
	cb.flash.down:SetDuration(on and Tokens.Duration("castFlash") or Tokens.Duration("readyFlash"))
	cb.flash.down:SetSmoothing(on and "OUT" or "IN")
	if on then alpha = colorName == "hostile" and 0.35 or 0.22 end
	if ns.CastEffects.Flash(cb, colorName, alpha) then
		return
	end
	if Motion.Level() == "off" or not cb.frame:IsShown() then
		return
	end
	cb.flash.wash:SetVertexColor(Widgets.Rgba(on and colorName ~= "hostile" and "white" or colorName, alpha))
	cb.flash:Show()
	cb.flash.group:Stop()
	cb.flash.group:Play()
end

local function NewFlash(cb)
	local flash = CreateFrame("Frame", nil, cb.bar)
	flash:SetAllPoints(cb.bar)
	flash:SetFrameLevel(cb.bar:GetFrameLevel() + FLASH_LEVEL)
	flash:Hide()
	local wash = flash:CreateTexture(nil, "OVERLAY")
	wash:SetColorTexture(Tokens.Color("white"))
	wash:SetBlendMode("ADD")
	wash:SetAllPoints(flash)
	flash.wash = wash
	local group = flash:CreateAnimationGroup()
	local rise = Tokens.Duration("pressIn")
	local up = group:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetToAlpha(1)
	up:SetDuration(rise)
	up:SetSmoothing("OUT")
	local down = group:CreateAnimation("Alpha")
	down:SetFromAlpha(1)
	down:SetToAlpha(0)
	down:SetDuration(Tokens.Duration("readyFlash"))
	down:SetStartDelay(rise)
	down:SetSmoothing("IN")
	group:SetScript("OnFinished", function()
		if Outcomes() and cb.medStreak and cb.medStreak.anim:IsPlaying() then
			wash:Hide()
		else
			flash:Hide()
		end
	end)
	flash.group, flash.down = group, down
	cb.flash = flash
end

local function StopTimer(cb)
	cb.frame:SetScript("OnUpdate", nil)
end

local StopRange

local function EndTimer(cb, value)
	cb.inkEmpty = value == 0
	StopTimer(cb)
	StopRange(cb)
	if cb.latency then cb.latency:Hide() end
	if cb.important then cb.important:Hide() end
	cb.duration = nil
	cb.timer:SetText("")
	local bar = cb.bar
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(value)
	if not cb.timed then
		return
	end
	cb.timed = false
	local util = C_DurationUtil
	if not (util and type(util.CreateDuration) == "function") then
		return
	end
	if not cb.ended then
		cb.ended = util.CreateDuration()
		pcall(cb.ended.SetTimeSpan, cb.ended, 0, 1)
	end
	if not pcall(bar.SetTimerDuration, bar, cb.ended, Interpolation(), Direction(value <= 0)) then
		LogOnce("timer-end-refused", "cast bars: SetTimerDuration refused the ended span; the bar keeps its last timer")
	end
end

local function HoldThen(cb, seconds)
	local token = (cb.token or 0) + 1
	cb.token, cb.hold = token, token
	cb.holds = cb.holds + 1
	C_Timer.After(seconds, cb.release)
end

local function Notify(cb)
	if cb.notify then
		cb.notify(cb.active == true)
	end
end

local function Hide(cb, instant)
	cb.active, cb.landed, cb.gcd = false, false, nil
	Notify(cb)
	cb.token = (cb.token or 0) + 1
	if cb.timed then
		EndTimer(cb, 0)
	end
	StopTimer(cb)
	StopRange(cb)
	if cb.latency then cb.latency:Hide() end
	if cb.important then cb.important:Hide() end
	cb.duration = nil
	if cb.idle then
		StopFlash(cb)
		if cb.ended then pcall(cb.bar.SetTimerDuration, cb.bar, cb.ended, Interpolation(), Direction(true)) end
		cb.bar:SetMinMaxValues(0, 1)
		cb.bar:SetValue(0)
		CastBars.SetName(cb, "")
		cb.timer:SetText("")
		cb.icon:SetTexture(nil)
		cb.bar:SetFillCursor(false)
		cb.label:Hide()
		cb.lock:Hide()
		cb.empty = true
		cb.frame:SetAlpha(1)
		local gone = cb.holder and not UnitExists(cb.unit)
		cb.frame:SetShown(not cb.noRoom and (issecretvalue(gone) or not gone))
		return
	end
	if instant or not cb.frame:IsShown() then
		StopFlash(cb)
		cb.frame:Hide()
		return
	end
	if Outcomes() then
		Motion.Tween(cb.frame, "SetAlpha", cb.frame:GetAlpha(), 0, cb.error and 0.25 or Tokens.Duration("fade"), cb.error and "inOutSine" or function(t) return t * t end, function(frame)
			frame:Hide()
			frame:SetAlpha(1)
		end)
	else
		Motion.FadeOut(cb.frame, Tokens.Duration("fade"))
	end
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
	cb.medalOn = false
	cb.panel = CreateFrame("Frame", nil, frame)
	cb.chrome = Widgets.Chrome(cb.panel, { shape = "panel", fill = "surface", shadow = true })
	cb.bar = Widgets.StatusBar(cb.panel, { sheen = true, spark = true, background = TRACK })
	cb.bar.edgeMax = 1
	cb.bar:SetLitShade(LIT_ALPHA, SHADE_ALPHA)
	cb.ornament = Widgets.Ornament(cb.panel, "bar", cb.bar)
	cb.ornament.light = true
	cb.ornament.bare = true
	cb.ornament.avoid = { cb.iconFrame }
	local over = CreateFrame("Frame", nil, cb.bar)
	over:SetAllPoints(cb.bar)
	over:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
	cb.text = NewText(over, "LEFT")
	cb.timer = NewText(over, "RIGHT")
	cb.label = NewText(over, "LEFT")
	cb.ornament.texts = { cb.text, cb.timer, cb.label }
	cb.label:SetText(L["Casting"])
	cb.lock = NewText(over, "LEFT")
	cb.lock:SetText(L["Locked"])
	cb.lock:Hide()
	NewFlash(cb)
	return cb
end

local function Snap(cb, units)
	return Widgets.Snap(cb.frame, units)
end

local function Ceil(cb, units)
	local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(cb.frame)
	return math.ceil(units / pixel - 1e-6) * pixel
end

local function Rect(x, y, w, h)
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

local function TextRect(x, w, slotY, slotH, size)
	local h = size + TEXT_EXTRA
	return Rect(x, slotY + slotH / 2 - h / 2, w, h)
end

local function Inline(out, bar, tall, timer, size, em)
	local h = size + TEXT_EXTRA
	if tall then
		out.text = Rect(bar.x, bar.y + TEXT_PAD, bar.w, h)
		out.timer = Rect(bar.x, bar.y + bar.h - TEXT_PAD - h, bar.w, h)
		return
	end
	local x, w = bar.x + TEXT_PAD, bar.w - 2 * TEXT_PAD
	local timerW = timer and math.min(math.ceil(em * size), math.floor(w / 2)) or 0
	out.timer = TextRect(x + w - timerW, timerW, bar.y, bar.h, size)
	out.text = TextRect(x, w - (timer and timerW + TEXT_PAD or 0), bar.y, bar.h, size)
end

function CastBars.Geometry(width, height, icon, timer, size, em, right, iconSize)
	em = em or TIMER_COLUMN
	local out = { tall = height > width }
	local thick = out.tall and width or height
	local offset = 0
	if icon then
		local side = (iconSize or 0) > 0 and math.min(iconSize, thick) or thick
		local across = (thick - side) / 2
		out.icon = Rect(out.tall and across or right and width - side or 0, out.tall and 0 or across, side, side)
		offset = side + math.max(GAP_MIN, math.floor(side * GAP_SHARE + 0.5))
	end
	local panel
	if out.tall then
		panel = Rect(0, offset, width, height - offset)
	else
		panel = Rect(right and 0 or offset, 0, width - offset, height)
	end
	out.panel = panel
	local bottom = math.max(LINES, math.floor(panel.h * BOTTOM_SHARE + 0.5))
	local room = panel.h - LINES - bottom
	if out.tall or room < size + ROW_GAP + BAR_MIN then
		out.stacked = false
		out.bar = Rect(panel.x + LINES, panel.y + LINES, panel.w - 2 * LINES, panel.h - 2 * LINES)
		Inline(out, out.bar, out.tall, timer, size, em)
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
	local timerW = timer and math.min(math.ceil(em * size), math.floor(w / 2)) or 0
	out.timer = TextRect(x + w - timerW, timerW, rowY, rowH, size)
	out.text = TextRect(x, w - (timer and timerW + TEXT_PAD or 0), rowY, rowH, size)
	return out
end

local function Place(cb, region, rect, dx, dy)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", cb.frame, "TOPLEFT", Snap(cb, rect.x) + (dx or 0), (dy or 0) - Snap(cb, rect.y))
	region:SetSize(Snap(cb, rect.w), Snap(cb, rect.h))
end

local function Nudge(cb, part)
	local x, y = Settings.Value(cb.kind, part .. "X"), Settings.Value(cb.kind, part .. "Y")
	return x ~= 0 and Snap(cb, x) or 0, y ~= 0 and Snap(cb, y) or 0
end

local function Lined(cb)
	if cb.attached ~= true then
		return false
	end
	local form = Settings.Form(cb.kind)
	return form ~= "plate" and form ~= "column"
end

local function Form(cb)
	cb.medal = K.HudStyle.Current() == "medallions"
	cb.line = not cb.medal and Lined(cb)
	cb.mode = not cb.medal and Caption(cb) or nil
	cb.iconRight, cb.showTotal = Settings.Value(cb.kind, "castbarIconRight"), cb.kind == "player" and Settings.Value(cb.kind, "castbarTotal")
	cb.lagText = cb.kind == "player" and Settings.Value(cb.kind, "castbarLagText")
	if cb.medalOn == cb.medal then
		return
	end
	cb.medalOn = cb.medal
	cb.iconChrome:SetShown(not cb.medal)
	if cb.medal and not cb.slab then
		cb.slab = Widgets.NineSlice(cb.frame, "medUnitSlab", "BACKGROUND", 1)
	end
	if cb.slab then
		Widgets.ShowSlice(cb.slab, cb.medal)
	end
	cb.bar.lit:SetShown(not cb.medal)
	cb.bar.shade:SetShown(not cb.medal)
end

local function Anchor(cb, region, point, relative, relPoint, x, dx, dy)
	region:ClearAllPoints()
	region:SetPoint(point, relative, relPoint, Snap(cb, x) + (dx or 0), dy or 0)
end

local function ShowLock(cb)
	local label, lock, value = cb.label, cb.lock, cb.locked
	if not cb.line or cb.empty then
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

local function LayoutLine(cb, width, height, column)
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
	local tx, ty = Nudge(cb, "castbarText")
	local mx, my = Nudge(cb, "castbarTimer")
	Anchor(cb, cb.text, "LEFT", cb.label, "RIGHT", LINE_LABEL_GAP, tx, ty)
	cb.text:SetHeight(h)
	cb.text:SetJustifyH("LEFT")
	cb.text:SetShown(Settings.Value(cb.kind, "castbarText"))
	local size = Settings.FontSize(cb.kind, "cast")
	local timerW = timerOn and math.min(math.ceil(column * size), math.floor(width / 3)) or 0
	local room = width - math.ceil(LINE_LABEL_EM * size) - LINE_LABEL_GAP - LINE_BAR_GAP - LINE_BAR_MIN
	if timerOn and room - timerW - LINE_LABEL_GAP < LINE_NAME_EM * size then
		timerOn, timerW = false, 0
	elseif timerOn then
		room = room - timerW - LINE_LABEL_GAP
	end
	cb.nameRoom, cb.nameFree = Snap(cb, math.max(0, room)), room >= LINE_NAME_EM * size
	cb.text:SetWidth(cb.nameFree and not cb.longName and 0 or cb.nameRoom)
	Anchor(cb, cb.timer, "RIGHT", frame, "RIGHT", 0, mx, my)
	cb.timer:SetSize(Snap(cb, timerW), h)
	cb.timer:SetJustifyH("RIGHT")
	cb.timer:SetShown(timerOn)
	local bar = cb.bar
	bar.opts.width, bar.opts.height = width, math.min(height, math.max(LINE_BAR, math.floor(height * LINE_BAR_SHARE)))
	bar:Restyle()
	bar:ClearAllPoints()
	if cb.text:IsShown() then
		bar:SetPoint("LEFT", cb.text, "RIGHT", Snap(cb, LINE_BAR_GAP) - tx, -ty)
	else
		bar:SetPoint("LEFT", cb.label, "RIGHT", Snap(cb, LINE_BAR_GAP), 0)
	end
	if timerOn then
		bar:SetPoint("RIGHT", cb.timer, "LEFT", -Snap(cb, LINE_LABEL_GAP) - mx, -my)
	else
		bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	end
	bar:SetSparkShown(false)
end

local function Roomy(cb)
	return cb.kind == "target" and not cb.attached and K.HudStyle.Current() == "orbs" and Settings.Module().orbCastRoom ~= false
end

local function LayoutCaption(cb, width, height)
	local mode, frame = cb.mode, cb.frame
	local above, inside = mode == "above", mode == "inside"
	cb.geometry = { caption = mode }
	local lead = 0
	local base, own = inside and math.min(CAPTION_BAR.inside, height) or height, Settings.Value(cb.kind, "castbarIconSize")
	local side = Snap(cb, own > 0 and math.min(own, base) or base)
	if Settings.Value(cb.kind, "castbarIcon") and side + Snap(cb, CAPTION_ICON_GAP) < width then
		lead = side + Snap(cb, CAPTION_ICON_GAP)
		cb.geometry.icon = { x = cb.iconRight and width - side or 0, y = own > 0 and (inside and height - (base + side) / 2 or (base - side) / 2) or inside and height - side or 0, w = side, h = side }
		Place(cb, cb.iconFrame, cb.geometry.icon, Nudge(cb, "castbarIcon"))
		cb.iconChrome:Restyle()
		local inset = Widgets.Border(cb.frame)
		cb.icon:ClearAllPoints()
		cb.icon:SetPoint("TOPLEFT", cb.iconFrame, "TOPLEFT", inset, -inset)
		cb.icon:SetPoint("BOTTOMRIGHT", cb.iconFrame, "BOTTOMRIGHT", -inset, inset)
		cb.iconFrame:Show()
	else
		cb.iconFrame:Hide()
	end
	width = width - lead
	local trail = cb.iconRight and lead or 0
	lead = lead - trail
	cb.chrome:SetShadow(false)
	cb.chrome:SetShown(false)
	cb.panel:ClearAllPoints()
	cb.panel:SetAllPoints(frame)
	ShowLock(cb)
	local size = Settings.FontSize(cb.kind, "cast")
	local rowH = size + TEXT_EXTRA
	local gap = CAPTION_GAP[mode]
	local spare = height - gap - rowH
	local labelOn = inside or spare >= BAR_MIN
	local barOffset = Snap(cb, CAPTION_OFFSET[mode])
	if above then
		barOffset = barOffset + Widgets.Snap(frame, K.Scale.Pixel(1) / Widgets.ScaleFactor(frame))
	end
	local barH = math.min(CAPTION_BAR[mode], labelOn and not inside and spare or height - barOffset)
	local timerOn = labelOn and Settings.Value(cb.kind, "castbarTimer")
	local em = CAPTION_TIMER_EM[Elapsed(cb) and "elapsed" or "remaining"] + (cb.lagText and LAG_EM or 0)
	local timerW = timerOn and math.min(math.ceil(em * size), math.floor(width / 2)) or 0
	local reach, roomy = 0, above and Roomy(cb)
	if roomy then
		reach = Ceil(cb, math.max(0, CAPTION_ROOM + timerW + (timerOn and TEXT_PAD or 0) - width) / 2)
		width, lead = width + 2 * reach, lead - reach
		if trail > 0 then
			cb.geometry.icon.x = cb.geometry.icon.x + reach
			Place(cb, cb.iconFrame, cb.geometry.icon, Nudge(cb, "castbarIcon"))
		end
	end
	local bar = cb.bar
	bar.opts.width, bar.opts.height = width, barH
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint((above or inside) and "BOTTOMLEFT" or "TOPLEFT", frame, (above or inside) and "BOTTOMLEFT" or "TOPLEFT", lead, -barOffset)
	bar:SetSparkShown(false)
	bar.keyline:Hide()
	bar:SetTrackBacking(true)
	bar:SetInnerEdge(bar:FlatTexture(), "castEdge")
	bar:SetFillCursor(cb.kind == "player" and Settings.Value(cb.kind, "castbarSpark"))
	local y = Snap(cb, barH + gap)
	local point = above and "BOTTOM" or "TOP"
	local offset = above and y or -y
	local pad = inside and Snap(cb, TEXT_PAD) or 0
	for _, text in ipairs({ cb.text, cb.timer }) do
		text:ClearAllPoints()
		text:SetHeight(Snap(cb, inside and barH or rowH))
		text:SetJustifyV(inside and "MIDDLE" or above and "BOTTOM" or "TOP")
	end
	local tx, ty = Nudge(cb, "castbarText")
	local mx, my = Nudge(cb, "castbarTimer")
	if inside then
		cb.text:SetPoint("LEFT", bar, "LEFT", pad + tx, ty)
	else
		cb.text:SetPoint(point .. "LEFT", frame, point .. "LEFT", lead + tx, offset + ty)
	end
	local textW = math.max(0, width - timerW - 2 * pad - (timerOn and TEXT_PAD or 0))
	cb.text:SetWidth(roomy and Ceil(cb, textW) or Snap(cb, textW))
	cb.text:SetJustifyH("LEFT")
	cb.text:SetShown(labelOn and Settings.Value(cb.kind, "castbarText"))
	if inside then
		cb.timer:SetPoint("RIGHT", bar, "RIGHT", mx - pad, my)
	else
		cb.timer:SetPoint(point .. "RIGHT", frame, point .. "RIGHT", reach - trail + mx, offset + my)
	end
	cb.timer:SetWidth(Snap(cb, timerW))
	cb.timer:SetJustifyH("RIGHT")
	cb.timer:SetShown(timerOn)
end

local function Spark(cb)
	local cursor = cb.bar.fillCursor
	if cb.medal and cursor then
		cursor:SetColorTexture(unpack(SPARK))
	end
end

local function LayoutMedal(cb, width, height, column)
	local frame = cb.frame
	cb.geometry = { medal = true }
	cb.iconFrame:Hide()
	cb.chrome:SetShadow(false)
	cb.chrome:SetShown(false)
	cb.panel:ClearAllPoints()
	cb.panel:SetAllPoints(frame)
	Widgets.LayoutSlice(cb.slab, frame, select(3, Tokens.Texture("medUnitSlab")))
	ShowLock(cb)
	local inset, pad = Snap(cb, MEDAL_INSET), Snap(cb, MEDAL_TEXT_PAD)
	local barW, barH = math.max(0, width - 2 * MEDAL_INSET), math.max(0, height - 2 * MEDAL_INSET)
	local bar = cb.bar
	bar.opts.width, bar.opts.height = barW, barH
	bar:Restyle()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
	bar:SetSparkShown(false)
	bar.keyline:Hide()
	bar:SetTrackBacking(true)
	bar:SetInnerEdge(true, "black")
	bar:SetFillCursor(not cb.empty and Settings.Value(cb.kind, "castbarSpark"))
	Spark(cb)
	local size = Settings.FontSize(cb.kind, "cast")
	local timerOn = Settings.Value(cb.kind, "castbarTimer")
	local timerW = timerOn and math.min(math.ceil(column * size), math.floor(barW / 2)) or 0
	for _, text in ipairs({ cb.text, cb.timer }) do
		text:ClearAllPoints()
		text:SetHeight(Snap(cb, barH))
		text:SetJustifyV("MIDDLE")
	end
	local tx, ty = Nudge(cb, "castbarText")
	local mx, my = Nudge(cb, "castbarTimer")
	cb.text:SetPoint("LEFT", bar, "LEFT", pad + tx, ty)
	cb.text:SetWidth(Snap(cb, math.max(0, barW - timerW - 2 * MEDAL_TEXT_PAD - (timerOn and TEXT_PAD or 0))))
	cb.text:SetJustifyH("LEFT")
	cb.text:SetShown(Settings.Value(cb.kind, "castbarText"))
	cb.timer:SetPoint("RIGHT", bar, "RIGHT", mx - pad, my)
	cb.timer:SetWidth(Snap(cb, timerW))
	cb.timer:SetJustifyH("RIGHT")
	cb.timer:SetShown(timerOn)
end

local function LayoutParts(cb, width, height)
	Form(cb)
	local column = (cb.showTotal and CAPTION_TIMER_EM.elapsed or TIMER_COLUMN) + (cb.lagText and LAG_EM or 0)
	if cb.medal then
		LayoutMedal(cb, width, height, column)
		return
	end
	if cb.mode then
		LayoutCaption(cb, width, height)
		return
	end
	cb.bar:SetFillCursor(false)
	cb.bar.keyline:Show()
	cb.bar:SetTrackBacking(false)
	if cb.line then
		LayoutLine(cb, width, height, column)
		return
	end
	ShowLock(cb)
	cb.chrome:SetShadow(true)
	cb.chrome:SetShown(true)
	cb.bar:SetSparkShown(Settings.Value(cb.kind, "castbarSpark"))
	local g = CastBars.Geometry(width, height, Settings.Value(cb.kind, "castbarIcon"), Settings.Value(cb.kind, "castbarTimer"), Settings.FontSize(cb.kind, "cast"), column, cb.iconRight, Settings.Value(cb.kind, "castbarIconSize"))
	cb.geometry = g
	if g.icon then
		local inset = Widgets.Border(cb.frame)
		Place(cb, cb.iconFrame, g.icon, Nudge(cb, "castbarIcon"))
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
	Place(cb, cb.text, g.text, Nudge(cb, "castbarText"))
	Place(cb, cb.timer, g.timer, Nudge(cb, "castbarTimer"))
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
	if cb.outOfRange then
		return Tokens.Color("textDisabled")
	end
	if cb.channel and cb.kind == "player" and Settings.Value("player", "castbarChannelOverride") then
		local c = Settings.Value("player", "castbarChannelColor")
		return c.r, c.g, c.b
	end
	local source = Settings.Value(cb.kind, "castbarColor")
	if cb.medal and cb.kind == "player" and source ~= "custom" then
		return K.Theme.Accent()
	end
	if source == "custom" then
		local c = Settings.Value(cb.kind, "castbarCustom")
		return c.r, c.g, c.b
	elseif source == "gold" then
		return Lumen.Color(Caption(cb) and "gold" or "cast")
	elseif source == "reaction" then
		local reaction = Reaction(cb)
		if type(reaction) == "number" then
			return K.Theme.ReactionColor(reaction)
		end
	end
	return K.Theme.Accent()
end

local function StyleText(text, path, size, flags)
	if not Widgets.ApplyFont(text, path, size, flags) then
		Widgets.ApplyFont(text, (Tokens.Font("body")), size, flags)
	end
end

local function StyleTarget(cb)
	local t, own, path, size, flags = cb.targetText, Settings.Value(cb.kind, "castbarTargetSize"), cb.text:GetFont()
	StyleText(t, path, own > 0 and own * K.Theme.FontScale() or size, flags)
	t:SetShadowColor(cb.text:GetShadowColor())
	t:SetShadowOffset(cb.text:GetShadowOffset())
	local c = Settings.Value(cb.kind, "castbarTargetColor")
	t:SetTextColor(c.r, c.g, c.b)
end

local function Paint(cb, r, g, b, a)
	local alpha = Settings.Value(cb.kind, "castbarAlpha")
	if alpha < 1 then a = alpha end
	local changed = cb.pr ~= r or cb.pg ~= g or cb.pb ~= b or cb.pa ~= a
	if (cb.medal or cb.mode == "inside") and Widgets.Readability("readableBars") and (changed or cb.inkPaint ~= cb.inkEmpty) then
		cb.inkPaint = cb.inkEmpty
		if cb.inkEmpty then
			Widgets.InkText(cb.text, Tokens.Color(TRACK))
		else
			Widgets.InkText(cb.text, r, g, b)
		end
		if cb.targetText then StyleTarget(cb) end
	end
	if not changed then
		return
	end
	cb.pr, cb.pg, cb.pb, cb.pa = r, g, b, a
	if a == nil then
		cb.bar:SetBarColor(r, g, b)
	else
		cb.bar:SetBarColor(r, g, b, a)
	end
end

local function PlaceTarget(cb)
	local place = not cb.line and Settings.Value(cb.kind, "castbarTarget") and Settings.Value(cb.kind, "castbarTargetPlace")
	local t, text = cb.targetText, cb.text
	local w, point, rel, relPoint, x, y = place and place ~= "" and text:GetWidth()
	if w then point, rel, relPoint, x, y = text:GetPoint(1) end
	cb.targetOn = nil
	if not (w and not issecretvalue(w) and type(w) == "number" and w > 2 * TEXT_PAD and not (issecretvalue(point) or issecretvalue(rel) or issecretvalue(relPoint) or issecretvalue(x) or issecretvalue(y))
		and type(x) == "number" and type(y) == "number") then
		if t then t:Hide() end
		return
	end
	if not t then
		t = NewText(text:GetParent(), place)
		cb.targetText = t
		cb.ornament.texts[#cb.ornament.texts + 1] = t
		StyleTarget(cb)
	end
	cb.targetOn = place
	local pad = Snap(cb, TEXT_PAD)
	local half = Snap(cb, (w - TEXT_PAD) / 2)
	local tx, ty = Nudge(cb, "castbarTarget")
	text:SetWidth(half)
	t:ClearAllPoints()
	t:SetSize(half, text:GetHeight())
	t:SetJustifyV(text:GetJustifyV())
	t:SetJustifyH(place)
	if place == "RIGHT" then
		t:SetPoint("LEFT", text, "RIGHT", pad + tx, ty)
	else
		text:SetPoint(point, rel, relPoint, x + half + pad, y)
		t:SetPoint("RIGHT", text, "LEFT", tx - pad, ty)
	end
	t:SetShown(text:IsShown())
end

function CastBars.Layout(cb, width, height)
	LayoutParts(cb, width, height)
	PlaceTarget(cb)
end

local function NameFont(cb, size)
	local style = cb.nameStyle
	StyleText(cb.text, style.path, size, style.flags)
	if style.shadow then
		local border = K.Scale.Border() / Widgets.ScaleFactor(cb.text)
		cb.text:SetShadowColor(Tokens.Color("textShadow"))
		cb.text:SetShadowOffset(border, -border)
	end
	cb.fitSize = size
	if cb.targetText then StyleTarget(cb) end
end

local function Advance(text)
	local width = text:GetUnboundedStringWidth()
	return not issecretvalue(width) and type(width) == "number" and width or nil
end

local function Fit(cb)
	local style = cb.nameStyle
	if not style then return end
	local size, room = style.size, Settings.Value(cb.kind, "castbarFit") and cb.text:GetWidth()
	local width = room and not issecretvalue(room) and type(room) == "number" and room > 0 and Advance(cb.text)
	if not width then
		if size ~= cb.fitSize then NameFont(cb, size) end
		return
	end
	local least = math.min(size, math.max(size * FIT_FLOOR, K.Scale.TextFloor() * K.Scale.Pixel(1) / Widgets.ScaleFactor(cb.text)))
	width = width * size / cb.fitSize
	if width > room then size = math.max(least, size * room / width) end
	if size ~= cb.fitSize then NameFont(cb, size) end
	width = size < style.size and Advance(cb.text)
	if width and width > room then
		NameFont(cb, math.max(least, size - K.Scale.Pixel(1) / Widgets.ScaleFactor(cb.text)))
	end
end

function CastBars.SetName(cb, text, target)
	if cb.targetOn then
		if issecretvalue(target) or target ~= nil then cb.targetText:SetText(target) else cb.targetText:SetText("") end
		target = nil
	end
	local shown, secret = text, issecretvalue(text)
	if not (secret or type(text) ~= "string" or not Settings.Value(cb.kind, "castbarCaps")) then
		shown = ns.Unit.Tracked(text, cb.textPath or (Settings.Font(cb.kind, "cast")))
	end
	local named = issecretvalue(target) or target ~= nil
	if named then
		cb.text:SetText(shown .. " - " .. target)
	else
		cb.text:SetText(shown)
	end
	if cb.line and cb.nameFree then
		local width = named and not (secret or issecretvalue(target)) and cb.text:GetUnboundedStringWidth()
		local long = named and not (not issecretvalue(width) and type(width) == "number" and width <= cb.nameRoom)
		if long ~= (cb.longName or false) then
			cb.longName = long
			cb.text:SetWidth(long and cb.nameRoom or 0)
		end
	end
	Fit(cb)
	secret = secret or named
	if not cb.ornament.joined and (secret or text ~= cb.ornamentText) then
		cb.ornamentText = not secret and text or nil
		cb.ornament:Restyle()
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
	bar:PlaceFillCursor()
	if turned then
		bar:Restyle()
	end
end

local LOW_STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true }

local function Raise(cb)
	local on = cb.unit ~= nil and Settings.Module().castbarRaise == true
	if on == (cb.raised ~= nil) then
		return
	end
	local frame = cb.frame
	if on then
		local strata = frame:GetFrameStrata()
		if issecretvalue(strata) or not LOW_STRATA[strata] then
			return
		end
		cb.raised = strata
		frame:SetFrameStrata("HIGH")
	else
		frame:SetFrameStrata(cb.raised)
		cb.raised = nil
	end
end

local function StyleImportant(cb)
	local glow = cb.important
	if not glow then return end
	local level = cb.bar:GetFrameLevel()
	if not issecretvalue(level) then glow:SetFrameLevel(level + FLASH_LEVEL) end
	Widgets.LayoutSlice(glow.line, glow, Tokens.Size("radiusTile"), 0)
	local c = Settings.Value(cb.kind, "castbarImportantColor")
	Widgets.ColorSlice(glow.line, c.r, c.g, c.b, 1)
end

function CastBars.Restyle(cb)
	local path, size, flags = Settings.Font(cb.kind, "cast")
	Form(cb)
	if cb.mode == "inside" and flags == "" then
		flags = "OUTLINE"
	end
	local caption = cb.mode ~= nil or cb.medal
	local textPath, timerPath = path, path
	if caption and Settings.ThemeFont(cb.kind, "cast") then
		textPath, timerPath = (Tokens.Font("caps")), Lumen.Font("time")
	end
	if cb.medal and Widgets.Readability("readableBars") then
		textPath = Settings.Font(cb.kind, "name")
		timerPath = Tokens.Font("number")
	end
	cb.textPath = textPath
	cb.nameStyle = { path = textPath, size = size, flags = flags, shadow = caption and flags == "" }
	NameFont(cb, size)
	StyleText(cb.timer, timerPath, size, cb.medal and Widgets.Readability("readableBars") and "OUTLINE" or flags)
	StyleText(cb.label, path, size, flags)
	StyleText(cb.lock, path, size, flags)
	cb.label:SetTextColor(Lumen.Color("muted"))
	cb.lock:SetTextColor(Tokens.Color("hostile"))
	if caption then
		cb.text:SetTextColor(Tokens.Color("textEmphasis"))
		cb.timer:SetTextColor(Tokens.Color("textEmphasis"))
	elseif cb.line then
		cb.text:SetTextColor(Lumen.Color("cast"))
		cb.timer:SetTextColor(Lumen.Color("muted"))
	else
		cb.text:SetTextColor(Tokens.Color("textEmphasis"))
		cb.timer:SetTextColor(Tokens.Color("text"))
	end
	if cb.medal then
		cb.bar:SetBarTexture(Tokens.Texture("barFlat"))
		cb.bar:SetInnerEdge(true, "black")
		cb.bar:SetFillCursor(not cb.empty and Settings.Value(cb.kind, "castbarSpark"))
	else
		cb.bar:SetBarTexture(Settings.Value(cb.kind, "castbarTexture"))
		cb.bar:SetInnerEdge(cb.mode ~= nil and cb.bar:FlatTexture(), "castEdge")
		cb.bar:SetFillCursor(cb.mode ~= nil and cb.kind == "player" and Settings.Value(cb.kind, "castbarSpark"))
	end
	Orient(cb)
	Spark(cb)
	Raise(cb)
	StyleImportant(cb)
	cb.styled = true
	cb.pr = nil
	Paint(cb, BarColor(cb))
end

local function ColorObjects(cb, r, g, b)
	local create = CreateColor
	if not create then
		return nil
	end
	local c, a = cb.colors, Settings.Value(cb.kind, "castbarAlpha")
	if c.r ~= r or c.g ~= g or c.b ~= b or c.a ~= a then
		c.r, c.g, c.b = r, g, b
		c.normal = create(r, g, b, a)
	end
	local color = Settings.Value(cb.kind, "castbarLockedColor")
	local lr, lg, lb = color.r, color.g, color.b
	if c.lr ~= lr or c.lg ~= lg or c.lb ~= lb or c.a ~= a then
		c.lr, c.lg, c.lb = lr, lg, lb
		c.locked = create(lr, lg, lb, a)
	end
	c.a = a
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
		local color = Settings.Value(cb.kind, "castbarLockedColor")
		Paint(cb, color.r, color.g, color.b)
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

local function Range(cb)
	local ok, inRange = pcall(C_Spell.IsSpellInRange, cb.rangeID)
	local out = ok and not issecretvalue(inRange) and inRange == false
	if out ~= cb.outOfRange then
		cb.outOfRange = out
		Tint(cb, cb.locked)
	end
end

function StopRange(cb)
	if not cb.rangeTicker then return end
	cb.rangeTicker:Cancel()
	cb.rangeTicker, cb.rangeID = nil, nil
	if cb.outOfRange then
		cb.outOfRange = false
		Tint(cb, cb.locked)
	end
end

local function WatchRange(cb, spellID)
	StopRange(cb)
	if not (cb.kind == "player" and Settings.Value("player", "castbarRangeGrey") and C_Timer and C_Timer.NewTicker and C_Spell and C_Spell.IsSpellInRange)
		or issecretvalue(spellID) or type(spellID) ~= "number" then
		return
	end
	cb.rangeID, cb.outOfRange = spellID, false
	cb.rangeTicker = C_Timer.NewTicker(RANGE_STEP, function() Range(cb) end)
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
	local ok = pcall(cb.bar.SetTimerDuration, cb.bar, duration, Interpolation(cb), Direction(channel))
	if not ok then
		LogOnce("timer-refused", "cast bars: SetTimerDuration refused a duration; using the cast times")
		return false
	end
	LogOnce("timer", "cast bars: duration objects through SetTimerDuration")
	cb.timed = true
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

local function Span(cb)
	local util = C_DurationUtil
	cb.span = cb.span or util and type(util.CreateDuration) == "function" and util.CreateDuration() or nil
	if not (cb.span and pcall(cb.span.SetTimeSpan, cb.span, cb.craftFirst / MS, cb.batch) and pcall(cb.bar.SetTimerDuration, cb.bar, cb.span, Interpolation(cb), Direction(false))) then
		return false
	end
	cb.timed, cb.duration = true, cb.span
	return true
end

local function Ranked(text, spellID)
	local api = C_Spell and C_Spell.GetSpellSubtext
	if not api or issecretvalue(text) or type(text) ~= "string" or issecretvalue(spellID) or type(spellID) ~= "number" then return text end
	local rank = api(spellID)
	if issecretvalue(rank) or type(rank) ~= "string" or not rank:find("%d") then return text end
	return text .. " (" .. rank .. ")"
end

local function Batch(cb, text, startMs, endMs, merge)
	local api = C_TradeSkillUI and C_TradeSkillUI.GetRemainingRecasts
	local left = api and api()
	if issecretvalue(left) or type(left) ~= "number" or left < 0 or issecretvalue(text) or type(text) ~= "string"
		or issecretvalue(startMs) or issecretvalue(endMs) or type(startMs) ~= "number" or type(endMs) ~= "number" or endMs <= startMs then
		return text
	end
	local finish = (endMs + left * (endMs - startMs)) / MS
	local same = cb.craftEnd and math.abs(finish - cb.craftEnd) < (endMs - startMs) / MS / 2
	if not same then cb.craftFirst = startMs end
	cb.craftEnd = finish
	if left < 1 and not (merge and same) then return text end
	cb.batch, cb.craftMore = finish, left > 0
	return text .. " (" .. (left + 1) .. ")"
end

local function Latency(cb, channel, startMs, endMs)
	if cb.latency then cb.latency:Hide() end
	cb.lag = nil
	local zone = cb.kind == "player" and Settings.Value(cb.kind, "castbarLatency")
	if not ((zone or cb.lagText) and GetNetStats) then return end
	local _, _, _, ms = GetNetStats()
	if issecretvalue(ms) or type(ms) ~= "number" or ms ~= ms or ms < 0 then return end
	if cb.lagText then cb.lag = math.floor(ms + 0.5) end
	if not zone or ms == 0 then return end
	if issecretvalue(startMs) or issecretvalue(endMs) or type(startMs) ~= "number" or type(endMs) ~= "number" or startMs ~= startMs or endMs ~= endMs or endMs <= startMs then return end
	local w, h = cb.bar:GetSize()
	if issecretvalue(w) or issecretvalue(h) or type(w) ~= "number" or type(h) ~= "number" or not (w > 0 and h > 0) then return end
	if not cb.latency then
		cb.latency = cb.bar:CreateTexture(nil, "OVERLAY")
		cb.latency:SetColorTexture(Widgets.Rgba("hostile", 0.4))
	end
	local vertical = cb.bar.vertical
	local reverse = cb.bar:GetReverseFill()
	local start = (reverse == true) ~= (channel == true)
	local point = vertical and (start and "BOTTOM" or "TOP") or (start and "LEFT" or "RIGHT")
	local share = math.min(1, ms / (endMs - startMs))
	cb.latency:ClearAllPoints()
	cb.latency:SetPoint(point, cb.bar, point)
	cb.latency:SetSize(vertical and w or w * share, vertical and h * share or h)
	cb.latency:Show()
end

function CastBars.Important(cb, spellID, sample)
	local glow, api = cb.important, C_Spell and C_Spell.IsSpellImportant
	if not (Settings.Value(cb.kind, "castbarImportant") and (sample or api and (issecretvalue(spellID) or spellID ~= nil))) then
		if glow and glow:IsShown() then glow:Hide() end
		return
	end
	if not glow then
		glow = CreateFrame("Frame", nil, cb.frame)
		glow:SetAllPoints(cb.frame)
		glow.line = Widgets.NineSlice(glow, "lumenOutline", "OVERLAY")
		cb.important = glow
		StyleImportant(cb)
	end
	local important = sample or api(spellID)
	if issecretvalue(important) and glow.SetAlphaFromBoolean then
		glow:Show()
		glow:SetAlphaFromBoolean(important, 1, 0)
	else
		glow:SetAlpha(1)
		glow:SetShown(not issecretvalue(important) and important == true)
	end
end

local function SpellTarget(cb)
	if not (UnitSpellTargetName and UnitShouldDisplaySpellTargetName and Settings.Value(cb.kind, "castbarTarget")) then return nil end
	local show = UnitShouldDisplaySpellTargetName(cb.unit)
	if issecretvalue(show) or show ~= true then return nil end
	local name = UnitSpellTargetName(cb.unit)
	if issecretvalue(name) or type(name) == "string" and name ~= "" then return name end
end

local function Start(cb, channel, update)
	local _, text, texture, startMs, endMs, isTradeSkill, notInterruptible, spellID, castBarID
	if channel and UnitChannelInfo then
		_, text, texture, startMs, endMs, isTradeSkill, notInterruptible, spellID, _, _, castBarID = UnitChannelInfo(cb.unit)
	elseif not channel and UnitCastingInfo then
		_, text, texture, startMs, endMs, isTradeSkill, _, notInterruptible, spellID, castBarID = UnitCastingInfo(cb.unit)
	end
	if type(isTradeSkill) ~= "boolean" or cb.noRoom then
		Hide(cb, true)
		return
	end
	cb.active, cb.landed, cb.channel, cb.error, cb.gcd = true, false, channel, false, nil
	cb.inkEmpty = false
	StopFlash(cb)
	cb.castBarID, cb.spellID = nil, nil
	if not issecretvalue(castBarID) and type(castBarID) == "number" then
		cb.castBarID = castBarID
	end
	if not channel and not issecretvalue(spellID) and type(spellID) == "number" then
		cb.spellID = spellID
	end
	cb.batch, cb.rankID = nil, nil
	if cb.kind == "player" then
		if Settings.Value("player", "castbarRank") then text, cb.rankID = Ranked(text, spellID), not issecretvalue(spellID) and spellID or nil end
		cb.merge = Settings.Value("player", "castbarCraftBar")
		if not issecretvalue(isTradeSkill) and isTradeSkill == true and (cb.merge or Settings.Value("player", "castbarCraft")) then text = Batch(cb, text, startMs, endMs, cb.merge) end
	end
	cb.token = (cb.token or 0) + 1
	cb.duration = nil
	if not update or not Outcomes() then Motion.FadeIn(cb.frame, Outcomes() and 0.08 or Tokens.Duration("fade")) end
	Notify(cb)
	if cb.empty then
		cb.empty = false
		cb.bar:SetFillCursor(cb.medal and Settings.Value(cb.kind, "castbarSpark"))
		Spark(cb)
	end
	CastBars.SetName(cb, text, SpellTarget(cb))
	Icon(cb, texture)
	if not cb.styled then
		CastBars.Restyle(cb)
	end
	WatchRange(cb, spellID)
	Locked(cb, notInterruptible)
	if cb.rangeID then Range(cb) end
	CastBars.Important(cb, spellID)
	Latency(cb, channel, startMs, endMs)
	cb.elapsed = TIMER_STEP
	cb.total = nil
	local tick
	if cb.batch and cb.merge and Span(cb) then
		tick = Settings.Value(cb.kind, "castbarTimer")
	elseif RunDuration(cb, channel) then
		tick = cb.duration ~= nil and Settings.Value(cb.kind, "castbarTimer")
	else
		tick = RunTimes(cb, channel, startMs, endMs)
	end
	if tick then
		cb.frame:SetScript("OnUpdate", Tick)
	else
		StopTimer(cb)
	end
	if not (update and Outcomes()) and not cb.bar.vertical and not cb.line and not cb.mode and not cb.medal then
		cb.bar:PlaySheen(false)
	end
end

local function Finish(cb, message)
	if not (cb.active or cb.landed) then
		return
	end
	cb.active, cb.landed, cb.error = false, false, true
	EndTimer(cb, Outcomes() and 1 or 0)
	cb.locked = false
	ShowLock(cb)
	CastBars.SetName(cb, message)
	Paint(cb, Tokens.Color("hostile"))
	Flash(cb, "hostile", STOPPED_ALPHA)
	HoldThen(cb, Outcomes() and Tokens.Duration("castErrorHold") or HOLD)
end

local function Land(cb)
	cb.active, cb.landed = false, true
	EndTimer(cb, 1)
	Flash(cb, "giltLit", LANDED_ALPHA)
	HoldThen(cb, Outcomes() and 0.35 or Tokens.Duration("pressIn") + Tokens.Duration("readyFlash"))
end

local function ShowGcd(cb, duration)
	local token = (cb.gcdToken or 0) + 1
	cb.gcdToken, cb.gcd, cb.timed = token, token, true
	StopFlash(cb)
	CastBars.SetName(cb, "")
	cb.timer:SetText("")
	cb.icon:SetTexture(nil)
	cb.label:Hide()
	cb.lock:Hide()
	Paint(cb, BarColor(cb))
	Motion.Tween(cb.frame, "SetAlpha", 1, 1, 0)
	cb.frame:Show()
	local ok, left = pcall(duration.GetRemainingDuration, duration)
	if not ok or issecretvalue(left) or type(left) ~= "number" or left ~= left or left <= 0 then left = GCD_MAX end
	C_Timer.After(left, function() if cb.gcd == token then Hide(cb, true) end end)
end

local function Gcd(cb, spellID)
	if cb.gcd and not cb.gcdNew or cb.active or cb.landed or cb.holds > 0 or cb.noRoom then return end
	cb.gcdNew = nil
	if issecretvalue(spellID) then spellID = nil end
	local api, cast, probe = C_Spell, cb.gcdCast ~= spellID and cb.gcdCast or nil, cb.gcdProbe ~= spellID and cb.gcdProbe ~= cb.gcdCast and cb.gcdProbe or nil
	for i = 1, 3 do
		local id = select(i, spellID, cast, probe)
		if type(id) == "number" then
			local ok, info = pcall(api.GetSpellCooldown, id)
			local on = ok and type(info) == "table" and info.isOnGCD
			if not issecretvalue(on) and on == true then
				local got, duration = pcall(api.GetSpellCooldownDuration, id)
				if got and type(duration) ~= "nil" and pcall(cb.bar.SetTimerDuration, cb.bar, duration, Interpolation(cb), Direction(false)) then
					cb.gcdProbe = id
					ShowGcd(cb, duration)
					return
				end
			end
		end
	end
end

local function Casting(unit)
	if not (UnitCastingInfo and UnitChannelInfo) then return false end
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
	local spellID = select(3, ...)
	if cb.landed and cb.spellID and not issecretvalue(spellID) and type(spellID) == "number" then
		return spellID == cb.spellID
	end
	return not Casting(cb.unit)
end

local HANDLERS = {
	Cast = function(cb)
		Start(cb, false)
	end,
	Delayed = function(cb)
		if cb.active then Start(cb, false, true) end
	end,
	Channel = function(cb)
		Start(cb, true)
	end,
	Stop = function(cb, event, ...)
		if cb.active and Matches(cb, event, ...) then
			if not cb.channel and cb.batch and cb.merge and cb.craftMore then
				local token = cb.token
				C_Timer.After(BATCH_GAP, function() if cb.token == token and cb.active then Land(cb) end end)
				return
			elseif not cb.channel then
				Land(cb)
				return
			end
			local by = event == "UNIT_SPELLCAST_CHANNEL_STOP" and select(4, ...)
			if not issecretvalue(by) and type(by) == "string" and by ~= "" then
				Finish(cb, L["Interrupted"])
			elseif Outcomes() then
				Land(cb)
			else
				Hide(cb)
			end
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
	local form = Settings.Form(kind)
	local plate = form == "plate"
	local separate = kind == "player" and form == "column" or form == "bar" or K.HudStyle.Current() == "medallions" and Settings.CAST_ELEMENTS[kind] ~= nil and not Settings.CastOnFrame(kind)
	if cb.inline then
		return not plate and not separate and Settings.Value(kind, "enabled")
	end
	if Settings.CAST_ELEMENTS[kind] then
		return plate or separate or not Settings.Value(kind, "enabled")
	end
	return Settings.Value(kind, "enabled")
end

local NONE = {}

local function Each(kind, fn)
	for _, cb in ipairs(bars[kind] or NONE) do
		fn(cb)
	end
	for _, cb in ipairs(inline[kind] or NONE) do
		fn(cb)
	end
end

local function RefreshOne(cb)
	if Enabled(cb) and UnitExists(cb.unit) and UnitCastingInfo and UnitChannelInfo then
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

function CastBars.Lined(kind)
	local lined = false
	Each(kind, function(cb) lined = lined or cb.line == true and Enabled(cb) end)
	return lined
end

local function Listen(cb)
	local owner = Owner(cb)
	K.Events.UnregisterAll(owner)
	local on = Enabled(cb)
	cb.idle = on and not Settings.Value(cb.kind, "castbarHideIdle")
	if not on then
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
	if cb.kind == "player" and Settings.Value("player", "castbarGcd") and C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldownDuration and C_Timer then
		cb.onGcd = cb.onGcd or function(_, spellID) Gcd(cb, spellID) end
		cb.onCast = cb.onCast or function(_, _, _, spellID)
			if not issecretvalue(spellID) and type(spellID) == "number" then cb.gcdCast = spellID end
			cb.gcdNew = true
		end
		K.Events.Register(owner, "SPELL_UPDATE_COOLDOWN", cb.onGcd)
		K.Events.RegisterUnit(owner, "UNIT_SPELLCAST_SUCCEEDED", cb.onCast, cb.unit)
	end
	if cb.kind == "player" and Settings.Value("player", "castbarRank") then
		cb.onText = cb.onText or function(_, spellID)
			if cb.active and not issecretvalue(spellID) and spellID == cb.rankID then Start(cb, cb.channel, true) end
		end
		K.Events.Register(owner, "SPELL_TEXT_UPDATE", cb.onText)
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
	local cb = New(kind == "target" and view.button or view.body or view.button, kind, view.unit)
	cb.attached, cb.noRoom = true, true
	view.castbar = cb
	local block = view.health and view.health.ornament
	if block then
		cb.ornament.card = block.card
		for _, text in ipairs(cb.ornament.texts) do
			block.texts[#block.texts + 1] = text
		end
		block.avoid[#block.avoid + 1] = cb.iconFrame
		block.reserve = block.reserve or {}
		block.reserve[cb.text], block.reserve[cb.timer] = true, true
		cb.frame:HookScript("OnShow", function() block:Restyle() end)
		cb.frame:HookScript("OnHide", function() block:Restyle() end)
		if view.power and Settings.CAST_ELEMENTS[kind] then
			block.spans = { view.power, cb.bar }
			cb.ornament.joined = true
			cb.ornament:Restyle()
		else
			block.near = { cb.bar }
		end
	end
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
	for _, kind in ipairs({ "player", "target" }) do
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
			cb.idle = false
			Hide(cb, true)
		end)
	end
	for kind, holder in pairs(holders) do
		holder:Hide()
		hiddenByModule[kind] = true
	end
end
