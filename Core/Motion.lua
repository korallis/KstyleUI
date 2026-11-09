-- Motion.lua: easing functions, AnimationGroup presets and the pooled tween driver.
local _, ns = ...

local Motion = {}
ns.Motion = Motion

local Tokens = ns.Tokens
local sin, cos, pi = math.sin, math.cos, math.pi
local BACK = 1.70158

local Ease = {}
Motion.Ease = Ease

local function Clamp(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t
end

function Ease.linear(t)
	return Clamp(t)
end

function Ease.outSine(t)
	return sin(Clamp(t) * pi / 2)
end

function Ease.inOutSine(t)
	return (1 - cos(pi * Clamp(t))) / 2
end

function Ease.outQuad(t)
	local u = 1 - Clamp(t)
	return 1 - u * u
end

function Ease.outCubic(t)
	local u = 1 - Clamp(t)
	return 1 - u * u * u
end

function Ease.outQuart(t)
	local u = 1 - Clamp(t)
	return 1 - u * u * u * u
end

function Ease.outQuint(t)
	local u = 1 - Clamp(t)
	return 1 - u * u * u * u * u
end

function Ease.outBack(t)
	local u = Clamp(t) - 1
	return 1 + (BACK + 1) * u * u * u + BACK * u * u
end

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local logged = {}
local function LogOnce(key, message)
	if logged[key] then
		return
	end
	logged[key] = true
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, "Motion", message)
	end
end

local function Report(err)
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	end
end

local function Call(setter, obj, value)
	if type(setter) == "string" then
		obj[setter](obj, value)
	else
		setter(obj, value)
	end
end

local function ResolveEase(easing)
	if easing == nil then
		return Ease.outQuad
	elseif type(easing) == "function" then
		return easing
	end
	local fn = Ease[easing]
	if not fn then
		error("KstyleUI.Motion: unknown easing " .. tostring(easing), 3)
	end
	return fn
end

local active, byHandle, pool = {}, {}, {}
local lastHandle, frameCount = 0, 0
local LEVELS = { full = true, reduced = true, off = true }
local level = "full"
local driver

local function IndexOf(rec)
	for i = 1, #active do
		if active[i] == rec then
			return i
		end
	end
end

