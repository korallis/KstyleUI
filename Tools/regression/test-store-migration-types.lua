-- test-store-migration-types.lua: LEE-1462: no migration raises on a wrong-typed key or value, and a profile stuck at version 29 by a non-string layout key reaches the current version on its next login.
local C = dofile("Tools/regression/core_env.lua")

local HOSTILE_VALUES = { 7, 0 / 0, true, "x", {}, { {}, x = {} } }
local HOSTILE_KEYS = { 1, 2.5, true }
local HOSTILE_ENTRIES = { { x = 1 }, 5, {} }
local FIRST, LAST = 2, 34

local probe, K = C.New()
C.Boot(probe)

local function fixture()
	local placed = {}
	for key, place in pairs(K.Setup.Layouts.Get("DPS")) do
		placed[key] = { anchor = place.anchor, x = place.x, y = place.y, width = 100, height = 20 }
		placed["Orbs:" .. key] = { anchor = place.anchor, x = place.x + 1, y = place.y }
	end
	return {
		version = 1,
		account = {},
		characters = { ["Realm-Name"] = "Default" },
		profiles = {
			Default = {
				Layout = { preset = "Healer" },
				Appearance = { font = "Folio", reducedMotion = true, uiScale = 0.8 },
				Chat = { fontSize = 12, tabStyle = "plain" },
				ActionBars = { bar4 = { showEmpty = true, size = 37, spacing = 4 }, bar1 = { size = 36.7, spacing = 4.6 }, pet = { rows = 2 } },
				UnitFrames = { player = { style = "lumen", castbarTexture = "Glass", fonts = { name = { size = 17 } } }, target = { style = "lumen", fonts = { health = { size = 12 } } }, boss = { auraPosition = "RIGHT" } },
				GroupFrames = { party = { height = 46, spacing = 8 }, raid = { width = 77, height = 40 } },
				Minimap = { compass = true, coords = { position = "x", outline = "" }, column = { hover = false }, zone = { outline = "" } },
				DataBars = { strip = { menus = false, outline = "NONE" }, micro = { size = 30 }, xp = { text = "x", colorSource = "gilt", segments = 0, outline = "NONE", restedColor = { r = 1, g = 1, b = 1, a = 0.5 } } },
				Auras = { card = true, buffs = { rows = 1, iconSize = 28 }, debuffs = { dispelFirst = true, spacing = 3 } },
				Nameplates = { name = { size = 12 }, target = { color = { r = 1, g = 1, b = 1 } } },
				Cooldowns = { accent = "class", essential = { size = 38 } },
				HudStyle = { style = "bogus" },
				QoL = {},
				Icons = {},
			},
			Tank = { Layout = { preset = "Tank" } },
			Placed = { Layout = { preset = "Healer" } },
		},
		layouts = {
			Default = {
				["unitframes.player"] = { x = 5 },
				["unitframes.boss"] = { y = 3 },
				["unitframes.castbar.target"] = { anchor = "TOP", x = 1, y = 2, height = 24 },
				["Orbs:unitframes.player"] = { x = 4 },
				["groupframes.party"] = { anchor = "LEFT", x = 3, y = 4 },
				["groupframes.raid"] = { x = 1 },
				["chat.main"] = { width = 372, height = 260 },
				["nameplates.plate"] = { width = 154, height = 12 },
				["meters.damage"] = { anchor = "TOPRIGHT", x = -28, y = -236 },
				["meters.threat"] = { x = 2 },
				["meters.swing"] = { anchor = "BOTTOM", x = 0, y = 376.5 },
				["minimap.main"] = { anchor = "TOPRIGHT", x = -28, y = -28, width = 160, height = 160 },
				["databars.xp"] = { height = 8, width = 491 },
				["actionbars.bar3"] = { x = 6 },
				["actionbars.bar4"] = { anchor = "RIGHT", x = -362, y = 0 },
				["auras.buffs"] = { x = 2 },
				["qol.lootfeed"] = { x = 2 },
				["cooldowns.essential"] = { x = 2 },
			},
			Tank = { ["unitframes.player"] = { x = 5 }, ["meters.threat"] = { x = 2 } },
			Placed = placed,
		},
	}
