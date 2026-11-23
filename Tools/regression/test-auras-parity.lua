-- test-auras-parity.lua: legacy profiles keep their aura finish, while stack visibility, cropping and text offsets write, preview and apply after combat.
local A = dofile("Tools/regression/auras_env.lua")
local saved = { version = 4, profiles = { Default = { Auras = { enabled = true, timer = { format = "short" }, count = { size = 10 } } } }, characters = {} }
local env, K, ns = A.New({ saved = saved })
env.RunTimers()
local header, offsets, timerPositions = nil, 0, 0
for _, row in ipairs(K.Options.Get("Auras")) do
 if row.type == "header" then header = row.label end
 if row.label == "Timer position" then timerPositions = timerPositions + 1 end
 if row.key == "timer.x" or row.key == "timer.y" then
  assert(header == "Timers" and row.disableWhen({ timer = { format = "none" } }) and not row.disableWhen({ timer = { format = "short" } }), "timer offsets belong in Timers and disable with timers")
  offsets = offsets + 1
 elseif row.key == "count.x" or row.key == "count.y" then
  assert(header == "Stack counts" and row.disableWhen({ count = { shown = false } }) and not row.disableWhen({ count = { shown = true } }), "stack offsets belong in Stack counts and disable with stacks")
  offsets = offsets + 1
 end
end
assert(offsets == 4 and timerPositions == 1, "offset rows need no extra position headers")
local desc = ns.Panel.Group("buffs")
local _, group = A.Container(env, "HELPFUL")
local button = group.frames[1]
local entry
for _, candidate in ipairs(desc.buttons) do if candidate.button == button then entry = candidate end end
assert(entry, "the real aura button has a styled entry")
assert(not entry.swipe, "legacy profiles allocate no duration swipe")
for _, name in ipairs({ "buffs", "debuffs" }) do
 local sample = ns.Panel.Group(name).buttons[1]
 K.Options.Write("Auras", name .. ".swipe", true); env.RunTimers()
 assert(sample.swipe and sample.button._aura.cooldown == sample.swipe, "the engine binds " .. name .. " swipes without reading aura durations")
 K.Options.Write("Auras", name .. ".swipe", false); env.RunTimers()
 assert(sample.button._aura.cooldown == nil and not sample.swipe:IsShown(), "disabling clears the engine binding")
end
assert(ns.Model.Timer({ timer = { x = "invalid" } }).x == 0, "invalid saved offsets use the default")
assert(entry.count:GetAlpha() == 1 and ns.Model.IconZoom(K.Store.Module("Auras")) == 0.07, "v0.2.8 keeps stack text and the existing crop")
local beforeTimer, beforeCount = entry.timer._points[1], entry.count._points[1]
local x, y, cx, cy = beforeTimer[4], beforeTimer[5], beforeCount[4], beforeCount[5]
for key, value in pairs({ ["timer.x"] = 4, ["timer.y"] = -3, ["count.x"] = -2, ["count.y"] = 3, iconZoom = 0.1, ["count.shown"] = false }) do
 K.Options.Write("Auras", key, value)
end
env.RunTimers()
assert(entry.count:GetAlpha() == 0, "the stack toggle hides text without reading engine-owned shown state")
assert(math.abs(entry.timer._points[1][4] - x - 4) < 1 and math.abs(entry.timer._points[1][5] - y + 3) < 1, "timer offsets apply")
assert(math.abs(entry.count._points[1][4] - cx + 2) < 1 and math.abs(entry.count._points[1][5] - cy - 3) < 1, "stack offsets apply")
assert(A.W.LastCall(entry.icon, "SetTexCoord")[1] == 0.1, "the shared icon crop applies")
local holder = env.CreateFrame("Frame", nil, K.Scale.Root()); holder:SetSize(280, 300)
local preview = ns.Preview.Build(holder)
assert(preview.buffs[3].count:GetAlpha() == 0 and A.W.LastCall(preview.buffs[1].icon, "SetTexCoord")[1] == 0.1, "the preview uses the same settings")
holder:SetHeight(40); preview:Refresh()
assert(preview.canvas:GetScale() < 1, "a short Options preview scales both aura rows to fit its height")
env.SetCombat(true); env._aurasSecret = true
K.Options.Write("Auras", "count.shown", true); env.RunTimers()
assert(entry.count:GetAlpha() == 0, "a restricted aura edit waits")
env._aurasSecret = false; env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers()
assert(entry.count:GetAlpha() == 1, "the edit applies when combat ends")
assert(#env._errors == 0 and K.ErrorCount() == 0, "aura edits raise no errors")
print("auras parity ok")
