-- test-groupframes-overflow.lua: the "+" mark takes the colour of the first hidden debuff's category, and dispellable debuffs past the dispel count raise their own "+" through a hidden engine container, read by anchors alone, so a saturated dispel category never vanishes silently.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box, what)
	assert(r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01,
		what .. string.format(" [%.1f %.1f %.1f %.1f] inside [%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4], box[1], box[2], box[3], box[4]))
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local function Batch(e, K, settings)
	local root = K.Store.Module("GroupFrames")
	for _, kv in ipairs(settings) do
		local node, parts = root, {}
		for part in kv[1]:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = type(node[parts[i]]) == "table" and node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = kv[2]
	end
	e.SetQuiet(true)
	K.Callbacks.Fire("SettingChanged", "GroupFrames", settings[#settings][1], settings[#settings][2])
	e.SetQuiet(false)
end

-- The engine sizes a container to its laid-out content (CustomAuraContainerFlowLayoutMixin:OnLayoutComplete): the
-- ghost stacks one element per line, so its height is the shown frames times the pitch.
local function Settle(e, more, shown)
	local group = more.ghost._groups[more.key]
	local want = A.Assign(e, more.ghost, more.key, shown)
	local pitch = group.layout.elementHeight
	more.ghost:SetSize(1, math.max(0, want) * pitch)
	return want
end

local function Check(e, K, ns, f, what)
	local Tokens = K.Tokens
	local function color(text, token, label)
		local r, g, b = text:GetTextColor()
		local wr, wg, wb = Tokens.Color(token)
		assert(W.Near(r, wr) and W.Near(g, wg) and W.Near(b, wb), what .. ": " .. label .. " in the " .. token .. " colour")
	end
	-- Fable R3 aura table, Muse #4, Grok #5: the mark says which category the hidden debuffs start with. The flow runs
	-- in the player's priority order, so the first hidden debuff's category is the worst one hidden.
	local groups = f.auras._groups
	local want = { boss = "hostile", important = "neutral", dispels = "rare", debuffs = "textEmphasis" }
	for key, token in pairs(want) do
		local group = groups[key]
		A.Assign(e, f.auras, key, group.maxFrameCount)
		for i = 1, group.maxFrameCount do
			local parts = ns.Auras.Parts(group.frames[i])
			ns.Auras.StyleIcon(group.frames[i])
			eq(parts.mark:GetText(), "+", what .. ": " .. key .. " carries the mark")
			color(parts.mark, token, key .. "'s mark")
		end
	end
	-- Astra R3 #3B: the dispel category caps at the dispel count, so the engine gives it one more frame in a hidden
	-- container; that frame exists only while more dispellable debuffs are up, and its anchor raises the "+".
	local more = f.dispelMore
	assert(more, what .. ": the frame has a dispel overflow ghost")
	local k = ns.Settings.current[f.kind]
	local group = more.ghost._groups[more.key]
	eq(group.filter, groups.dispels.filter, what .. ": the ghost watches the debuffs the row does")
	eq(group.candidateFilters.processedAuraType, groups.dispels.candidateFilters.processedAuraType, what .. ": dispellable ones")
	eq(group.candidateFilters.isBossAura, false, what .. ": not boss ones")
	eq(group.candidateFilters.isPriorityAura, false, what .. ": not priority ones")
	local shownDispels = groups.dispels.maxFrameCount
	eq(group.maxFrameCount, shownDispels + 1, what .. ": one frame more than the row shows")
	assert(group.enabled, what .. ": the ghost is on")
	local window, face = { Scene.Rect(e, more.window) }, more.face
	inside(window, { Scene.Rect(e, f.auraClip) }, what .. ": the dispel mark sits on the debuff block")
	eq(more.text:GetText(), "+", what .. ": the dispel mark")
	color(more.text, "rare", "the dispel mark")
	-- Dispel-only, eight or more: every count past the dispel row raises the mark, any count within it does not.
	for _, count in ipairs({ 0, shownDispels, shownDispels + 1, 8, 12 }) do
		Settle(e, more, count)
		local lit = intersects({ Scene.Rect(e, face) }, window)
		eq(lit, count > shownDispels, what .. ": " .. count .. " dispellable debuffs " .. (lit and "raise" or "raise no") .. " mark")
		if lit then
			inside({ Scene.Rect(e, face) }, window, what .. ": the raised mark fills its window")
		end
	end
	-- The dispel mark draws above the marks of every category the player ranks below dispellable debuffs.
	local order = ns.Auras.Order()
	local level = more.face:GetFrameLevel()
	for key, rank in pairs(order) do
		local parts = ns.Auras.Parts(groups[key].frames[1])
		local markLevel = parts.mark:GetParent():GetFrameLevel()
		if rank > order.dispels then
			assert(level > markLevel, what .. ": the dispel mark draws above " .. key .. "'s")
		elseif rank < order.dispels then
			assert(level < markLevel, what .. ": " .. key .. "'s mark draws above the dispel mark")
		end
	end
	return k
end

-- Party: the shared environment, the tank's frame.
local env, K, ns = G.New()
G.SetRoster(env, "party", {
	{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 92 },
	{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 87 },
})
assert(K.Modules.Enable("GroupFrames"))
env.RunTimers()
local tank = content(ns, ns.Headers.party, "party1")
Check(env, K, ns, tank, "party")

-- Codex review, round 3: with boss debuffs ranked just above dispellable ones, the dispel badge still draws below the
-- boss mark, and above the dispel row's own.
Batch(env, K, { { "auras.priority1", "BOSS" }, { "auras.priority2", "DISPEL" } })
Check(env, K, ns, tank, "party, boss first")
Batch(env, K, { { "auras.priority1", "DISPEL" }, { "auras.priority2", "BOSS" } })

-- Owner, round 3: a healer's preset shows two dispellable debuffs first; the ghost follows the count.
Batch(env, K, { { "party.auraDispelCount", 2 } })
eq(tank.dispelMore.ghost._groups[tank.dispelMore.key].maxFrameCount, 3, "party, two dispels first: the ghost watches for a third")
Check(env, K, ns, tank, "party, two dispels")

-- A dispel count of 0 gives dispellable debuffs no row of their own, so the other debuffs take them, and the ghost
-- turns off: nothing is capped, so the shared "+" says the rest.
Batch(env, K, { { "party.auraDispelCount", 0 } })
local others = tank.auras._groups.debuffs.candidateFilters
eq(others.processedAuraType, nil, "with no dispel row the other debuffs take dispellable ones too")
eq(others.isBossAura, false, "still leaving boss debuffs to their row")
eq(tank.auras._groups.dispels.enabled, false, "the dispel row is off")
eq(tank.dispelMore.ghost._groups[tank.dispelMore.key].enabled, false, "and so is its ghost")
Batch(env, K, { { "party.auraDispelCount", 1 } })
eq(tank.auras._groups.debuffs.candidateFilters.processedAuraType, env.AuraUtil.AuraUpdateChangedType.Debuff, "with a dispel row back, the other debuffs leave dispellable ones to it")
eq(#env._errors, 0, tostring(env._errors[1]))

-- Raid: the same checks on a 72 by 40 tile, where the block is two 12-unit cells at the bottom left.
do
	local renv, RK, rns = G.New()
	G.SetRoster(renv, "raid", G.Members(10))
	assert(RK.Modules.Enable("GroupFrames"))
	renv.RunTimers()
	local f = content(rns, rns.Headers.raid[1], "raid1")
	Check(renv, RK, rns, f, "raid")
	eq(#renv._errors, 0, tostring(renv._errors[1]))
end

print("groupframes overflow ok")
