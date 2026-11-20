-- test-aura-review.lua: empty spell lists impose no restriction and aura pages offer only supported controls beside their related settings; spell-ID rows stay where the engine matches spell IDs.
local A = dofile("Tools/regression/auras_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")
local G = dofile("Tools/regression/group_env.lua")

local _, K = A.New()
local base = { excludeSpellIDs = { [42] = true } }
for _, value in ipairs({ "", "Corruption", "bad, -1, 1.5, 0", string.rep("9", 400) }) do
	for _ = 1, 2 do
		assert(K.Options.AuraCandidates({ allowSpells = value }, base) == base, "an empty or invalid allow list means no allow list")
		assert(K.Options.AuraCandidates({ blockSpells = value }, base) == base, "an invalid block list adds no candidates")
	end
end
local c = K.Options.AuraCandidates({ allowSpells = "Corruption", blockSpells = "139" }, base)
assert(c.includeSpellIDs == nil and c.excludeSpellIDs[139] and c.excludeSpellIDs[42])

for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, case in ipairs({ { A, "Auras", "buffs" }, { A, "Auras", "debuffs" }, { G, "GroupFrames", "auras" }, { N, "Nameplates", "debuffs" } }) do
		local _, core, ns = case[1].New({ width = size[1], height = size[2] })
		local module, prefix = case[2], case[3]
		if module == "GroupFrames" then
			core.Store.Module(module).auras.sort = "invalid"
			assert(ns.Settings.Get("auras.sort") == "", "sort is checked even before opening Options")
		end
		for _, key in ipairs({ "allowSpells", "blockSpells" }) do
			local row = core.Options.Row(module, prefix .. "." .. key)
			local honoured = module == "Nameplates" or (module == "Auras" and prefix == "buffs")
			assert((row ~= nil) == honoured, "spell-ID rows belong only where the engine matches spell IDs: nameplates and your own buffs")
			if row then assert(row.help:find(module == "Nameplates" and "nameplates" or "buff", 1, true), "spell-ID help names its supported surface") end
		end
		if module == "GroupFrames" then
			assert(core.Options.Row(module, "auras.dispellable") == nil, "reuse Which debuffs instead of a duplicate dispel toggle")
			assert(core.Options.Row(module, "auras.filter"))
		elseif module == "Auras" then
			local schema = core.Options.Get(module)
			for i, row in ipairs(schema) do
				if row.key == prefix .. ".sort" then
					assert(schema[i + 1].key == prefix .. ".reverse", "Sort by stays beside Reverse order")
				end
			end
		end
	end
end
print("aura review fixes ok at all four screen sizes")
