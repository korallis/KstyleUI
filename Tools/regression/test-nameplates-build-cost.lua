-- test-nameplates-build-cost.lua: building a plate stays cheap, so a pull of new mobs costs the game little. A plate is made once per nameplate base and kept (Plates.lua), so this is the cost of the first sight of each base: the frames and regions it creates are counted against the KSTY-48 build, and its time under Lua 5.1 against a budget ten times the time measured alone. The perf runner cannot hold this path, because building allocates by nature.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local UNIT = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, raid = 8 }
local PLATES = 40
local MAX_FRAMES, MAX_REGIONS = 108, 170
-- Lua 5.1 on the MacBook Pro takes about 4600 us a plate in the stubs (load 7), most of it the stubs' own CreateFrame;
-- the counts are the KSTY-48 build (102 frames and 162 regions, most of them the effect container's tiles) with a little room.
local BUDGET_US = 50000
local ROUNDS = 3

local function objects(plate)
	local frames, regions = 0, 0
	for _, object in ipairs(A.Descendants(plate)) do
		local kind = object:GetObjectType()
		if kind == "Texture" or kind == "FontString" or kind == "MaskTexture" or kind == "Line" then
			regions = regions + 1
		else
			frames = frames + 1
		end
	end
	return frames, regions
end

local best = math.huge
local perFrame, perRegion
for _ = 1, ROUNDS do
	local env, K, ns = N.New()
	local bases = {}
	for i = 1, PLATES do
		bases[i] = N.Base(env)
	end
	local start = os.clock()
	for i = 1, PLATES do
		N.Add(env, "nameplate" .. i, UNIT, { base = bases[i] })
	end
	local spent = (os.clock() - start) / PLATES * 1e6
	best = math.min(best, spent)
	perFrame, perRegion = objects(ns.Plates.Get("nameplate1"))
	assert(ns.Plates.Get("nameplate" .. PLATES).level:IsShown(), "the fixture built whole plates")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

assert(perFrame <= MAX_FRAMES, string.format("a plate holds at most %d frames, got %d", MAX_FRAMES, perFrame))
assert(perRegion <= MAX_REGIONS, string.format("a plate holds at most %d regions, got %d", MAX_REGIONS, perRegion))
assert(best <= BUDGET_US, string.format("building a plate takes %.0f us, over its %d us budget", best, BUDGET_US))
print(string.format("nameplates build cost ok: %.0f us, %d frames and %d regions a plate", best, perFrame, perRegion))
