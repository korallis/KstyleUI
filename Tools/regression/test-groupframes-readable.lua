-- test-groupframes-readable.lua: Party and Raid > Readability on the four test screens and a narrow one, Frames and Medallions: larger party frames that leave a player's own size alone, whole health percentages, ten-letter names, names that meet 4.5:1 in range and 3:1 out of range over a bright world, and a dark missing-health track; each switch off restores the earlier look.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G

-- A bright world behind the frames: a linear luminance of 0.1, about three times the owner's grass on 2026-11-23.
local WORLD = 0.1
local MEMBERS = {
	{ name = "Kassandrel", class = "WARLOCK", role = "TANK", health = 100, maxHealth = 100 },
	{ name = "Blessed", class = "PALADIN", role = "HEALER", health = 100, maxHealth = 100 },
	{ name = "For", class = "PRIEST", role = "DAMAGER", health = 100, maxHealth = 100, inRange = false },
	{ name = "Torvald", class = "DRUID", role = "DAMAGER", health = 23, maxHealth = 100 },
}

local function Contrast(env, K, f, world)
	local r, g, b = f.name:GetTextColor()
	local text = K.Widgets.InkLuminance(r, g, b)
	local a = H.reveal(env, f:GetAlpha())
	local scrim = f.medPartyScrim and f.medPartyScrim[1]:IsShown() and select(4, f.medPartyScrim[1]:GetVertexColor()) or 0
	local halo = f.name.halo and f.name.halo:IsShown() and select(4, f.name.halo:GetVertexColor()) or 0
	local back = world * (1 - scrim * a) * (1 - halo * a)
	local ink = back * (1 - a) + text * a
	return (ink + 0.05) / (back + 0.05)
end

local function Frames(ns)
	local out = {}
	ns.Unit.ForEach(function(f) if f.kind == "party" and f.unit then out[#out + 1] = f end end)
	return out
end

local function Boot(screen)
	local env, K, ns = G.New(H.screen(screen, { shipped = true, setup = H.setup }))
	env.SetQuiet(true)
	G.SetRoster(env, "party", MEMBERS, { name = "Korallis", class = "SHAMAN", role = "DAMAGER", health = 45, maxHealth = 100 })
	K.Modules.Enable(H.MODULE)
	env.RunTimers()
	return env, K, ns
end

local function Scale(K)
	return K.Layout.Element("groupframes.party").frame:GetScale()
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2560, 1600 } }) do
	local env, K, ns = Boot(screen)
	local wide = screen[1] / screen[2] >= 2.05
	for _, style in ipairs({ "medallions", "frames" }) do
		K.Options.Write("HudStyle", "style", style)
		env.RunTimers()
		local at = style .. " " .. screen[1] .. "x" .. screen[2]
		-- Size: a quarter larger on ultrawide screens, where it shrinks nothing; 16:9 and 16:10 keep the HUD's size and bar 3's slot.
		assert(H.near(Scale(K), wide and 1.25 or 1), at .. ": the party is " .. Scale(K) .. " times its size")
		for _, f in ipairs(Frames(ns)) do
			local who = at .. " " .. f.unit
			-- Whole percentages: the percent takes its own width, so "100%" never shortens to "10...".
			assert(H.width(env, f.healthText) == 0, who .. ": the percent keeps its natural width")
			if f.rawName then
				assert(H.text(env, f.name) == f.rawName, who .. ": " .. f.rawName .. " shows whole, got " .. tostring(H.text(env, f.name)))
			end
			-- Contrast over a bright world: 4.5:1 in range, 3:1 out of range (at least 0.7 opaque).
			local need = f.unit == "party3" and 3 or 4.5
			local ratio = Contrast(env, K, f, WORLD)
			assert(ratio >= need, who .. ": the name reads at " .. string.format("%.2f", ratio) .. ":1, under " .. need .. ":1")
			-- Dark missing health: no pale band for health just lost.
			assert(f.health.lossOn == false and not f.health.under:GetStatusBarTexture():IsShown(), who .. ": the missing health stays dark")
		end
		assert(H.reveal(env, H.frame(ns, "party3"):GetAlpha()) >= 0.7, at .. ": out of range keeps 0.7 opacity")
	end
	-- A hit keeps the track dark: the loss band never shows.
	local me = H.frame(ns, "player")
	env._roster.player.health = 20
	env.FireEvent("UNIT_HEALTH", "player")
	env.RunTimers()
	assert(not me.health.under:GetStatusBarTexture():IsShown(), screen[1] .. "x" .. screen[2] .. ": a hit shows no pale band")

	-- Off restores the earlier look: scale 1, a fixed percent lane, the 0.5 Medallions backing without a halo, 0.4 out of range and the band.
	for _, key in ipairs({ "readable.size", "readable.text", "readable.track" }) do
		H.write(env, K, key, false)
	end
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	assert(Scale(K) == 1, "off: the party keeps its earlier size")
	local weakest = math.huge
	for _, f in ipairs(Frames(ns)) do
		assert(H.width(env, f.healthText) > 0, "off: the percent keeps its fixed lane")
		assert(not (f.name.halo and f.name.halo:IsShown()), "off: no halo behind the name")
		assert(H.near(select(4, f.medPartyScrim[1]:GetVertexColor()), 0.5), "off: the earlier 0.5 backing")
		assert(f.health.lossOn == true, "off: the pale band for health just lost returns")
		weakest = math.min(weakest, Contrast(env, K, f, WORLD) / (f.unit == "party3" and 3 or 4.5))
	end
	assert(weakest < 1, "the contrast check fails on the earlier look, as the owner's screenshot showed")
	assert(H.near(H.reveal(env, H.frame(ns, "party3"):GetAlpha()), 0.4), "off: out of range fades to the saved 0.4")
	H.noErrors(env, K)
	collectgarbage()
end

-- A player's own size wins: their width, or their Layout Mode scale, keeps the party as they set it.
do
	local env, K = Boot({ 5120, 1440 })
	H.write(env, K, "party.width", 280)
	assert(Scale(K) == 1, "an own width keeps the party at scale 1")
	H.write(env, K, "party.width", 259)
	assert(H.near(Scale(K), 1.25), "the stock width grows again")
	K.Options.Write("Layout", "preset", "Healer")
	H.write(env, K, "party.height", 43)
	assert(H.near(Scale(K), 1.25), "the Healer layout's stock rows grow too")
	K.Layout.Set("groupframes.party", "scale", 1.1)
	env.RunTimers()
	assert(H.near(Scale(K), 1.1), "a Layout Mode scale is the player's own")
	H.noErrors(env, K)
end

print("groupframes readable ok: larger party frames, whole percentages, legible names and a dark track on five screens, each switch off restoring the earlier look")
