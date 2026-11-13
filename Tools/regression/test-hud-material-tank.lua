-- test-hud-material-tank.lua: the raw Tank reference HUD draws every card in ForgedBrackets, the threat card as the quest card with no warning outline (KSTY-60 item 23).
collectgarbage("setpause", 120)
collectgarbage("collect")
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local rims = {}
for _, card in ipairs(Lib.Audit(Lib.Build("Tank", "Glass"), "Glass", Lib.ROLES.Tank)) do
	if card.role == "meters.threat" or card.role == "meters.damage" then
		assert(card.drawn.rim and #card.drawn.rim > 0 and not card.drawn.materialEdge, "under Glass the " .. card.role .. " card draws its rounded rim")
		rims[card.role] = card.drawn.rim[1].vertex
	end
end
local threatRim, damageRim = rims["meters.threat"], rims["meters.damage"]
assert(threatRim and damageRim, "the Tank HUD draws the threat and damage cards")
for i = 1, 4 do
	assert(math.abs(threatRim[i] - damageRim[i]) < 1e-4, "the Glass threat card's rim is the damage card's, with the warning on the count instead")
end
collectgarbage("collect")

local cards = Lib.Audit(Lib.Build("Tank", "ForgedBrackets"), "ForgedBrackets", Lib.ROLES.Tank)
assert(#cards == #Lib.ROLES.Tank, "Tank draws " .. #Lib.ROLES.Tank .. " cards, got " .. #cards)
local outlined = {}
for _, card in ipairs(cards) do
	if card.drawn.materialEdge then
		outlined[#outlined + 1] = card.role
	end
end
assert(#outlined == 0, "no card outlines its forged frame, the threat card's warning included, got " .. table.concat(outlined, ", "))
print("ok test-hud-material-tank")
