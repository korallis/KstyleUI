-- CastEffects.lua: the Medallions cast flash: when a cast lands or stops the bar washes steel or red and a light streak runs along it, clipped to the bar, through the shared effects layer so it obeys the Medallions motion level.
local _, ns = ...

local K = KstyleUI
local Tokens = K.Tokens

local CastEffects = {}
ns.CastEffects = CastEffects

local STREAK_SHARE, STREAK_RUN = 0.35, 0.25

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

local function Streak(cb)
	local holder = cb.medStreak
	if holder then
		return holder
	end
	cb.flash:SetClipsChildren(true)
	holder = CreateFrame("Frame", nil, cb.flash)
	holder:SetAllPoints(cb.flash)
	local streak = holder:CreateTexture(nil, "OVERLAY")
	streak:SetTexture((K.Effects.Texture("medCombatSweep", "barSheen")))
	streak:SetBlendMode("ADD")
	streak:SetAlpha(0)
	local group = streak:CreateAnimationGroup()
	local move = group:CreateAnimation("Translation")
	move:SetDuration(STREAK_RUN)
	move:SetSmoothing("IN_OUT")
	local rise = group:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(STREAK_RUN / 2)
	local fall = group:CreateAnimation("Alpha")
	fall:SetFromAlpha(1)
	fall:SetToAlpha(0)
	fall:SetStartDelay(STREAK_RUN / 2)
	fall:SetDuration(STREAK_RUN / 2)
	group:SetScript("OnFinished", function()
		streak:SetAlpha(0)
		if ns.CastBars.Outcomes() then cb.flash:Hide() end
	end)
	holder.streak, holder.anim, holder.move, holder.rise, holder.fall = streak, group, move, rise, fall
	cb.medStreak = holder
	cb.medStop = function()
		group:Stop()
		streak:SetAlpha(0)
		cb.flash.group:Stop()
		cb.flash:Hide()
	end
	return holder
end

function CastEffects.Flash(cb, colorName, alpha)
	local effects = K.Effects
	if not effects then
		return false
	end
	if not (effects.Allows("flare") and cb.frame:IsShown()) then
		return true
	end
	local holder = Streak(cb)
	local on = ns.CastBars.Outcomes()
	local seconds = on and 0.35 or Tokens.Duration("pressIn") + Tokens.Duration("readyFlash")
	local run = on and 0.35 or STREAK_RUN
	holder.move:SetDuration(run)
	holder.rise:SetDuration(run / 2)
	holder.fall:SetStartDelay(run / 2)
	holder.fall:SetDuration(run / 2)
	if not effects.ClaimFor(cb, effects.PRIORITY.cast, seconds, cb.medStop) then
		return true
	end
	local r, g, b
	if colorName == "hostile" then
		r, g, b = Tokens.Color("hostile")
	else
		r, g, b = Color(on and "white" or "steelLit", "textEmphasis")
	end
	cb.flash.wash:SetVertexColor(r, g, b, alpha)
	cb.flash:Show()
	cb.flash.group:Stop()
	cb.flash.group:Play()
	local width, height = cb.bar:GetWidth(), cb.bar:GetHeight()
	if IsSecret(width) or IsSecret(height) or type(width) ~= "number" or width <= 0 then
		return true
	end
	local streak, length = holder.streak, width * STREAK_SHARE
	streak:SetVertexColor(r, g, b, on and 0.6 or 1)
	streak:SetSize(length, height)
	streak:ClearAllPoints()
	streak:SetPoint("RIGHT", holder, "LEFT", 0, 0)
	holder.move:SetOffset(width + length, 0)
	holder.anim:Stop()
	holder.anim:Play()
	return true
end
