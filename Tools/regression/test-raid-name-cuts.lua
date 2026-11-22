local G = dofile("Tools/regression/group_env.lua")
local env, K, ns = G.New()
local Names = ns.Names
local others = { "LongsharedprefixAlice", "LongsharedprefixBrent" }
local function fits(name) return #name <= 9 end
local a = Names.Short(others[1], fits, others, "")
local b = Names.Short(others[2], fits, others, "")
assert(a ~= b and not a:find("...", 1, true) and not b:find("...", 1, true), "letter cuts retain clash disambiguation")
assert(fits(a) and fits(b), "disambiguated names fit the lane")
local name = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
K.Widgets.ApplyFont(name, K.Tokens.Font("body"), 11, "")
name.GetUnboundedStringWidthForText = function(_, text) return #text * 10 end
local f = { rawName = "LongsharedprefixAlice", name = name, nameWidth = 89.5, nameLetterCut = true,
	others = others, nameFit = { size = 11, min = 11, slack = 0.5, set = function() end } }
Names.Apply(f)
assert(#name:GetText() == 9, "letter cuts use the fitter's half-pixel slack")
G.SetRoster(env, "raid", G.Members(10))
K.Modules.Enable("GroupFrames")
env.RunTimers()
local shown, index = {}, 0
ns.Unit.ForEach(function(tile)
	if tile.kind == "raid" and tile.unit and index < 2 then
		index = index + 1
		tile.rawName, tile.others, tile.nameWidth = others[index], others, 55
		Names.Apply(tile)
		shown[index] = tile.name:GetText()
	end
end)
assert(index == 2 and shown[1] ~= shown[2], "live raid tiles sharing a long prefix must have distinct cut names")
assert(#env._errors == 0, tostring(env._errors[1]))
print("raid name cuts preserve clashes and slack")
