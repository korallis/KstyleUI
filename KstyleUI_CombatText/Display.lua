-- Display.lua: emitters, one per place that shows numbers, and Spawn, which styles, places and animates one number from the emitter's pool.
local _, ns = ...

local K = KstyleUI
local Tokens = K.Tokens
local Format = ns.Format

local Display = {}
ns.Display = Display

local LANES = { 0, -1, 1 }
local FIELD_LANE = 0.25
local FIELD_ARC = 0.35
local FIELD_START = 0.6
local FIELD_HEADROOM = 1.2
local FRAME_LANE = 1.6
local FRAME_ARC = 0.7
local TOP_START = 0.6
local GROUP_TRAVEL = 0.6
local ARC_APEX = 0.45
local ARC_RISE, ARC_FALL = 0.5, 0.8
local POP_FROM, CRIT_POP_FROM, POP_TIME = 1.8, 1.35, 0.18
local POP_DRIFT = 0.3
local FADE_SHARE = 0.35
local OFF_FADE = 0.05
local LEVEL_BOOST = 20
local MAX_LEVEL = 9000
local MIN_FOLLOW, MAX_FOLLOW = 0.25, 4
local DEFAULT_STRATA = "MEDIUM"
local MOVE_SMOOTHING, FALL_SMOOTHING = "OUT", "IN"
local FOLLOWS = { unit = true, group = true }

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Plain(v, default)
	if IsSecret(v) or type(v) ~= "number" or v ~= v then
		return default
	end
	return v
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log("CombatText", message)
	end
end

function Display.NewEmitter(frame, kind, pool)
	return { frame = frame, kind = kind, pool = pool, active = {}, lane = 0, side = 1 }
end

