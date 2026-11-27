-- test-actionbars-crest-floor.lua: the crest plan's Part 4 readability floor: every class, in every form, with every piece known, draws each state-carrying part of a crest piece at 16 hub units or more: each fill or drain bar (a gem's liquid, a pip, a vial, a figure's light), each cooldown sweep it shows, each cooldown sigil, each Clearcasting leaf and each shaman imbue stone.
local F = dofile("Tools/regression/crest_armory_fixture.lua")

local FLOOR = 16
local FORMS = { WARRIOR = { 17, 18, 19 }, DRUID = { 0, 1, 5, 31 }, ROGUE = { 0, 30 }, PRIEST = { 0, 28 } }

local function Part(part, marks)
	local kind = part.GetObjectType and part:GetObjectType()
	if kind == "StatusBar" then
		return "bar"
	elseif kind == "Cooldown" then
		local swipe = part._state and part._state.DrawSwipe
		return not (swipe and swipe[1] == false) and "sweep" or nil
	end
	local texture = kind == "Texture" and part._state and part._state.Texture
	return texture and marks[texture[1]]
end

local checked = 0
for _, class in ipairs({ "WARRIOR", "PALADIN", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN" }) do
	local env, K, ns = F.New(class, {})
	setmetatable(env._known, { __index = function() return true end })
	local marks = { [(K.Tokens.Texture("trackerLeaf"))] = "leaf", [(K.Tokens.Texture("trackerStone"))] = "imbue stone" }
	for _, form in ipairs(FORMS[class] or { 0 }) do
		env._form = form
		env.FireEvent("UPDATE_SHAPESHIFT_FORM")
		env.FireEvent("SPELLS_CHANGED")
		env.RunTimers()
		for _, p in pairs(ns.SlabTrackers.state.forms.crest.pieces) do
			local where = class .. " form " .. form .. " " .. tostring(p.spec.key)
			for _, part in ipairs(p.parts or {}) do
				local what = Part(part, marks)
				if what and part.units then
					assert(part.units >= FLOOR, where .. ": " .. what .. " drawn at " .. part.units .. " units")
					checked = checked + 1
				end
			end
			for _, sigil in ipairs(p.sigils or {}) do
				assert(sigil.units >= FLOOR, where .. ": a cooldown sigil drawn at " .. sigil.units .. " units")
				checked = checked + 1
			end
		end
		F.Clean(env, K, class .. " form " .. form)
	end
end
assert(checked > 200, "only " .. checked .. " state-carrying parts measured")

print("test-actionbars-crest-floor: ok (" .. checked .. " parts)")
