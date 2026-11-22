-- test-groupframes-parity-r7-review.lua: the PR #732 review's probes: party pets in one place only (a missing secure API or a small raid keeps them in the pet frames), beside pets never wider or taller than their owner's pitch, icons scaled to the height shown, the preview's pets returned when pet frames go off, and a role change that touches only the indicators and the open preview.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, frame, noErrors, boot = H.write, H.frame, H.noErrors, H.boot

local function setup(env)
	H.setup(env)
	G.Secure(env)
	env._units = { pet = { name = "Wolf", class = "HUNTER" }, partypet1 = { name = "Cat", class = "HUNTER" }, partypet2 = { name = "Cat", class = "HUNTER" }, raidpet2 = { name = "Cat", class = "HUNTER" } }
end

local env, K, ns = boot({ setup = setup })
local header

-- One place for party pets.
do
	write(env, K, "pets.enabled", true)
	write(env, K, "pets.beside", true)
	header = ns.Extras.groups.pets.header
	local pv = H.preview(env, K)
	write(env, K, "pets.enabled", false)
	pv:Refresh()
	assert(not pv.extras.pets[1]:IsVisible() and pv.extras.pets[1]:GetParent() == pv.extras.pets.holder, "pet frames off: the preview's pets go back and hide")
	write(env, K, "pets.enabled", true)
	write(env, K, "party.smallRaid", true)
	G.SetRoster(env, "raid", G.Members(5))
	env.RunTimers()
	assert(ns.AutoLayout.state.smallRaid and table.concat(G.Shown(header), ",") == "raidpet2", "a small raid keeps its pets in the pet frames")
	ns.Headers.Children(ns.Headers.party, function(owner)
		assert(not (owner.kstylePet and owner.kstylePet:IsVisible()), "and none beside the party-style raid frames")
	end)
	H.party(env)
	env.RunTimers()
	write(env, K, "pets.beside", false)
	local ref = env.SecureHandlerSetFrameRef
	env.SecureHandlerSetFrameRef = nil
	write(env, K, "pets.beside", true)
	assert(header:GetAttribute("showParty") == true and #G.Shown(header) == 3 and not ns.Extras.beside, "without the secure API the pet frames keep party pets")
	env.SecureHandlerSetFrameRef = ref
	noErrors(env, K)
end

-- Beside pets keep to their owner's pitch, and their icons follow the height shown.
do
	write(env, K, "party.growth", "RIGHT")
	write(env, K, "party.width", 100)
	write(env, K, "pets.width", 100)
	local a, b = frame(ns, "player").owner.kstylePet, frame(ns, "party1").owner.kstylePet
	local pitch = ns.Geometry.Party(ns.Settings.current.party).memberWidth
	assert(a:IsVisible() and b:IsVisible() and a:GetWidth() <= pitch + 1e-3 and select(4, b:GetPoint(1)) == select(4, a:GetPoint(1)), "side-by-side owners give their pets no more than their own width")
	write(env, K, "party.growth", "DOWN")
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	write(env, K, "pets.icons", true)
	local f = ns.Button.Content(frame(ns, "player").owner.kstylePet)
	write(env, K, "pets.height", 15)
	local small = ns.Auras.Block(f, ns.Settings.current.raid).size
	write(env, K, "pets.height", 100)
	assert(ns.Auras.Block(f, ns.Settings.current.raid).size == small and f.owner:GetHeight() <= ns.Settings.current.party.height + 1e-3, "icons scale with the height shown, not the one asked for")
	noErrors(env, K)
end

-- A role change touches the indicators and the open preview only.
do
	write(env, K, "indicator1.role", "HEALER")
	local pv = H.preview(env, K)
	local slot = pv.partyFrames[1].sampleSlots[1]
	local apply, applied = ns.Style.Apply, 0
	ns.Style.Apply = function(f, ...) if not f.sample then applied = applied + 1 end return apply(f, ...) end
	env.SetCombat(true)
	env._roster.player.role = "HEALER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	assert(applied == 0 and #env._blocked == 0, "no live frame is restyled: " .. applied)
	ns.Style.Apply = apply
	assert(ns.Slots.Placements(frame(ns, "party1"))[1].fits, "the indicator follows")
	assert(slot:IsShown(), "the open preview follows")
	env.SetCombat(false)
	noErrors(env, K)
end
print("groupframes parity round 7 review ok: pets in one place, pet pitch and scale, preview pets, role changes scoped")
