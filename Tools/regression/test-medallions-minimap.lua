-- test-medallions-minimap.lua: under Medallions the minimap is round, a steel ring over a round mask with steel plaques for the zone and the coordinate row.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function LastArg(frame, method)
	local call = W.LastCall(frame, method)
	return call and call[1]
end

local env, K, ns = M.New({ enabled = true })
M.Settle(env)
local face, minimap = ns.Map.face, env.Minimap
local round = (K.Tokens.Texture((K.Widgets.TextureName("medMinimapMask"))))
assert(env.GetMinimapShape() == "ROUND", "LibDBIcon and friends place their buttons on a round map")
assert(LastArg(minimap, "SetMaskTexture") == round, "the minimap wears the round mask")
assert(W.LastCall(face.mask, "SetTexture")[1] == round, "and so does the face's own mask")
assert(face.ring and face.ring:IsShown(), "a steel ring frames the map")
local rp, rrel, rrelp = face.ring:GetPoint(1)
assert(rp == "CENTER" and rrel == face.mapArea and rrelp == "CENTER", "the ring is centred on the map")
assert(face.ring:GetWidth() * 0.9189 >= face.mapArea:GetWidth() - 1, "the ring's outer edge covers the map square's disc, so the map never shows past it: " .. face.ring:GetWidth() .. " for " .. face.mapArea:GetWidth())
for i, plaque in ipairs(face.plaques) do
	assert(plaque.chrome.fill[5]:IsShown(), "plaque " .. i .. " shows")
end
assert(face.zone:GetJustifyH() == "CENTER", "the zone name is centred on its plaque")

local section = K.Store.Module("Minimap")
section.zone = section.zone or {}
section.zone.shown = false
K.Callbacks.Fire("SettingChanged", "Minimap", "zone.shown")
M.Settle(env)
assert(not face.plaques[1].chrome.fill[5]:IsShown() and face.plaques[2].chrome.fill[5]:IsShown(), "no empty zone plaque when the zone name is off")
section.clock = section.clock or {}
section.coords = section.coords or {}
section.clock.shown, section.coords.shown = false, false
K.Callbacks.Fire("SettingChanged", "Minimap", "clock.shown")
M.Settle(env)
assert(not face.plaques[2].chrome.fill[5]:IsShown(), "no empty row plaque when the clock and the coordinates are off")
section.zone.shown, section.clock.shown, section.coords.shown = true, true, true
K.Callbacks.Fire("SettingChanged", "Minimap", "zone.shown")
M.Settle(env)
assert(face.plaques[1].chrome.fill[5]:IsShown() and face.plaques[2].chrome.fill[5]:IsShown())

assert(#env._errors == 0, tostring(env._errors[1]))
print("test-medallions-minimap: ok")
