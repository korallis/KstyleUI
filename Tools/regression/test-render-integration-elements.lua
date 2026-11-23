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
assert(K.Store.Module("ActionBars").bindingHints == false, "populate the previous binding-helper choice before isolated setup summaries are built")
assert(#env._errors == 0, tostring(env._errors[1]))
print("isolated HUD off choice ok")

local common = assert(loadfile("Tools/render/scenes/_common.lua"))
setfenv(common, setmetatable({ os = { getenv = function(key) if key == "RENDER_NEEDS_OFF" then return "1" end end } }, { __index = _G }))
local saved = common().FinishSettings({})
local beforeEnv, beforeK = C.New({ saved = { version = 2, profiles = { Default = saved } } })
C.Boot(beforeEnv)
local changed = 0
beforeK.Callbacks.Register("ThemeChanged", "PreviousScene", function() changed = changed + 1 end)
audit().Apply(beforeK)
assert(changed == 0, "Seed the previous palette and fit choices before login; late fixture restyles change the guide card's padding")
assert(beforeK.ColorVision.Mode() == "standard" and not beforeK.Setup.Layouts.ThirdBarFinished())
assert(#beforeEnv._errors == 0, tostring(beforeEnv._errors[1]))
print("previous choices start before login ok")

local values = { RENDER_NEEDS_OFF = "1", RENDER_BAR3 = "1", RENDER_HUD_STYLE = "Frames", RENDER_SCREEN = "5120x1440", RENDER_SIZE = "auto" }
local runtime = { getenv = function(key) return values[key] or os.getenv(key) end }
local commonChunk = assert(loadfile("Tools/render/scenes/_common.lua"))
setfenv(commonChunk, setmetatable({ os = runtime }, { __index = _G }))
local picked = commonChunk()
local hudChunk = assert(loadfile("Tools/render/scenes/hud.lua"))
setfenv(hudChunk, setmetatable({ os = runtime, dofile = function(path)
	if path == "Tools/render/scenes/_common.lua" then return picked end
	return load(path)
end }, { __index = _G }))
local actual = hudChunk()
local edit = load("Tools/regression/editmode_fake.lua")
local native = edit.Find(assert(actual.EditModeLayout("DPS", false, { buffs = 2, bars = 0 })), edit.VIEWER, edit.BUFF_ICON)
assert(math.abs(native.anchorInfo.offsetX - 1687.1015625) < 1e-6 and math.abs(native.anchorInfo.offsetY - 331.134375) < 1e-6, "The native-viewer render copy must use the previous third-bar choice before fitting its Edit Mode layout: " .. tostring(native.anchorInfo.offsetX) .. ", " .. tostring(native.anchorInfo.offsetY))
print("previous native-viewer anchor ok")
