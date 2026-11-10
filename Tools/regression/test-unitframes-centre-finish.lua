-- test-unitframes-centre-finish.lua: column paint follows the picture without changing reserved frames or legacy styles.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K, ns = U.New()

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 0.0001
end

local function settle()
	env.RunTimers()
	W.Tick(env, 0.01)
end

local function color(bar, token)
	local r, g, b = K.Tokens.Color(token)
	local c = bar.colorRGBA
	assert(near(c[1], r) and near(c[2], g) and near(c[3], b), token .. " reaches the fill unchanged")
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

local player, target = ns.Frames.Get("player").views[1], ns.Frames.Get("target").views[1]
for _, cast in ipairs({ ns.CastBars.Get("player")[1], ns.CastBars.Inline("target")[1] }) do
	assert(cast.bar.textureKey == "Flat", "a caption cast replaces the default Glass fill, not only its overlays")
	assert(not cast.bar.spark:IsShown() and not cast.bar.keyline:IsShown(), "a caption cast paints no spark or outside keyline")
	assert(not cast.bar.lit:IsShown() and not cast.bar.shade:IsShown(), "caption cast paint is flat")
	color(cast.bar, "gilt")
end
for _, view in ipairs({ player, target }) do
	local coords = W.LastCall(view.ring, "SetTexCoord")
	assert(coords and near(coords[1], 1 / 64) and near(coords[2], 63 / 64), "the column ring crops its transparent asset gutter")
	color(view.power, "hudMana")
	assert(near(view.geometry.portrait.w, 70) and near(view.geometry.badge.w, 27), "the main ring and disc use the picture's distinct diameters")
	assert(near(ns.Geometry.COLUMN.ring + ns.Geometry.COLUMN.ringGap, 91.5), "the ring and gap keep the old outside reserve")
	local _, configured = ns.Settings.Font(view.kind, "level")
	assert(near(select(2, view.levelText:GetFont()), K.Widgets.FontSize(view.levelText, configured * 0.95)), "only the disc numeral receives the optical size correction")
end
color(target.health, "hudTargetHealth")
local r, g, b = K.Tokens.Color("hudTargetHealth")
assert(near(r, 197 / 255) and near(g, 68 / 255) and near(b, 62 / 255), "target health uses the measured red")
assert(ns.Settings.FontSize("target", "aura") == 12 * K.Theme.FontScale(), "target aura text has the reference optical size")
local auraTimer = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
ns.Auras.PlaceTimer(auraTimer, target.portraitFrame, "target")
assert(select(5, auraTimer:GetPoint(1)) == -K.Widgets.Snap(target.portraitFrame, 4), "the target timer's optical gap clears the tile")

K.Options.Write("UnitFrames", "player.castbarTexture", "Flat")
assert(ns.CastBars.Get("player")[1].bar.textureKey == "Flat", "a selected flat texture is retained")
K.Options.Write("UnitFrames", "player.style", "plate")
settle()
local cast = ns.CastBars.Get("player")[1]
assert(cast.bar.keyline:IsShown() and cast.bar.spark:IsShown(), "a legacy cast restores its keyline and spark")
local coords = W.LastCall(player.ring, "SetTexCoord")
assert(coords and coords[1] == 0 and coords[2] == 1, "legacy portrait texture coordinates are restored")
K.Options.Write("UnitFrames", "player.power", true)
assert(not near(player.power.colorRGBA[3], select(3, K.Tokens.Color("hudMana"))), "legacy mana keeps the engine-derived brightened colour")
assert(#env._errors == 0 and K.ErrorCount() == 0, "the finish introduces no errors")

local screens = { {1280, 720}, {1366, 768}, {1920, 1080}, {2560, 1440}, {3440, 1440}, {5120, 1440}, {3840, 2160}, {2383, 1540}, {3456, 2234} }
for _, screen in ipairs(screens) do
	local e, SK, sns = U.New({ width = screen[1], height = screen[2], size = "default", fit = true })
	local function snapped(frame, value)
		local pixel = SK.Scale.Pixel(1) / SK.Widgets.ScaleFactor(frame)
		local count = value / pixel
		assert(math.abs(count - math.floor(count + 0.5)) < 0.00001, "the finished geometry stays on physical pixels")
	end
	for _, cb in ipairs({ sns.CastBars.Get("player")[1], sns.CastBars.Inline("target")[1] }) do
		local w, h = cb.bar:GetSize()
		snapped(cb.bar, w)
		snapped(cb.bar, h)
		local _, _, _, x, y = cb.bar:GetPoint(1)
		snapped(cb.bar, x)
		snapped(cb.bar, y)
		assert(not cb.bar.keyline:IsShown() and not cb.bar.spark:IsShown(), "no paint escapes the snapped caption track")
	end
	for _, kind in ipairs({ "player", "target" }) do
		local view = sns.Frames.Get(kind).views[1]
		local w, h = view.portraitFrame:GetSize()
		snapped(view.portraitFrame, w)
		snapped(view.portraitFrame, h)
	end
	assert(#e._errors == 0 and SK.ErrorCount() == 0, "the nine-screen matrix has no errors")
end
print("unitframes centre finish ok")
