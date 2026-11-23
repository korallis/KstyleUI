-- test-nameplates-build-cost.lua: cold plate construction stays within addon instruction, frame and region budgets.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local UNIT = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, raid = 8 }
local PLATES = 40
local MAX_FRAMES, MAX_REGIONS = 108, 177

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

local env, K, ns = N.New()
local bases = {}
for i = 1, PLATES do
	bases[i] = N.Base(env)
end
local instructions = dofile("Tools/regression/instruction_budget.lua")(function()
	for i = 1, PLATES do
		N.Add(env, "nameplate" .. i, UNIT, { base = bases[i] })
	end
end, 180000 * PLATES, "cache plate construction and reuse frames", 100) / PLATES
local perFrame, perRegion = objects(ns.Plates.Get("nameplate1"))
assert(ns.Plates.Get("nameplate" .. PLATES).level:IsShown(), "the fixture built whole plates")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))

assert(perFrame <= MAX_FRAMES, string.format("a plate holds at most %d frames, got %d", MAX_FRAMES, perFrame))
assert(perRegion <= MAX_REGIONS, string.format("a plate holds at most %d regions, got %d", MAX_REGIONS, perRegion))
print(string.format("nameplates build cost ok: %.0f addon instructions, %d frames and %d regions a plate", instructions, perFrame, perRegion))
