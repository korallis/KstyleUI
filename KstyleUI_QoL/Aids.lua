-- Aids.lua: the crosshair at the screen centre, and the ring around the mouse pointer with its centre dot, trail and the cast circle that fills as the player casts, each shown by its rule and redrawn only when a setting or that state changes. The pointer frame's OnUpdate, a reviewed exception to the no-per-frame rule, exists only while the ring or a cast circle on the pointer shows: one pointer read a frame, a move only when the pointer moved, and trail moves only until the trail settles.
local _, ns = ...

local K = ns.K
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER = "QoL.aids"
local WIDTHS = { thin = 1, normal = 2, thick = 4 }
local RING, DOT, CAST, TRAIL = 32, 6, 1.5, 6
local CROSS_ALPHA = 0.75
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }
local LOOK_EVENTS = { PLAYER_STARTED_LOOKING = true, PLAYER_STOPPED_LOOKING = false, PLAYER_STARTED_TURNING = true, PLAYER_STOPPED_TURNING = false }

local cross, ring, cast
local fighting, instanced, casting = false, false, false
local looking = {}

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

local function Tint(texture, file, base, dim)
	local r, g, b = ns.NoticeColor("cursor")
	texture:SetTexture((Tokens.Texture(file)))
	texture:SetVertexColor(r, g, b, ns.Get("cursorOpacity") / 100 * (dim or 1))
	local size = base * ns.Get("cursorScale") / 100
	Widgets.Size(texture, size, size)
end

function ns.PaintRing(texture, dim)
	Tint(texture, ns.Get("cursorTexture"), RING, dim)
end

function ns.PaintDot(texture, dim)
	Tint(texture, "dot", DOT, dim)
end

function ns.BuildCast(parent)
	local frame = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	frame:SetDrawBling(false)
	frame:SetHideCountdownNumbers(true)
	frame:SetUseCircularEdge(true)
	return frame
end

function ns.PaintCast(frame, dim)
	local r, g, b = ns.NoticeColor("cursor")
	local size = RING * CAST * ns.Get("cursorScale") / 100
	Widgets.Size(frame, size, size)
	frame:SetSwipeTexture((Tokens.Texture(ns.Get("cursorTexture"))))
	frame:SetSwipeColor(r, g, b, ns.Get("cursorOpacity") / 100 * (dim or 1))
	frame:SetDrawEdge(ns.Get("castSpark"))
end

local function Trail(self, x, y)
	local xs, ys, settled = self.xs, self.ys, true
	for i = TRAIL + 1, 2, -1 do xs[i], ys[i] = xs[i - 1] or x, ys[i - 1] or y end
	xs[1], ys[1] = x, y
	for i, dot in ipairs(self.trail) do
		local away = xs[i + 1] ~= x or ys[i + 1] ~= y
		settled = settled and not away
		dot:SetShown(away)
		if away then
			dot:ClearAllPoints()
			dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", xs[i + 1], ys[i + 1])
		end
	end
	self.settling = not settled
end

local function Follow(self)
	local x, y = GetCursorPosition()
	if ns.IsSecret(x) or ns.IsSecret(y) then return end
	local moved = x ~= self.x or y ~= self.y
	if not (moved or self.settling) then return end
	local scale = self:GetEffectiveScale()
	if moved then
		self.x, self.y = x, y
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end
	if self.trailOn then Trail(self, x / scale, y / scale) end
end

local function Looking()
	return next(looking) ~= nil
end

local function Visible()
	if cross then cross:SetShown(ns.running and ns.Get("crosshair") ~= "none" and Shown(ns.Get("crosshairShow"))) end
	if cast then cast:SetShown(ns.running and ns.Get("castRing") and casting) end
	if ring then
		local shown = ns.running and ns.Get("cursorRing") and Shown(ns.Get("cursorShow")) and (not ns.Get("cursorHidden") or Looking())
		local follow = shown or cast ~= nil and cast:IsShown() and ns.Get("castAttach")
		ring.texture:SetShown(shown)
		ring.dot:SetShown(shown and ns.Get("cursorDot"))
		ring.trailOn = shown and ns.Get("cursorTrail")
		ring.x, ring.settling = nil, false
		for i, dot in ipairs(ring.trail) do
			dot:Hide()
			ring.xs[i], ring.ys[i] = nil, nil
		end
		ring:SetShown(follow)
		ring:SetScript("OnUpdate", follow and Follow or nil)
	end
