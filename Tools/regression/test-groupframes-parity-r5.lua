-- test-groupframes-parity-r5.lua: EllesmereUI parity round 5: the Medallions party heal icons clear of the indicator lane and the percent at default settings on every test screen.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function boot()
	local env, K, ns = G.New()
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 80, maxHealth = 100 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 90, maxHealth = 100 },
	})
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	return env, K, ns
end

local function frame(ns, unit)
	local out
	ns.Unit.ForEach(function(f) if f.unit == unit then out = f end end)
	return assert(out, "no frame for " .. unit)
end

local function overlap(env, a, b)
	local r, s = { Scene.Rect(env, a) }, { Scene.Rect(env, b) }
	return math.min(r[1] + r[3], s[1] + s[3]) - math.max(r[1], s[1]), math.min(r[2] + r[4], s[2] + s[4]) - math.max(r[2], s[2])
end

-- Medallions party heal icons clear the percent and every default indicator lane spot at all four screens.
do
	local previous = rawget(_G, "RENDER_SCREEN")
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
		for _, style in ipairs({ "frames", "medallions" }) do
			local env, K, ns = boot()
			K.Options.Write("HudStyle", "style", style)
			env.RunTimers()
			for _, unit in ipairs({ "player", "party1" }) do
				local f = frame(ns, unit)
				-- This build's scene solver gives a font string no natural height, so the percent takes its font size.
				f.healthText:SetHeight(select(2, f.healthText:GetFont()))
				local w0, h0 = overlap(env, f.buffClip, f.healthText)
				assert(w0 <= 0 or h0 <= 0, style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit .. ": the heal icons cover the percent by " .. w0 .. " x " .. h0)
				for i = 1, 3 do
					local indicator = f.indicators._slots["indicator" .. i]
					indicator.frame:Show()
					local w, h = overlap(env, f.buffClip, indicator.frame)
					assert(indicator.enabled and (w <= 0 or h <= 0), style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit .. ": the heal icons cover indicator " .. i .. " by " .. w .. " x " .. h)
				end
			end
			assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
			collectgarbage()
		end
	end
	rawset(_G, "RENDER_SCREEN", previous)
end

print("groupframes parity round 5 ok")
