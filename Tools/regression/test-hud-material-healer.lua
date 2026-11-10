-- test-hud-material-healer.lua: the raw Healer reference HUD draws every card in ForgedBrackets.
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local cards = Lib.Audit(Lib.Build("Healer", "ForgedBrackets"), "ForgedBrackets", Lib.ROLES.Healer)
assert(#cards == #Lib.ROLES.Healer, "Healer draws " .. #Lib.ROLES.Healer .. " cards, got " .. #cards)
print("ok test-hud-material-healer")
