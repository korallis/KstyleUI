-- test-unitframes-power-lane.lua: power has a separate 18-unit lane, automatic mana/resource formatting, secret-safe values, and opt-in hue separation.
local U = dofile("Tools/regression/unitframes_env.lua")
local function near(a, b) return math.abs(a - b) < 0.02 end
for _, style in ipairs({ "frames", "medallions" }) do
	local env, K, ns = U.New()
	K.Options.Write("HudStyle", "style", style)
	local view = ns.Frames.Get("player").views[1]
	local g = view.geometry
	assert(view.powerText:IsShown() and g.powerText, "H2: " .. style .. " must display the power number")
	if style == "medallions" then
		assert(g.powerText.h == 18 and g.powerReserve == 22, "the Medallions power lane is 18 units with a 4-unit gap and 22-unit reserve")
		assert(g.powerText.y == g.name.y + g.name.h + 4, "the number clears the identity row by four units")
	else
		assert(g.powerReserve == nil and g.powerText.y == g.power.y and g.powerText.h == g.power.h, "Frames uses the existing power bar without moving its layout")
	end
	assert(view.powerText:GetJustifyH() == "RIGHT", "the number is right-aligned")
	assert(select(2, view.powerText:GetFont()) >= 12, "power uses the 12-unit number role")
	assert((view.powerText:GetFont()) == K.Tokens.Font("number"), "power uses the number face")
	assert(U.Shown(env, view.powerText) == "50%", "mana reads as a percent by default")
	local player = env._units.player
	player.powerType, player.powerToken, player.power, player.powerMax = 3, "ENERGY", 37, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, view.powerText) == "37", "energy reads as a current value")
	player.powerType, player.powerToken = 1, "RAGE"
	env._restricted = true
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, view.powerText) == "37", "secret rage goes straight to the number")
	local powerType = env.UnitPowerType
	env.UnitPowerType = function() return env.Secret(0), env.Secret("MANA") end
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, view.powerText) == "37", "a secret power type takes the current-value fallback")
	env.UnitPowerType = powerType
	ns.Format.Power(view.powerText, "player", "auto", env.Secret(3))
	assert(U.Shown(env, view.powerText) == "37", "a supplied secret power type is not compared")
	K.Options.Write("UnitFrames", "player.powerText", "none")
	assert(not view.powerText:IsShown() and not view.geometry.powerText, "None removes the lane")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = U.New()
	K.Options.Write("HudStyle", "style", "orbs")
	local power = ns.Orbs.Get("power")
	assert(power.value:GetJustifyH() == "RIGHT", "the resource number is right-aligned in its existing text box")
	assert(U.Shown(env, power.value) == "50%", "Orbs keeps mana in its existing resource orb")
	local player = env._units.player
	player.powerType, player.powerToken, player.power, player.powerMax = 3, "ENERGY", 37, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, power.value) == "37", "Orbs shows current energy in the same place")
	env._restricted = true
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, power.value) == "37", "the orb passes restricted resource values to its number")
end

local env, K, ns = U.New()
local view = ns.Frames.Get("player").views[1]
assert(view.s.powerSeparate == false, "H2b defaults off")
K.Options.Write("UnitFrames", "player.healthColor", "custom")
K.Options.Write("UnitFrames", "player.healthCustom", { r = 1, g = 1, b = 0 })
K.Options.Write("UnitFrames", "player.powerColor", "custom")
K.Options.Write("UnitFrames", "player.powerCustom", { r = 1, g = 0.9, b = 0 })
local r, g, b = view.power:GetStatusBarColor()
assert(near(r, 1) and near(g, 0.9) and near(b, 0), "power colour stays with the option off")
K.Options.Write("UnitFrames", "player.powerSeparate", true)
local sr, sg, sb = K.Tokens.Color("steelLit")
r, g, b = view.power:GetStatusBarColor()
assert(near(r, sr) and near(g, sg) and near(b, sb), "nearby hues use steel for power when enabled")
assert(view.powerTypeLine:IsShown() and near(view.powerTypeLine:GetHeight(), 1), "a 1-unit line keeps the power colour")
K.Options.Write("UnitFrames", "player.powerCustom", { r = 0, g = 0, b = 1 })
r, g, b = view.power:GetStatusBarColor()
assert(near(r, 0) and near(g, 0) and near(b, 1) and not view.powerTypeLine:IsShown(), "distant hues keep their power colour")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("unitframes power lane ok")
