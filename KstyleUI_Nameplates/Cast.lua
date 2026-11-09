-- Cast.lua: the plate's cast bar, run by the engine from the cast APIs' duration objects, with the spell's name, icon and interruptible state passed through.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Motion, L = K.Widgets, K.Tokens, K.Theme, K.Motion, K.L
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce

local Cast = {}
ns.Cast = Cast

local GAP = Tokens.Size("gapTiny")
local TEXT_INSET = Tokens.Size("gapSmall")
local TIME_STEP = 0.1
local INTERRUPT_FADE = 0.8
local SHIELD_ALPHA = 0.6
local ICON_CROP = 0.07
local MS = 1000
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local SPARK_EDGE = {
	HORIZONTAL = { normal = "RIGHT", reverse = "LEFT" },
	VERTICAL = { normal = "TOP", reverse = "BOTTOM" },
}

local function Direction(name)
	local enum = Enum and Enum.StatusBarTimerDirection
	return enum and enum[name]
end

local function Immediate()
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.Immediate
end

local function CastColor()
	if Settings.Get("cast.colorSource") == "custom" then
		local c = Settings.Get("cast.color")
		return c.r, c.g, c.b
	end
	return Theme.Accent()
end

local function ShieldColor()
	local c = Settings.Get("cast.shieldColor")
	return c.r, c.g, c.b
end

local function OpenColor()
	local interrupt = ns.Interrupt
	if interrupt and interrupt.ready == false then
		local c = Settings.Get("cast.waitColor")
		return c.r, c.g, c.b
	end
	return CastColor()
end

local colors = { open = {}, wait = {}, shield = {} }
local function ColorObject(slot, r, g, b)
	if slot.r ~= r or slot.g ~= g or slot.b ~= b then
		slot.r, slot.g, slot.b = r, g, b
		slot.object = CreateColor(r, g, b, 1)
	end
	return slot.object
end

local function ColorObjects()
	if not CreateColor then
		return nil
	end
	local interrupt = ns.Interrupt
	local open
	if interrupt and interrupt.ready == false then
		local c = Settings.Get("cast.waitColor")
		open = ColorObject(colors.wait, c.r, c.g, c.b)
	else
		open = ColorObject(colors.open, CastColor())
	end
	return open, ColorObject(colors.shield, ShieldColor())
end

local function StyleFont(text)
	local flags = OUTLINE_FLAGS[Settings.Get("cast.outline")] or "OUTLINE"
	local size = Settings.Get("cast.textSize")
	if text:SetFont(Settings.Get("font"), size, flags) == false then
		text:SetFont((Tokens.Font("world")), size, flags)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

local function OnUpdate(bar, elapsed)
	local plate = bar.plate
	if plate.castFallback then
		bar:SetValue(GetTime() * MS)
	end
	local duration = plate.castDuration
	if not duration or not plate.castTime:IsShown() then
		return
	end
	plate.castClock = plate.castClock - elapsed
	if plate.castClock > 0 then
		return
	end
	plate.castClock = TIME_STEP
	local ok, remaining = pcall(duration.GetRemainingDuration, duration)
	if ok then
		plate.castTime:SetFormattedText("%.1f", remaining)
	end
end

local function StopFade(plate)
	if plate.castFade then
		Motion.Stop(plate.castFade)
		plate.castFade = nil
	end
end

local function Fill(plate, r, g, b)
	if plate.castR == r and plate.castG == g and plate.castB == b then
		return
	end
	plate.castR, plate.castG, plate.castB = r, g, b
	plate.castBar:SetFillColor(r, g, b)
end

local function Shade(plate, alpha)
	if plate.castShade == alpha then
		return
	end
	plate.castShade = alpha
	plate.castShield:SetAlpha(alpha)
end

