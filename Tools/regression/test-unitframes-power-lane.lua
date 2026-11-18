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
	K.Options.Write("UnitFrames", "player.powerText", "legacy")
	assert(not view.powerText:IsShown() and not view.geometry.powerText, "Previous display restores the original hidden power text")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = U.New()
	K.Options.Write("HudStyle", "style", "orbs")
	local power = ns.Orbs.Get("power")
	assert(power.value:GetJustifyH() == "CENTER", "the resource number keeps its existing centred position")
	assert(U.Shown(env, power.value) == "50%", "Orbs keeps mana in its existing resource orb")
	local player = env._units.player
	player.powerType, player.powerToken, player.power, player.powerMax = 3, "ENERGY", 37, 100
	env.FireEvent("UNIT_DISPLAYPOWER", "player")
	assert(U.Shown(env, power.value) == "37%", "Orbs keeps its independent percent format")
	env._restricted = true
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, power.value) == "37%", "the orb passes restricted resource values to its number")
	K.Options.Write("UnitFrames", "player.powerText", "legacy")
	assert(power.value:GetJustifyH() == "CENTER" and U.Shown(env, power.value) == "37%", "frame text options leave the orb unchanged")
	K.Options.Write("UnitFrames", "player.powerText", "none")
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, power.value) == "37%", "None on the player frame leaves the orb's number visible")
end

local env, K, ns = U.New()
local view = ns.Frames.Get("player").views[1]
assert(view.s.powerSeparate == true, "H2b defaults on under the owner's new-settings rule")
K.Options.Write("UnitFrames", "player.powerSeparate", false)
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
local ir, ig, ib, ia = K.Widgets.InkFor(sr, sg, sb)
assert(view.powerFillText, "a fill-clipped ink layer leaves the empty power track readable")
local tr, tg, tb, ta = view.powerFillText:GetTextColor()
assert(near(tr, ir) and near(tg, ig) and near(tb, ib) and near(ta, ia), "text inside the light power fill uses the merged dark-ink rule")
assert(select(3, view.powerFillText:GetFont()) == "", "dark ink on a light fill does not rely on an outline")
assert(select(1, view.powerText:GetTextColor()) > 0.9 and select(3, view.powerText:GetFont()) == "OUTLINE", "light outlined ink stays readable over the empty track")
local player = env._units.player
for _, amount in ipairs({ 0, 50, 100 }) do
	player.power = amount
	env._restricted = true
	env.FireEvent("UNIT_POWER_UPDATE", "player")
	assert(U.Shown(env, view.powerText) == U.Shown(env, view.powerFillText), "both ink layers format the same restricted power")
end
env._restricted = false
assert(U.W.LastCall(view.powerFillClip, "SetClipsChildren")[1] and select(2, view.powerFillClip:GetPoint(1)) == view.power:GetStatusBarTexture(), "the engine clips fill ink to the actual fill without Lua reading power")
assert(view.powerTypeLine:IsShown() and near(env.Look(view.powerTypeLine:GetHeight()), 1), "a 1-unit line keeps the power colour")
K.Options.Write("UnitFrames", "player.powerSeparate", false)
r, g, b = view.power:GetStatusBarColor()
assert(near(r, 1) and near(g, 0.9) and near(b, 0) and not view.powerTypeLine:IsShown(), "turning the option off restores the original fill")
K.Options.Write("UnitFrames", "player.powerSeparate", true)
K.Options.Write("UnitFrames", "player.powerCustom", { r = 0, g = 0, b = 1 })
r, g, b = view.power:GetStatusBarColor()
assert(near(r, 0) and near(g, 0) and near(b, 1) and not view.powerTypeLine:IsShown(), "distant hues keep their power colour")
ir, ig, ib = K.Widgets.InkFor(0, 0, 1)
tr, tg, tb = view.powerFillText:GetTextColor()
assert(near(tr, ir) and near(tg, ig) and near(tb, ib), "a dark fill restores light ink")
K.Options.Write("HudStyle", "style", "medallions")
K.Options.Write("UnitFrames", "player.powerCustom", { r = 1, g = 0.9, b = 0 })
tr, tg, tb = view.powerText:GetTextColor()
ir, ig, ib = K.Tokens.Color("textEmphasis")
assert(near(tr, ir) and near(tg, ig) and near(tb, ib) and select(3, view.powerText:GetFont()) == "OUTLINE", "the separate Medallions lane keeps light world ink on a light power fill")
assert(not view.powerFillClip:IsShown(), "the outside-fill Medallions lane has no clipped overlay")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("unitframes power lane ok")
