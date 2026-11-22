-- test-unitframes-clean-bars.lua: acceptance pass 1 (KSTY-60 items 1, 3, 4 and 22) on the Medallions frames: target health from the left, no card or brackets round the boss frames or the Targeted chip, the sub-labels in the label grey, old saved cast heights and the resource place migrated, and the damage rows' lit top edge.
local U = dofile("Tools/regression/unitframes_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.01)
end

local function withEnum(env)
	env.Enum = env.Enum or {}
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
end

local function saved(style, frames)
	local profile = { UnitFrames = frames or { enabled = true } }
	return { version = 32, profiles = { Default = profile }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function noErrors(env, K, where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local TARGET = { name = "Shadowgale Poacher", level = 12, health = 118, healthMax = 236, reaction = 2, canAttack = true, creature = "Humanoid", power = 10, powerMax = 100 }

-- Item 3: the target fills from the left.
do
	local env, K, ns = U.New({ saved = saved("frames"), setup = withEnum })
	U.SetUnit(env, "target", TARGET)
	env.SetTarget(true)
	assert(ns.Settings.Value("target", "healthOrientation") == "RIGHT", "the target's health fills from the left, as both mock-ups draw it")
	local target = ns.Frames.Get("target").views[1]
	assert(target.health:GetReverseFill() ~= true, "the target's health bar is not reversed")
	noErrors(env, K, "frames")
end

-- Item 1: the boss frames lay out no glass card, and the folded boss chip wears none. Known: the Medallions boss scrim
-- runs past the 6-unit gap to the next boss.
do
	local env, K, ns = U.New({ saved = saved("frames"), setup = withEnum })
	for i = 1, 2 do
		U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
	end
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	env._units.target = env._units.boss1
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	for i, view in ipairs(ns.Frames.Get("boss").views) do
		if i <= 2 then
			assert(not view.chrome.visible, "boss " .. i .. " shows no card")
			assert(view.scrim:IsShown(), "boss " .. i .. " reads on the world over the soft scrim")
		end
	end
	local chip = ns.Frames.Get("boss").views[1].chip
	assert(not chip.chrome.visible, "the Targeted chip has no card")
	noErrors(env, K, "boss")
end

-- Item 22: the type word and the dimmed value read in the Medallions label colour, a cool grey.
do
	local env, K, ns = U.New({ saved = saved("frames"), setup = withEnum })
	U.SetUnit(env, "target", TARGET)
	env.SetTarget(true)
	local view = ns.Frames.Get("target").views[1]
	local sr, sg, sb = K.Tokens.Color("labelMuted")
	for _, key in ipairs({ "caption", "healthSub" }) do
		local r, g, b = view[key]:GetTextColor()
		assert(near(r, sr, 1e-6) and near(g, sg, 1e-6) and near(b, sb, 1e-6), key .. " takes the Medallions label token")
	end
	assert(sr <= sb, "the caption follows the shared cool grey")
	noErrors(env, K, "sub-label")
end

-- Item 4 for the cast elements: a saved layout that kept the old default height lets the new one through.
do
	local env, K = U.New({ saved = saved("frames"), setup = withEnum })
	local data = {
		version = 30, profiles = {}, layouts = {
			Default = {
				["unitframes.castbar.player"] = { height = 30 },
				["unitframes.castbar.target"] = { height = 24 },
				["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = K.Setup.Layouts.CastMoves()["unitframes.resource"][3] },
				["orbs:unitframes.castbar.target"] = { height = 24, x = 4 },
			},
		},
	}
	K.Store.migrations[32](data)
	local layout = data.layouts.Default
	assert(layout["unitframes.castbar.target"] == nil, "the target cast bar's old default height goes")
	assert(layout["orbs:unitframes.castbar.target"].height == nil and layout["orbs:unitframes.castbar.target"].x == 4, "a style's old default height goes, its place stays")
	assert(layout["unitframes.castbar.player"].height == 30, "the player cast bar keeps its 30-unit element")
	assert(layout["unitframes.resource"] == nil, "a class resource saved at its old default follows the new one, clear of the cast label")
	local now = K.Setup.Layouts.Get("DPS")["unitframes.resource"]
	assert(near(now.y, K.Setup.Layouts.CastMoves()["unitframes.resource"][3] + 1), "the new default stands one unit higher")
	noErrors(env, K, "migration")
end

-- Item 4 for the damage card: its full-height rows keep the fill's lit top edge and shade.
do
	local M = dofile("Tools/regression/meters_env.lua")
	local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
	env._session = { combatSources = { { name = "Kragar", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0 } }, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
	M.Enable(env, K)
	local row = ns.Damage.list.rows[1]
	assert(row and row.bar.lit and row.bar.lit:IsShown(), "a damage row's fill keeps its lit top edge")
	assert(row.bar.shade:IsShown() or type(env.CreateColor) ~= "function", "and its shade, where the client can draw it")
	noErrors(env, K, "meters")
end

print("ok unit frames clean bars")
