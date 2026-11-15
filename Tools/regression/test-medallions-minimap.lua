-- test-medallions-minimap.lua: under Medallions the minimap is round, a steel ring over a round mask with steel plaques for the zone and the coordinate row, and Frames and Orbs keep the square map.
local M = dofile("Tools/regression/minimap_env.lua")
local W = M.W

local function LastArg(frame, method)
	local call = W.LastCall(frame, method)
	return call and call[1]
end

local function SetStyle(env, K, style)
	K.Store.Module("HudStyle").style = style
	K.Callbacks.Fire("SettingChanged", "HudStyle", "style")
	M.Settle(env)
	assert(K.HudStyle.Current() == style)
end

local env, K, ns = M.New({ enabled = true })
M.Settle(env)
local face, minimap = ns.Map.face, env.Minimap
local square = (K.Tokens.Texture("minimapMask"))

for _, style in ipairs({ "frames", "orbs" }) do
	SetStyle(env, K, style)
	assert(env.GetMinimapShape() == "SQUARE", "Frames and Orbs keep the square map")
	assert(LastArg(minimap, "SetMaskTexture") == square and W.LastCall(face.mask, "SetTexture")[1] == square, "with the square mask")
	assert(not face.ring or not face.ring:IsShown(), "and no ring")
	assert(face.fill:IsShown() and face.shade.top:IsShown(), "the square card stays")
end

SetStyle(env, K, "medallions")
local round = (K.Tokens.Texture((K.Widgets.TextureName("medMinimapMask"))))
assert(round ~= square)
assert(env.GetMinimapShape() == "ROUND", "LibDBIcon and friends place their buttons on a round map")
assert(LastArg(minimap, "SetMaskTexture") == round, "the minimap wears the round mask")
assert(W.LastCall(face.mask, "SetTexture")[1] == round, "and so does the face's own mask")
assert(face.ring and face.ring:IsShown(), "a steel ring frames the map")
assert(LastArg(face.ring, "SetAllPoints") == face.mapArea, "the ring covers the map square, so the map never shows past it")
assert(not face.fill:IsShown() and not face.shade.top:IsShown() and not face.vignette.top:IsShown(), "no square card behind or on the round map")
for _, bracket in ipairs(face.brackets) do
	assert(not bracket.across:IsShown() and not bracket.down:IsShown(), "no gilt brackets")
end
for i, plaque in ipairs(face.plaques) do
	assert(plaque.chrome.fill[5]:IsShown(), "plaque " .. i .. " shows")
end
assert(face.zone:GetJustifyH() == "CENTER", "the zone name is centred on its plaque")

SetStyle(env, K, "frames")
assert(env.GetMinimapShape() == "SQUARE" and LastArg(minimap, "SetMaskTexture") == square, "switching back restores the square map")
assert(not face.ring:IsShown() and not face.plaques[1].chrome.fill[5]:IsShown() and face.fill:IsShown())
assert(face.zone:GetJustifyH() == "LEFT")
assert(#env._errors == 0, tostring(env._errors[1]))
print("test-medallions-minimap: ok")
