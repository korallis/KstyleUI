-- test-hud-material-tank.lua: the raw Tank reference HUD draws every card in ForgedBrackets.
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local cards = Lib.Audit(Lib.Build("Tank", "ForgedBrackets"), "ForgedBrackets", Lib.ROLES.Tank)
assert(#cards == #Lib.ROLES.Tank, "Tank draws " .. #Lib.ROLES.Tank .. " cards, got " .. #cards)
local outlined = {}
for _, card in ipairs(cards) do
	if card.drawn.rim then
		outlined[#outlined + 1] = card.role
	end
end
assert(#outlined == 1 and outlined[1] == "meters.threat", "only the threat card's warning edge outlines a forged frame, got " .. table.concat(outlined, ", "))
local threat
for _, card in ipairs(cards) do
	threat = card.role == "meters.threat" and card or threat
end
local K = threat.chrome.owner._env.KstyleUI
local r, g, b = K.Tokens.Color("neutral")
for _, item in ipairs(threat.drawn.rim) do
	local v = item.vertex
	assert(math.abs(v[1] - r) < 1e-4 and math.abs(v[2] - g) < 1e-4 and math.abs(v[3] - b) < 1e-4, "the threat card's outline is its neutral warning edge")
end
Lib.ACCENTS["meters.threat"] = nil
assert(not pcall(Lib.AuditCard, threat, "ForgedBrackets"), "an outline over a forged frame with no recorded reason fails the audit")
print("ok test-hud-material-tank")
