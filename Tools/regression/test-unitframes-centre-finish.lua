-- test-unitframes-centre-finish.lua: the centre finish on the Medallions cast bars: the Flat texture and whole-pixel geometry on every screen, with the measured tokens and reserves.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K, ns = U.New()
K.Options.Write("UnitFrames", "player.powerSeparate", false)
local paths = {}
for _, item in ipairs(K.Tokens.MediaList("statusbar")) do
	paths[item.key] = item.path
end

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.0001
end

local function settle()
	env.RunTimers()
	W.Tick(env, 0.01)
end

env._time = 2.2
env._units.player.powerType, env._units.player.powerToken = 0, "MANA"
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 403 }
env.FireEvent("UNIT_DISPLAYPOWER", "player")
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 403)
U.SetUnit(env, "target", { name = "Poacher", health = 50, healthMax = 100, reaction = 2, canAttack = true, powerType = 0, powerToken = "MANA",
	cast = { name = "Shadow Bolt", texture = 136197, start = 1000, finish = 3800, spellID = 686 } })
env.SetTarget(true)
settle()

assert(near(ns.Geometry.COLUMN.ring + ns.Geometry.COLUMN.ringGap, 91.5), "the ring and gap keep the old outside reserve")
local r, g, b = K.Tokens.Color("hudTargetHealth")
assert(near(r, 197 / 255) and near(g, 68 / 255) and near(b, 62 / 255), "target health uses the measured red")
for _, cast in ipairs({ ns.CastBars.Inline("player")[1], ns.CastBars.Inline("target")[1] }) do
	assert(cast.bar.texturePath == paths.Flat, "the Medallions cast bar paints the Flat texture")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, "the finish introduces no errors")

local screens = { {1280, 720}, {1366, 768}, {1920, 1080}, {2560, 1440}, {3440, 1440}, {5120, 1440}, {3840, 2160}, {2383, 1540}, {3456, 2234} }
for _, screen in ipairs(screens) do
	local e, SK, sns = U.New({ width = screen[1], height = screen[2], size = "default", fit = true })
	local function snapped(frame, value)
		local pixel = SK.Scale.Pixel(1) / SK.Widgets.ScaleFactor(frame)
		local count = value / pixel
		assert(math.abs(count - math.floor(count + 0.5)) < 0.00001, "the finished geometry stays on physical pixels")
	end
	for _, cb in ipairs({ sns.CastBars.Inline("player")[1], sns.CastBars.Inline("target")[1] }) do
		local w, h = cb.bar:GetSize()
		snapped(cb.bar, w)
		snapped(cb.bar, h)
		local _, _, _, x, y = cb.bar:GetPoint(1)
		snapped(cb.bar, x)
		snapped(cb.bar, y)
		assert(not cb.bar.keyline:IsShown() and not cb.bar.spark:IsShown(), "no paint escapes the snapped track")
	end
	assert(#e._errors == 0 and SK.ErrorCount() == 0, "the nine-screen matrix has no errors")
end
print("unitframes centre finish ok")