local function Paint(plate, openR, openG, openB)
	local flag = plate.castFlag
	if plate.castInterrupted then
		Fill(plate, Tokens.Color("hostile"))
		Shade(plate, 0)
		return
	end
	if openR == nil then
		openR, openG, openB = OpenColor()
	end
	if IsSecret(flag) then
		local normal, shield = ColorObjects()
		local texture = plate.castBar:GetStatusBarTexture()
		if normal and texture and texture.SetVertexColorFromBoolean then
			plate.castR = nil
			texture:SetVertexColorFromBoolean(flag, shield, normal)
		else
			Fill(plate, openR, openG, openB)
			LogOnce("cast-flag", "SetVertexColorFromBoolean is missing; secret uninterruptible casts use the normal colour")
		end
		if plate.castShield.SetAlphaFromBoolean then
			plate.castShade = nil
			plate.castShield:SetAlphaFromBoolean(flag, SHIELD_ALPHA, 0)
		end
	elseif flag == true then
		Fill(plate, ShieldColor())
		Shade(plate, SHIELD_ALPHA)
	else
		Fill(plate, openR, openG, openB)
		Shade(plate, 0)
	end
end
Cast.Paint = Paint

local openR, openG, openB

local function RepaintOpen(plate)
	if plate.casting then
		Paint(plate, openR, openG, openB)
	end
end

function Cast.RepaintAll()
	openR, openG, openB = OpenColor()
	ns.Plates.Each(RepaintOpen)
end

local function Info(unit, channel)
	if channel then
		local name, text, texture, startMs, endMs, _, notInterruptible = UnitChannelInfo(unit)
		return name, text, texture, startMs, endMs, notInterruptible, nil
	end
	local name, text, texture, startMs, endMs, _, castID, notInterruptible = UnitCastingInfo(unit)
	return name, text, texture, startMs, endMs, notInterruptible, castID
end

local function DurationFor(unit, channel)
	local fn = channel and UnitChannelDuration or UnitCastingDuration
	if type(fn) ~= "function" then
		return nil
	end
	local ok, duration = pcall(fn, unit)
	if not ok or type(duration) == "nil" then
		return nil
	end
	if IsSecret(duration) then
		LogOnce("cast-secret-duration", "a cast's duration object came back secret; that bar runs from the start and end times")
		return nil
	end
	return duration
end

local function Run(plate, channel, startMs, endMs)
	local bar = plate.castBar
	local duration = DurationFor(plate.unit, channel)
	plate.castDuration, plate.castFallback = nil, false
	if duration and type(bar.SetTimerDuration) == "function" then
		local direction = Direction(channel and "RemainingTime" or "ElapsedTime")
		local ok = pcall(bar.SetTimerDuration, bar, duration, Immediate(), direction)
		if ok then
			plate.castDuration = duration
			return
		end
	end
	LogOnce("cast-fallback", "UnitCastingDuration or SetTimerDuration is unavailable; cast bars run from the cast's start and end times")
	bar:SetMinMaxValues(startMs, endMs)
	bar:SetValue(GetTime() * MS)
	plate.castFallback = true
end

local function Shows(plate)
	return Settings.Get("cast.enabled") and not plate.nameOnly and plate.unit ~= nil
end

function Cast.Start(plate, channel)
	if not Shows(plate) then
		return
	end
	local name, text, texture, startMs, endMs, flag, castID = Info(plate.unit, channel)
	if type(name) == "nil" then
		return
	end
	StopFade(plate)
	plate.casting, plate.castChannel, plate.castInterrupted = true, channel, false
	plate.castFlag, plate.castID = flag, castID
	local cast = plate.cast
	cast:SetAlpha(1)
	cast:Show()
	plate.castIcon:SetTexture(texture)
	plate.castName:SetText(text)
	Run(plate, channel, startMs, endMs)
	plate.castClock = 0
	local showTime = Settings.Get("cast.showTime") and plate.castDuration ~= nil
	plate.castTime:SetShown(showTime)
	if showTime then
		plate.castTime:SetText("")
	end
	plate.castBar:SetScript("OnUpdate", (showTime or plate.castFallback) and OnUpdate or nil)
	Paint(plate)
	plate.castBar:PlaySheen(false)
