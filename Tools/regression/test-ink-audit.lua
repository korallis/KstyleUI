local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
local W, Widgets, Tokens = U.W, K.Widgets, K.Tokens
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
assert(type(Widgets.InkFor) == "function", "add Widgets.InkFor with linearised WCAG luminance")
assert(near(Widgets.InkLuminance(1, 1, 1), 1), "white luminance is one")
assert(near(Widgets.InkLuminance(0.5, 0.5, 0.5), 0.21404114048223), "linearise sRGB before deciding ink")
local r, g, b, a, flags = Widgets.InkFor(Tokens.Color("gilt"))
local dr, dg, db = Tokens.Color("slabBottom")
assert(near(r, dr) and near(g, dg) and near(b, db) and a == 0.92 and flags == "", "gilt takes dark ink at 92%")
assert(select(5, Widgets.InkFor(0, 0, 0)) == "OUTLINE", "dark fills take outlined light ink")
assert(select(5, Widgets.InkFor(env.Secret(1), 1, 1)) == "OUTLINE", "secret fill channels take the safe light-ink path")
local bar = Widgets.UnitBar(K.Scale.Root(), { width = 200, height = 18 })
bar:SetBarColor(0.2, 0.4, 0.6)
assert(near(bar.gradients.lossBottom.r, 0.48) and near(bar.gradients.lossTop.r, 0.6), "tint loss bands from their fill by 35% and 50%")
assert(bar.gradients.lossBottom.a == 0.75 and bar.gradients.lossTop.a == 0.75, "both loss stops use 75% alpha")
bar:SetBarColor(env.Secret(0.2), 0.4, 0.6)
assert(near(bar.gradients.lossBottom.r, 1) and near(bar.gradients.lossBottom.a, 0.32), "a secret colour resets the previous tint to the white fallback")
env._units.player.health, env._units.player.healthMax = 20, 100
local text = Widgets.FontString(K.Scale.Root(), "OVERLAY")
Widgets.LowHealthText(text, "player", "textEmphasis")
local ink = W.LastCall(text, "SetTextColor")
assert(near(env.Reveal(ink[1]), Tokens.Color("healthLowText")), "low-health text uses healthLowText, leaving bar red alone")
assert(select(3, ns.Settings.Font("player", "name")) == "OUTLINE", "bare unit text defaults to a thin outline")
local cb = ns.CastBars.Get("player")[1]
env._units.player.cast = { name = "Terrifying Screech", texture = 136048, start = 0, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-Ink", 188196)
assert(cb.text:GetFont() == ns.Settings.Font("player", "name"), "Medallions cast labels use the slab name face")
assert(cb.timer:GetFont() == Tokens.Font("number") and select(3, cb.timer:GetFont()) == "OUTLINE", "cast timer uses outlined number role")
local tr, tg, tb = Tokens.Color("textEmphasis")
local timerInk = W.LastCall(cb.timer, "SetTextColor")
assert(near(timerInk[1], tr) and near(timerInk[2], tg) and near(timerInk[3], tb), "timers keep light ink on the unfilled track")
for _, event in ipairs({ "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
	K.Options.Write("UnitFrames", "player.castbarColor", "custom")
	local cr, cg, cbv = Tokens.Color("gilt")
	K.Options.Write("UnitFrames", "player.castbarCustom", { r = cr, g = cg, b = cbv })
	env._units.player.cast = { name = "Terrifying Screech", texture = 136048, start = 0, finish = 3500, spellID = 188196 }
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-Ink", 188196)
	assert(select(3, cb.text:GetFont()) == "", "a new pale cast restores dark unoutlined ink")
	env._units.player.cast = nil
	env.FireEvent(event, "player", "Cast-Ink", 188196)
	local ended = W.LastCall(cb.text, "SetTextColor")
	assert(not cb.inkEmpty and near(ended[1], dr) and near(ended[2], dg) and near(ended[3], db) and select(3, cb.text:GetFont()) == "", "full hostile interrupted and failed bars keep readable dark ink")
end
assert(#env._errors == 0, tostring(env._errors[1]))
print("ink audit rules passed")
