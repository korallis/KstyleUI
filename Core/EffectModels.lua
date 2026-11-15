-- EffectModels.lua: the Medallions 3D effects: a pool of at most three live ModelScenes, each larger than its effect so it never clips, paused and hidden when idle and rebuilt after a reload; a model plays only at the Full motion level, and the caller's 2D twin plays instead when the pool is full, the file was refused, or it has not loaded in time (twice for a file means it is not tried again).
local _, ns = ...

local Effects = ns.Effects

local CAP = 3
local MARGIN = 1.6
local LOAD_GRACE, MISSES = 0.5, 2
local FADE_IN, FADE_OUT = 0.1, 0.3
local DISTANCE = 4
local PAD = 2

Effects.MODEL_CAP, Effects.MODEL_MARGIN, Effects.MODEL_GRACE = CAP, MARGIN, LOAD_GRACE

Effects.MODELS = {
	levelUp = 166464,
	levelUpBlue = 340883,
	DRUID = 166604,
	HUNTER = 166027,
	MAGE = 166014,
	PALADIN = 166334,
	PRIEST = 166338,
	ROGUE = 166808,
	SHAMAN = 534877,
	WARLOCK = 166071,
	WARRIOR = 166120,
	frost = 5855149,
}

local pool = {}
local failed, misses = {}, {}
local clock = 0

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Idle(scene)
	scene.busy, scene.priority, scene.fallback, scene.place = false, nil, nil, nil
	scene.fade:Stop()
	scene.actor:ClearModel()
	scene:SetPaused(true)
	scene:Hide()
end

local function Check(scene)
	scene.waiting = scene.waiting - 1
	if scene.waiting > 0 or not scene.busy then
		return
	end
	local loaded = scene.actor:IsLoaded()
	if IsSecret(loaded) or loaded then
		return
	end
	local file = scene.file
	misses[file] = (misses[file] or 0) + 1
	failed[file] = misses[file] >= MISSES or nil
	local fallback, place, priority, seconds = scene.fallback, scene.place, scene.priority, scene.seconds
	Idle(scene)
	if place then
		Effects.ClaimFor(place, priority, seconds, Effects.Stopper(place))
	end
	if fallback then
		fallback()
	end
end

local function NewScene()
	if type(CreateFrame) ~= "function" then
		return nil
	end
	local scene = CreateFrame("ModelScene", nil, UIParent)
	if not (scene and scene.CreateActor and scene.SetPaused) then
		return nil
	end
	scene:Hide()
	local ok, actor = pcall(scene.CreateActor, scene, nil, "ModelSceneActorTemplate")
	if not (ok and actor) then
		ok, actor = pcall(scene.CreateActor, scene)
	end
	if not (ok and actor) then
		return nil
	end
	scene.actor = actor
	scene:SetCameraPosition(-DISTANCE, 0, 0)
	scene:SetCameraOrientationByYawPitchRoll(0, 0, 0)
	actor:SetPosition(0, 0, 0)
	actor:SetUseCenterForOrigin(true, true, true)
	local fade = scene:CreateAnimationGroup()
	local rise = fade:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(FADE_IN)
	rise:SetOrder(1)
	local fall = fade:CreateAnimation("Alpha")
	fall:SetFromAlpha(1)
	fall:SetToAlpha(0)
	fall:SetDuration(FADE_OUT)
	fall:SetOrder(2)
	fade.fall = fall
	fade:SetScript("OnFinished", function()
		Idle(scene)
	end)
	scene.fade = fade
	scene.waiting = 0
	scene.check = function()
		Check(scene)
	end
	scene.busy = false
	return scene
end

local function Pick(priority)
	local free, worst
	for i = 1, CAP do
		local scene = pool[i]
		if not scene then
			scene = NewScene()
			if not scene then
				return nil
			end
			pool[i] = scene
		end
		if not scene.busy then
			free = free or scene
		elseif not worst or scene.priority > worst.priority or (scene.priority == worst.priority and scene.started < worst.started) then
			worst = scene
		end
	end
	if free then
		return free
	end
	if worst and worst.priority >= priority then
		local fallback = worst.fallback
		Idle(worst)
		if fallback then
			fallback()
		end
		return worst
	end
end

function Effects.LiveModels()
	local n = 0
	for i = 1, #pool do
		if pool[i].busy then
			n = n + 1
		end
	end
	return n
end

function Effects.ModelFailed(key)
	local file = Effects.MODELS[key]
	return file == nil or failed[file] == true
end

function Effects.Model(anchor, key, size, seconds, priority, fallback, place)
	local file = Effects.MODELS[key]
	if not (file and not failed[file] and Effects.Allows("model") and anchor and anchor:IsVisible()) then
		return false
	end
	local scene = Pick(priority)
	if not scene then
		return false
	end
	local actor = scene.actor
	if actor:SetModelByFileID(file) == false then
		failed[file] = true
		return false
	end
	clock = clock + 1
	scene.busy, scene.priority, scene.started, scene.file, scene.seconds = true, priority, clock, file, seconds
	scene.fallback, scene.place = fallback, place
	local side = size * MARGIN
	scene:SetParent(anchor)
	scene:SetFrameStrata(anchor:GetFrameStrata())
	scene:SetFrameLevel(anchor:GetFrameLevel() + PAD)
	scene:ClearAllPoints()
	scene:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	scene:SetSize(side, side)
	actor:SetAlpha(1)
	scene:SetPaused(false)
	scene.fade.fall:SetStartDelay(math.max(0, seconds - FADE_IN - FADE_OUT))
	scene:Show()
	scene.fade:Stop()
	scene.fade:Play()
	scene.waiting = scene.waiting + 1
	C_Timer.After(LOAD_GRACE, scene.check)
	return true
end

function Effects.StopModels(place, twins)
	for i = 1, #pool do
		local scene = pool[i]
		if scene.busy and (place == nil or scene.place == place) then
			local fallback = scene.fallback
			Idle(scene)
			if twins and fallback then
				fallback()
			end
		end
	end
end

local stoppers, stop2Ds = {}, {}

function Effects.Stopper(place)
	local stop = stoppers[place]
	if not stop then
		stop = function()
			Effects.StopModels(place)
			local own = stop2Ds[place]
			if own then
				own()
			end
		end
		stoppers[place] = stop
	end
	return stop
end

function Effects.Burst(place, priority, anchor, key, size, seconds, play2D, stop2D)
	if not Effects.Allows("flare") then
		return false
	end
	if not Effects.ClaimFor(place, priority, seconds, Effects.Stopper(place)) then
		return false
	end
	stop2Ds[place] = stop2D
	if Effects.Model(anchor, key, size, seconds, priority, play2D, place) then
		return "model"
	end
	if play2D then
		play2D()
	end
	return "2d"
end

ns.Callbacks.Register("EffectsLevelChanged", "EffectModels", function()
	if not Effects.Allows("model") then
		Effects.StopModels(nil, Effects.Allows("flare"))
	end
end)
ns.Callbacks.Register("HudStyleChanged", "EffectModels", function(_, style)
	if style ~= "medallions" then
		Effects.StopModels()
	end
end)
