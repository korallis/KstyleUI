local N = dofile("Tools/regression/nameplates_env.lua")
local env, K, ns = N.New()
K.Options.Write("Nameplates", "threat.groupOnly", false)
N.Add(env, "nameplate1", { name = "Guard", health = 100, maxHealth = 100, reaction = 2, canAttack = true, threat = 3 })
local plate = ns.Plates.Get("nameplate1")
assert(plate.threatShape:IsShown(), "plain threat has a shape beside the bar")
N.Cast(env, "nameplate1", { name = "Shadow Bolt", texture = 136197, notInterruptible = env.Secret(true) })
assert(env.Reveal(plate.castBadge:GetAlpha()) == 1, "the engine draws the shield for a secret uninterruptible cast")
K.Options.Write("Nameplates", "cast.showIcon", false)
assert(env.Reveal(plate.castBadge:GetWidth()) >= 11, "the shield stays visible without a spell icon")
K.Options.Write("ColorVision", "mode", "redGreen")
local r, g, b = K.Tokens.Color("visionRGDanger")
local color = { plate.threatShape:GetVertexColor() }
assert(color[1] == r and color[2] == g and color[3] == b, "threat shapes use the selected semantic palette")
N.Cast(env, "nameplate1", { name = "Shadow Bolt", texture = 136197, notInterruptible = env.Secret(false) })
local tint = N.Last(plate.castBar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
local cr, cg, cb = K.Tokens.Color("visionRGCalm")
assert(tint and tint[3].r == cr and tint[3].g == cg and tint[3].b == cb, "the engine also gets the selected palette for secret interruptibility")
assert(#env._errors == 0, tostring(env._errors[1]))

K.Options.Write("Nameplates", "threat.shapes", false)
K.Options.Write("Nameplates", "cast.shieldBadge", false)
N.Cast(env, "nameplate1", { name = "Shadow Bolt", texture = 136197, notInterruptible = env.Secret(true) })
assert(not plate.threatShape:IsShown() and plate.castBadge:GetAlpha() == 0, "turning off shapes restores the previous plate")
K.Options.Write("Nameplates", "threat.shapes", true)
K.Options.Write("Nameplates", "cast.shieldBadge", true)
assert(plate.threatShape:IsShown() and env.Reveal(plate.castBadge:GetAlpha()) == 1, "both shape options update the visible plate")
assert(#env._errors == 0, tostring(env._errors[1]))

local Geometry = dofile("Tools/regression/geometry.lua")
local function Clear(a, b, root, what)
	local ra, rb = assert(Geometry.Rect(a, root)), assert(Geometry.Rect(b, root))
	assert(ra.right <= rb.left or rb.right <= ra.left or ra.top <= rb.bottom or rb.top <= ra.bottom,
		what .. ": " .. ra.left .. ".." .. ra.right .. " against " .. rb.left .. ".." .. rb.right)
end
N.Target(env, "nameplate1")
for i, style in ipairs({ "medallions", "frames" }) do
	K.Options.Write("HudStyle", "style", style)
	local unit = "nameplate" .. (i + 1)
	N.Add(env, unit, { name = "Skull", health = 100, maxHealth = 100, reaction = 2, canAttack = true, threat = 3, raid = 8 })
	local marked = ns.Plates.Get(unit)
	assert(marked.raid:IsShown() and marked.threatShape:IsShown(), style .. ": the marked plate shows its skull and threat")
	Clear(marked.threatShape, marked.raid, marked, style .. ": the threat mark stands clear of the raid marker")
	for _, side in ipairs(plate.brackets.sides) do
		Clear(plate.threatShape, side, plate, style .. ": the threat mark stands clear of the " .. side.side .. " target bracket")
	end
end
assert(#env._errors == 0, tostring(env._errors[1]))

print("nameplate accessibility ok")
