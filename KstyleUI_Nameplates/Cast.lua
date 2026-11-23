-- Cast.lua: the plate's flat cast bar, run by the engine from duration objects, with optional name, icon, time and target-frame deduplication.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Theme, Motion, L = K.Widgets, K.Tokens, K.Theme, K.Motion, K.L
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce

local Cast = {}
ns.Cast = Cast
ns.Interrupt = K.Interrupt

local GAP = Tokens.Size("gapTiny")
local TEXT_INSET = Tokens.Size("gapSmall")
local TIME_STEP = 0.1
local INTERRUPT_FADE = 0.8
local function InQuad(t) return t * t end
local function HideCast(cast) cast:Hide() end
local SHIELD_ALPHA = 0.6
local IN_FRONT = 100
local GLOW_CORNER, GLOW_OUTSET = 8, 6
local ICON_CROP = 0.07
local MS = 1000
local SIGIL_MODULE = "UnitFrames"
local SIGIL_KEYS = { "target.enabled", "target.castbar" }
local OUTLINE_FLAGS = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }
local function Direction(name)
	local enum = Enum and Enum.StatusBarTimerDirection
	return enum and enum[name]
end

local function Immediate()
	local enum = Enum and Enum.StatusBarInterpolation
	return enum and enum.Immediate
end

local function Rgb(c)
	return c.r, c.g, c.b
end

local function Plain(value)
	return not IsSecret(value) and type(value) == "number" and value or nil
end

local function CastColor()
	if Settings.Get("cast.colorSource") == "custom" then
		local c = Settings.Get("cast.color")
		return c.r, c.g, c.b
	end
	return Theme.Accent()
end

local function ShieldColor()
	if not Settings.Get("cast.combatCues") then return Tokens.Color("textDisabled") end
	local c = Settings.Get("cast.shieldColor")
	return K.ColorVision.Color(2, c.r, c.g, c.b)
end

local function OpenColor()
	if not Settings.Get("cast.combatCues") then return CastColor() end
	local interrupt = ns.Interrupt
	if interrupt and interrupt.spell and interrupt.ready ~= true then
		local c = Settings.Get("cast.waitColor")
		return K.ColorVision.Color(3, c.r, c.g, c.b)
	end
	return K.ColorVision.Color(1, CastColor())
end

local colors = { open = {}, wait = {}, shield = {}, important = {} }
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
	if Settings.Get("cast.combatCues") and interrupt and interrupt.spell and interrupt.ready ~= true then
		local c = Settings.Get("cast.waitColor")
		open = ColorObject(colors.wait, K.ColorVision.Color(3, c.r, c.g, c.b))
	else
		open = ColorObject(colors.open, K.ColorVision.Color(1, CastColor()))
	end
	return open, ColorObject(colors.shield, ShieldColor())
end

local function StyleFont(text, role)
	local flags = OUTLINE_FLAGS[Settings.Get("cast.outline")] or "OUTLINE"
	local size = Settings.Get("cast.textSize")
	if not Widgets.ApplyFont(text, Settings.Get("font", role), size, flags) then
		Widgets.ApplyFont(text, (Tokens.Font("world")), size, flags)
	end
end

local function OnUpdate(bar, elapsed)
	local plate = bar.plate
	if plate.castFallback then
		bar:SetValue(GetTime() * MS)
	end
	local duration = plate.castDuration
	if type(duration) == "nil" or IsSecret(duration) or not plate.castTime:IsShown() then
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
	plate.castToken = (plate.castToken or 0) + 1
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
	plate.castGlyph:SetAlpha(Settings.Get("cast.combatCues") and alpha > 0 and 1 or 0)
end

local function FromFlag(region, flag, yes, no)
	yes, no = yes or 1, no or 0
	if IsSecret(flag) and region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(flag, yes, no)
	else
		region:SetAlpha(not IsSecret(flag) and flag == true and yes or no)
	end
end

