-- clip.lua CLASS OUTDIR FPS FIRST LAST: a class's crest story as a clip, run from the repository root under the usual
-- RENDER_* environment; Tools/media/marketing.py draws the frames. The HUD boots once at the story's start; then each
-- frame moves the clock 1/FPS s, plays the story's new beats at their own times, runs what the client runs on its own
-- (C_Timer timers and tickers, a Cooldown's end, an aura's expiry, OnUpdate, an animation group's end and OnFinished)
-- and writes frames FIRST to LAST as OUTDIR/NNNN.json, the merged scene of every HUD module.
-- CLIP_TRACKERS=steel (or none) shows the crest without the class story; CLIP_HEALTH=from,to,seconds sets the target's
-- health line; CLIP_FX_AT starts RENDER_FX at that second instead of at the boot; CLIP_LAND lands the player's cast then.
local CLASS, OUT, FPS, FIRST, LAST = arg[1], arg[2], tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
local T, getenv = 0, os.getenv
local STORY = getenv("CLIP_TRACKERS") or "moment"
STORY = STORY ~= "none" and STORY or nil
local fxAt = tonumber(getenv("CLIP_FX_AT") or "")
rawset(os, "getenv", function(k)
	if k == "RENDER_TRACKERS" then return STORY end
	if k == "RENDER_TRACKERS_T" then return tostring(T) end
	if k == "RENDER_FX" and fxAt and T < fxAt then return nil end
	return getenv(k)
end)
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
-- hud.lua's own Scene, whose draw keys order the merge (Scene.Merge).
local Scene
for i = 1, math.huge do
	local name, value = debug.getupvalue(Hud.Build, i)
	if not name then break end
	if name == "Scene" then Scene = value end
end
local Trackers = dofile("Tools/render/scenes/_trackers.lua")
local Fx = dofile("Tools/render/scenes/_effects.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

-- The melee stories set their state from the time, so they replay only where it changes (_trackers.lua, Play).
local MELEE = { WARRIOR = { 0.5, 2.5, 3, 9 }, PALADIN = { 1, 2, 4 }, ROGUE = { 1, 6 } }
local HEALTH = { WARRIOR = { 0.62, 0.15, 9 }, DRUID = { 0.97, 0.82, 3 }, PRIEST = { 0.92, 0.6, 6 }, WARLOCK = { 1, 0.55, 6 } }

local opts = Hud.Options({ layout = "DPS", class = CLASS })
opts.trackerAnchor = Hud.StoryTracker(opts.layout, false)
-- Every module boots in the HUD's order, as Hud.Build composes it; only the unit frames and action bars move.
local scenes, live, nss = {}, {}, {}
for i, name in ipairs(Hud.Order()) do
	local scene, ns = Hud.Module(name, opts)
	scenes[i] = scene
	if name == "unitframes" then live[1], nss[1] = i, ns elseif name == "actionbars" then live[2], nss[2] = i, ns end
end
local envs = { Hud.envs[scenes[live[1]]], Hud.envs[scenes[live[2]]] }
local ufEnv, abEnv, ns = envs[1], envs[2], nss[2]
local base = {}

local function objects(env)
	local list = {}
	for _, f in ipairs(env._frames) do
		list[#list + 1] = f
		for _, r in ipairs(f._regions or {}) do list[#list + 1] = r end
	end
	return list
end

local function length(group)
	local orders, total = {}, 0
	for _, a in ipairs(group._anims or {}) do
		local s = a._state
		local o = s.Order and s.Order[1] or 1
		orders[o] = math.max(orders[o] or 0, (s.StartDelay and s.StartDelay[1] or 0) + (s.Duration and s.Duration[1] or 0) + (s.EndDelay and s.EndDelay[1] or 0))
	end
	for _, len in pairs(orders) do total = total + len end
	return total
end

-- The clip starts half a minute after login: groups the boot played on the stub's wall clock run from then.
for i, env in ipairs(envs) do
	base[i] = env._time
	env._clip, env._now = true, env._time
	for _, o in ipairs(objects(env)) do
		for _, g in ipairs(o._groups or {}) do
			if g._playedAt and g._playedAt > 1e6 then g._playedAt = env._time - 30 end
		end
	end
end
abEnv._clipFrom = 0

local function engine(env, dt)
	env.RunTimers()
	env.RunTickers()
	local list = objects(env)
	for _, o in ipairs(list) do
		if o._type == "Cooldown" then
			local _, left = Scene.CooldownFraction(env, o, env._time)
			if o._clipLeft and not left and o._clipLeft <= dt + 1e-6 then
				local done = o:GetScript("OnCooldownDone")
				if done then done(o) end
				env.FireEvent("SPELL_UPDATE_COOLDOWN")
			end
			o._clipLeft = left
		end
	end
	for unit, auras in pairs(env._slotAuras or {}) do
		local kept = {}
		for _, a in ipairs(auras) do
			if not (a.duration and a.start and a.start + a.duration <= env._time) then kept[#kept + 1] = a end
		end
		if #kept < #auras then
			for i = #auras, 1, -1 do auras[i] = nil end
			for i, a in ipairs(kept) do auras[i] = a end
			Slots.Set(env, unit, auras)
			env.FireEvent("UNIT_AURA", unit, {})
		end
	end
	for _, o in ipairs(list) do
		local update = o._scripts and o._scripts.OnUpdate
		if update and o:IsVisible() then update(o, dt) end
	end
	for _, o in ipairs(objects(env)) do
		for _, g in ipairs(o._groups or {}) do
			local looping = g._state.Looping and g._state.Looping[1]
			if g._playedAt and looping ~= "REPEAT" and looping ~= "BOUNCE" and env._time >= g._playedAt + length(g) then
				g._playedAt = nil
				if g._state.ToFinalAlpha and g._state.ToFinalAlpha[1] then
					for _, a in ipairs(g._anims or {}) do
						if a._type == "Alpha" and a._state.ToAlpha then
							local target = a._state.Target and a._state.Target[1] or g._parent
							target:SetAlpha(a._state.ToAlpha[1])
						end
					end
				end
				local finished = g._scripts and g._scripts.OnFinished
				if finished then finished(g, false) end
			end
		end
	end
end

local melee = MELEE[CLASS]
local health = HEALTH[CLASS] or { 0.8, 0.5, 6 }
local hf, ht, hs = (getenv("CLIP_HEALTH") or ""):match("^([%d.]+),([%d.]+),([%d.]+)$")
if hf then health = { tonumber(hf), tonumber(ht), tonumber(hs) } end
local land = tonumber(getenv("CLIP_LAND") or "")
for k = 0, LAST do
	local prev, now = T, k / FPS
	if k > 0 then
		if STORY == "moment" and melee then
			for _, c in ipairs(melee) do
				if c > prev and c <= now then
					T, abEnv._time = c, base[2] + c
					abEnv._now = abEnv._time
					Trackers.Play(abEnv, abEnv.KstyleUI, ns, {})
					abEnv._clipFrom = c
				end
			end
		end
		T = now
		for i, env in ipairs(envs) do
			env._time = base[i] + now
			env._now = env._time
		end
		if STORY == "moment" and not melee then
			Trackers.Play(abEnv, abEnv.KstyleUI, ns, {})
			abEnv._clipFrom, abEnv._now = now, abEnv._time
		end
		abEnv._story = now
		if fxAt and fxAt > prev and fxAt <= now then
			Fx.Apply(ufEnv, "unitframes", nss[1], {})
			Fx.Apply(abEnv, "actionbars", ns, {})
		end
		if land and land > prev and land <= now then abEnv.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player") end
		-- The target loses health as the story runs (hud.lua, modules.unitframes), a hit each second.
		local target = ufEnv._units and ufEnv._units.target
		local hp = target and math.floor(target.healthMax * (health[1] + (health[2] - health[1]) * math.min(1, math.floor(now) / health[3])))
		if hp and hp ~= target.health then
			target.health = hp
			ufEnv.FireEvent("UNIT_HEALTH", "target")
		end
		for _, env in ipairs(envs) do engine(env, now - prev) end
	end
	if k >= FIRST then
		for i, env in ipairs(envs) do
			scenes[live[i]] = Scene.Build(env, { iconDirs = Common.IconDirs(), time = env._time })
		end
		local f = assert(io.open(string.format("%s/%04d.json", OUT, k), "wb"))
		f:write(Scene.ToJSON(Scene.Merge(scenes, Hud.Style() ~= "Frames")))
		f:close()
	end
end
