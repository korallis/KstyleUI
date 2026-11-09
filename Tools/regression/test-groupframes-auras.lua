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

-- Blizzard's unit frame processing classifies each debuff, as its own raid frames do: dispellable
-- debuffs first, then boss, priority and other debuffs, each sorted in Blizzard's unit frame order.
eq(container._policy, env.CustomAuraContainerAuraProcessingPolicy.ProcessAura, "auras are processed as Blizzard's raid frames do")
eq(container._policyOptions.ignoreBuffs, true, "buffs are ignored")
eq(container._policyOptions.displayOnlyDispellableDebuffs, false, "all debuffs by default")
local types = env.AuraUtil.AuraUpdateChangedType
local dispels = container._groups.dispels
assert(dispels, "the container has a dispellable debuff group")
eq(dispels.candidateFilters.processedAuraType, types.Dispel, "dispellable debuffs")
eq(dispels.sortMethod, env.AuraContainerSortMethod.UnitFrameDebuff, "in unit frame order")
eq(dispels.maxFrameCount, 1, "one dispellable debuff by default")
local group = container._groups.debuffs
assert(group, "the container has a debuff group")
eq(group.candidateFilters.processedAuraType, types.Debuff, "boss, priority and other debuffs")
eq(group.filter, "HARMFUL", "all debuffs by default")
eq(group.sortMethod, env.AuraContainerSortMethod.UnitFrameDebuff, "boss and priority debuffs first")
-- Six cells show (Grok R3 #5, Muse #4: three across, two rows); the engine may fill one more, which falls in the
-- clipped row and raises the "+" mark.
eq(group.maxFrameCount, 7, "six party debuffs and one for the overflow mark")
assert(dispels.layoutIndex < group.layoutIndex, "dispellable debuffs come first")
eq(group.layout.elementWidth, 18, "18-unit party icons, two rows of them in a 40-unit row")
eq(group.layout.elementSpacing, 2, "2-unit gaps")
eq(container._flow.anchor, "TOPLEFT", "party icons grow right and down from the top left")
eq(container._flow.horizontal, env.AnchorUtil.FlowDirection.Right, "growing right")
eq(container._flow.vertical, env.AnchorUtil.FlowDirection.Down, "wrapping down")
-- The container sits in a clip frame the size of the cells, so extra debuffs never draw past the card.
local clip = f.auraClip
eq(container:GetParent(), clip, "the container lives in the clip frame")
eq(container._points[1][1], "TOPLEFT", "at the clip's top left")
eq(clip._points[1][1], "TOPLEFT", "the clip's top left")
eq(clip._points[1][3], "TOPRIGHT", "sits at the frame's top right, outside it, in the card's lane")

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
eq(#button._aura.dispel, 9, "the chamfered tile behind the icon, nine slices, takes the debuff type colour")
do
	local skin = (button:GetChildren())
	local fr, fg, fb = K.Tokens.Color("buttonFill")
	local rr, rg, rb = K.Widgets.IconRim()
	local body, rim = false, false
	for _, region in ipairs({ skin:GetRegions() }) do
		local set = region._state.Texture and region._state.Texture[1]
		local r, g, b = region:GetVertexColor()
		if type(r) == "number" and set == (K.Tokens.Texture("chamferTile")) and math.abs(r - fr) < 1e-3 and math.abs(g - fg) < 1e-3 and math.abs(b - fb) < 1e-3 then
			body = true
		elseif type(r) == "number" and math.abs(r - rr) < 1e-3 and math.abs(g - rg) < 1e-3 and math.abs(b - rb) < 1e-3 then
			rim = true
		end
	end
	assert(body, "the tile's body is the near-black button fill every square icon shares")
	assert(rim, "its hairline rests on the accent rim, as an action button")
end

-- The dispel highlight: a slot for debuffs the player can dispel, drawn as a coloured border over the frame.
local slot = f.highlights._slots.dispel
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
eq(container._policyOptions.displayOnlyDispellableDebuffs, true, "only debuffs you can dispel")
K.Options.Write("GroupFrames", "auras.filter", "RAID")
eq(group.filter, "HARMFUL|RAID_IN_COMBAT", "debuffs Blizzard shows on raid frames")
eq(dispels.filter, "HARMFUL|RAID_IN_COMBAT", "for both groups")
eq(container._policyOptions.displayOnlyDispellableDebuffs, false, "back to all kinds")
K.Options.Write("GroupFrames", "party.auraDispelCount", 0)
eq(dispels.enabled, false, "no dispellable debuff icons at a count of 0")
K.Options.Write("GroupFrames", "party.auraDispelCount", 2)
eq(dispels.enabled, true, "dispellable debuff icons come back")
eq(dispels.maxFrameCount, 2, "two dispellable debuffs")
K.Options.Write("GroupFrames", "party.auraColumns", 2)
K.Options.Write("GroupFrames", "party.auraRows", 1)
eq(group.maxFrameCount, 3, "the count stops at columns times rows, plus one for the overflow mark")
K.Options.Write("GroupFrames", "auras.dispelFilter", "GROUP")
eq(slot.filter, "HARMFUL|RAID_PLAYER_DISPELLABLE", "debuffs anyone in the group can dispel")
K.Options.Write("GroupFrames", "party.auraSize", 24)
local w = button:GetSize()
eq(w, 24, "the icons resize")
eq(group.layout.elementWidth, 24, "and the layout follows")
K.Options.Write("GroupFrames", "auras.enabled", false)
eq(group.enabled, false, "debuff icons switch off")
eq(dispels.enabled, false, "dispellable icons too")
eq(container:IsShown(), true, "the dispel highlight stays while it is on")
eq(container._unit, "party1", "and keeps following the unit")
K.Options.Write("GroupFrames", "auras.dispelHighlight", false)
eq(container:IsShown(), true, "the boss debuff glow still needs the container")
K.Options.Write("GroupFrames", "auras.glow", false)
eq(container:IsShown(), false, "with all three off the container hides")
eq(container._unit, "none", "and stops following the unit")
K.Options.Write("GroupFrames", "auras.enabled", true)
K.Options.Write("GroupFrames", "auras.dispelHighlight", true)
eq(container:IsShown(), true, "debuffs switch back on")
eq(group.enabled, true, "the debuff group comes back")
eq(container._unit, "party1", "and follow the unit again")

-- A scale change redraws the dispel border in whole pixels.
local corner = f.dispelRing[1][1]
local sizes = 0
for _, call in ipairs(corner._calls) do
	sizes = sizes + (call.method == "SetSize" and 1 or 0)
end
K.Callbacks.Fire("ScaleChanged")
local after = 0
for _, call in ipairs(corner._calls) do
	after = after + (call.method == "SetSize" and 1 or 0)
end
assert(after > sizes, "ScaleChanged lays the dispel border out again")
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
