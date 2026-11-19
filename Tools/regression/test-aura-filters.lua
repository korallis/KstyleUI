-- test-aura-filters.lua: the three aura surfaces keep their defaults, share filter controls and update the engine and overflow counters together at every owner screen size.
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local G = dofile("Tools/regression/group_env.lua")

local function Lists(group)
	local c = assert(group.candidateFilters, "spell lists reach the engine")
	assert(c.includeSpellIDs[774] and c.includeSpellIDs[139], "plain numeric spell IDs are allowed")
	assert(c.includeSpellIDs[1] == nil and c.includeSpellIDs[2] == nil, "fractions and links are not spell IDs")
	assert(c.excludeSpellIDs[139], "blocking wins when a spell occurs in both lists")
end

local function Rows(K, module, prefix, sort)
	for _, key in ipairs({ "onlyMine", "dispellable", "allowSpells", "blockSpells", sort }) do
		assert(K.Options.Row(module, prefix .. "." .. key), module .. " shares the filter rows")
	end
end

local function Change(env, K, module, prefix)
	local function write(key, value)
		K.Options.Write(module, prefix .. "." .. key, value)
		env.RunTimers()
	end
	write("onlyMine", true)
	write("dispellable", true)
	write("allowSpells", "774, 139 774 1.2 spell:2 -3")
	write("blockSpells", "139")
	return write
end

for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	do
		local env, K, ns = A.New({ width = size[1], height = size[2] })
		K.Modules.Enable("Auras")
		env.RunTimers()
		local desc = ns.Panel.Group("debuffs")
		local group = desc.container._groups.debuffs
		assert(group.filter == "HARMFUL" and group.candidateFilters == nil, "player debuffs keep today's filter")
		assert(group.sortMethod == env.AuraContainerSortMethod.UnitFrameDebuff, "player debuffs keep today's sort")
		Rows(K, "Auras", "debuffs", "sort")
		Rows(K, "Auras", "buffs", "sort")
		local write = Change(env, K, "Auras", "debuffs")
		assert(group.filter == "HARMFUL|PLAYER|RAID")
		Lists(group)
		Lists(desc.chip.pairs[1].a._groups.count)
		write("sort", "name")
		assert(group.sortMethod == env.AuraContainerSortMethod.NameOnly)
		write("onlyMine", false)
		write("dispellable", false)
		write("allowSpells", "")
		write("blockSpells", "")
		assert(group.filter == "HARMFUL" and group.candidateFilters == nil, "off removes the optional filters")
		assert(desc.chip.pairs[1].a._groups.count.candidateFilters == nil, "off clears the counting filter too")
		K.Modules.Disable("Auras")
		assert(not desc.host:IsShown(), "the disabled module draws no aura row")
	end
	do
		local env, K, ns = N.New({ width = size[1], height = size[2] })
		N.Add(env, "nameplate1")
		local plate = ns.Plates.Get("nameplate1")
		local group = plate.auras._groups.debuffs
		assert(group.filter == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", "nameplates keep only your debuffs by default")
		assert(group.sortMethod == env.AuraContainerSortMethod.ImportantOnly, "nameplates keep their existing sort")
		Rows(K, "Nameplates", "debuffs", "order")
		local write = Change(env, K, "Nameplates", "debuffs")
		assert(group.filter == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY|RAID")
		Lists(group)
		Lists(plate.auraChip.pairs[1].a._groups.count)
		write("order", "longest")
		assert(group.sortMethod == env.AuraContainerSortMethod.ExpirationOnly and group.sortDirection == env.AuraContainerSortDirection.Reverse)
		write("onlyMine", false)
		write("dispellable", false)
		write("allowSpells", "")
		write("blockSpells", "")
		assert(group.filter == "HARMFUL|INCLUDE_NAME_PLATE_ONLY" and group.candidateFilters == nil, "turning mine off allows other casters")
		write("enabled", false)
		assert(not plate.auras:IsShown(), "the disabled row hides")
	end
	do
		local env, K, ns = G.New({ width = size[1], height = size[2] })
		G.SetRoster(env, "party", { { name = "Healer", class = "PRIEST" } })
		K.Modules.Enable("GroupFrames")
		env.RunTimers()
		local f = ns.Button.Content(ns.Headers.party._attributes.child1)
		local group = f.auras._groups.debuffs
		assert(group.filter == "HARMFUL" and group.candidateFilters.includeSpellIDs == nil, "group frames keep all debuffs by default")
		Rows(K, "GroupFrames", "auras", "sort")
		local write = Change(env, K, "GroupFrames", "auras")
		for _, key in ipairs({ "boss", "important", "dispels", "debuffs" }) do
			local g = f.auras._groups[key]
			assert(g.filter == "HARMFUL|PLAYER|RAID", "every priority lane uses the filter")
			Lists(g)
		end
		for _, pair in ipairs(f.debuffChip.pairs) do
			for _, g in pairs(pair.a._groups) do Lists(g) end
		end
		write("sort", "name")
		assert(group.sortMethod == env.AuraContainerSortMethod.NameOnly)
		write("onlyMine", false)
		write("dispellable", false)
		write("allowSpells", "")
		write("blockSpells", "")
		write("sort", "")
		assert(group.filter == "HARMFUL" and group.candidateFilters.includeSpellIDs == nil)
		assert(group.sortMethod == env.AuraContainerSortMethod.UnitFrameDebuff, "current style restores the original ordering")
		write("filter", "DISPELLABLE")
		assert(group.filter == "HARMFUL|RAID", "the old saved filter still works")
		write("enabled", false)
		assert(not group.enabled, "turning debuffs off disables the lane")
	end
end

do
	local env, K = A.New()
	local base = { excludeSpellIDs = { [42] = true }, processedAuraType = 3 }
	local c = K.Options.AuraCandidates({ allowSpells = "774", blockSpells = "139" }, base)
	assert(c.excludeSpellIDs[42] and c.excludeSpellIDs[139] and c.processedAuraType == 3, "lists preserve existing engine candidates")
	assert(base.excludeSpellIDs[139] == nil, "shared tracked spell sets are not mutated")
	assert(K.Options.AuraCandidates({ allowSpells = env.Secret("774") }, base) == base, "a secret setting is never parsed")
	assert(K.Options.AuraCandidates({ allowSpells = "bad, -1, 1.5" }).includeSpellIDs[1] == nil, "invalid input never accidentally allows another spell")
end

print("shared aura filters ok at all four screen sizes")
