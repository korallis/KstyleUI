-- test-orbs-finish.lua: the Orbs finish: sharp glass and a clear loss band, a ledge under bar 2 and room for a long target spell name, each with an Options switch that brings back the old look.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local env, K, ns = U.New()
local Tokens = K.Tokens
K.Options.Write("HudStyle", "style", "orbs")
local health, power, tray = ns.Orbs.Get("health"), ns.Orbs.Get("power"), ns.Orbs.Tray()

local function color(region, method)
	return W.LastCall(region, method)
end

assert(health.glass:GetTexture() == Tokens.Texture("orbGlass") and power.back:GetTexture() == Tokens.Texture("orbBack"), "G5: the 256-texel sharp glass by default")
local r, g, b, a = Tokens.Color("orbLossGlaze")
local band = color(health.loss, "SetStatusBarColor")
assert(near(band[1], r) and near(band[2], g) and near(band[3], b) and near(a, 0.75) and near(band[4], a), "G5: the loss band is orbLoss at 0.75, with no dark back mixed in")
assert(near(color(health.lossCap, "SetVertexColor")[4], 0.35), "G5: its cap at 0.35")
assert(tray.ledge:IsShown(), "G5: a rail ledge seats bar 2")

local target = ns.CastBars.Get("target")[1]
env._time = 2
U.SetUnit(env, "target", { name = "Bloodtalon Matriarch", level = 12, health = 50, healthMax = 100, reaction = 2,
	cast = { name = "Terrifying Screech", texture = 136197, start = 1000, finish = 4500, spellID = 686 } })
env.SetTarget(true)
local wide = target.text:GetWidth()
assert(wide >= 180, "G5: the Orbs target cast label gets at least 180 units, got " .. wide)

K.Options.Write("UnitFrames", "orbGlass", false)
assert(health.glass:GetTexture() == Tokens.Texture("orbGlassSoft") and power.back:GetTexture() == Tokens.Texture("orbBackSoft"), "off: the softer glass again")
band = color(health.loss, "SetStatusBarColor")
assert(near(band[4], 1) and band[1] < r, "off: the opaque band mixed toward the dark back, as before")
assert(near(color(health.lossCap, "SetVertexColor")[4], 0.7), "off: the cap at 0.7 again")
K.Options.Write("UnitFrames", "orbLedge", false)
assert(not tray.ledge:IsShown(), "off: no ledge")
K.Options.Write("UnitFrames", "orbCastRoom", false)
env.SetTarget(true)
local timer = target.timer:GetWidth()
local holder = ns.CastBars.Holder("target"):GetWidth()
assert(target.text:GetWidth() < wide and near(target.text:GetWidth() + timer + 4, holder, 1), "off: the label keeps the holder's width as before")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
for _, screen in ipairs({ { 3456, 2234 }, { 5120, 1440 } }) do
	local wideEnv, wideK, wideNs = U.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "auto" })
	wideK.Options.Write("HudStyle", "style", "orbs")
	wideEnv._time = 2
	U.SetUnit(wideEnv, "target", { name = "Bloodtalon Matriarch", level = 12, health = 50, healthMax = 100, reaction = 2,
		cast = { name = "Terrifying Screech", texture = 136197, start = 1000, finish = 4500, spellID = 686 } })
	wideEnv.SetTarget(true)
	local label = wideNs.CastBars.Get("target")[1].text:GetWidth()
	assert(label >= 180, "G5: at least 180 units after pixel snapping at " .. screen[1] .. "x" .. screen[2] .. ", got " .. label)
	assert(#wideEnv._errors == 0 and wideK.ErrorCount() == 0, tostring(wideEnv._errors[1]))
end
print("orbs finish ok")