end

local function Pointer()
	if not ring then
		ring = CreateFrame("Frame", nil, K.Scale.Root())
		ring:SetFrameStrata("TOOLTIP")
		ring.texture = ring:CreateTexture(nil, "OVERLAY")
		ring.texture:SetPoint("CENTER")
		ring.dot = ring:CreateTexture(nil, "OVERLAY")
		ring.dot:SetPoint("CENTER")
		ring.trail, ring.xs, ring.ys = {}, {}, {}
		for i = 1, TRAIL do ring.trail[i] = ring:CreateTexture(nil, "ARTWORK") end
		Widgets.Size(ring, 1, 1)
	end
	ns.PaintRing(ring.texture)
	ns.PaintDot(ring.dot)
	for i, dot in ipairs(ring.trail) do ns.PaintDot(dot, 1 - i / (TRAIL + 1)) end
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
	local pointer = type(GetCursorPosition) == "function"
	if ns.running and pointer and (ns.Get("cursorRing") or ns.Get("castRing")) then Pointer() end
	if ns.running and ns.Get("castRing") then
		if not cast then
			cast = ns.BuildCast(K.Scale.Root())
			cast:SetFrameStrata("TOOLTIP")
			cast:Hide()
		end
		ns.PaintCast(cast)
		cast:ClearAllPoints()
		if pointer and ns.Get("castAttach") then Widgets.Point(cast, "CENTER", ring, "CENTER", 0, 0) else Widgets.Point(cast, "CENTER", K.Scale.Root(), "CENTER", 0, 0) end
	end
end

local function Info(api)
	if type(api) == "function" then
		local _, _, _, start, finish = api("player")
		return ns.Number(start), ns.Number(finish)
	end
end

local function Cast()
	local start, finish = Info(UnitCastingInfo)
	local channel = start == nil
	if channel then start, finish = Info(UnitChannelInfo) end
	casting = start ~= nil and finish ~= nil and finish > start
	if cast and casting then
		cast:SetReverse(not channel)
		cast:SetCooldown(start / 1000, (finish - start) / 1000)
	elseif cast then
		cast:Clear()
	end
	Visible()
end

local function State()
	instanced, fighting = ns.Ask(IsInInstance) == true, ns.Ask(InCombatLockdown) == true
	Visible()
end

local function Fight(event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Visible()
end

local function Look(event)
	looking[event:find("LOOKING") and "look" or "turn"] = LOOK_EVENTS[event] or nil
	Visible()
end

function ns.AidFrames()
	return cross, ring, cast
end

local EVENTS = { PLAYER_REGEN_DISABLED = Fight, PLAYER_REGEN_ENABLED = Fight, PLAYER_ENTERING_WORLD = State, ZONE_CHANGED_NEW_AREA = State }

local function Sync()
	local on = ns.running and (ns.Get("crosshair") ~= "none" or ns.Get("cursorRing") or ns.Get("castRing"))
	for event, fn in pairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, fn) else K.Events.Unregister(OWNER, event) end
	end
	local look = ns.running and ns.Get("cursorRing") and ns.Get("cursorHidden")
	for event in pairs(LOOK_EVENTS) do
		if look then K.Events.Register(OWNER, event, Look) else K.Events.Unregister(OWNER, event) end
	end
	if not look then looking = {} end
	local casts = ns.running and ns.Get("castRing")
	for _, event in ipairs(CAST_EVENTS) do
		if casts then K.Events.RegisterUnit(OWNER, event, Cast, "player") else K.Events.Unregister(OWNER, event) end
	end
	if on then
		Paint()
		if casts then Cast() else casting = false end
		State()
	elseif cross or ring or cast then
		Visible()
	end
end

ns.AddPart({
	name = "aids",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and (key:find("^crosshair") or key:find("^cursor") or key:find("^cast")) then Sync() end
	end,
})
