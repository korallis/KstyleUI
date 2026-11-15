-- EffectBursts.lua: the Medallions one-shot effects the core owns: the class-motif burst behind the player's medallion on a level-up (a 3D model at Full, its 2D twin otherwise), and the motion of the target bracket glows on enemy plates, which fade in and then breathe at Full.
local _, ns = ...

local Effects = ns.Effects

local OWNER = "EffectBursts"
local GLOW_IN, GLOW_BREATH, GLOW_LOW = 0.18, 1.2, 0.5

Effects.GLOW_IN, Effects.GLOW_BREATH = GLOW_IN, GLOW_BREATH

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function GlowParts(t)
	if t.medGlowIn then
		return
	end
	local rise = t:CreateAnimationGroup()
	local a = rise:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(1)
	a:SetDuration(GLOW_IN)
	a:SetSmoothing("OUT")
	rise:SetToFinalAlpha(true)
	local breath = t:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local b = breath:CreateAnimation("Alpha")
	b:SetFromAlpha(1)
	b:SetToAlpha(GLOW_LOW)
	b:SetDuration(GLOW_BREATH)
	b:SetStartDelay(GLOW_IN)
	b:SetSmoothing("IN_OUT")
	t.medGlowIn, t.medBreath = rise, breath
end

function Effects.TargetGlow(glows)
	if type(glows) ~= "table" or not Effects.Active() then
		return false
	end
	local flare, pulse = Effects.Allows("flare"), Effects.Allows("pulse")
	for _, t in ipairs(glows) do
		GlowParts(t)
		t.medGlowIn:Stop()
		t.medBreath:Stop()
		t:SetAlpha(1)
		if pulse then
			t.medBreath:Play()
		end
		if flare then
			t.medGlowIn:Play()
		end
	end
	return flare
end

ns.Events.Register(OWNER, "PLAYER_LEVEL_UP", function()
	local medallion = Effects.playerMedallion
	if not (medallion and Effects.Active()) then
		return
	end
	local _, class = UnitClass("player")
	medallion:Burst(not IsSecret(class) and class or nil)
end)