end

function Cast.Stop(plate, interrupted)
	if not plate.casting then
		return
	end
	local bar, cast = plate.castBar, plate.cast
	bar:SetScript("OnUpdate", nil)
	plate.casting, plate.castDuration, plate.castFallback = false, nil, false
	if interrupted then
		plate.castInterrupted = true
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		plate.castName:SetText(L["Interrupted"])
		plate.castTime:SetText("")
		Paint(plate)
		plate.castFade = Motion.FadeOut(cast, INTERRUPT_FADE)
	else
		plate.castFade = Motion.FadeOut(cast, Tokens.Duration("fade"))
	end
end

function Cast.Hide(plate)
	StopFade(plate)
	plate.casting, plate.castDuration, plate.castFallback, plate.castInterrupted = false, nil, false, false
	plate.castBar:SetScript("OnUpdate", nil)
	plate.cast:Hide()
end

function Cast.SetInterruptible(plate, interruptible)
	if plate.casting then
		plate.castFlag = not interruptible
		Paint(plate)
	end
end

local function Running(plate, channel, castID)
	if not plate.casting or plate.castChannel ~= channel then
		return false
	end
	if channel then
		return true
	end
	local last = plate.castID
	if IsSecret(castID) or IsSecret(last) then
		return true
	end
	return castID ~= nil and castID == last
end

function Cast.Refresh(plate, immediate)
	if not Shows(plate) then
		Cast.Hide(plate)
		return
	end
	local unit = plate.unit
	local name, _, _, _, _, _, castID = UnitCastingInfo(unit)
	if type(name) ~= "nil" then
		if not immediate and Running(plate, false, castID) then
			return
		end
		Cast.Start(plate, false)
		return
	end
	name = UnitChannelInfo(unit)
	if type(name) ~= "nil" then
		if not immediate and Running(plate, true) then
			return
		end
		Cast.Start(plate, true)
	elseif plate.casting then
		Cast.Hide(plate)
	end
end

local Component = { events = {} }
ns.Components[#ns.Components + 1] = Component

function Component.Build(plate)
	local cast = CreateFrame("Frame", nil, plate)
	cast:Hide()
	plate.cast = cast
	plate.castBarOpts = { width = 100, height = 12, border = true, spark = true, sheen = true }
	local bar = Widgets.StatusBar(cast, plate.castBarOpts)
	bar.plate = plate
	plate.castBar = bar
	local icon = cast:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = cast:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	plate.castIcon = icon
	local shield = cast:CreateTexture(nil, "OVERLAY")
	shield:SetColorTexture(Tokens.Color("black"))
	shield:SetAllPoints(icon)
	shield:AddMaskTexture(mask)
	shield:SetAlpha(0)
	plate.castShield = shield
	local name = Widgets.FontString(bar, "OVERLAY")
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	plate.castName = name
	local time = Widgets.FontString(bar, "OVERLAY")
	time:SetJustifyH("RIGHT")
	time:SetWordWrap(false)
	plate.castTime = time
end

function Component.Room(plate)
	if not Settings.Get("cast.enabled") then
		return 0
	end
	return Settings.Get("cast.height") + GAP
end

function Component.Restyle(plate)
	local state = ns.state
	local h = Settings.Get("cast.height")
	local showIcon = Settings.Get("cast.showIcon")
	local iconRoom = showIcon and h + GAP or 0
	local cast, bar, icon = plate.cast, plate.castBar, plate.castIcon
	Widgets.Size(cast, state.width, h)
	cast:ClearAllPoints()
	cast:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", 0, -Widgets.Snap(plate, GAP))
	Widgets.Size(icon, h, h)
	icon:ClearAllPoints()
	icon:SetPoint("LEFT", cast, "LEFT")
	icon:SetShown(showIcon)
	plate.castShield:SetShown(showIcon)
	local opts = plate.castBarOpts
	opts.width, opts.height = math.max(1, state.width - iconRoom), h
	bar:ClearAllPoints()
	bar:SetPoint("RIGHT", cast, "RIGHT")
	local orientation = Settings.Get("cast.orientation")
	bar:SetOrientation(orientation)
	bar.vertical = orientation == "VERTICAL"
	local reverse = Settings.Get("cast.reverse")
	bar:SetReverseFill(reverse)
	bar:SetBarTexture(Settings.Get("cast.texture"))
	local edges = SPARK_EDGE[orientation] or SPARK_EDGE.HORIZONTAL
	bar.spark:ClearAllPoints()
	bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), reverse and edges.reverse or edges.normal)
	bar:Restyle()
	StyleFont(plate.castName)
	StyleFont(plate.castTime)
	plate.castName:ClearAllPoints()
	plate.castName:SetPoint("LEFT", bar, "LEFT", Widgets.Snap(plate, TEXT_INSET), 0)
	plate.castName:SetPoint("RIGHT", plate.castTime, "LEFT", -Widgets.Snap(plate, GAP), 0)
	plate.castName:SetShown(Settings.Get("cast.showName"))
	plate.castTime:ClearAllPoints()
	plate.castTime:SetPoint("RIGHT", bar, "RIGHT", -Widgets.Snap(plate, TEXT_INSET), 0)
