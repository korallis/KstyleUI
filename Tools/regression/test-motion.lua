-- test-motion.lua: Penner easings, one pooled tween driver that stops when idle and allocates nothing per frame, fades and reduced motion.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end

local function NewMotion()
	local env = Stubs.NewEnv()
	local errors = {}
	env.geterrorhandler = function()
		return function(err)
			errors[#errors + 1] = err
		end
	end
	Load(core, env)
	return env, env.KstyleUI, errors
end

-- The frames whose OnUpdate is set: the tween driver while it runs.
local function updating(env)
	local out = {}
	for _, frame in ipairs(env._frames) do
		if frame:GetScript("OnUpdate") then
			out[#out + 1] = frame
		end
	end
	return out
end

local function tick(env, dt)
	for _, frame in ipairs(updating(env)) do
		frame:GetScript("OnUpdate")(frame, dt)
	end
end

local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-9)
end

local function setV(obj, v)
	obj.v = v
end

-- Easings -------------------------------------------------------------------------------------------

do
	local _, ns = NewMotion()
	local Ease = ns.Motion.Ease
	local NAMES = { "linear", "outSine", "inOutSine", "outQuad", "outQuart", "outQuint", "outBack" }
	for _, name in ipairs(NAMES) do
		local f = assert(Ease[name], "Ease." .. name .. " exists")
		assert(near(f(0), 0) and near(f(1), 1), name .. " runs from 0 to 1")
		assert(near(f(-0.5), 0) and near(f(1.5), 1), name .. " clamps t to 0..1")
	end
	assert(near(Ease.linear(0.3), 0.3), "linear")
	assert(near(Ease.outSine(0.5), math.sin(math.pi / 4)), "outSine")
	assert(near(Ease.inOutSine(0.5), 0.5) and near(Ease.inOutSine(0.25), (1 - math.cos(math.pi / 4)) / 2), "inOutSine")
	assert(near(Ease.outQuad(0.5), 0.75), "outQuad")
	assert(near(Ease.outQuart(0.5), 0.9375), "outQuart")
	assert(near(Ease.outQuint(0.5), 0.96875), "outQuint")
	local peak = 0
	for i = 0, 100 do
		peak = math.max(peak, Ease.outBack(i / 100))
	end
	assert(peak > 1.05 and peak < 1.15, "outBack overshoots by about 10%, got " .. peak)
	for _, name in ipairs(NAMES) do
		if name ~= "outBack" then
			for i = 1, 100 do
				assert(Ease[name](i / 100) >= Ease[name]((i - 1) / 100) - 1e-12, name .. " never goes backwards")
			end
		end
	end
end

-- One tween -----------------------------------------------------------------------------------------

do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	assert(#updating(env) == 0, "no OnUpdate runs at load")
	local obj, done = { v = -1 }, 0
	local handle = Motion.Tween(obj, setV, 0, 10, 1, "linear", function(o)
		assert(o == obj, "onDone gets the object")
		done = done + 1
	end)
	assert(handle and Motion.IsPlaying(handle), "Tween returns a playing handle")
	assert(obj.v == 0, "the start value is set at once")
	assert(#updating(env) == 1, "the driver runs while a tween plays")
	tick(env, 0.5)
	assert(near(obj.v, 5), "halfway through a linear tween the value is halfway")
	tick(env, 0.25)
	assert(near(obj.v, 7.5))
	tick(env, 5) -- a long hitch finishes the tween without overshooting
	assert(obj.v == 10 and done == 1, "the end value is exact and onDone runs once")
	assert(not Motion.IsPlaying(handle), "a finished handle is not playing")
	assert(#updating(env) == 0, "the driver removes its OnUpdate when idle")
	tick(env, 1)
	assert(done == 1, "onDone never runs twice")

	-- A method name works as the setter, and easing defaults to outQuad.
	local frame = env.CreateFrame("Frame")
	Motion.Tween(frame, "SetAlpha", 0, 1, 1)
	tick(env, 0.5)
	assert(near(frame:GetAlpha(), 0.75), "the default easing is outQuad")
	tick(env, 1)
	assert(frame:GetAlpha() == 1)
	assert(not pcall(Motion.Tween, obj, setV, 0, 1, 1, "outBounce"), "an unknown easing is an error")
	Motion.Tween(obj, setV, 0, 1, 1, function(t)
		return t * t
	end)
	tick(env, 0.5)
	assert(near(obj.v, 0.25), "an easing can be a function")
	tick(env, 1)
end

-- Many tweens share one driver. A new tween on the same object and setter replaces the old one.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local objs = {}
	for i = 1, 10 do
		objs[i] = { v = 0 }
		Motion.Tween(objs[i], setV, 0, i, 1, "linear")
	end
	assert(#updating(env) == 1, "ten tweens use one driver frame")
	local first, replaced = { v = 0 }, false
	local h1 = Motion.Tween(first, setV, 0, 100, 1, "linear", function()
		replaced = true
	end)
	tick(env, 0.5)
	local h2 = Motion.Tween(first, setV, 50, 0, 1, "linear")
	assert(not Motion.IsPlaying(h1) and Motion.IsPlaying(h2), "the new tween replaces the old one")
	tick(env, 1)
	assert(first.v == 0 and not replaced, "a replaced tween never finishes or calls onDone")
	assert(objs[10].v == 10, "the other tweens finished")
	assert(#updating(env) == 0)

	-- Stop, with and without finishing. A stale handle never touches the tween that reuses its slot.
	local obj, done = { v = 0 }, 0
	local h = Motion.Tween(obj, setV, 0, 1, 1, "linear", function()
		done = done + 1
	end)
	tick(env, 0.5)
	assert(Motion.Stop(h) == true and done == 0 and near(obj.v, 0.5), "Stop leaves the value and skips onDone")
	assert(Motion.Stop(h) == false, "stopping twice does nothing")
	h = Motion.Tween(obj, setV, 0, 1, 1, "linear", function()
		done = done + 1
	end)
	assert(Motion.Stop(h, true) == true and obj.v == 1 and done == 1, "Stop(handle, true) jumps to the end and calls onDone")
	local other = { v = 0 }
	local fresh = Motion.Tween(other, setV, 0, 1, 1, "linear")
	assert(Motion.Stop(h) == false and Motion.IsPlaying(fresh), "a stale handle does not stop a newer tween")
	Motion.Stop(fresh)
	assert(#updating(env) == 0, "stopping the last tween removes the OnUpdate")
end

-- A callback that starts or stops tweens while the driver runs.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local a, b, c = { v = 0 }, { v = 0 }, { v = 0 }
	local hc = Motion.Tween(c, setV, 0, 1, 2, "linear")
	Motion.Tween(b, setV, 0, 1, 2, "linear")
	Motion.Tween(a, setV, 0, 1, 1, "linear", function()
		Motion.Stop(hc)
		Motion.Tween(a, setV, 1, 0, 1, "linear")
	end)
	tick(env, 1)
	assert(a.v == 1 and not Motion.IsPlaying(hc), "onDone may stop another tween and start a new one")
	tick(env, 0.5)
	assert(near(a.v, 0.5) and near(b.v, 0.75), "each tween advanced once per frame")
	tick(env, 1)
	assert(a.v == 0 and b.v == 1 and #updating(env) == 0)
end

-- A setter that errors is reported and dropped, and the other tweens carry on.
do
	local env, ns, errors = NewMotion()
	local Motion = ns.Motion
	local good = { v = 0 }
	local h = Motion.Tween({}, function(_, v)
		if v > 0 then
			error("broken setter")
		end
	end, 0, 1, 1, "linear")
	Motion.Tween(good, setV, 0, 1, 1, "linear")
	tick(env, 0.5)
	assert(#errors == 1 and tostring(errors[1]):find("broken setter"), "the error reaches the game's error handler")
	assert(not Motion.IsPlaying(h), "a failing tween is dropped")
	tick(env, 1)
	assert(good.v == 1 and #errors == 1 and #updating(env) == 0, "the other tween finished")
end

-- Re-entry and failures inside the setter or the easing never corrupt the driver.
do
	local env, ns, errors = NewMotion()
	local Motion = ns.Motion

	-- A setter that stops its own tween and then fails: the record goes back to the pool once.
	local selfStop = {}
	local h
	h = Motion.Tween(selfStop, function(_, v)
		if v > 0 then
			Motion.Stop(h)
			error("stopped myself")
		end
	end, 0, 1, 1, "linear")
	tick(env, 0.5)
	assert(#errors == 1 and not Motion.IsPlaying(h), "the failing tween is gone")
	local p, q = { v = 0 }, { v = 0 }
	local hp = Motion.Tween(p, setV, 0, 1, 1, "linear")
	local hq = Motion.Tween(q, setV, 0, 2, 1, "linear")
	assert(hp ~= hq and Motion.IsPlaying(hp) and Motion.IsPlaying(hq))
	tick(env, 0.5)
	assert(near(p.v, 0.5) and near(q.v, 1), "two new tweens each have their own record")
	tick(env, 1)

	-- A start value that starts another tween: each call returns its own handle.
	local inner = { v = 0 }
	local hInner
	local outer = { v = 0 }
	local hOuter = Motion.Tween(outer, function(o, v)
		o.v = v
		if not hInner then
			hInner = Motion.Tween(inner, setV, 0, 1, 1, "linear")
		end
	end, 0, 1, 1, "linear")
	assert(hOuter ~= hInner, "the outer tween gets its own handle")
	assert(Motion.Stop(hOuter) and Motion.IsPlaying(hInner), "stopping the outer tween leaves the inner one")
	Motion.Stop(hInner)

	-- A start value that fails: the error reaches the caller and nothing is left registered.
	local before = #errors
	local ok = pcall(Motion.Tween, {}, function()
		error("no start")
	end, 0, 1, 1, "linear")
	assert(not ok, "Tween raises the setter's error")
	assert(#updating(env) == 0, "a tween that failed to start leaves no driver running")
	local later = { v = 0 }
	Motion.Tween(later, setV, 0, 1, 1, "linear")
	tick(env, 2)
	assert(later.v == 1 and #updating(env) == 0 and #errors == before, "the driver still runs and idles")

	-- An easing that fails is dropped, and the other tweens advance.
	local steady = { v = 0 }
	Motion.Tween(steady, setV, 0, 1, 1, "linear")
	local hBad = Motion.Tween({ v = 0 }, setV, 0, 1, 1, function()
		error("bad easing")
	end)
	tick(env, 0.5)
	assert(not Motion.IsPlaying(hBad) and #errors == before + 1, "a failing easing is reported and dropped")
	assert(near(steady.v, 0.5), "the other tween advanced")
	tick(env, 1)
	assert(#updating(env) == 0)
end

-- Forever can answer IsShown, GetAlpha and IsProtected with a secret. Fades never branch on one.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local frame = env.CreateFrame("Frame")
	frame.IsShown = function()
		return env.Secret(true)
	end
	frame._calls = {}
	Motion.FadeIn(frame, 0.1)
	tick(env, 1)
	assert(frame:GetAlpha() == 1, "FadeIn still fades the alpha")
	Motion.FadeOut(frame, 0.1)
	tick(env, 1)
	assert(frame:GetAlpha() == 0, "FadeOut still fades the alpha")
	for _, call in ipairs(frame._calls) do
		assert(call.method ~= "Show" and call.method ~= "Hide", "no " .. call.method .. " when visibility is secret")
	end

	local guarded = env.CreateFrame("Button")
	guarded.IsProtected = function()
		return env.Secret(true)
	end
	guarded:Hide()
	env._combat = true
	guarded._calls = {}
	Motion.FadeIn(guarded, 0.1)
	tick(env, 1)
	for _, call in ipairs(guarded._calls) do
		assert(call.method ~= "Show", "a secret protection answer counts as protected")
	end
	env._combat = false
end

-- No allocation per frame.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local objs = {}
	for i = 1, 20 do
		objs[i] = { v = 0 }
		Motion.Tween(objs[i], setV, 0, 1, 100, "outBack")
	end
	local driver = updating(env)[1]
	local step = driver:GetScript("OnUpdate")
	step(driver, 0.01)
	-- LuaJIT's trace compiler allocates GC objects of its own. The game's Lua 5.1 has no JIT.
	local jit = rawget(_G, "jit")
	if jit then
		jit.off()
		jit.flush()
	end
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 1000 do
		step(driver, 0.01)
	end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then
		jit.on()
	end
	assert(grown == 0, "the driver allocated " .. grown .. " KB over 1000 frames")
	assert(near(objs[1].v, Motion.Ease.outBack(10.01 / 100), 1e-6), "the tweens advanced")
end

-- Fades.
do
	local env, ns = NewMotion()
	local Motion, Tokens = ns.Motion, ns.Tokens
	local frame = env.CreateFrame("Frame")
	frame:Hide()
	Motion.FadeIn(frame)
	assert(frame:IsShown() and frame:GetAlpha() == 0, "FadeIn shows a hidden frame at alpha 0")
	tick(env, Tokens.Duration("panelOpen") / 2)
	assert(frame:GetAlpha() > 0 and frame:GetAlpha() < 1)
	tick(env, Tokens.Duration("panelOpen"))
	assert(frame:GetAlpha() == 1, "FadeIn ends at alpha 1 after panelOpen seconds")

	Motion.FadeOut(frame)
	tick(env, Tokens.Duration("panelClose") / 2)
	assert(frame:IsShown(), "the frame stays shown while it fades out")
	tick(env, Tokens.Duration("panelClose"))
	assert(not frame:IsShown() and frame:GetAlpha() == 1, "FadeOut hides the frame and restores its alpha")

	-- A FadeIn during a FadeOut cancels the hide and starts from the current alpha.
	Motion.FadeIn(frame, 0.2, 0.8)
	tick(env, 1)
	Motion.FadeOut(frame, 0.4)
	tick(env, 0.2)
	local mid = frame:GetAlpha()
	Motion.FadeIn(frame, 0.2, 0.8)
	assert(frame:GetAlpha() == mid, "FadeIn continues from the current alpha")
	tick(env, 1)
	assert(frame:IsShown() and near(frame:GetAlpha(), 0.8), "the FadeOut's hide never runs, and FadeIn reaches its alpha")
	Motion.FadeOut(frame, 0.1)
	tick(env, 1)
	assert(not frame:IsShown() and near(frame:GetAlpha(), 0.8), "FadeOut restores the alpha FadeIn last aimed at")
	assert(Motion.FadeOut(frame) == nil, "FadeOut on a hidden frame does nothing")

	-- A protected frame in combat only fades: Show and Hide are protected calls.
	local secure = env.CreateFrame("Button")
	secure.IsProtected = function()
		return true, true
	end
	secure:Hide()
	env._combat = true
	secure._calls = {}
	Motion.FadeIn(secure, 0.1)
	tick(env, 1)
	Motion.FadeOut(secure, 0.1)
	tick(env, 1)
	for _, call in ipairs(secure._calls) do
		assert(call.method ~= "Show" and call.method ~= "Hide", "no " .. call.method .. " on a protected frame in combat")
	end
	env._combat = false
end

-- Reduced motion jumps to the end at once.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local obj, done = { v = 0 }, 0
	local running = Motion.Tween(obj, setV, 0, 1, 10, "linear", function()
		done = done + 1
	end)
	assert(Motion.ReducedMotion() == false, "motion is on by default")
	assert(Motion.SetReducedMotion(true) == true and Motion.ReducedMotion() == true)
	assert(obj.v == 1 and done == 1 and not Motion.IsPlaying(running), "switching motion off finishes running tweens")
	assert(Motion.Tween(obj, setV, 5, 9, 1, "linear", function()
		done = done + 1
	end) == nil, "under reduced motion Tween returns no handle")
	assert(obj.v == 9 and done == 2 and #updating(env) == 0, "it sets the end value and calls onDone at once")
	local frame = env.CreateFrame("Frame")
	frame:Hide()
	Motion.FadeIn(frame)
	assert(frame:IsShown() and frame:GetAlpha() == 1, "FadeIn shows at full alpha")
	Motion.FadeOut(frame)
	assert(not frame:IsShown(), "FadeOut hides at once")
	assert(Motion.SetReducedMotion("yes") == false, "the switch takes a boolean")
	assert(Motion.SetReducedMotion(false) == true and Motion.ReducedMotion() == false)
end

-- Secret values go straight to the setter: Lua never does arithmetic on them.
do
	local env, ns = NewMotion()
	local Motion = ns.Motion
	local obj, done = {}, false
	local secret = env.Secret(5)
	assert(Motion.Tween(obj, setV, 0, secret, 1, "linear", function()
		done = true
	end) == nil, "a secret target returns no handle")
	assert(obj.v == secret and done, "the secret is set as the end value")
	Motion.Tween(obj, setV, env.Secret(1), 2, 1, "linear")
	assert(obj.v == 2, "a secret start jumps to the end")
	local frame = env.CreateFrame("Frame")
	frame:SetAlpha(env.Secret(0.5)) -- SetAlphaFromBoolean can leave a secret alpha
	Motion.FadeOut(frame)
	assert(not frame:IsShown(), "a fade from a secret alpha jumps to the end")
	assert(#updating(env) == 0)
end

print("motion ok")
