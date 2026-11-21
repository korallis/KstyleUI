-- test-groupframes-parity-r5.lua: EllesmereUI parity round 5: the Medallions party heal icons clear of the indicator lane and the percent at default settings on every test screen.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G, MODULE = H.G, H.MODULE
local frame, noErrors = H.frame, H.noErrors
local Scene = dofile("Tools/render/scene.lua")

local function boot(setup)
	local env, K, ns = G.New({ setup = setup or H.setup })
	H.party(env)
	K.Modules.Enable(MODULE)
	env.RunTimers()
	return env, K, ns
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
				local w0, h0 = overlap(env, f.buffClip, f.healthText)
				assert(w0 <= 0 or h0 <= 0, style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit .. ": the heal icons cover the percent by " .. w0 .. " x " .. h0)
				for i = 1, 3 do
					local indicator = f.indicators._slots["indicator" .. i]
					indicator.frame:Show()
					local w, h = overlap(env, f.buffClip, indicator.frame)
					assert(indicator.enabled and (w <= 0 or h <= 0), style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit .. ": the heal icons cover indicator " .. i .. " by " .. w .. " x " .. h)
				end
			end
			noErrors(env, K)
			collectgarbage()
		end
	end
	rawset(_G, "RENDER_SCREEN", previous)
end

print("groupframes parity round 5 ok")