end

function Component.Refresh(plate, immediate)
	if plate.sample then
		Cast.Sample(plate)
		return
	end
	Cast.Refresh(plate, immediate)
end

function Component.Clear(plate)
	Cast.Hide(plate)
end

function Cast.Sample(plate)
	local sample = plate.sample.cast
	if not sample or not Settings.Get("cast.enabled") or plate.nameOnly then
		plate.cast:Hide()
		return
	end
	plate.cast:SetAlpha(1)
	plate.cast:Show()
	plate.castIcon:SetTexture(sample.texture)
	plate.castName:SetText(sample.text)
	plate.castTime:SetText(sample.time)
	plate.castTime:SetShown(Settings.Get("cast.showTime"))
	plate.castBar:SetBarRange(0, 1)
	plate.castBar:SetValue(sample.progress)
	plate.castFlag = sample.notInterruptible
	Paint(plate)
end

Component.events.UNIT_SPELLCAST_START = function(plate)
	Cast.Start(plate, false)
end
Component.events.UNIT_SPELLCAST_CHANNEL_START = function(plate)
	Cast.Start(plate, true)
end
Component.events.UNIT_SPELLCAST_DELAYED = function(plate)
	if plate.casting and not plate.castChannel then
		Cast.Start(plate, false)
	end
end
Component.events.UNIT_SPELLCAST_CHANNEL_UPDATE = function(plate)
	if plate.casting and plate.castChannel then
		Cast.Start(plate, true)
	end
end
local function OtherCast(plate, castGUID)
	local shown = plate.castID
	if type(castGUID) == "string" and type(shown) == "string" and not IsSecret(castGUID) and not IsSecret(shown) then
		return castGUID ~= shown
	end
	return type((UnitCastingInfo(plate.unit))) ~= "nil"
end

Component.events.UNIT_SPELLCAST_STOP = function(plate, _, castGUID)
	if not plate.castChannel and not OtherCast(plate, castGUID) then
		Cast.Stop(plate, false)
	end
end
Component.events.UNIT_SPELLCAST_FAILED = Component.events.UNIT_SPELLCAST_STOP
Component.events.UNIT_SPELLCAST_CHANNEL_STOP = function(plate, _, _, _, interruptedBy)
	if plate.castChannel then
		Cast.Stop(plate, type(interruptedBy) ~= "nil")
	end
end
Component.events.UNIT_SPELLCAST_INTERRUPTED = function(plate)
	Cast.Stop(plate, true)
end
Component.events.UNIT_SPELLCAST_INTERRUPTIBLE = function(plate)
	Cast.SetInterruptible(plate, true)
end
Component.events.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(plate)
	Cast.SetInterruptible(plate, false)
end
