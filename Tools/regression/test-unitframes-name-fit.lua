-- test-unitframes-name-fit.lua: on the Medallions slab a unit name that does not fit its line steps down to the 9-pixel floor before it truncates, and a name that fits keeps the frame's own size (round 3: Opus #7, Muse #1, Fable R3-9). Text is measured with the kit fonts' real advances.
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")

local env, K, ns = U.New()
env._textWidth = D.TextWidth
local Frames = ns.Frames

local function size(text)
	local _, s = text:GetFont()
	return s
end

-- The Medallions slab names in capitals: a name that does not fit steps its size down to the 9-pixel floor, then
-- truncates there; a name that fits keeps the frame's own size.
local focus = Frames.Get("focus").views[1]
local floor = math.ceil(9 / (K.Scale.AppliedUserScale() * K.Scale.Pixel(1)) - 1e-6) * K.Widgets.Border(focus.name)

U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
local full = size(focus.name)
assert(U.Shown(env, focus.name) == "ELUNARA" and not focus.name:IsTruncated(), "a short name shows whole in capitals")

U.SetUnit(env, "focus", { name = "Elunara Frostweaver", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(math.abs(size(focus.name) - full) < 0.01 and not focus.name:IsTruncated(), "a longer name that fits keeps the frame's own size, whole")
-- At the gallery's 200 by 90 the level sits on the medallion's plaque, so the name line keeps no room for it.
local element = K.Layout.Get("unitframes.focus")
local w, h = element.width, element.height
assert(K.Layout.Update("unitframes.focus", { width = 200, height = 90 }))
env.RunTimers()
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(not focus.name:IsTruncated() and focus.name:GetUnboundedStringWidth() <= focus.geometry.name.w, "at 200 by 90 the long name shows whole on its line")
assert(K.Layout.Update("unitframes.focus", { width = w, height = h }))
env.RunTimers()

-- A name too long even at the floor truncates there; nothing shrinks further.
U.SetUnit(env, "focus", { name = "Elunara Frostweaver the Everlasting Moonshadow", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(size(focus.name) < full and size(focus.name) >= floor - 0.01 and focus.name:IsTruncated(), "a very long name steps down to the floor and truncates there: " .. tostring(size(focus.name)))

U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(math.abs(size(focus.name) - full) < 0.01, "a short name again takes the frame's own size back")

-- The pet's names show whole in capitals (round 4: Opus #6, "BRISTLEBA..." on the hunter's pet).
local pet = Frames.Get("pet").views[1]
U.SetUnit(env, "pet", { name = "Bristleback", level = 38, health = 300, healthMax = 400, reaction = 5 })
env.FireEvent("UNIT_PET", "player")
assert(not pet.name:IsTruncated(), "the pet's name shows whole: " .. tostring(pet.name:GetUnboundedStringWidth()) .. " in " .. tostring(pet.name:GetWidth()))
U.SetUnit(env, "pet", { name = "Wolf", level = 38, health = 300, healthMax = 400, reaction = 5 })
env.FireEvent("UNIT_PET", "player")
assert(U.Shown(env, pet.name) == "WOLF", "a short pet name keeps the row's own capitals: " .. U.Shown(env, pet.name))

local chosen = K.Tokens.FontPath("InterSemiBold")
K.Options.Write("UnitFrames", "focus.fonts.name.font", chosen)
U.SetUnit(env, "focus", { name = "Elunara Frostweaver the Everlasting Moonshadow", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert((focus.name:GetFont()) == chosen, "fitting a long name does not replace a saved face override")

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("unitframes name fit ok")