local function PaintImportant(plate)
	local important = plate.castImportant
	if plate.castInterrupted then important = nil end
	local fill, glow = plate.castImportantFill, plate.castImportantGlow
	if fill then
		local interrupt, flag = ns.Interrupt, plate.castFlag
		local kick = Settings.Get("cast.importantKick") and interrupt and interrupt.spell and interrupt.ready == true
		if type(important) ~= "nil" and Settings.Get("cast.important") and not (kick and not IsSecret(flag) and flag ~= true) then
			local r, g, b = Rgb(Settings.Get("cast.importantColor"))
			if kick and IsSecret(flag) and fill.SetVertexColorFromBoolean and CreateColor then
				fill:SetVertexColorFromBoolean(flag, ColorObject(colors.important, r, g, b), (ColorObjects()))
			else
				fill:SetVertexColor(r, g, b)
			end
			FromFlag(fill, important)
			plate.castFillOn = true
		elseif plate.castFillOn ~= false then
			fill:SetAlpha(0)
			plate.castFillOn = false
		end
	end
	if glow then
		local on = type(important) ~= "nil" and Settings.Get("cast.importantGlow") or false
		if on ~= plate.castGlowOn then
			Widgets.ShowSlice(glow, on)
			plate.castGlowOn = on
			if on then
				for i = 1, #glow do FromFlag(glow[i], important) end
			end
		end
	end
end

local function PaintTarget(plate)
	local glow = plate.castTargetGlow
	if not glow then return end
	local flag = plate.castAtMe
	local on = not plate.castInterrupted and Settings.Get("cast.targetGlow") and type(flag) ~= "nil" or false
	if on ~= plate.castAtMeOn then
		Widgets.ShowSlice(glow, on)
		plate.castAtMeOn = on
		if on then
			for i = 1, #glow do FromFlag(glow[i], flag) end
		end
	end
end

local function Mark(plate)
	local interrupt = ns.Interrupt
	local left = interrupt.Left(plate, Mark, plate.casting and not plate.castInterrupted and Settings.Get("cast.caster") and Settings.Get("cast.combatCues"))
	if left or plate.castWait then
		if not plate.castWait then
			plate.castWait = Widgets.FontString(plate.castBar, "OVERLAY")
			plate.castWait:SetPoint("CENTER", plate.castGlyph, "CENTER")
			StyleFont(plate.castWait, "time")
		end
		plate.castWait:SetText(left or "")
		FromFlag(plate.castWait, plate.castFlag, 0, 1)
	end
	local at = left and interrupt.At(plate.castStart, plate.castEnd, plate.castChannel)
	if not at then
		if plate.castMark then plate.castMark:Hide() end
		return
	end
	local opts, vertical, thick = plate.castBarOpts, Settings.Get("cast.orientation") == "VERTICAL", Widgets.Snap(plate, 2)
	plate.castMark = interrupt.Mark(plate.castMark, plate.castBar, at, opts.width, opts.height, vertical, Settings.Get("cast.reverse"), plate)
	Widgets.Size(plate.castMark, vertical and opts.width or thick, vertical and thick or opts.height)
	FromFlag(plate.castMark, plate.castFlag, 0, 1)
end

local function WhoPlace(plate)
	return Settings.Get("cast.caster") and (plate.castTargetOwn or Settings.Get("cast.nameBelow"))
end

local function WhoRoom(plate)
	if not WhoPlace(plate) then return false end
	if plate.castTargetOwn then return plate.castTarget:IsShown() end
	return plate.castName:IsShown()
end

local function ShowWho(plate)
	if plate.castWho then
		local on = WhoRoom(plate)
		plate.castWho:SetShown(on)
		plate.castYou:SetShown(on)
	end
end

local function PlaceWho(plate)
	local own, size = plate.castTargetOwn and plate.castTarget, Settings.Get("cast.textSize")
	for _, text in ipairs({ plate.castWho, plate.castYou }) do
		StyleFont(text, "caps")
		text:ClearAllPoints()
		if own then
			text:SetAllPoints(own)
			text:SetJustifyH(Settings.Get("cast.targetPlace"))
		else
			text:SetJustifyH(Settings.Get("cast.nameAlign"))
			ns.Plate.Place(text, "TOPLEFT", plate.castBar, "BOTTOMLEFT", 0, -GAP - size - GAP, ns.state.width, size)
			text:SetWidth(Widgets.Snap(plate, plate.castBarOpts.width))
		end
	end
	plate.castYou:SetTextColor(Rgb(Settings.Get("cast.targetGlowColor")))
	ShowWho(plate)
