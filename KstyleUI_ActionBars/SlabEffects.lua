-- SlabEffects.lua: the Medallions action effects beside the slab and hub: a steel ready flash on a slot when its cooldown ends, yielding to a proc on that slot; the hub's rune ring brightening while the player's resource is capped, its alpha a UnitPowerPercent curve so Lua never compares the value; a class-motif 3D model at the hub on a proc and the level-up rays over the hub's 2D burst, through the shared model pool.
local _, ns = ...

local K = KstyleUI
local Effects, Tokens, Widgets = K.Effects, K.Tokens, K.Widgets
local P = Effects.PRIORITY

local Fx = {}
ns.SlabEffects = Fx

local OWNER = "SlabEffects"
local READY, READY_RISE = 0.3, 0.25
local READY_SHARE = 1 / 0.7
local CAP_AT = 0.995
local CAP_LOW, CAP_BREATH, CAP_HALO = 0.55, 1.1, 1.3
local PROC_SECONDS, PROC_SHARE = 0.9, 1
local LEVEL_SECONDS, LEVEL_SHARE = 1.2, 1.6
local SECONDARY = { PALADIN = "HolyPower", WARLOCK = "SoulShards" }

Fx.READY, Fx.CAP_AT = READY, CAP_AT

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Color(name, fallback)
	local ok, r, g, b = pcall(Tokens.Color, name)
	if ok then
		return r, g, b
	end
	return Tokens.Color(fallback)
end

local function SlotSize(b)
	local size = b:GetWidth()
	if IsSecret(size) or type(size) ~= "number" or size <= 0 then
		return Tokens.Size("actionButton")
	end
	return size
end

local function Fade(group, from, to, duration, order)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order)
	return a
end

local function ReadyParts(b)
	local flash = b.medReady
	if not flash then
		flash = b.overlay:CreateTexture(nil, "OVERLAY", nil, 5)
		flash:SetTexture((Effects.Texture("medReadyFlash", "glow")))
		flash:SetBlendMode("ADD")
		flash:SetPoint("CENTER", b, "CENTER", 0, 0)
		flash:SetAlpha(0)
		local group = flash:CreateAnimationGroup()
		Fade(group, 0, 1, READY * READY_RISE, 1)
		Fade(group, 1, 0, READY * (1 - READY_RISE), 2)
		group:SetScript("OnFinished", function()
			flash:SetAlpha(0)
		end)
		flash.anim = group
		flash.stop = function()
			group:Stop()
			flash:SetAlpha(0)
		end
		b.medReady = flash
	end
	local side = SlotSize(b) * READY_SHARE
	Widgets.Size(flash, side, side)
	return flash
end

function Fx.Ready(b)
	if not Effects.Active() then
		return false
	end
	if not Effects.Allows("flare") or b.proc then
		return true
	end
	local flash = ReadyParts(b)
	if not Effects.ClaimFor(b, P.ready, READY, flash.stop) then
		return true
	end
	flash:SetVertexColor(Color("steelLit", "textEmphasis"))
	flash.anim:Stop()
	flash.anim:Play()
	return true
end

function Fx.SlotProc(b, on)
	if on then
		b.medProcToken = Effects.Claim(b, P.proc, nil)
	elseif b.medProcToken then
		Effects.Release(b, b.medProcToken)
		b.medProcToken = nil
	end
end

local cap = {}
local capCurve, logged

local function CapCurve()
	if capCurve then
		return capCurve
	end
	local util = C_CurveUtil
	if not (util and type(util.CreateCurve) == "function" and UnitPowerPercent) then
		if not logged then
			logged = true
			K.DevTest.Log(OWNER, "C_CurveUtil.CreateCurve or UnitPowerPercent is missing; the hub ring does not brighten at a resource cap")
		end
		return nil
	end
	capCurve = util.CreateCurve()
	local kinds = Enum and Enum.LuaCurveType
	if kinds and kinds.Step and capCurve.SetType then
		capCurve:SetType(kinds.Step)
	end
	capCurve:AddPoint(0, 0)
	capCurve:AddPoint(CAP_AT, 1)
	capCurve:AddPoint(1, 1)
	return capCurve
end

function Fx.PowerType()
	if type(UnitPowerType) ~= "function" then
		return nil
	end
	local kind, token = UnitPowerType("player")
	if IsSecret(kind) or IsSecret(token) or type(kind) ~= "number" then
		return nil
	end
	if token ~= "MANA" then
		return kind
	end
	local _, class = UnitClass("player")
	local name = not IsSecret(class) and SECONDARY[class]
	local types = Enum and Enum.PowerType
	return name and types and types[name] or nil
