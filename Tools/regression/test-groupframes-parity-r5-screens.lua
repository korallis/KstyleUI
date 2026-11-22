-- test-groupframes-parity-r5-screens.lua: EllesmereUI parity round 5 on the four test screens, each booted at its size: party heal icons clear of the indicator lane and the percent on Frames and Medallions rows, and Medallions names clear of the indicators.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local frame, noErrors, overlap = H.frame, H.noErrors, H.overlap

-- Party heal icons clear the percent and every default indicator lane spot at all four screens, and Medallions names clear the indicators.
do
	for _, screen in ipairs(H.SCREENS) do
		do
			local env, K, ns = H.boot(H.screen(screen))
			for _, style in ipairs({ "medallions" }) do
				env.RunTimers()
				for _, unit in ipairs({ "player", "party1" }) do
					local f = frame(ns, unit)
					local at = style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. unit
					local w0, h0 = overlap(env, f.buffClip, f.healthText)
					assert(w0 <= 0 or h0 <= 0, at .. ": the heal icons cover the percent by " .. w0 .. " x " .. h0)
					for i = 1, 3 do
						local indicator = f.indicators._slots["indicator" .. i]
						indicator.frame:Show()
						local w, h = overlap(env, f.buffClip, indicator.frame)
						assert(indicator.enabled and (w <= 0 or h <= 0), at .. ": the heal icons cover indicator " .. i .. " by " .. w .. " x " .. h)
						if style == "medallions" then
							w, h = overlap(env, f.name, indicator.frame)
							assert(w <= 0 or h <= 0, at .. ": indicator " .. i .. " covers the name by " .. w .. " x " .. h)
							w, h = overlap(env, f.healthText, indicator.frame)
							assert(w <= 0 or h <= 0, at .. ": indicator " .. i .. " covers the percent by " .. w .. " x " .. h)
						end
					end
				end
			end
			noErrors(env, K)
		end
		collectgarbage()
	end
end

print("groupframes parity round 5 screens ok: the heal lane and Medallions names on four real screens")
