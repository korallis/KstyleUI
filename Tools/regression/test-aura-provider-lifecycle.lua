-- test-aura-provider-lifecycle.lua: the stub follows Forever's LIFO pool and its current ReleaseAllFrames rejection order.
local A = dofile("Tools/regression/auras_env.lua")
local env, K = A.New()
local container = env.CreateFrame("AuraContainer", nil, K.Scale.Root(), "CustomAuraContainerTemplate")
container:AddAuraGroup("probe", "HARMFUL", { maxFrameCount = 3 })
local group = container._groups.probe
assert(#group.frames == 10, "P6: model AddAuraGroup's fixed batch of ten, regardless of maxFrameCount")
A.Assign(env, container, "probe", 3)
assert(group.active[1] == group.frames[10] and group.active[3] == group.frames[8], "P6: fix the stub's acquisition order; Forever takes frames from the end")
A.Assign(env, container, "probe", 1)
local released = group.frames[9]
A.Assign(env, container, "probe", 2)
assert(group.active[2] == released, "P6: reacquire the most recently released frame, rather than a creation index")
A.Assign(env, container, "probe", 0)
for i = 1, 5 do
	container:SetUnit("raid" .. i)
	A.Assign(env, container, "probe", 3)
	A.Assign(env, container, "probe", 0)
end
assert(#group.frames == 10, "P6: ordinary unit/zone churn reuses frames and must not be confused with ReleaseAllFrames")
for i = 1, 3 do
	A.Assign(env, container, "probe", 3)
	A.ReleaseAll(container, "probe")
	assert(#group.provider.availableFrames == 0, "P6: reproduce Forever ReleaseAllFrames emptying both lists before ReleaseFrame")
	assert(group.provider.rejectedReleases > 0, "P6: reproduce ReleaseFrame rejecting inactive frames after ReleaseAllFrames")
	A.Assign(env, container, "probe", 3)
	assert(#group.frames == 10 * (i + 1), "P6: count the new batch after ReleaseAllFrames instead of assuming reuse")
end
local child = env.CreateFrame("Frame", nil, group.active[1])
local icon = child:CreateTexture()
env._aurasSecret = true
local ok, err = pcall(group.active[1].SetIcon, group.active[1], icon)
assert(not ok and tostring(err):find("access denied", 1, true), "P6: first-assignment decoration is forbidden after aura restrictions apply")
env._aurasSecret = false
print("aura provider lifecycle ok; ReleaseAllFrames grows 10 -> 40 buttons, ordinary churn stays at 10")
