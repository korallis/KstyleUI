-- test-minimap-cache.lua: repeated layout and clock updates reuse snapped geometry, while size, scale, font and style changes place it again.
local M = dofile("Tools/regression/minimap_env.lua")
local env, K, ns = M.New({ enabled = true })
M.Settle(env)
local face, calls = ns.Map.face, 0
for _, name in ipairs({ "Point", "Fill", "Size" }) do
	local original = K.Widgets[name]
	K.Widgets[name] = function(...)
		calls = calls + 1
		return original(...)
	end
end

local function Reuse()
	calls = 0
	for _ = 1, 10 do
		face:Layout()
		M.RunTickers(env)
	end
	for _, text in ipairs({ "9:20 PM", "10:05 PM", "10:06 AM", "23:59" }) do
		face:SetClock(text)
	end
	face:SetZone("A longer zone name", nil)
	assert(calls == 0, "Cache minimap geometry on layout changes: layout, zone and clock updates must not call Widgets.Point/Fill/Size")
end

Reuse()
local width, height = face.holder:GetSize()
face.holder:SetSize(width + 17, height + 17)
assert(calls > 0, "a minimap resize must rebuild snapped geometry")
Reuse()
face.holder:SetScale(1.13)
face:Layout()
assert(calls > 0, "a minimap scale change must rebuild snapped geometry")
Reuse()
K.Options.Write("Minimap", "zone.size", 20)
M.Settle(env)
assert(calls > 0, "a minimap font change must rebuild snapped geometry")
Reuse()
K.Store.Module("HudStyle").style = "medallions"
K.Callbacks.Fire("SettingChanged", "HudStyle", "style")
M.Settle(env)
assert(calls > 0 and face.ring:IsShown(), "a minimap style change must rebuild snapped geometry")
Reuse()
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("minimap geometry cache ok")