end

local function SetWho(plate, name, class, me)
	local who = plate.castWho
	local on = type(name) ~= "nil"
	if not who then
		if not on then return end
		who = Widgets.FontString(plate.castBar, "OVERLAY")
		who:SetWordWrap(false)
		local you = Widgets.FontString(plate.castBar, "OVERLAY")
		you:SetWordWrap(false)
		you:SetText(K.Locale.Upper(L["You"]))
		plate.castWho, plate.castYou = who, you
		PlaceWho(plate)
	end
	if not on then
		who:SetText("")
		plate.castYou:SetAlpha(0)
		return
	end
	who:SetText(name)
	who:SetTextColor(K.Theme.ClassColorForWidget(class))
	FromFlag(who, me, 0, 1)
	FromFlag(plate.castYou, me, 1, 0)
end

local function Aimed(plate)
	if WhoRoom(plate) then SetWho(plate, K.Interrupt.Target(plate.unit)) else SetWho(plate, nil) end
end

local function Paint(plate, openR, openG, openB)
	PaintImportant(plate)
	PaintTarget(plate)
	Mark(plate)
	local flag = plate.castFlag
	if Settings.Get("cast.shieldBadge") and plate.castBadge.SetAlphaFromBoolean and (IsSecret(flag) or type(flag) == "boolean") then
		plate.castBadge:SetAlphaFromBoolean(flag, 1, 0)
	else
		plate.castBadge:SetAlpha(0)
	end
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
			plate.castGlyph:SetAlphaFromBoolean(flag, Settings.Get("cast.combatCues") and 1 or 0, 0)
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

function Cast.WatchInterrupt()
	K.Interrupt.Name(Settings.Get("cast.interruptSpell"))
	K.Interrupt.Watch(Settings.MODULE, Cast.RepaintAll)
end

local function Info(unit, channel)
	if channel then
		local name, text, texture, startMs, endMs, _, notInterruptible, spellID = UnitChannelInfo(unit)
		return name, text, texture, startMs, endMs, notInterruptible, nil, spellID
	end
	local name, text, texture, startMs, endMs, _, castID, notInterruptible, spellID = UnitCastingInfo(unit)
	return name, text, texture, startMs, endMs, notInterruptible, castID, spellID
end

local function Important(spellID)
	if not (Settings.Get("cast.important") or Settings.Get("cast.importantGlow")) or type(spellID) == "nil" then
		return nil
	end
	local api = C_Spell and C_Spell.IsSpellImportant
	if type(api) ~= "function" then
		LogOnce("cast-important", "C_Spell.IsSpellImportant is missing; no cast is marked important")
		return nil
	end
	local ok, important = pcall(api, spellID)
	if ok then return important end
	LogOnce("cast-important-refused", "C_Spell.IsSpellImportant refused a spell: " .. tostring(important))
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
	return duration
end

local function Run(plate, channel, startMs, endMs)
	local bar = plate.castBar
	local duration = DurationFor(plate.unit, channel)
	plate.castDuration, plate.castFallback = nil, false
	if type(duration) ~= "nil" and type(bar.SetTimerDuration) == "function" then
		local direction = Direction(channel and "RemainingTime" or "ElapsedTime")
		local ok = pcall(bar.SetTimerDuration, bar, duration, Immediate(), direction)
		if ok then
			plate.castDuration = duration
			return
		end
	end
	LogOnce("cast-fallback", "UnitCastingDuration or SetTimerDuration is unavailable or refused the duration; cast bars run from the start and end times")
	bar:SetMinMaxValues(startMs, endMs)
	bar:SetValue(GetTime() * MS)
	plate.castFallback = true
end

