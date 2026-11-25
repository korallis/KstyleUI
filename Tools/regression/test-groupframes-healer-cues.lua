-- The healer information audit found lost engine slots, hidden resurrection and identical five-letter raid labels.
local S = dofile("Tools/regression/raid_status.lua")
local G = S.G
local env, K, ns = G.New({ setup = function(e)
	e.UnitHasIncomingResurrection = function() return e.Secret(true) end
end })
G.SetRoster(env, "raid", G.Members(25), { name = "Ysra", class = "PRIEST", role = "HEALER" })
assert(K.Modules.Enable("GroupFrames"))
env.RunTimers()
local f = assert(S.Content(ns, ns.Headers.raid[1], "raid1"))
for _, preset in ipairs({ "Compact", "Healer", "Compact" }) do
	K.Options.Write("GroupFrames", "presets.raid", preset)
	env.RunTimers()
	local _, slots = ns.Auras.HealIcons(f, ns.Settings.current.raid)
	assert(f.buffs._groups.buffs.enabled and slots == 3, preset .. " lost own-heal slots")
	assert(f.auras._groups.dispels.maxFrameCount == 2, preset .. " lost dispel slots")
	if preset == "Healer" then
		local tile, row = { S.Scene.Rect(env, f) }, { S.Scene.Rect(env, f.buffClip) }
		assert(ns.Settings.current.raid.width == 128 and ns.Settings.current.raid.healthText == "DEFICIT")
		assert(row[1] >= tile[1] - 1 and row[1] + row[3] <= tile[1] + tile[3] + 1, "heals must fit the tile")
	end
end
K.Options.Write("GroupFrames", "icons.readyCheck", false)
env.RunTimers()
env.FireEvent("READY_CHECK")
assert(not f.ready:IsShown() and env.Reveal(f.statusIcons.resurrection:GetAlpha()) == 1, "hidden ready checks must not displace resurrection")
local function fits(s) return #s <= 5 end
local a = ns.Names.Short("Staraxlight", fits, { "Staraylight" }, "")
local b = ns.Names.Short("Staraylight", fits, { "Staraxlight" }, "")
assert(a ~= b and fits(a) and fits(b), "five-letter labels collide: " .. a .. ", " .. b)
assert(#env._errors == 0, tostring(env._errors[1]))