end

local function run(data, label)
	for version = FIRST, LAST do
		local step = K.Store.migrations[version]
		if step then
			local ok, err = pcall(step, data)
			assert(ok, string.format("migration %d raised on %s: %s", version, label, tostring(err)))
		end
	end
end

local function tablePaths(node, path, out)
	out[#out + 1] = path
	for key, value in pairs(node) do
		if type(key) == "string" and type(value) == "table" then
			local child = { unpack(path) }
			child[#child + 1] = key
			tablePaths(value, child, out)
		end
	end
	return out
end

local function at(root, path)
	local node = root
	for i = 1, #path do
		node = node[path[i]]
	end
	return node
end

local cases = 0
for _, path in ipairs(tablePaths(fixture(), {}, {})) do
	if #path > 0 then
		local keys = {}
		for key in pairs(at(fixture(), path)) do
			keys[#keys + 1] = key
		end
		for _, key in ipairs(keys) do
			for _, value in ipairs(HOSTILE_VALUES) do
				local data = fixture()
				at(data, path)[key] = C.DeepCopy(value)
				run(data, table.concat(path, ".") .. "." .. tostring(key) .. " = " .. tostring(value))
				cases = cases + 1
			end
		end
		for _, key in ipairs(HOSTILE_KEYS) do
			for _, value in ipairs(HOSTILE_ENTRIES) do
				local data = fixture()
				at(data, path)[key] = C.DeepCopy(value)
				run(data, table.concat(path, ".") .. "[" .. tostring(key) .. "] = " .. tostring(value))
				cases = cases + 1
			end
		end
	end
end
assert(cases > 1000, "the sweep covers the fixture, ran " .. cases)

local function stuck(extra)
	local layout = { ["unitframes.castbar.target"] = { height = 24 }, ["unitframes.player"] = { x = 5 } }
	for key, value in pairs(extra) do
		layout[key] = value
	end
	return { saved = { version = 29, profiles = { Default = { Layout = { preset = "DPS" } } }, layouts = { Default = layout } } }
end

for label, extra in pairs({
	number = { [1] = { x = 1 } },
	float = { [2.5] = { anchor = "TOP", x = 1, y = 1 } },
	boolean = { [true] = { x = 1 }, [false] = 5 },
	mixed = { [1] = 7, [2] = { height = 24 }, [true] = { anchor = "TOP", x = 1 } },
}) do
	local env, KS = C.New(stuck(extra))
	C.Boot(env)
	assert(env.KstyleUIDB.version == KS.Store.DB_VERSION, label .. ": a profile at version 29 with a non-string layout key reaches the current version, stayed at " .. tostring(env.KstyleUIDB.version))
	assert(KS.ErrorCount() == 0, label .. ": the migrations finish without errors")
	local layout = env.KstyleUIDB.layouts.Default
	assert(layout["unitframes.castbar.target"] == nil, label .. ": the string-keyed entries still migrate beside the odd key")
	for key, value in pairs(extra) do
		assert(C.DeepEqual(layout[key], value), label .. ": the odd key " .. tostring(key) .. " is left as it was")
	end
end

local env28, K28 = C.New({ saved = { version = 28, profiles = { Default = { Layout = { preset = "Healer" } } }, layouts = { Default = { ["unitframes.boss"] = 7 } } } })
C.Boot(env28)
assert(env28.KstyleUIDB.version == K28.Store.DB_VERSION and K28.ErrorCount() == 0, "a non-table boss layout entry no longer stops migration 29")

local own = { profiles = { Default = { Layout = { preset = "DPS" } } }, layouts = { Default = { [1] = { x = 1 }, ["unitframes.player"] = { x = 5 } } } }
K.Store.migrations[30](own)
local player = own.layouts.Default["unitframes.player"]
assert(player.anchor ~= nil and player.y ~= nil and player.x == 5, "migration 30 still completes a partly saved place beside an odd key")
assert(C.DeepEqual(own.layouts.Default[1], { x = 1 }), "migration 30 leaves the odd key as it was")

print("store migration types ok (" .. cases .. " sweep cases)")
