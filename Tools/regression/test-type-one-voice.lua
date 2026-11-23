-- test-type-one-voice.lua: One typeface voice and Soft glow behind world text are on by default: Medallions plate names and cast names share the number face, a plate name sits on a three-piece halo that follows the name's setting, alpha and the switch, outlined text casts the kit's drop shadow, and switching each Appearance setting off restores Inter, the caps face, no halo and no shadow.
local N = dofile("Tools/regression/nameplates_env.lua")

local function file(path)
	return (tostring(path):match("([^\\/]+)$"))
end

local env, K, ns = N.New()
local function set(module, key, value)
	K.Options.Write(module, key, value)
	env.RunTimers()
end

N.Add(env, "nameplate1", { name = "Decrepit Darkhound", level = 12, reaction = 2, canAttack = true })
env.RunTimers()
local plate = ns.Plates.Get("nameplate1")
local number = (K.Tokens.Font("number"))
assert(K.Appearance.Get("oneVoice") == true and K.Appearance.Get("softBacking") == true, "both settings are on by default")
assert(file(number) == "BarlowSemiCondensedTabular-SemiBold.ttf", "under Medallions the number face is Barlow")
assert(plate.name:GetFont() == number, "the plate name shares the number face")
assert(plate.castName:GetFont() == number, "the plate's cast name shares it too")

local halo = plate.name.halo
assert(type(halo) == "table" and #halo == 3, "the name sits on a three-piece halo")
local function shown()
	return halo[1]:IsShown() and halo[2]:IsShown() and halo[3]:IsShown()
end
local function hidden()
	return not (halo[1]:IsShown() or halo[2]:IsShown() or halo[3]:IsShown())
end
assert(shown(), "the halo shows behind a shown name")
assert(halo[2]:GetParent() == plate and halo[2]:GetDrawLayer() == "BACKGROUND", "the halo is drawn under the plate's art")
local sx, sy = plate.name:GetShadowOffset()
assert(sx > 0 and sy < 0 and select(3, plate.name:GetFont()) == "OUTLINE", "the outlined name casts the kit's drop shadow")

plate:SetNameAlpha(0)
assert(hidden(), "a name faded out while casting takes its halo with it")
plate:SetNameAlpha(1)
assert(shown(), "and brings it back")
set("Nameplates", "name.show", false)
assert(hidden(), "hidden names leave no halo")
set("Nameplates", "name.show", true)
assert(shown(), "shown names get it back")

set("Appearance", "softBacking", false)
assert(hidden(), "off hides the halo")
sx, sy = plate.name:GetShadowOffset()
assert(sx == 0 and sy == 0, "off: the outline alone, as before")
set("Appearance", "oneVoice", false)
assert(file(plate.name:GetFont()) == "Inter-SemiBold.ttf", "off: the plate name is Inter SemiBold again")
assert(plate.castName:GetFont() == (K.Tokens.Font("caps")), "off: the cast name is the caps face again")

N.Add(env, "nameplate2", { name = "Rotting Dead", level = 6, reaction = 2, canAttack = true })
env.RunTimers()
assert(ns.Plates.Get("nameplate2").name.halo == nil, "no halo pieces are made while the setting is off")

set("Appearance", "softBacking", true)
set("Appearance", "oneVoice", true)
assert(shown() and plate.name:GetFont() == number, "switching both back on restores the halo and the number face")
assert(ns.Plates.Get("nameplate2").name.halo, "a plate built while it was off gets its halo")

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("ok - test-type-one-voice")
