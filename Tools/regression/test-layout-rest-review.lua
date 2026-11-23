-- test-layout-rest-review.lua: the clean screen at rest against the PR #744 review probes: low power, death and a reload at low health keep the panels up; a pointer already on a panel, a late panel and a refused hook; Layout Mode and the action bar grid; fades another owner set; nothing done while off or for hidden panels; one timer however many events; missing APIs; the Options row and reset; and renders that boot with it off.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 1e-3
end

local function Panel(env, K, key, name)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(100, 40)
	local child = env.CreateFrame("Button", name, frame)
	K.Layout.Register(frame, key, { anchor = "CENTER" }, { label = key })
	return frame, child
end

local function New(setup)
	local env, K = W.New({ setup = setup })
	local frame, child = Panel(env, K, "unitframes.player")
	local strip = Panel(env, K, "databars.strip")
	return env, K, frame, child, strip
end

local function Settle(env, K)
	env.RunTimers()
	K.Motion.Settle()
end

local function Cycle(env, K)
	env.SetTarget(true)
	env.SetTarget(false)
	Settle(env, K)
end

-- 1. Low power, death and a reload at low health keep the panels up --------------------------------------------

do
	local env, K, frame = New()
	env.UnitHealth = function() return env.Secret(20) end
	env.UnitHealthMax = function() return 100 end
	env.UnitPower = function() return 10 end
	env.UnitPowerMax = function() return 100 end
	env.FireEvent("UNIT_HEALTH", "player")
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	Settle(env, K)
	assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "mana at 10 of 100 keeps the panels up: " .. frame:GetAlpha())
	env.UnitPower = function() return 100 end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	Settle(env, K)
	assert(K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 0.35), "full mana lets them rest")
	env.UnitPower = function() return env.Secret(100) end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	Settle(env, K)
	assert(not K.Layout.Rest.Quiet(), "power the game keeps secret is not taken as full")
	env.UnitPower = function() return 0 end
	env.FireEvent("UNIT_POWER_UPDATE", "player", "MANA")
	Settle(env, K)
	assert(K.Layout.Rest.Quiet(), "an empty power that only drains lets them rest")
	env.UnitIsDeadOrGhost = function() return true end
	env.FireEvent("UNIT_HEALTH", "player")
	Settle(env, K)
	assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "a dead player's panels stay up")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local now, queue = 0, {}
	local env, K, frame = New(function(e)
		e.GetTime = function() return now end
		e.C_Timer.After = function(seconds, fn) queue[#queue + 1] = { at = now + seconds, fn = fn } end
	end)
	local function Advance(seconds)
		now = now + seconds
		local i = 1
		while i <= #queue do
			if queue[i].at <= now + 1e-6 then
				table.remove(queue, i).fn()
				i = 1
			else
				i = i + 1
			end
		end
		K.Motion.Settle()
	end
	env.FireEvent("PLAYER_ENTERING_WORLD", false, true)
	for _ = 1, 4 do
		Advance(1)
		env.FireEvent("UNIT_HEALTH", "player")
		assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "a reload at low health stays up while health climbs")
	end
	Advance(2.9)
	assert(not K.Layout.Rest.Quiet(), "no rest within three seconds of the last health change")
	Advance(0.2)
	assert(K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 0.35), "rests three seconds after the last health change")
	env.FireEvent("PLAYER_ENTERING_WORLD", false, false)
	K.Motion.Settle()
	assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "entering the world again wakes the panels while health is unknown")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- 2. A pointer already on a panel, a late panel and a refused hook ---------------------------------------------

do
	local env, K, frame, child, strip = New()
	frame._mouseOver, child._mouseOver = true, true
	W.Enter(child)
	Settle(env, K)
	assert(K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1) and near(strip:GetAlpha(), 0.35), "a pointer already on a panel when the rest begins keeps that panel up")
	frame._mouseOver, child._mouseOver = false, false
	W.Leave(child)
	Settle(env, K)
	assert(near(frame:GetAlpha(), 0.35), "leaving it lets it rest")

	local late, button = Panel(env, K, "cooldowns.custom")
	K.Motion.Settle()
	assert(near(late:GetAlpha(), 1), "a panel registered at rest stays up until it can be hovered back")
	Cycle(env, K)
	assert(button:GetScript("OnEnter") and near(late:GetAlpha(), 0.35), "it joins the next rest, hooked")
	W.Enter(button)
	K.Motion.Settle()
	assert(near(late:GetAlpha(), 1), "and a hover brings it back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, frame, child = New()
	local hook, refused, attempts = child.HookScript, true, 0
	child.HookScript = function(self, kind, fn)
		if kind == "OnEnter" then
			attempts = attempts + 1
			if refused then return false end
		end
		return hook(self, kind, fn)
	end
	Settle(env, K)
	refused = false
	Cycle(env, K)
	W.Enter(child)
	K.Motion.Settle()
	assert(attempts == 2 and near(frame:GetAlpha(), 1), "a hook the client refused is tried again at the next rest: " .. attempts .. " " .. frame:GetAlpha())
end

-- 3. Layout Mode and the action bar grid -----------------------------------------------------------------------

do
	local env, K, frame = New()
	Settle(env, K)
	assert(K.Layout.Enter())
	Settle(env, K)
	assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "opening Layout Mode wakes the resting panels")
	K.Layout.Exit(true)
	env.SetTarget(true)
	assert(K.Layout.Enter())
	env.SetTarget(false)
	Settle(env, K)
	K.Layout.Exit(true)
	Settle(env, K)
	assert(K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 0.35), "closing Layout Mode starts the wait again")

	env.GetCursorInfo = function() return nil end
	env.FireEvent("ACTIONBAR_SHOWGRID")
	Settle(env, K)
	assert(not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "the action bar grid wakes the panels even with nothing on the cursor")
	env.FireEvent("ACTIONBAR_HIDEGRID")
	Settle(env, K)
	assert(K.Layout.Rest.Quiet(), "closing the grid lets them rest")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- 4. Fades another owner set ----------------------------------------------------------------------------------