local function Release(rec)
	local i = IndexOf(rec)
	if i then
		local n = #active
		active[i] = active[n]
		active[n] = nil
	end
	byHandle[rec.handle] = nil
	rec.obj, rec.setter, rec.onDone, rec.ease = nil, nil, nil, nil
	pool[#pool + 1] = rec
end

local function StopDriverIfIdle()
	if driver and #active == 0 then
		driver:SetScript("OnUpdate", nil)
	end
end

local function Finish(obj, setter, to, onDone)
	local ok, err = pcall(Call, setter, obj, to)
	if not ok then
		Report(err)
	end
	if onDone then
		ok, err = pcall(onDone, obj)
		if not ok then
			Report(err)
		end
	end
end

local function Advance(rec, t)
	Call(rec.setter, rec.obj, rec.from + (rec.to - rec.from) * rec.ease(t))
end

local function Step(_, elapsed)
	frameCount = frameCount + 1
	local i = #active
	while i > 0 do
		local rec = active[i]
		if rec and rec.stamp ~= frameCount then
			rec.stamp = frameCount
			rec.elapsed = rec.elapsed + elapsed
			local t = rec.elapsed / rec.duration
			if t >= 1 then
				local obj, setter, to, onDone = rec.obj, rec.setter, rec.to, rec.onDone
				Release(rec)
				Finish(obj, setter, to, onDone)
			else
				local handle = rec.handle
				local ok, err = pcall(Advance, rec, t)
				if not ok then
					if byHandle[handle] == rec then
						Release(rec)
					end
					Report(err)
				end
			end
		end
		i = i - 1
		if i > #active then
			i = #active
		end
	end
	StopDriverIfIdle()
end

local function Find(obj, setter)
	for i = 1, #active do
		local rec = active[i]
		if rec.obj == obj and rec.setter == setter then
			return rec
		end
	end
end

function Motion.Tween(obj, setter, from, to, duration, easing, onDone)
	local ease = ResolveEase(easing)
	local existing = Find(obj, setter)
	if existing then
		Release(existing)
	end
	local secret = IsSecret(from) or IsSecret(to)
	if secret then
		LogOnce("secret", "a tween got a secret value and set it without easing")
	end
	if level == "off" or secret or IsSecret(duration) or type(duration) ~= "number" or duration ~= duration or duration <= 0 then
		Finish(obj, setter, to, onDone)
		StopDriverIfIdle()
		return nil
	end
	if type(from) ~= "number" or type(to) ~= "number" then
		error("KstyleUI.Motion.Tween: from and to must be numbers", 2)
	end
	local ok, err = pcall(Call, setter, obj, from)
	if not ok then
		StopDriverIfIdle()
		error(err, 0)
	end
	existing = Find(obj, setter)
	if existing then
		Release(existing)
	end
	local rec = pool[#pool]
	if rec then
		pool[#pool] = nil
	else
		rec = {}
	end
	lastHandle = lastHandle + 1
	local handle = lastHandle
	rec.handle, rec.obj, rec.setter, rec.from, rec.to = handle, obj, setter, from, to
	rec.duration, rec.ease, rec.onDone, rec.elapsed, rec.stamp = duration, ease, onDone, 0, frameCount
	byHandle[handle] = rec
	active[#active + 1] = rec
	if not driver then
		driver = CreateFrame("Frame")
	end
	if not driver:GetScript("OnUpdate") then
		driver:SetScript("OnUpdate", Step)
	end
	return handle
end

function Motion.IsPlaying(handle)
	return byHandle[handle] ~= nil
end

function Motion.Stop(handle, finish)
	local rec = byHandle[handle]
	if not rec then
		return false
	end
	local obj, setter, to, onDone = rec.obj, rec.setter, rec.to, rec.onDone
	Release(rec)
	if finish then
		Finish(obj, setter, to, onDone)
	end
	StopDriverIfIdle()
	return true
end

function Motion.Level()
	return level
end

function Motion.SetLevel(name)
	if not LEVELS[name] then
		return false
	end
	level = name
	if name == "off" then
		while #active > 0 do
			Motion.Stop(active[#active].handle, true)
		end
	end
	return true
end

function Motion.ReducedMotion()
	return level ~= "full"
end

function Motion.SetReducedMotion(on)
	if type(on) ~= "boolean" then
		return false
	end
	return Motion.SetLevel(on and "off" or "full")
end

local restAlpha = setmetatable({}, { __mode = "k" })

local function MayToggle(frame)
	if not InCombatLockdown() then
		return true
	end
	local protected = frame:IsProtected()
	if IsSecret(protected) then
		return false
	end
	return not protected
end

function Motion.FadeIn(frame, duration, alpha)
	alpha = alpha or 1
	restAlpha[frame] = alpha
	local from = frame:GetAlpha()
	local shown = frame:IsShown()
	if IsSecret(shown) then
		LogOnce("shown", "a fade met a frame whose visibility is secret and changed its alpha only")
	elseif not shown then
		from = 0
		frame:SetAlpha(0)
		if MayToggle(frame) then
			frame:Show()
		end
	end
	return Motion.Tween(frame, "SetAlpha", from, alpha, duration or Tokens.Duration("panelOpen"), Tokens.Easing("panelOpen"))
end

local function Hidden(frame)
	if MayToggle(frame) then
		frame:Hide()
		frame:SetAlpha(restAlpha[frame] or 1)
	end
end

function Motion.FadeOut(frame, duration)
	local shown = frame:IsShown()
	local onDone = Hidden
	if IsSecret(shown) then
		LogOnce("shown", "a fade met a frame whose visibility is secret and changed its alpha only")
		onDone = nil
	elseif not shown then
		return nil
	end
	return Motion.Tween(frame, "SetAlpha", frame:GetAlpha(), 0, duration or Tokens.Duration("panelClose"), Tokens.Easing("panelClose"), onDone)
end