end

local function BuildCap(hub)
	local frame = CreateFrame("Frame", nil, hub)
	frame:SetAllPoints(hub)
	frame:SetFrameLevel(hub:GetFrameLevel() + 1)
	frame.inner = CreateFrame("Frame", nil, frame)
	frame.inner:SetAllPoints(frame)
	local halo = frame.inner:CreateTexture(nil, "BACKGROUND")
	halo:SetTexture((Effects.Texture("glow")))
	halo:SetBlendMode("ADD")
	halo:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local glyphs = frame.inner:CreateTexture(nil, "ARTWORK")
	glyphs:SetTexture((Effects.Texture("medRuneGlyphs", "ring")))
	glyphs:SetBlendMode("ADD")
	glyphs:SetAllPoints(frame)
	frame.halo, frame.glyphs = halo, glyphs
	local breath = frame.inner:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local a = Fade(breath, 1, CAP_LOW, CAP_BREATH, 1)
	a:SetSmoothing("IN_OUT")
	frame.breath = breath
	frame:Hide()
	cap.frame = frame
	return frame
end

local Listen

local function HideCap()
	Listen(false)
	local frame = cap.frame
	if frame then
		frame.breath:Stop()
		frame:Hide()
	end
	cap.power = nil
end

function Fx.UpdateCap()
	local slab = ns.Slab
	local hub = slab and slab.hub
	local curve = CapCurve()
	local power = Fx.PowerType()
	if not (hub and hub:IsShown() and Effects.Active() and curve and power) then
		HideCap()
		return
	end
	local frame = cap.frame or BuildCap(hub)
	local ring = slab.RING or hub:GetWidth()
	Widgets.Size(frame.halo, ring * CAP_HALO, ring * CAP_HALO)
	local _, class = UnitClass("player")
	local c = not IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	local r, g, b = Color("steelLit", "textEmphasis")
	if c then
		r, g, b = c.r, c.g, c.b
	end
	frame.halo:SetVertexColor(r, g, b, 1)
	frame.glyphs:SetVertexColor(r, g, b, 1)
	cap.power = power
	Listen(true)
	frame:SetAlpha(UnitPowerPercent("player", power, false, curve))
	frame:Show()
	if Effects.Allows("pulse") then
		if not frame.breath:IsPlaying() then
			frame.breath:Play()
		end
	else
		frame.breath:Stop()
	end
end

function Fx.OnPower()
	local frame, power = cap.frame, cap.power
	if frame and power and frame:IsShown() then
		frame:SetAlpha(UnitPowerPercent("player", power, false, capCurve))
	end
end

local function ClassFile()
	local _, class = UnitClass("player")
	if IsSecret(class) then
		return nil
	end
	return class
end

function Fx.Proc(hub)
	if not (hub and Effects.Active()) then
		return false
	end
	local class = ClassFile()
	return Effects.Burst("hub", P.proc, hub, class or "", (ns.Slab.RING or hub:GetWidth()) * PROC_SHARE, PROC_SECONDS, nil, nil)
end

function Fx.LevelUp(hub, play2D, stop2D)
	if not (hub and Effects.Active()) then
		if play2D then
			play2D()
		end
		return false
	end
	if play2D and Effects.Allows("flare") then
		play2D()
	end
	return Effects.Burst("hub", P.levelUp, hub, "levelUp", (ns.Slab.RING or hub:GetWidth()) * LEVEL_SHARE, LEVEL_SECONDS, nil, stop2D)
end

local listening = false

function Listen(on)
	if on == listening then
		return
	end
	listening = on
	if on then
		K.Events.RegisterUnit(OWNER, "UNIT_POWER_UPDATE", Fx.OnPower, "player")
		K.Events.RegisterUnit(OWNER, "UNIT_MAXPOWER", Fx.OnPower, "player")
		K.Events.RegisterUnit(OWNER, "UNIT_DISPLAYPOWER", Fx.UpdateCap, "player")
	else
		K.Events.UnregisterAll(OWNER)
	end
end

function Fx.Enable()
	K.Callbacks.Register("EffectsLevelChanged", OWNER, Fx.UpdateCap)
	Fx.UpdateCap()
end

function Fx.Disable()
	K.Callbacks.Unregister("EffectsLevelChanged", OWNER)
	HideCap()
end
