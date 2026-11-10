-- test-hud-material-tank.lua: the raw Tank reference HUD draws every card in ForgedBrackets.
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local cards = Lib.Audit(Lib.Build("Tank", "ForgedBrackets"), "ForgedBrackets", Lib.ROLES.Tank)
assert(#cards == #Lib.ROLES.Tank, "Tank draws " .. #Lib.ROLES.Tank .. " cards, got " .. #cards)
print("ok test-hud-material-tank")
