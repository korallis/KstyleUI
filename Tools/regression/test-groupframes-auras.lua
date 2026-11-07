-- test-groupframes-auras.lua: debuff icons and the dispellable debuff highlight on the AuraContainer engine: filters, layout, settings, secrecy, combat and a client without the engine.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function setup(opts)
	local env, K, ns = G.New(opts)
	local party = {
		{ name = "Thaldren", class = "WARRIOR" },
		{ name = "Sylaen", class = "DRUID" },
	}
	G.SetRoster(env, "party", party)
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	local function content(unit)
		local i = 1
		while ns.Headers.party._attributes["child" .. i] do
			local button = ns.Headers.party._attributes["child" .. i]
			if button._attributes.unit == unit and button._shown then
				return ns.Button.Content(button)
			end
			i = i + 1
		end
	end
	return env, K, ns, party, content
end

local env, K, ns, _, content = setup()
local f = content("party1")
local container = f.auras
assert(container, "party1 has a debuff container")
eq(container:GetObjectType(), "AuraContainer", "the container is an AuraContainer")
eq(container._unit, "party1", "the container follows the frame's unit")
eq(container._editModePreview, false, "Edit Mode preview auras are off")

-- The debuff group: harmful auras, Blizzard's unit frame order, the party's size and count.
local group = container._groups.debuffs
assert(group, "the container has a debuff group")
eq(group.filter, "HARMFUL", "all debuffs by default")
eq(group.sortMethod, env.AuraContainerSortMethod.UnitFrameDebuff, "boss and priority debuffs first")
eq(group.maxFrameCount, 3, "three party debuffs")
eq(group.layout.elementWidth, 20, "20-unit party icons")
eq(group.layout.elementSpacing, 2, "2-unit gaps")
eq(container._flow.anchor, "TOPLEFT", "party icons grow right and down from the top left")
eq(container._flow.horizontal, env.AnchorUtil.FlowDirection.Right, "growing right")
eq(container._flow.vertical, env.AnchorUtil.FlowDirection.Down, "wrapping down")
eq(container._points[1][1], "TOPLEFT", "the container's top left")
eq(container._points[1][3], "TOPRIGHT", "sits at the frame's top right, outside it")

-- Each aura button: icon, swipe and stack count bound to the engine, clicks passing through to the unit.
local button = group.frames[1]
assert(button._aura.icon, "the icon is bound")
assert(button._aura.cooldown, "the duration swipe is bound")
assert(button._aura.count, "the stack count is bound")
local passes = false
for _, call in ipairs(button._calls) do
	if call.method == "SetMouseClickEnabled" and call.args and call.args[1] == false then
		passes = true
	end
	if call.method == "EnableMouse" and call.args and call.args[1] == false then
		passes = true
	end
end
assert(passes, "debuff icons let clicks through to the unit button")
eq(#button._aura.dispel, 1, "the icon border takes the debuff type colour")

-- The dispel highlight: a slot for debuffs the player can dispel, drawn as a coloured border over the frame.
local slot = container._slots.dispel
assert(slot, "the container has a dispel slot")
eq(slot.filter, "HARMFUL|RAID", "debuffs the player can dispel")
assert(#slot.frame._aura.dispel >= 4, "the highlight's border lines take the dispel type colour")
eq(slot.frame._state.AllPoints and slot.frame._state.AllPoints[1], f, "the highlight covers the frame")

-- Unit changes rebind the container; an empty button binds to none.
ns.Unit.Set(f, "party2")
eq(container._unit, "party2", "the container follows a unit change")
ns.Unit.Set(f, nil)
eq(container._unit, "none", "an empty button binds the container to none")
ns.Unit.Set(f, "party1")

-- Settings: filter, count, grid, dispel filter and the switch.
K.Options.Write("GroupFrames", "auras.filter", "DISPELLABLE")
eq(group.filter, "HARMFUL|RAID", "debuffs you can dispel")
K.Options.Write("GroupFrames", "auras.filter", "RAID")
eq(group.filter, "HARMFUL|RAID_IN_COMBAT", "debuffs Blizzard shows on raid frames")
K.Options.Write("GroupFrames", "party.auraColumns", 2)
K.Options.Write("GroupFrames", "party.auraRows", 1)
eq(group.maxFrameCount, 2, "the count stops at columns times rows")
K.Options.Write("GroupFrames", "auras.dispelFilter", "GROUP")
eq(slot.filter, "HARMFUL|RAID_PLAYER_DISPELLABLE", "debuffs anyone in the group can dispel")
K.Options.Write("GroupFrames", "party.auraSize", 24)
local w = button:GetSize()
eq(w, 24, "the icons resize")
eq(group.layout.elementWidth, 24, "and the layout follows")
K.Options.Write("GroupFrames", "auras.enabled", false)
eq(container:IsShown(), false, "debuffs switch off")
eq(container._unit, "none", "and stop following the unit")
K.Options.Write("GroupFrames", "auras.enabled", true)
eq(container:IsShown(), true, "debuffs switch back on")
eq(container._unit, "party1", "and follow the unit again")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- While auras are secret, aura buttons are not touched; the change lands when they are readable.
env._aurasSecret = true
K.Options.Write("GroupFrames", "party.auraSize", 18)
eq(#env._errors, 0, "no access to aura buttons while auras are secret: " .. tostring(env._errors[1]))
eq((button:GetSize()), 24, "the icon size waits")
env._aurasSecret = false
env.RunTimers()
eq((button:GetSize()), 18, "and applies once auras are readable")

-- A frame that first gets a unit in combat makes its container after combat.
env.SetCombat(true)
local fresh = content("party2")
local before = #env._containers
G.SetRoster(env, "party", { { name = "A", class = "WARRIOR" }, { name = "B", class = "DRUID" }, { name = "C", class = "MAGE" } })
eq(#env._containers, before, "no container is made in combat")
env.SetCombat(false)
assert(#env._containers > before, "the container is made when combat ends")
assert(fresh, "party2 still has a frame")
eq(#env._blocked, 0, "no protected call: " .. tostring(env._blocked[1]))
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- Without the engine the frames still work and the devlog says why there are no debuffs.
env, _, _, _, content = setup({ engine = { noContainer = true } })
eq(#env._errors, 0, "no errors without the engine: " .. tostring(env._errors[1]))
eq(content("party1").auras, nil, "no container without the engine")
local logged = false
for _, entry in ipairs(env.KstyleUIDB.devlog) do
	logged = logged or (entry.module == "GroupFrames" and entry.message:find("AuraContainer", 1, true) ~= nil)
end
assert(logged, "the devlog names the missing engine")

print("groupframes auras ok")