local function Recolor(plate)
	if not plate.unit then return end
	if Settings.Get("types.casting") then plate:UpdateColor() end
	if Settings.Get("cast.fullOpacity") or Settings.Get("cast.scale") ~= 1 then plate:UpdateHighlight() end
end

local function Shows(plate)
	return Settings.Get("cast.enabled") and not plate.nameOnly and plate.unit ~= nil
end
Cast.Shows = Shows

function Cast.Active(plate)
	if plate.sample then return plate.sample.cast ~= nil end
	return plate.unit ~= nil and (type((UnitCastingInfo(plate.unit))) ~= "nil" or type((UnitChannelInfo(plate.unit))) ~= "nil")
end

function Cast.Start(plate, channel, update)
	if not Shows(plate) then
		return Recolor(plate)
	end
	local name, text, texture, startMs, endMs, flag, castID, spellID = Info(plate.unit, channel)
	if type(name) == "nil" then
		return
	end
	StopFade(plate)
	plate.casting, plate.castChannel, plate.castInterrupted = true, channel, false
	plate.castFlag, plate.castID, plate.castImportant, plate.castGlowOn = flag, castID, Important(spellID), nil
	plate.castAtMe, plate.castAtMeOn = nil, nil
	if Settings.Get("cast.targetGlow") then
		local ok, me = false, nil
		if type(PlayerIsSpellTarget) == "function" then ok, me = pcall(PlayerIsSpellTarget, plate.unit) end
		if ok then plate.castAtMe = me else LogOnce("cast-at-me", "PlayerIsSpellTarget is missing or refused; no cast glows for targeting you") end
	end
	local cast = plate.cast
	plate.castIcon:SetTexture(texture)
	local target
	if Settings.Get("cast.showTarget") and not WhoPlace(plate) and type(UnitSpellTargetName) == "function" then
		target = UnitSpellTargetName(plate.unit)
	end
	Cast.Name(plate, not IsSecret(text) and type(text) == "string" and K.Locale.Upper(text) or text, target)
	Aimed(plate)
	plate.castStart, plate.castEnd = Plain(startMs), Plain(endMs)
	Run(plate, channel, startMs, endMs)
	plate.castClock = 0
	local showTime = Settings.Get("cast.showTime") and type(plate.castDuration) ~= "nil" and not IsSecret(plate.castDuration)
	plate.castTime:SetShown(showTime)
	if showTime then
		plate.castTime:SetText("")
	end
	cast:SetAlpha(1)
	cast:Show()
	plate.castBar:SetScript("OnUpdate", (showTime or plate.castFallback) and OnUpdate or nil)
	Paint(plate)
	plate:SetNameAlpha(Settings.Get("cast.hideUnitName") and 0 or 1)
	if not (update and Settings.Get("cast.outcomes")) then plate.castBar:PlaySheen(false) end
	Recolor(plate)
end

local function ShowTarget(plate)
	if plate.castTarget then
		plate.castTarget:SetShown(plate.castTargetOwn and not (plate.castName:IsShown() and not Settings.Get("cast.nameBelow")))
	end
	ShowWho(plate)
end

function Cast.Name(plate, spell, target)
	if plate.castTargetOwn then
		if type(target) == "nil" then plate.castTarget:SetText("") else plate.castTarget:SetText(target) end
		if Settings.Get("cast.nameBelow") then target = nil end
	end
	if type(target) ~= "nil" then
		plate.castName:SetFormattedText("%s > %s", spell, target)
	else
		plate.castName:SetText(spell)
	end
end

local function RestoreName(plate)
	plate:SetNameAlpha(1)
	Recolor(plate)
end

