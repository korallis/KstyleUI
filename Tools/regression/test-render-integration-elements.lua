local load = dofile
local Hud = { envs = {} }
local chunk = assert(loadfile("Tools/render/scenes/_lumen.lua"))
setfenv(chunk, setmetatable({ dofile = function(path)
	if path == "Tools/render/scenes/hud.lua" then return Hud end
	return load(path)
end }, { __index = _G }))
local Lumen = chunk()
local built = {}
for _, name in ipairs({ "zeta", "beta", "alpha", "theta" }) do
	local scene = {}
	built[name] = { scene = scene }
	Hud.envs[scene] = { KstyleUI = { Layout = {
		Elements = function() return { { key = "integrations.timerLane", live = true } } end,
		Rect = function() return 10, 20, 360, 120 end,
	} } }
end
local element = Lumen.Elements(built)["integrations.timerLane"]
assert(element.module == "alpha", "Sort module names before reporting shared integration anchors; hash order changes scene JSON")
assert(element.left == 10 and element.bottom == 20 and element.width == 360 and element.height == 120)
print("integration element order ok")

local C = load("Tools/regression/core_env.lua")
local env, K = C.New()
C.Boot(env)
assert(not K.Options.Row("ActionBars", "bar3.finished"), "this HUD environment omits the action-bar schema")
local audit = assert(loadfile("Tools/render/scenes/_audit.lua"))
setfenv(audit, setmetatable({ os = { getenv = function() return "1" end } }, { __index = _G }))
audit().Apply(K)
assert(not K.Setup.Layouts.ThirdBarFinished(), "populate the previous bar-3 choice in isolated HUD environments without its options schema")
assert(#env._errors == 0, tostring(env._errors[1]))
print("isolated HUD off choice ok")