function Display.Clear(emitter)
	local active, pool = emitter.active, emitter.pool
	while #active > 0 do
		pool:Release(active[#active])
	end
end

local function ApplyFont(text, cfg)
	if text:SetFont(cfg.fontPath, cfg.size, cfg.flags) == false then
		local fallback = Tokens.Font("number")
		text:SetFont(fallback, cfg.size, cfg.flags)
		LogOnce("font:" .. cfg.fontPath, "the font " .. cfg.fontPath .. " did not load; numbers use " .. tostring(fallback))
	end
	if cfg.shadow then
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowColor(Tokens.Color("textShadow"))
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
end

local function Layer(number, anchor)
	local strata = anchor:GetFrameStrata()
	if IsSecret(strata) or type(strata) ~= "string" or strata == "" then
		strata = DEFAULT_STRATA
	end
	local level = Plain(anchor:GetFrameLevel(), 0)
	number.frame:SetFrameStrata(strata)
	number.frame:SetFrameLevel(math.min(MAX_LEVEL, level + LEVEL_BOOST))
end

local function Follow(emitter)
	if not FOLLOWS[emitter.kind] then
		return 1
	end
	local own = Plain(emitter.frame:GetEffectiveScale(), 0)
	local base = Plain(emitter.pool.parent:GetEffectiveScale(), 0)
	if own <= 0 or base <= 0 then
		LogOnce("follow", "a frame's scale could not be read; its numbers keep their own size")
		return 1
	end
	return math.min(MAX_FOLLOW, math.max(MIN_FOLLOW, own / base))
end

local function Opacity(emitter)
	if emitter.kind == "field" then
		return 1
	end
	local frame = emitter.frame
	if type(frame.GetEffectiveAlpha) ~= "function" then
		return 1
	end
	local ok, alpha = pcall(frame.GetEffectiveAlpha, frame)
	if not ok then
		LogOnce("alpha", "a frame's opacity could not be read; its numbers show at full opacity")
		return 1
	end
	if IsSecret(alpha) then
		return alpha
	end
	if type(alpha) ~= "number" or alpha ~= alpha then
		return 1
	end
	return math.min(1, math.max(0, alpha))
end

local function NextLane(emitter)
	local lane = LANES[emitter.lane % #LANES + 1]
	emitter.lane = emitter.lane + 1
	return lane
end

local function FieldGeometry(emitter, cfg)
	local frame = emitter.frame
	local width = Plain(frame:GetWidth(), 0)
	local height = Plain(frame:GetHeight(), 0)
	local size = cfg.size
	local x = NextLane(emitter) * width * FIELD_LANE
	local distance = math.max(0, height - size * (FIELD_START + FIELD_HEADROOM))
	return "BOTTOM", x, size * FIELD_START, distance, width * FIELD_ARC, 1
end

local function FrameGeometry(emitter, cfg)
	local size, sizeScale, travel = cfg.size, 1, cfg.distance
	if emitter.kind == "group" then
		size = cfg.groupSize
		sizeScale = cfg.groupSize / cfg.size
		travel = travel * GROUP_TRAVEL
	end
	local point = cfg.framePoint
	local y = point == "TOP" and size * TOP_START or 0
	return point, NextLane(emitter) * size * FRAME_LANE, y, travel, travel * FRAME_ARC, sizeScale
end

local function Animate(number, emitter, cfg, emphasis, per, distance, spread)
	local duration = cfg.duration
	local level = K.Motion.Level()
	local dx1, dy1, dx2, dy2, from = 0, 0, 0, 0, 1
	local moveTime, fallDelay, fallTime = duration, 0, duration
	if level == "full" then
		local style = cfg.style
		if style == "arc" then
			local side = emitter.side
			emitter.side = -side
			local half = spread * 0.5 * side
			dx1, dy1 = half, distance * ARC_RISE
			dx2, dy2 = half, -distance * ARC_FALL
			moveTime = duration * ARC_APEX
			fallDelay, fallTime = moveTime, duration - moveTime
		elseif style == "pop" then
			dy1 = distance * POP_DRIFT
			from = POP_FROM
		else
			dy1 = distance
		end
		if emphasis == "crit" and cfg.critScale > 1 and from < CRIT_POP_FROM then
			from = CRIT_POP_FROM
		end
	end
	local move, fall, pop, fade = number.move, number.fall, number.pop, number.fade
	move:SetOffset(dx1 * per, dy1 * per)
	move:SetDuration(moveTime)
	move:SetSmoothing(MOVE_SMOOTHING)
	fall:SetOffset(dx2 * per, dy2 * per)
	fall:SetStartDelay(fallDelay)
	fall:SetDuration(fallTime)
	fall:SetSmoothing(FALL_SMOOTHING)
	pop:SetScaleFrom(from, from)
	pop:SetDuration(POP_TIME)
	pop:SetSmoothing(MOVE_SMOOTHING)
	if level == "off" then
		fade:SetStartDelay(duration - OFF_FADE)
		fade:SetDuration(OFF_FADE)
	else
		fade:SetStartDelay(duration * (1 - FADE_SHARE))
		fade:SetDuration(duration * FADE_SHARE)
	end
end

function Display.Spawn(emitter, cfg, kind, emphasis, amount, word, school)
	local pool, active = emitter.pool, emitter.active
	while #active >= cfg.maxPerFrame do
		pool:Release(active[1])
	end
	local number = pool:Acquire()
	number.emitter = emitter
	active[#active + 1] = number
	local text = number.text
	if number.fontKey ~= cfg.fontKey then
		ApplyFont(text, cfg)
		number.fontKey = cfg.fontKey
	end
	Format.Text(text, cfg, kind, amount, word)
	text:SetTextColor(Format.Color(cfg, kind, emphasis, school))
	text:SetAlpha(Opacity(emitter))
	local point, x, y, distance, spread, sizeScale
	if emitter.kind == "field" then
		point, x, y, distance, spread, sizeScale = FieldGeometry(emitter, cfg)
	else
		point, x, y, distance, spread, sizeScale = FrameGeometry(emitter, cfg)
	end
	local follow = Follow(emitter)
	local scale = Format.Scale(cfg, emphasis) * sizeScale * follow
	local per = follow / scale
	local frame = number.frame
	Layer(number, emitter.frame)
	frame:SetScale(scale)
	frame:SetAlpha(1)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", emitter.frame, point, x * per, y * per)
	Animate(number, emitter, cfg, emphasis, per, distance, spread)
	frame:Show()
	number.group:Play()
	return number
end
