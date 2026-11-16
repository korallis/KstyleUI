local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
K.Options.Write("HudStyle", "style", "medallions")
local view = ns.Frames.Get("player").views[1]
for _, class in ipairs({ "WARLOCK", "PRIEST", "ROGUE", "MAGE", "DRUID", "HUNTER", "PALADIN", "SHAMAN", "WARRIOR" }) do
	env._units.player.class = class
	env._units.player.health, env._units.player.healthMax = 100, 100
	ns.Unit.HealthColor(view, "player")
	assert(view.health.flat and not view.health.cleanSheen:IsShown(), class .. ": no white sheen washes out the fill")
	assert(not view.health.cleanShade:IsShown() and not view.health.cleanLit:IsShown(), "Medallions fill is flat")
	local r, g, b = K.Theme.ClassColorForWidget(class)
	local bright = 0.2126 * r + 0.7152 * g + 0.0722 * b >= 0.5
	local wanted = K.Tokens.Color(bright and "slabBottom" or "textEmphasis")
	local actual = env.Reveal(select(1, view.healthText:GetTextColor()))
	assert(math.abs(actual - wanted) < 0.001, class .. ": ink follows fill luminance")
	env._units.player.health = 20
	ns.Slab.Health(view, "player")
	actual = env.Reveal(select(1, view.healthText:GetTextColor()))
	assert(math.abs(actual - K.Tokens.Color("textEmphasis")) < 0.001, class .. ": low health and empty track keep light ink")
end
U.SetUnit(env, "target", { name = "Duskbat", reaction = 4, health = 99, healthMax = 120 })
env.SetTarget(true)
local target = ns.Frames.Get("target").views[1]
ns.Unit.HealthColor(target, "target")
assert(env.Reveal(select(1, target.healthText:GetTextColor())) == K.Tokens.Color("slabBottom"), "yellow target fill has dark readable ink")
K.Options.Write("HudStyle", "style", "frames")
assert(not view.health.flat, "Frames restores its existing shading")
assert(#env._errors == 0, tostring(env._errors[1]))
print("Medallions health ink passed")
