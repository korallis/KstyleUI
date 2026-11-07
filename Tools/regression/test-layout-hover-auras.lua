-- test-layout-hover-auras.lua: under the mouseover rule, the pointer on an aura button shows the real Auras panel while auras are secret, and Layout never touches an aura button.
local A = dofile("Tools/regression/auras_env.lua")
local W = A.W

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local env, K = A.New({})
K.Modules.Enable("Auras")
env.RunTimers()
local buffs = A.Container(env, "HELPFUL")
assert(buffs, "the buffs container is built")
local host = buffs:GetParent()
local holder = K.Layout.Element("auras.buffs").frame
assert(K.Layout.Set("auras.buffs", "shown", "mouseover"))
W.Settle(env)
assert(holder:GetAlpha() == 0 and host:GetAlpha() == 0, "the buffs start faded out")

local before = {}
for i, button in ipairs(A.Buttons(buffs)) do
	before[i] = #button._calls
end
env._aurasSecret = true

-- The aura button keeps the mouse focus, so the holder gets no OnEnter; only its rect sees the pointer.
holder._mouseOver = true
env.RunTickers()
W.Settle(env)
assert(near(holder:GetAlpha(), 1) and near(host:GetAlpha(), 1), "the pointer on an aura button shows the buffs")
holder._mouseOver = false
env.RunTickers()
W.Settle(env)
assert(holder:GetAlpha() == 0 and host:GetAlpha() == 0, "and leaving hides them")

-- W.Settle reads every frame's OnUpdate with GetScript, so that one read is the harness's own.
for i, button in ipairs(A.Buttons(buffs)) do
	for j = before[i] + 1, #button._calls do
		local method = button._calls[j].method
		assert(method == "GetScript", "Layout never calls an aura button, got " .. tostring(method))
	end
	assert(button:GetScript("OnEnter") == nil, "nor hooks one")
end
assert(#env._errors == 0, tostring(env._errors[1]))

print("layout hover auras ok")
