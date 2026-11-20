-- Aids.lua: the crosshair at the screen centre and the ring around the mouse pointer, each shown by its rule (always, in combat, in instances or in instance combat) and redrawn only when a setting or that state changes. The ring's OnUpdate, a reviewed exception to the no-per-frame rule, exists only while the ring is on and shown: one pointer read a frame, and a move only when the pointer moved.
local _, ns = ...

local K = ns.K
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER = "QoL.aids"
local WIDTHS = { thin = 1, normal = 2, thick = 4 }
local RING = 32
local CROSS_ALPHA = 0.75

local cross, ring
local fighting, instanced = false, false

local function Shown(mode)
	return mode == "always" or mode == "combat" and fighting or mode == "instances" and instanced or mode == "instancesCombat" and fighting and instanced
end

function ns.BuildCrosshair(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.hb, frame.vb = frame:CreateTexture(nil, "BACKGROUND"), frame:CreateTexture(nil, "BACKGROUND")
	frame.h, frame.v = frame:CreateTexture(nil, "ARTWORK"), frame:CreateTexture(nil, "ARTWORK")
	return frame
end

function ns.PaintCrosshair(frame)
	local base = WIDTHS[ns.Get("crosshair")] or WIDTHS.normal
	local hw, vw, edge = ns.Get("crosshairHWidth"), ns.Get("crosshairVWidth"), K.Scale.Pixel(ns.Get("crosshairBorder"))
	hw, vw = K.Scale.Pixel(hw > 0 and hw or base), K.Scale.Pixel(vw > 0 and vw or base)
	local hl, vl = ns.Get("crosshairHLength"), ns.Get("crosshairVLength")
	local r, g, b = Tokens.Color("textEmphasis")
	frame.h:SetColorTexture(r, g, b, CROSS_ALPHA)
	frame.v:SetColorTexture(r, g, b, CROSS_ALPHA)
	frame.hb:SetColorTexture(Tokens.Color("textShadow"))
	frame.vb:SetColorTexture(Tokens.Color("textShadow"))
	Widgets.Size(frame.h, hl, hw)
	Widgets.Size(frame.v, vw, vl)
	Widgets.Size(frame.hb, hl + 2 * edge, hw + 2 * edge)
	Widgets.Size(frame.vb, vw + 2 * edge, vl + 2 * edge)
	frame.hb:SetShown(edge > 0)
	frame.vb:SetShown(edge > 0)
	Widgets.Size(frame, math.max(hl, vw) + 2 * edge, math.max(vl, hw) + 2 * edge)
	for _, bar in ipairs({ frame.hb, frame.vb, frame.h, frame.v }) do Widgets.Point(bar, "CENTER", frame, "CENTER", 0, 0) end
end

function ns.PaintRing(texture, dim)
	local r, g, b = ns.NoticeColor("cursor")
	texture:SetTexture((Tokens.Texture("ring")))
	texture:SetVertexColor(r, g, b, ns.Get("cursorOpacity") / 100 * (dim or 1))
	local size = RING * ns.Get("cursorScale") / 100
	Widgets.Size(texture, size, size)
end

local function Follow(self)
	local x, y = GetCursorPosition()
	if ns.IsSecret(x) or ns.IsSecret(y) or x == self.x and y == self.y then return end
	self.x, self.y = x, y
	local scale = self:GetEffectiveScale()
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function Visible()
	if cross then cross:SetShown(ns.running and ns.Get("crosshair") ~= "none" and Shown(ns.Get("crosshairShow"))) end
	if ring then
		local shown = ns.running and ns.Get("cursorRing") and Shown(ns.Get("cursorShow")) or false
		ring.x = nil
		ring:SetShown(shown)
		ring:SetScript("OnUpdate", shown and Follow or nil)
	end
end

local function Paint()
	if ns.running and ns.Get("crosshair") ~= "none" then
		if not cross then
			cross = ns.BuildCrosshair(K.Scale.Root())
			cross:SetFrameStrata("BACKGROUND")
		end
		ns.PaintCrosshair(cross)
		cross:ClearAllPoints()
		Widgets.Point(cross, "CENTER", K.Scale.Root(), "CENTER", ns.Get("crosshairX"), ns.Get("crosshairY"))
	end
	if ns.running and ns.Get("cursorRing") and type(GetCursorPosition) == "function" then
		if not ring then
			ring = CreateFrame("Frame", nil, K.Scale.Root())
			ring:SetFrameStrata("TOOLTIP")
			ring.texture = ring:CreateTexture(nil, "OVERLAY")
			ring.texture:SetPoint("CENTER")
			Widgets.Size(ring, 1, 1)
		end
		ns.PaintRing(ring.texture)
	end
end

local function State()
	instanced, fighting = ns.Ask(IsInInstance) == true, ns.Ask(InCombatLockdown) == true
	Visible()
end

local function Fight(event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Visible()
end

function ns.AidFrames()
	return cross, ring
end

local EVENTS = { PLAYER_REGEN_DISABLED = Fight, PLAYER_REGEN_ENABLED = Fight, PLAYER_ENTERING_WORLD = State, ZONE_CHANGED_NEW_AREA = State }

local function Sync()
	local on = ns.running and (ns.Get("crosshair") ~= "none" or ns.Get("cursorRing"))
	for event, fn in pairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
	end
	if on then
		Paint()
		State()
	elseif cross or ring then
		Visible()
	end
end

ns.AddPart({
	name = "aids",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and (key:find("^crosshair") or key:find("^cursor")) then Sync() end
	end,
})
