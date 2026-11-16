local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K, ns = U.New()
K.Options.Write("HudStyle", "style", "medallions")
local view = ns.Frames.Get("player").views[1]
local function Ink(text)
	local r, g, b = text:GetTextColor()
	local function plain(v)
		return env.issecretvalue(v) and env.Reveal(v) or v
	end
	return plain(r), plain(g), plain(b)
end
local function Light(text, what)
	local r, g, b = Ink(text)
	local wr, wg, wb = K.Tokens.Color("textEmphasis")
	assert(math.abs(r - wr) < 0.001 and math.abs(g - wg) < 0.001 and math.abs(b - wb) < 0.001, what .. ": the health number is light")
	assert(select(3, text:GetFont()) == "OUTLINE", what .. ": and outlined, so it reads on a pale fill")
end
for _, class in ipairs({ "WARLOCK", "PRIEST", "ROGUE", "MAGE", "DRUID", "HUNTER", "PALADIN", "SHAMAN", "WARRIOR" }) do
	env._units.player.class = class
	env._units.player.health, env._units.player.healthMax = 100, 100
	ns.Unit.HealthColor(view, "player")
	local sheen = W.LastCall(view.health.cleanSheen, "SetGradient")
	assert(view.health.finish == "medallions" and sheen and sheen[2].a <= 0.13 + 1e-6 and sheen[3].a <= 0.13 + 1e-6, class .. ": no white sheen washes out the fill")
	assert(view.health.cleanShade:IsShown() and view.health.cleanLit:IsShown(), class .. ": the fill keeps its shade and lit end")
	Light(view.healthText, class)
	env._units.player.health = 20
	ns.Slab.Health(view, "player")
	Light(view.healthText, class .. " at low health")
end
U.SetUnit(env, "target", { name = "Duskbat", reaction = 4, health = 99, healthMax = 120 })
env.SetTarget(true)
local target = ns.Frames.Get("target").views[1]
ns.Unit.HealthColor(target, "target")
Light(target.healthText, "the yellow target fill")
K.Options.Write("HudStyle", "style", "frames")
assert(view.health.finish == nil, "Frames restores its existing shading")
assert(#env._errors == 0, tostring(env._errors[1]))
print("Medallions health ink passed")
