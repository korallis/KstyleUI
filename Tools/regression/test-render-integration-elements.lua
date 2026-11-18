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