function Cast.Stop(plate, interrupted, failed, by)
	if not plate.casting then
		return Recolor(plate)
	end
	local bar, cast = plate.castBar, plate.cast
	bar:SetScript("OnUpdate", nil)
	plate.casting, plate.castDuration, plate.castFallback = false, nil, false
	RestoreName(plate)
	if interrupted then
		plate.castInterrupted = true
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		plate.castName:SetText(K.Locale.Upper(failed and L["Failed"] or L["Interrupted"]))
		plate.castTime:SetText("")
		if plate.castTargetOwn then plate.castTarget:SetText("") end
		if WhoRoom(plate) then SetWho(plate, K.Interrupt.By(by)) else SetWho(plate, nil) end
		Paint(plate)
		if Settings.Get("cast.outcomes") then
			local token = (plate.castToken or 0) + 1
			plate.castToken = token
			C_Timer.After(Tokens.Duration("castErrorHold"), function()
				if plate.castToken == token then
					plate.castFade = Motion.Tween(cast, "SetAlpha", cast:GetAlpha(), 0, 0.25, "inOutSine", HideCast)
				end
			end)
		else
			plate.castFade = Motion.FadeOut(cast, INTERRUPT_FADE)
		end
	else
		if Settings.Get("cast.outcomes") then
			plate.castFade = Motion.Tween(cast, "SetAlpha", cast:GetAlpha(), 0, Tokens.Duration("fade"), InQuad, HideCast)
		else
			plate.castFade = Motion.FadeOut(cast, Tokens.Duration("fade"))
		end
	end
end

function Cast.Hide(plate)
	StopFade(plate)
	plate.casting, plate.castChannel, plate.castDuration, plate.castFallback, plate.castInterrupted = false, nil, nil, false, false
	plate.castBar:SetScript("OnUpdate", nil)
	plate.cast:Hide()
	RestoreName(plate)
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

local function SigilCasts()
	local modules, options = K.Modules, K.Options
	if not modules.IsRunning(SIGIL_MODULE) then
		return false
	end
	for _, key in ipairs(SIGIL_KEYS) do
		local ok, on = pcall(options.Read, SIGIL_MODULE, key)
		if not ok or on ~= true then
			return false
		end
	end
	return true
end
Cast.SIGIL_MODULE, Cast.SIGIL_KEYS = SIGIL_MODULE, SIGIL_KEYS
Cast.SigilCasts = SigilCasts

function Cast.Gate(plate, isTarget, sigilCasts)
	local gate = plate.castGate
	if gate then
		if sigilCasts == nil then sigilCasts = SigilCasts() end
		gate:SetShown(not (isTarget and not plate.sample and Settings.Get("cast.hideOnTarget") and sigilCasts))
	end
end

function Cast.Selection(plate, isTarget, isFocus)
	local shown = Settings.Get("cast.showName") and (not Settings.Get("cast.nameSelectedOnly") or isTarget or isFocus) and true or false
	plate.castName:SetShown(shown)
	ShowTarget(plate)
	if plate.casting and not plate.castInterrupted then Aimed(plate) end
	local below = shown and Settings.Get("cast.nameBelow") and true or false
	if below == (plate.castNameBelow == true) then return end
	plate.castNameBelow = below
	if not plate.sample then ns.Stacking.Bound(plate, plate.rise or 0) end
	if Settings.Get("debuffs.growthY") == "DOWN" then ns.Auras.Reanchor(plate) end
end

function Component.Build(plate)
	local gate = CreateFrame("Frame", nil, plate)
	plate.castGate = gate
	local cast = CreateFrame("Frame", nil, gate)
	cast:Hide()
	plate.cast = cast
	plate.castBarOpts = { width = 100, height = 6, border = true }
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
	local glyph = bar:CreateTexture(nil, "OVERLAY")
	glyph:SetTexture((Tokens.Texture("medCastShieldGlyph")))
	glyph:SetVertexColor(Tokens.Color("steelLit"))
	glyph:SetAlpha(0)
	plate.castGlyph = glyph
	plate.castBadge = cast:CreateTexture(nil, "OVERLAY")
	plate.castBadge:SetTexture((Tokens.Texture("medCastShield")))
	plate.castBadge:SetAlpha(0)
	local name = Widgets.FontString(bar, "OVERLAY")
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	plate.castName = name
	local time = Widgets.FontString(bar, "OVERLAY")
	time:SetJustifyH("RIGHT")
	time:SetWordWrap(false)
	plate.castTime = time
