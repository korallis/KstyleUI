-- Vignette.lua: the Medallions screen-edge low-health vignette: a crimson frame around the screen, under the whole interface, whose alpha is the player's health through a curve (no threshold in Lua), breathing at the Full motion level and still at Calm, shown only under the Medallions style and never while dead.
local _, ns = ...

local Effects = ns.Effects

local Vignette = {}
Effects.Vignette = Vignette

local OWNER = "Vignette"
Vignette.FULL, Vignette.CLEAR = 0.12, 0.4
Vignette.BREATH, Vignette.LOW = 0.8, 0.6
Vignette.EDGE = 0.22
local EDGE_ALPHA = 0.45

local frame, curve, logged

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Curve()
	if curve then
		return curve
	end
	local util = C_CurveUtil
	if not (util and type(util.CreateCurve) == "function" and UnitHealthPercent) then
		if not logged then
			logged = true
			ns.DevTest.Log(OWNER, "C_CurveUtil.CreateCurve or UnitHealthPercent is missing; the low-health vignette stays off")
		end
		return nil
	end
	curve = util.CreateCurve()
	curve:AddPoint(0, 1)
	curve:AddPoint(Vignette.FULL, 1)
	curve:AddPoint(Vignette.CLEAR, 0)
	curve:AddPoint(1, 0)
	return curve
end

local function Edge(point, relative, horizontal, from, to)
	local t = frame.layer:CreateTexture(nil, "BACKGROUND")
	t:SetColorTexture(ns.Tokens.Color("white"))
	t:SetPoint(point, frame.layer, point)
	t:SetPoint(relative, frame.layer, relative)
	local r, g, b = ns.Tokens.Color("healthLow")
	if type(CreateColor) == "function" and t.SetGradient then
		t:SetGradient(horizontal and "HORIZONTAL" or "VERTICAL", CreateColor(r, g, b, from), CreateColor(r, g, b, to))
	else
		t:SetVertexColor(r, g, b, 0.3)
	end
	return t
end

local function Build()
	local parent = WorldFrame or UIParent
	frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetFrameLevel(0)
	frame:SetAllPoints(parent)
	frame:EnableMouse(false)
	frame:Hide()
	frame.layer = CreateFrame("Frame", nil, frame)
	frame.layer:SetAllPoints(frame)
	local path, own = Effects.Texture("medVignette")
	if own then
		local t = frame.layer:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(path)
		t:SetBlendMode("ADD")
		t:SetAllPoints(frame.layer)
		frame.art = { t }
	else
		frame.art = {}
	end
	frame.fallback = not own
	local breath = frame.layer:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local alpha = breath:CreateAnimation("Alpha")
	alpha:SetFromAlpha(1)
	alpha:SetToAlpha(Vignette.LOW)
	alpha:SetDuration(Vignette.BREATH)
	alpha:SetSmoothing("IN_OUT")
	frame.breath = breath
	frame:HookScript("OnHide", function()
		breath:Stop()
	end)
	frame:HookScript("OnShow", Vignette.Update)
	Vignette.frame = frame
end

local function Edges()
	if frame.edges or not frame.fallback then
		return
	end
	frame.edges = true
	local height = UIParent:GetHeight()
	local band = (not IsSecret(height) and type(height) == "number" and height or 768) * Vignette.EDGE
	local top = Edge("TOPLEFT", "TOPRIGHT", false, 0, EDGE_ALPHA)
	top:SetHeight(band)
	local bottom = Edge("BOTTOMLEFT", "BOTTOMRIGHT", false, EDGE_ALPHA, 0)
	bottom:SetHeight(band)
	local left = Edge("TOPLEFT", "BOTTOMLEFT", true, EDGE_ALPHA, 0)
	left:SetWidth(band)
	local right = Edge("TOPRIGHT", "BOTTOMRIGHT", true, 0, EDGE_ALPHA)
	right:SetWidth(band)
	frame.art = { top, bottom, left, right }
end

local function Dead()
	local dead = UnitIsDeadOrGhost("player")
	return not IsSecret(dead) and dead == true
end

function Vignette.Update()
	local c = Effects.Active() and Curve()
	if not c or Dead() then
		if frame then
			frame.breath:Stop()
			frame:Hide()
		end
		return
	end
	if not frame then
		Build()
		Edges()
	end
	frame:SetAlpha(UnitHealthPercent("player", true, c))
	frame:Show()
	local visible = frame:IsVisible()
	if IsSecret(visible) then
		visible = true
	end
	if visible and Effects.Allows("pulse") then
		if not frame.breath:IsPlaying() then
			frame.breath:Play()
		end
	else
		frame.breath:Stop()
	end
end

local function OnHealth()
	if frame and frame:IsShown() then
		frame:SetAlpha(UnitHealthPercent("player", true, curve))
	end
end

local LIFE = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
local listening = false

local function Listen()
	local active = Effects.Active()
	if active ~= listening then
		listening = active
		if active then
			ns.Events.RegisterUnit(OWNER, "UNIT_HEALTH", OnHealth, "player")
			ns.Events.RegisterUnit(OWNER, "UNIT_MAXHEALTH", OnHealth, "player")
			for _, event in ipairs(LIFE) do
				ns.Events.Register(OWNER, event, Vignette.Update)
			end
		else
			ns.Events.Unregister(OWNER, "UNIT_HEALTH")
			ns.Events.Unregister(OWNER, "UNIT_MAXHEALTH")
			for _, event in ipairs(LIFE) do
				ns.Events.Unregister(OWNER, event)
			end
		end
	end
	Vignette.Update()
end

ns.Events.Register(OWNER, "PLAYER_ENTERING_WORLD", Listen)
ns.Callbacks.Register("HudStyleChanged", OWNER, Listen)
ns.Callbacks.Register("ProfileChanged", OWNER, Listen)
ns.Callbacks.Register("EffectsLevelChanged", OWNER, Vignette.Update)
