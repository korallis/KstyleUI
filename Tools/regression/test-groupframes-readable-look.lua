-- test-groupframes-readable-look.lua: Party and Raid > Readability on 1920x1080 in Medallions and Frames: the party backing reaches below the power bar and portrait, a three-unit divider between health and power, offline and dead members on an empty track, a leader crown seated on the rim, the preview's out-of-range opacity matching the live one, and light raid tile names on a dark halo that shorten with an ellipsis.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local Scene = dofile("Tools/render/scene.lua")

local env, K, ns = H.G.New(H.screen({ 1920, 1080 }, { shipped = true, setup = H.setup }))
env.SetQuiet(true)
H.G.SetRoster(env, "party", {
	{ name = "Thessaly", class = "PALADIN", role = "TANK", health = 100, maxHealth = 100, online = false },
	{ name = "Brannoc", class = "HUNTER", role = "DAMAGER", health = 0, maxHealth = 100, dead = true },
	{ name = "Ilyra", class = "PRIEST", role = "HEALER", health = 100, maxHealth = 100, inRange = false },
}, { name = "Valerin", class = "SHAMAN", role = "HEALER", health = 82, maxHealth = 100, leader = true })
K.Modules.Enable(H.MODULE)
env.RunTimers()

local function Bottom(region)
	local _, y, _, h = Scene.Rect(env, region)
	return y + h
end

for _, style in ipairs({ "medallions", "frames" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	ns.Unit.ForEach(function(f)
		if f.kind ~= "party" or not f.unit then return end
		local who = style .. " " .. f.unit
		local parts, edge = f.parts, K.Scale.Pixel(1)
		-- The backing reaches the lowest visible edge: past the power bar's frame, and the portrait's rim no further below it than above.
		local _, top, _, height = Scene.Rect(env, f.medPartyInk)
		assert(top + height >= Bottom(f.power) + edge, who .. ": the backing ends at " .. top + height .. ", above the power bar's " .. Bottom(f.power))
		if f.ring:IsShown() then
			local _, ringTop = Scene.Rect(env, f.ring)
			assert(Bottom(f.ring) - (top + height) <= top - ringTop + 1e-6, who .. ": the portrait hangs below the backing to " .. Bottom(f.ring))
		end
		-- A divider of three units between the health and power fills in both styles.
		assert(parts.power.top - (parts.health.top + parts.health.height) >= 3, who .. ": the health and power fills read as one bar")
		-- Offline and dead members show an empty track, not a full grey bar or live mana.
		local idle = f.unit == "party1" or f.unit == "party2"
		for _, bar in ipairs({ f.health, f.power }) do
			local hidden = (select(4, bar:GetStatusBarColor()) or 1) == 0 and bar.fillClip:GetAlpha() == 0
			assert(hidden == idle, who .. ": the fills show only for available members")
		end
	end)
	if style == "medallions" then
		local me = H.frame(ns, "player")
		-- The crown sits on the portrait's rim, inside the frame.
		local x, y, w = Scene.Rect(env, me.leader)
		local rx, ry, rw = Scene.Rect(env, me.ring)
		local _, top = Scene.Rect(env, me)
		local dx, dy = x + w / 2 - (rx + rw / 2), y + w / 2 - (ry + rw / 2)
		assert(y >= top - 1e-6 and dx * dx + dy * dy <= (rw / 2) ^ 2, "the leader crown floats off the rim")
	end
end

-- The preview fades an out-of-range member as far as the live frames do.
local preview = H.preview(env, K)
env.RunTimers()
for _, list in ipairs({ preview.partyFrames, preview.raidFrames }) do
	for _, f in ipairs(list) do
		if f.sample.far then
			assert(H.near(H.reveal(env, f:GetAlpha()), H.reveal(env, H.frame(ns, "party3"):GetAlpha())), "the preview's out-of-range opacity matches the live frames")
		end
	end
end

-- Medallions raid tiles: a light name on a dark halo over a light fill and the track, shortened with an ellipsis.
K.Options.Write("HudStyle", "style", "medallions")
H.G.SetRoster(env, "raid", H.G.Members(20, function(i, m)
	if i == 1 then m.name, m.class, m.health, m.maxHealth = "Wanderbrightest", "HUNTER", 43, 100 end
	return m
end))
env.RunTimers()
local tile = H.frame(ns, "raid1")
assert((K.Widgets.InkLuminance(tile.name:GetTextColor()) or 0) > 0.5 and tile.name.halo and tile.name.halo:IsShown(), "a light class's tile name is light ink on a dark halo")
local shown = H.text(env, tile.name)
assert(shown ~= tile.rawName and shown:sub(-3) == "...", "a shortened tile name ends with the ellipsis, got " .. tostring(shown))
H.noErrors(env, K)

print("groupframes readable look ok: backing, divider, idle tracks, crown, preview fade and tile names")