end

function Component.Room(plate, anchor)
	if not Settings.Get("cast.enabled") then
		return 0
	end
	local label = not anchor and plate.castNameBelow and Settings.Get("cast.showName") and Settings.Get("cast.nameBelow") and (Settings.Get("cast.textSize") + GAP) * (Settings.Get("cast.caster") and 2 or 1) or 0
	local h = Cast.Height(plate)
	local icon = Settings.Get("cast.showIcon") and not Settings.Get("cast.iconFull") and math.max(0, (Settings.Get("cast.iconScale") - 1) * h / 2 - Settings.Get("cast.iconY")) or 0
	return math.max(0, h + Cast.Gap(plate) + Settings.Get("cast.offsetY") + Widgets.Border(plate.castBar) * 2 + label + icon)
end
Cast.Room = Component.Room

function Cast.Height(plate)
	local h = Settings.Get("cast.height")
	return plate.castFocus and h * Settings.Get("focus.castHeight") or h
end

function Cast.Resize(plate)
	Component.Restyle(plate)
	if plate.casting then
		plate.castR = nil
		Paint(plate)
	end
	if not plate.sample then plate:PlaceOnBase(ns.state.width, ns.state.height) end
	ns.Auras.Reanchor(plate)
end

function Cast.FullIcon(plate, sign)
	if not (Settings.Get("cast.iconFull") and Settings.Get("cast.showIcon") and Settings.Get("cast.enabled")) or (Settings.Get("cast.iconRight") and 1 or -1) ~= sign then
		return nil
	end
	return math.max(Cast.Height(plate), Widgets.Snap(plate, ns.state.height) + Cast.Gap(plate) + Widgets.Snap(plate, Settings.Get("cast.offsetY")) + Widgets.Snap(plate, Cast.Height(plate)))
end

function Cast.Gap(plate)
	return Widgets.Border(plate.health) + Widgets.Snap(plate, ns.Plate.FRAME_GAP) + Widgets.Border(plate.castBar)
end

function Cast.Place(plate)
	local cast = plate.cast
	cast:ClearAllPoints()
	cast:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", Widgets.Snap(plate, Settings.Get("cast.offsetX")), -Widgets.Snap(plate, Cast.Gap(plate)) - Widgets.Snap(plate, Settings.Get("cast.offsetY")))
end

