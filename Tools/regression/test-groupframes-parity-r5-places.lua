-- test-groupframes-parity-r5-places.lua: the PR #654 review of EllesmereUI parity round 5: switched on at their default places, pet, tank and friendly boss frames clear the raid, the party and each other on the four test screens, in the module's own layout and the first-run setup's.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local write, noErrors, overlap = H.write, H.noErrors, H.overlap

-- Switched on at their default places, pet, tank and friendly boss frames clear the raid, the party and each other on every test screen,
-- with a ten-player raid and you healing (its frames are the largest), in the module's own layout and the first-run setup's.
for pass, screen in ipairs(H.SCREENS) do
	do
		local env, K, ns = H.boot(H.screen(screen, { setup = function(e)
			H.setup(e)
			H.G.Secure(e)
			e._units = {}
			e.UnitCanAssist = function(_, unit) return unit == "boss1" end
		end }))
		H.G.SetRoster(env, "raid", H.G.Members(10, function(i, m) if i <= 2 then m.role = "TANK" end end), { name = "Tester", class = "PRIEST", role = "HEALER" })
		for i = 1, 3 do env._units["raidpet" .. i] = { name = "Fang", class = "HUNTER", health = 50, maxHealth = 50 } end
		env._units.boss1 = { name = "Valithria", class = "DRUID", health = 41, maxHealth = 100 }
		env.RunTimers()
		for key, value in pairs({ ["tanks.enabled"] = true, ["pets.enabled"] = true, ["boss.display"] = "ALWAYS" }) do write(env, K, key, value) end
		env.RunStateDrivers()
		local function clear(at)
			local keys = { "groupframes.raid", "groupframes.party", "groupframes.tanks", "groupframes.pets", "groupframes.boss" }
			for i = 3, #keys do
				local l, b, w, h = K.Layout.Rect(keys[i])
				for j = 1, i - 1 do
					local l2, b2, w2, h2 = K.Layout.Rect(keys[j])
					local ow, oh = math.min(l + w, l2 + w2) - math.max(l, l2), math.min(b + h, b2 + h2) - math.max(b, b2)
					assert(ow <= 0 or oh <= 0, at .. ": " .. keys[i] .. " covers " .. keys[j] .. " by " .. ow .. " x " .. oh)
				end
			end
			local shown = {}
			ns.Unit.ForEach(function(f) if f.unit and f:IsVisible() then shown[#shown + 1] = f end end)
			for i, a in ipairs(shown) do
				for j = i + 1, #shown do
					local b = shown[j]
					if (a.extra or a.kind) ~= (b.extra or b.kind) then
						local w, h = overlap(env, a, b)
						assert(w <= 0 or h <= 0, at .. ": " .. (a.extra or a.kind) .. " " .. a.unit .. " covers " .. (b.extra or b.kind) .. " " .. b.unit)
					end
				end
			end
		end
		clear(screen[1] .. "x" .. screen[2])
		if pass == 1 then
			assert(K.Setup.Apply(K.Setup.NewChoice()))
			env.RunTimers()
			env.RunStateDrivers()
			clear("the first-run setup's layout at " .. screen[1] .. "x" .. screen[2])
		end
		noErrors(env, K)
	end
	collectgarbage()
end

print("groupframes parity round 5 places ok: pet, tank and friendly boss frames clear of the raid, the party and each other on four real screens")
