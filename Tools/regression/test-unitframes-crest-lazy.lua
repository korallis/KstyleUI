-- test-unitframes-crest-lazy.lua: empty rank windows defer shared chrome; their first restricted show and native layout preserve complete rims without touching engine state.
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K, ns = U.New({ before = function(_, core)
	core.Store.Module("UnitFrames").auraLayout = "fan"
	core.Store.Module("HudStyle").style = "medallions"
	core.Callbacks.Fire("SettingChanged", "HudStyle", "style")
end })
local fan = ns.Frames.Get("target").views[1].auras.fan
local chromes = {}
for _, entry in ipairs(fan.buttons) do
	assert(not entry.chrome.fill, "defer crest chrome until its window is actually shown")
	assert(entry.chrome.owner ~= entry.skin, "a rank rim belongs to its public window, not a secret aura button")
	chromes[entry.chrome] = true
	for _, object in ipairs({ entry.button, entry.skin, entry.icon, entry.timer, entry.count }) do
		for _, method in ipairs({ "GetWidth", "GetHeight", "GetPoint", "IsVisible", "IsShown" }) do
			local original = object[method]
			object[method] = function(self, ...)
				assert(not env._restricted, "first fan show must not inspect engine aura state: " .. method)
				return original(self, ...)
			end
		end
	end
end
local count = 0
for _ in pairs(chromes) do count = count + 1 end
assert(count == ns.Fan.MAX, "share exactly one chrome per rank, instead of dressing every pooled button")
K.Callbacks.Fire("ThemeChanged")
for chrome in pairs(chromes) do assert(not chrome.fill, "hidden restyles must not allocate crest artwork") end

local fixtures = { { id = 1, icon = 135813, left = 3, harmful = true, mine = true } }
env._restricted = true
env.SetCombat(true)
U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = fixtures })
env.SetTarget(true)
for chrome in pairs(chromes) do assert(chrome.fill, "first restricted show builds the public window's complete artwork") end
Engine.Install(env)
assert(#env._errors == 0 and K.ErrorCount() == 0, "first restricted show touches no secret or protected state")

local rims = {}
for chrome in pairs(chromes) do
	for _, group in ipairs({ chrome.fill, chrome.rim, chrome.line }) do
		for _, region in ipairs(group) do rims[region] = true end
	end
end
local function RimCount()
	local n = 0
	for _, item in ipairs(Scene.Build(env).items) do
		if rims[item.object] then n = n + 1 end
	end
	return n
end
local one = RimCount()
assert(one > 0, "the apex draws its rim with one aura")
env._units.target.auras = {}
env.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
assert(RimCount() == 0, "native empty container geometry must clip away every shared rim")
env._units.target.auras = fixtures
for i = 2, 7 do fixtures[i] = { id = i, icon = 135813, left = i * 3, harmful = true, mine = true } end
env.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
assert(RimCount() == one * ns.Fan.MAX, "each full rank draws exactly one complete shared rim")
env._restricted = false
env.SetCombat(false)
K.Layout.Set(ns.Fan.KEY, "scale", 0.5)
assert(RimCount() > 0 and #env._errors == 0 and K.ErrorCount() == 0, "shared rims restyle at Layout Mode scale")
print("ok crest lazy: seven deferred shared rims, first restricted show, empty and full native clips")
