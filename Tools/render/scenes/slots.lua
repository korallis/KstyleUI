-- slots.lua: the shared action slot in every state on bar 1, labelled: at rest, hovered, pressed mid-flash, on cooldown with its lit edge, procced, out of range, out of resource, unusable, empty, flashing ready, on the global cooldown and selected.
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local STATES = { "rest", "hover", "pressed", "cooldown", "proc", "range", "power", "unusable", "empty", "ready", "gcd", "selected" }
local SAMPLE = 0.05

return Common.Run(function()
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local env, K, ns = AB.New({
		class = "SHAMAN",
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		setup = function(e)
			Common.ForceScreen(e)
			local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			for i = 1, 12 do
				e._game.bindings["ACTIONBUTTON" .. i] = { keys[i] }
			end
			e.GetBindingText = function(key)
				return key
			end
		end,
	})
	env._time = 100
	env._now = env._time
	env.GetTime = function()
		return env._time
	end
	AB.Enable(env, K)
	local icons = Hud.BAR1
	local g = env._game
	for i = 1, 12 do
		local icon = icons[i] or I.heroicStrike
		if STATES[i] ~= "empty" then
			g.slots[i] = { texture = icon, type = "spell", id = 100 + i }
		end
	end
	for i = 1, 12 do
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", i)
	end
	env.RunTimers()
	local bar = ns.bars.bar1
	bar.holder:ClearAllPoints()
	bar.holder:SetPoint("CENTER", bar.holder:GetParent(), "CENTER", 0, 0)
	bar:RefreshTray(true)
	local function button(state)
		for i, name in ipairs(STATES) do
			if name == state then
				return AB.Button(ns, "bar1", i)
			end
		end
	end
	K.Widgets.Hover(button("hover"), true)
	K.Widgets.Press(button("pressed"), true)
	local cd = button("cooldown")
	cd:SetCooldown(env._time - 3, 8)
	cd.cooldown:Show()
	cd.cooldown:GetScript("OnShow")(cd.cooldown)
	button("proc"):SetProc(true)
	local range = K.Options.Read("ActionBars", "rangeColor")
	local out = button("range")
	out.outOfRange = true
	ns.Button.ApplyTint(out, true)
	local power = button("power")
	ns.Button.UpdateUsable(power, false, true)
	button("unusable"):SetUsable(false)
	local ready = button("ready")
	ready:SetCooldown(env._time - 1, 1)
	ready.cooldown:GetScript("OnShow")(ready.cooldown)
	ready.cooldown:GetScript("OnCooldownDone")(ready.cooldown)
	ready:ClearCooldown()
	local gcd = button("gcd")
	gcd:SetCooldown(env._time - 0.5, 1.5, true)
	gcd.cooldown:Show()
	gcd.cooldown:GetScript("OnShow")(gcd.cooldown)
	button("selected"):SetSelected(true)
	for i, name in ipairs(STATES) do
		local b = AB.Button(ns, "bar1", i)
		local label = K.Widgets.Text(K.Scale.Root(), "caption", "text")
		label:SetPoint("BOTTOM", b, "TOP", 0, 6)
		label:SetText(name)
	end
	local _ = range
	return Scene.Build(env, Common.ScreenOpts({ time = env._time + SAMPLE, iconDirs = Common.IconDirs() }))
end)
