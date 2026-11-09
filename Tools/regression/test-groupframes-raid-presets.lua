-- test-groupframes-raid-presets.lua: the DPS, Tank and Healer presets' raid tiles at 20 and 40 players keep their defensive indicators in the status lane, crowd control under the boss slot, and a route for every boss debuff across the restricted transition (rank round 6, Astra #1 and #2); raid_status.lua holds the checks, test-groupframes-raid-status.lua runs Default.
local S = dofile("Tools/regression/raid_status.lua")
local G = S.G

-- Tank writes the same group frame settings as DPS (its own changes are the threat meter and the boss cards), so the
-- DPS run covers both.
local _, K = G.New()
local function same(a, b, path)
	for key, value in pairs(a) do
		if type(value) == "table" then
			same(value, b[key] or {}, path .. key .. ".")
		else
			S.eq(b[key], value, "Tank's " .. path .. key .. " matches DPS")
		end
	end
end
local dps, tank = S.Preset(K, "DPS"), S.Preset(K, "Tank")
same(dps, tank, "")
same(tank, dps, "")
S.Presets({ "DPS" })
collectgarbage()
S.Presets({ "Healer" })

print("groupframes raid presets ok")
