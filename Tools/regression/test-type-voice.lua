-- test-type-voice.lua: stable slab face, high-density text minimum and single level, including their original-look switches.
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local function near(a, b) return math.abs(a - b) < 1e-6 end

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	local _, K = U.New({ width = screen[1], height = screen[2] })
	assert(K.Scale.TextFloor() == math.floor(11 * screen[2] / 1080 + 0.5), "retain the ordinary-screen reading floor in every HUD style")
end

for _, screen in ipairs({ { 1920, 1080 }, { 3456, 2234 }, { 5120, 1440 } }) do
	for _, locale in ipairs({ "enUS", "deDE", "zhCN" }) do
		local env, K, ns = U.New({ width = screen[1], height = screen[2], locale = locale })
		env._textWidth = D.TextWidth
		local name = locale == "zhCN" and "暗影峡谷的游荡者和古老森林守卫" or locale == "deDE" and "Ödlandwilderer Aus Dem Schattenwald" or "Shadowgale Poacher With A Very Long Name"
		U.SetUnit(env, "target", { name = name, level = 12, health = 118, healthMax = 236, reaction = 2, creature = "Humanoid" })
		env.SetTarget(true)
		local view = ns.Frames.Get("target").views[1]
		local path = ns.Settings.Font("target", "name")
		assert(view.name:GetFont() == path, "C1: keep the slab face at every resolution and locale; shrink then bound the name")
		assert(view.plainName == env._units.target.name, "C1: keep the full name for tooltips and later refits")
		assert(not view.slabLevel:IsShown() and view.medallion.plaque:IsShown(), "C2: show the level only on the portrait plaque")
		local room = view.geometry.nameRoom
		local plaqueSide = view.geometry.medalSide
		view.geometry.medalSide = nil
		ns.Slab.Caption(view)
		assert(view.slabLevel:IsShown(), "C2: use the name-row level when the plaque is off")
		view.geometry.medalSide = plaqueSide
		ns.Slab.Caption(view)
		K.Options.Write("UnitFrames", "singleSlabLevel", false)
		assert(view.slabLevel:IsShown() and view.geometry.nameRoom < room, "C2 off: restore the name-row level and its reserve")
		K.Options.Write("UnitFrames", "stableSlabNames", false)
		if locale ~= "zhCN" then
			assert(view.name:GetFont() == K.Tokens.Font("body"), "C1 off: restore the long-name body face")
		end
		local pixel = K.Scale.Pixel(1)
		local minimum = screen[2] <= 1440 and math.floor(11 * screen[2] / 1080 + 0.5) or math.max(1, math.floor(11 / pixel + 0.5))
		assert(near(K.Scale.TextFloor(), minimum), "C1: retain ordinary-screen floors and use the effective scale at high density")
		K.Options.Write("Appearance", "textFloor", false)
		assert(K.Scale.TextFloor() == math.floor(11 * screen[2] / 1080 + 0.5), "C1 off: restore the screen-height floor")
		assert(#env._errors == 0, tostring(env._errors[1]))
	end
end
print("test-type-voice: stable slab face, effective floor and single level with original-look switches")
