-- test-widgets-unitbar.lua: the clean unit bar shows health just lost as a pale band and flashes it, turns red at low health, and does it all with secret values only passed to widget setters: every health value here is a secret that raises on comparison or arithmetic.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K = U.New({ enabled = false })
local Widgets = K.Widgets
local S, Reveal = env.Secret, env.Reveal
local EASED = env.Enum.StatusBarInterpolation.ExponentialEaseOut

local root = K.Scale.Root()
local bar = Widgets.UnitBar(root, { lowHealth = true, width = 300, height = 18 })
bar:SetPoint("TOPLEFT", root, "TOPLEFT", 100, -100)
bar:Restyle()
local under = bar.under

local function value(frame)
	local call = W.LastCall(frame, "SetValue")
	return Reveal(call[1]), call[2]
end

local function playing(group)
	return group:IsPlaying() == true
end

local function finish(group)
	group:Stop()
	group:GetScript("OnFinished")(group)
end

assert(under:GetFrameLevel() < bar:GetFrameLevel(), "the loss band's bar sits below the fill's bar")
assert(under:GetParent() == bar:GetParent(), "the loss band is the fill's sibling, so the fill draws over it")
assert(not bar.background and not bar.keyline, "the fill bar draws no track or keyline of its own")
assert(under.track and under.edgeHard and under.edgeSoft, "the track and the two-pixel black edge are drawn under the band")
assert(under.edgeHard:GetDrawLayer() == "BACKGROUND" and under.track:GetDrawLayer() == "BACKGROUND", "the edge and track are background art")

bar:SetBarRange(0, S(1000))
bar:SetHealth(S(1000), true)
local fill, how = value(bar)
assert(fill == 1000 and how == nil, "an instant health snaps the fill")
assert(value(under) == 1000, "an instant health snaps the band with it")
assert(not playing(bar.lossAnim), "an instant health plays no flash")

bar:SetHealth(S(600))
fill, how = value(bar)
local band, bandHow = value(under)
assert(fill == 600 and how == EASED, "a new health eases the fill with the client's interpolation")
assert(band == 1000 and bandHow == nil, "the band holds the health before the hit, so 600 to 1000 shows pale")
assert(playing(bar.lossAnim), "the hit flash and the hold play as one animation group")
assert(bar.flash:GetNumPoints() > 0 and select(2, bar.flash:GetPoint(1)) == under:GetStatusBarTexture(), "the flash covers the band's fill, so only the lost part flashes")
assert(bar.flash:IsShown(), "the flash shows over the lost part")
assert(playing(bar.sparkAnim) and bar.sparkFrame:IsShown(), "the spark lights while the fill moves")

bar:SetHealth(S(500))
assert(value(under) == 1000 and value(bar) == 500, "a second hit inside the hold keeps the band at the health before the burst")
finish(bar.lossAnim)
band, bandHow = value(under)
assert(band == 500 and bandHow == EASED, "after the hold the band eases down to the newest health")
assert(not bar.flash:IsShown(), "and the flash is gone")

bar:SetHealth(S(900))
band = value(under)
fill = value(bar)
assert(band == 500 and fill == 900, "on a heal the band takes the old, lower health, so it hides behind the fill")
finish(bar.lossAnim)
bar:SetHealth(S(700))
band = value(under)
fill = value(bar)
assert(band == 900 and fill == 700, "a hit after a heal's hold shows: the band holds the healed health")

bar:SetHealth(S(400), true)
assert(value(under) == 400 and not playing(bar.lossAnim) and not bar.flash:IsShown(), "a new unit snaps band and fill and stops the flash")
assert(not bar.sparkFrame:IsShown(), "and puts the spark out")
K.Motion.SetLevel("reduced")
bar:SetHealth(S(350))
assert(not bar.flash:IsShown() and playing(bar.lossAnim), "reduced motion keeps the band and its hold but shows no flash")
assert(not bar.sparkFrame:IsShown(), "and no spark")
K.Motion.SetLevel("full")

env._units.player.health, env._units.player.healthMax = 3800, 4000
bar:SetBarColor(K.Tokens.Color("hudPlayerHealth"))
bar:SetHealthUnit("player")
local function color()
	local call = W.LastCall(bar, "SetStatusBarColor")
	return Reveal(call[1]), Reveal(call[2]), Reveal(call[3])
end
local br, bg, bb = K.Tokens.Color("hudPlayerHealth")
local r, g, b = color()
assert(math.abs(r - br) < 1e-6 and math.abs(g - bg) < 1e-6 and math.abs(b - bb) < 1e-6, "at 95% the bar keeps its own colour")
env._units.player.health = 1000
bar:SetHealth(S(1000))
local lr, lg, lb = K.Tokens.Color("healthLow")
r, g, b = color()
assert(math.abs(r - lr) < 1e-6 and math.abs(g - lg) < 1e-6 and math.abs(b - lb) < 1e-6, "at 25% the curve turns the bar red, through secret channels")
assert(env.issecretvalue(W.LastCall(bar, "SetStatusBarColor")[1]), "the low-health colour reaches SetStatusBarColor as a secret")

bar:SetBarColor(S(0.2), S(0.4), S(0.8))
assert(bar.curve == nil, "a secret colour gets no curve, so nothing compares it")

local power = Widgets.UnitBar(root, { loss = false, spark = false })
power:Restyle()
assert(not power.sparkFrame, "a power bar has no spark")
assert(not power.under:GetStatusBarTexture():IsShown(), "a power bar draws no loss band")
power:SetBarRange(0, S(100))
power:SetBarValue(S(40))
local pv, phow = value(power)
assert(pv == 40 and phow == EASED, "power eases with the client's interpolation")

bar:Hide()
assert(not under:IsShown(), "hiding the bar hides its track and band")
bar:Show()
assert(under:IsShown(), "showing the bar shows them")

K.Motion.SetLevel("off")
bar:SetHealth(S(300))
fill, how = value(bar)
assert(fill == 300 and how == nil and value(under) == 300, "with motion off the fill and band snap together")
K.Motion.SetLevel("full")

assert(#env._errors == 0, tostring(env._errors[1]))
print("ok unit bar: loss band, flash, spark and low-health curve on secret values")