function Component.Restyle(plate)
	plate.castShade = nil
	local state = ns.state
	local h = Cast.Height(plate)
	local showIcon = Settings.Get("cast.showIcon")
	local badge = math.max(11, h)
	local cast, bar, icon = plate.cast, plate.castBar, plate.castIcon
	Widgets.Size(cast, state.width, h)
	Cast.Place(plate)
	local right = Settings.Get("cast.iconRight")
	local sign = right and 1 or -1
	local full = Cast.FullIcon(plate, sign)
	local side = full or h * Settings.Get("cast.iconScale")
	local grow = (side - h) / 2
	local iconRoom = showIcon and not full and h + grow + GAP or 0
	Widgets.Size(icon, side, side)
	local iconSide = right and "TOPRIGHT" or "TOPLEFT"
	icon:ClearAllPoints()
	if full then
		icon:SetPoint(right and "TOPLEFT" or "TOPRIGHT", plate.health, iconSide, Widgets.Snap(plate, sign * ns.Auras.SideReach(plate, sign, true) + Settings.Get("cast.iconX")),
			Widgets.Snap(plate, Settings.Get("cast.iconY")))
	else
		icon:SetPoint(iconSide, cast, iconSide, Widgets.Snap(plate, (right and grow or -grow) + Settings.Get("cast.iconX")), Widgets.Snap(plate, grow + Settings.Get("cast.iconY")))
	end
	local front = Settings.Get("cast.inFront")
	if front or plate.castRaised then
		plate.castGate:SetFrameLevel(plate:GetFrameLevel() + (front and IN_FRONT or 1))
		plate.castRaised = front
	end
	icon:SetShown(showIcon)
	plate.castShield:SetShown(showIcon)
	Widgets.Size(plate.castBadge, badge, badge)
	plate.castBadge:ClearAllPoints()
	Widgets.Point(plate.castBadge, "TOPLEFT", cast, "TOPLEFT", -badge - GAP, (badge - h) / 2)
	local opts = plate.castBarOpts
	opts.width, opts.height = math.max(1, state.width - iconRoom), h
	local barSide = iconSide == "TOPLEFT" and "TOPRIGHT" or "TOPLEFT"
	bar:ClearAllPoints()
	bar:SetPoint(barSide, cast, barSide)
	local orientation = Settings.Get("cast.orientation")
	bar:SetOrientation(orientation)
	bar.vertical = orientation == "VERTICAL"
	local reverse = Settings.Get("cast.reverse")
	bar:SetReverseFill(reverse)
	bar:SetBarTexture(Settings.Get("cast.texture"))
	bar:Restyle()
	bar:SetFillCursor(Settings.Get("cast.spark"))
	local bg = Settings.Get("cast.bgAlpha")
	if bg ~= 1 then
		Widgets.Tint(bar.background, bar.backgroundName, bg)
		Widgets.Tint(bar.barEdge.track, "barTrack", bg)
	end
	local border = Settings.Get("cast.border")
	if (not border or plate.castBare) and bar.barEdge then
		plate.castBare = not border
		bar.barEdge:SetShown(border)
	end
	if Settings.Get("cast.important") and not plate.castImportantFill then
		plate.castImportantFill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
		plate.castImportantFill:SetColorTexture(Tokens.Color("white"))
		plate.castImportantFill:SetAllPoints(bar:GetStatusBarTexture())
		plate.castImportantFill:SetAlpha(0)
		plate.castFillOn = false
	end
	if Settings.Get("cast.importantGlow") then
		local glow = plate.castImportantGlow
		if not glow then
			glow = Widgets.NineSlice(cast, "shadow", "BACKGROUND", -8)
			for _, piece in ipairs(glow) do piece:SetBlendMode("ADD") end
			Widgets.ShowSlice(glow, false)
			plate.castImportantGlow, plate.castGlowOn = glow, false
		end
		Widgets.LayoutSlice(glow, bar, GLOW_CORNER, GLOW_OUTSET)
		Widgets.ColorSlice(glow, Rgb(Settings.Get("cast.importantColor")))
	end
	if plate.castImportantGlow and not Settings.Get("cast.importantGlow") and plate.castGlowOn ~= false then
		Widgets.ShowSlice(plate.castImportantGlow, false)
		plate.castGlowOn = false
	end
	if Settings.Get("cast.targetGlow") then
		local glow = plate.castTargetGlow
		if not glow then
			glow = Widgets.NineSlice(cast, "shadow", "BACKGROUND", -7)
			for _, piece in ipairs(glow) do piece:SetBlendMode("ADD") end
			Widgets.ShowSlice(glow, false)
			plate.castTargetGlow, plate.castAtMeOn = glow, false
		end
		Widgets.LayoutSlice(glow, bar, GLOW_CORNER, GLOW_OUTSET)
		Widgets.ColorSlice(glow, Rgb(Settings.Get("cast.targetGlowColor")))
	elseif plate.castTargetGlow and plate.castAtMeOn ~= false then
		Widgets.ShowSlice(plate.castTargetGlow, false)
		plate.castAtMeOn = false
	end
	StyleFont(plate.castName, "caps")
	StyleFont(plate.castTime, "time")
	if plate.castWait then StyleFont(plate.castWait, "time") end
	local glyph = plate.castGlyph
	glyph:SetShown(Settings.Get("cast.combatCues"))
	local glyphSize = math.max(h, 11)
	Widgets.Size(glyph, glyphSize, glyphSize)
	glyph:ClearAllPoints()
	glyph:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, Widgets.Snap(plate, (Widgets.Snap(plate, glyphSize) - Widgets.Snap(plate, h)) / 2))
	local align = Settings.Get("cast.nameAlign")
	local aligned = align ~= "LEFT" or plate.castAligned
	plate.castAligned = align ~= "LEFT"
	plate.castName:ClearAllPoints()
	if aligned then plate.castName:SetJustifyH(align) end
	if Settings.Get("cast.nameBelow") then
		ns.Plate.Place(plate.castName, "TOPLEFT", bar, "BOTTOMLEFT", 0, -GAP, state.width, Settings.Get("cast.textSize"))
		if align ~= "LEFT" or plate.castWide then plate.castName:SetWidth(align == "LEFT" and 0 or Widgets.Snap(plate, opts.width)) end
		plate.castWide = align ~= "LEFT"
	else
		ns.Plate.Place(plate.castName, "LEFT", bar, "LEFT", TEXT_INSET, 0, nil, nil, nil, Widgets.Snap(plate, h))
		plate.castName:SetPoint("RIGHT", plate.castTime, "LEFT", -Widgets.Snap(plate, GAP), 0)
	end
	plate.castTime:ClearAllPoints()
	ns.Plate.Place(plate.castTime, "RIGHT", bar, "RIGHT", -TEXT_INSET, 0, nil, nil, nil, Widgets.Snap(plate, h))
	local place = Settings.Get("cast.showTarget") and Settings.Get("cast.targetPlace") or ""
	local own = place ~= ""
	plate.castTargetOwn = own
	if own or plate.castTarget then
		local text = plate.castTarget or Widgets.FontString(bar, "OVERLAY")
		plate.castTarget = text
		ShowTarget(plate)
		if own then
			text:SetWordWrap(false)
			text:SetJustifyH(place)
			StyleFont(text, "caps")
			text:ClearAllPoints()
			ns.Plate.Place(text, "LEFT", bar, "LEFT", TEXT_INSET + (Settings.Get("cast.combatCues") and glyphSize or 0), 0, nil, nil, nil, Widgets.Snap(plate, h))
			if Settings.Get("cast.showTime") then
				text:SetPoint("RIGHT", plate.castTime, "LEFT", -Widgets.Snap(plate, GAP), 0)
			else
				ns.Plate.Place(text, "RIGHT", bar, "RIGHT", -TEXT_INSET, 0, nil, nil, nil, Widgets.Snap(plate, h))
			end
		end
	end
	if plate.castWho then PlaceWho(plate) end
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
	plate.castAtMe, plate.castAtMeOn = Settings.Get("cast.targetGlow") and sample.atMe or nil, nil
	local target = plate.castAtMe and UnitName("player") or sample.target
	Cast.Name(plate, K.Locale.Upper(sample.text), Settings.Get("cast.showTarget") and not WhoPlace(plate) and target or nil)
	SetWho(plate, WhoRoom(plate) and sample.target or nil, sample.targetClass, sample.atMe)
	plate.castTime:SetText(sample.time)
	plate.castTime:SetShown(Settings.Get("cast.showTime"))
	plate.castBar:SetBarRange(0, 1)
	plate.castBar:SetValue(sample.progress)
	plate.castFlag, plate.castImportant, plate.castGlowOn = sample.notInterruptible, sample.important, nil
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
		Cast.Start(plate, false, true)
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
Component.events.UNIT_SPELLCAST_FAILED = function(plate, _, castGUID)
	if not OtherCast(plate, castGUID) then
		Cast.Stop(plate, Settings.Get("cast.outcomes"), true)
	end
end
Component.events.UNIT_SPELLCAST_CHANNEL_STOP = function(plate, _, _, _, interruptedBy)
	if plate.castChannel or not plate.casting then
		Cast.Stop(plate, type(interruptedBy) ~= "nil", nil, interruptedBy)
	end
end
Component.events.UNIT_SPELLCAST_INTERRUPTED = function(plate, _, _, _, interruptedBy)
	Cast.Stop(plate, true, nil, interruptedBy)
end
Component.events.UNIT_SPELLCAST_INTERRUPTIBLE = function(plate)
	Cast.SetInterruptible(plate, true)
end
Component.events.UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(plate)
	Cast.SetInterruptible(plate, false)
end