do
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	K.Options.Write("ActionBars", "bar1.fade", true)
	K.Options.Write("ActionBars", "bar1.fadeAlpha", 0.5)
	env.SetTarget(false)
	Settle(env, K)
	local bar = ns.bars.bar1
	assert(near(bar.header:GetAlpha() * bar.holder:GetAlpha(), 0.5), "a bar on Fade until hovered keeps its own fade: " .. bar.holder:GetAlpha())
	assert(near(ns.bars.bar2.holder:GetAlpha(), 0.35), "the other bars rest")
end

do
	local env, K, frame = New()
	local foreign = env.CreateFrame("Button", "ExampleExternalWidget", frame)
	frame:SetAlpha(0.6)
	Settle(env, K)
	assert(K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 0.6), "a holder another owner faded keeps that fade")
	K.Options.Write("Rest", "enabled", false)
	Settle(env, K)
	assert(near(frame:GetAlpha(), 0.6), "and keeps it when the switch goes off")
	assert(foreign:GetScript("OnEnter") == nil, "another addon's frame is never hooked")
end

-- 5. Nothing done while off or for hidden panels ---------------------------------------------------------------

do
	local env, K, _, child = New()
	Settle(env, K)
	K.Options.Write("Rest", "enabled", false)
	Settle(env, K)
	local n, after = 0, env.C_Timer.After
	env.C_Timer.After = function(seconds, fn)
		n = n + 1
		return after(seconds, fn)
	end
	W.Enter(child)
	W.Leave(child)
	assert(n == 0, "switched off, crossing a hooked button schedules nothing: " .. n)
end

do
	local env, K, frame = New()
	K.Layout.SetLive("unitframes.player", false)
	frame:Hide()
	Settle(env, K)
	assert(near(frame:GetAlpha(), 1) and frame:GetScript("OnEnter") == nil, "a hidden panel that is not live is neither hooked nor faded")
end

-- 6. One timer however many events ----------------------------------------------------------------------------

do
	local env, K = New()
	Settle(env, K)
	local n, after = 0, env.C_Timer.After
	env.C_Timer.After = function(seconds, fn)
		if seconds == 3 then n = n + 1 end
		return after(seconds, fn)
	end
	env.SetTarget(true)
	for _ = 1, 100 do env.FireEvent("UNIT_HEALTH", "player") end
	assert(n == 0, "with a target held no wait is scheduled: " .. n)
	env.SetTarget(false)
	for _ = 1, 100 do env.FireEvent("UNIT_HEALTH", "player") end
	assert(n == 1, "a burst of health changes keeps one wait: " .. n)
end

-- 7. Missing APIs ---------------------------------------------------------------------------------------------

do
	local env, K = New()
	env.UnitExists = nil
	env.FireEvent("PLAYER_TARGET_CHANGED")
	Settle(env, K)
	assert(K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- 8. The Options row and the Elements reset ------------------------------------------------------------------

do
	local O = dofile("Tools/regression/options_env.lua")
	local env, K, ns = O.New()
	K.Options.Open("Elements")
	ns.Window.Jump({ page = "Elements", labelTarget = "Rest opacity" })
	W.Settle(env)
	local readout
	for _, row in ipairs(ns.Window.Parts().content.rows) do
		if row.item and row.item.label == "Rest opacity" then readout = row.controls.slider.readout:GetText() end
	end
	assert(readout == "35%", "Rest opacity reads as a percentage like its sibling opacity sliders: " .. tostring(readout))
	local page = ns.Pages.Find(ns.Pages.List(), "Elements")
	K.Options.Write("Rest", "alpha", 0.7)
	K.Options.Write("Rest", "panels.player", false)
	K.Options.Write("Rest", "enabled", false)
	page.reset(page)
	assert(K.Options.Read("Rest", "alpha") == 0.35 and K.Options.Read("Rest", "panels.player") == true and K.Options.Read("Rest", "enabled") == true,
		"resetting the Elements page restores the clean screen's defaults")
end

-- 10. Renders boot with it off --------------------------------------------------------------------------------

do
	local Common = dofile("Tools/render/scenes/_common.lua")
	local env, K = W.New({ setup = function(e) Common.ForceScreen(e) end })
	local frame = Panel(env, K, "unitframes.player")
	Settle(env, K)
	assert(K.Store.Module("Rest").enabled == false and not K.Layout.Rest.Quiet() and near(frame:GetAlpha(), 1), "a render without RENDER_REST boots with the clean screen off")
	assert(K.Layout.Set("unitframes.player", "alphaIdle", 0.5))
	local start = frame:GetAlpha()
	local scene = io.open("Tools/render/scene.lua", "rb"):read("*a")
	assert(not scene:find("_rest", 1, true), "Scene.Build leaves the scene's alphas as the addon set them")
	assert(near(start, 1), "the opacity tween is still running")
end

print("ok layout rest review")
