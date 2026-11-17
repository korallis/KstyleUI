-- test-skins-restedxp-arrow.lua: the waypoint's bright silhouette and dark edge survive dark art, accent changes and RestedXP's own updates without taking over its geometry or visibility.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W
local rxp
local env, K, ns = S.New({ setup = function(e) rxp = Fake.Install(e, { activeTheme = "DarkMode" }) end })
K.Modules.Enable("Skins")
env.RunTimers()
local arrow, texture = rxp.arrowFrame, rxp.arrowFrame.texture

local function Luminance(r, g, b)
	local function Linear(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local layers = {}
for _, region in ipairs({ arrow:GetRegions() }) do
	if region:GetObjectType() == "Texture" and region ~= texture and region._masks and #region._masks == 1 then
		layers[#layers + 1] = region
	end
end
assert(#layers == 2, "RestedXP arrow needs a bright alpha silhouette and a dark contrast layer: tinting DarkMode's black artwork cannot brighten it")
local edge, fill = layers[1], layers[2]

local function Visible()
	local c = W.LastCall(fill, "SetColorTexture")
	assert(c and Luminance(unpack(c)) >= 0.8, "keep the waypoint silhouette luminance >= 0.8 for dark zones, independent of the accent")
	c = W.LastCall(edge, "SetColorTexture")
	assert(c and Luminance(unpack(c)) <= 0.02 and c[4] == 1, "keep an opaque dark contrast layer for snow and desert")
	assert(edge:GetDrawLayer() == "BACKGROUND" and fill:GetDrawLayer() == "ARTWORK", "the edge stays behind the arrow and the label stays above it")
	assert(edge:GetWidth() > texture:GetWidth() and edge:GetHeight() > texture:GetHeight(), "the dark silhouette extends beyond the bright arrow")
	assert(fill:GetWidth() == texture:GetWidth() and fill:GetHeight() == texture:GetHeight(), "the bright silhouette preserves the arrow size")
	assert(Luminance(arrow.text:GetTextColor()) >= 0.8, "the distance remains bright")
	local shadow = W.LastCall(arrow.text, "SetShadowColor")
	assert(shadow and Luminance(unpack(shadow)) <= 0.02 and shadow[4] >= 0.85, "the distance needs a dark shadow on bright ground")
	local _, _, flags = arrow.text:GetFont()
	assert(flags and flags:find("OUTLINE", 1, true), "keep the distance outline after the skin applies its number font")
end

for _, source in ipairs({ "appearance", "class", "custom" }) do
	if source == "class" then
		env.UnitClass = function() return "Warlock", "WARLOCK" end
		env.RAID_CLASS_COLORS = { WARLOCK = { r = 0.58, g = 0.51, b = 0.79 } }
		env.FireEvent("PLAYER_LOGIN")
	end
	K.Options.Write("Skins", "accent.source", source)
	K.Options.Write("Skins", "accent.color", { r = 0.01, g = 0.02, b = 0.01 })
	env.RunTimers()
	rxp.SetupArrow()
	Visible()
	local ar, ag, ab = ns.Style.Accent()
	if source == "class" then
		assert(ar == 0.58 and ag == 0.51 and ab == 0.79, "exercise an actual class accent, not its fallback")
	elseif source == "custom" then
		assert(ar == 0.01 and ag == 0.02 and ab == 0.01, "exercise the near-black custom accent")
	end
	local path = texture:GetTexture()
	assert(type(path) == "string" and path:find("DarkMode", 1, true), "keep RestedXP's own DarkMode texture")
	for _, layer in ipairs(layers) do
		assert(layer._masks[1]:GetTexture() == path, "the silhouette uses the original texture alpha, ignoring its black pigment")
	end
end
K.Options.Write("Skins", "accent.color", { r = 0.2, g = 0.4, b = 0.9 })
env.RunTimers()
Visible()
K.Theme.SetCustomAccent(0, 0, 0)
K.Theme.SetAccentSource("custom")
K.Options.Write("Skins", "accent.source", "appearance")
env.RunTimers()
Visible()

rxp.fake.arrow("Tirisfal Glades", 126, 1.25)
local original = { texture:GetPoint(1) }
for _, layer in ipairs(layers) do
	assert(W.Near(layer._masks[1]:GetRotation(), 1.25), "contrast layers rotate with RestedXP's DrawArrow")
end
rxp.fake.trust(function()
	texture:SetTexCoord(0.1, 0.9, 0.2, 0.8)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	texture:SetSize(48, 40)
end)()
for _, layer in ipairs(layers) do
	local a, b, c, d = layer._masks[1]:GetTexCoord()
	assert(a == 0.1 and b == 0.9 and c == 0.2 and d == 0.8, "copy, never replace, RestedXP's texture coordinates")
end
assert(texture:GetWidth() == 48 and texture:GetHeight() == 40 and fill:GetWidth() == 48 and fill:GetHeight() == 40, "both silhouettes follow a size RestedXP chooses")
local current = { texture:GetPoint(1) }
rxp.SetupArrow()
local after = { texture:GetPoint(1) }
for i = 1, #current do assert(after[i] == current[i], "the skin must not move the source arrow") end
assert(original[1] == "TOPLEFT", "RestedXP originally anchors its texture to its frame")
rxp.fake.trust(function() arrow:Hide() end)()
assert(not fill:IsVisible() and not edge:IsVisible(), "both layers hide with RestedXP")
rxp.fake.trust(function() arrow:Show(); arrow:SetAlpha(0.25) end)()
assert(fill:IsVisible() and edge:IsVisible() and arrow:GetAlpha() == 0.25, "RestedXP owns fading and showing")
local count = #layers
rxp.SetupArrow()
assert(#edge._masks == 1 and #fill._masks == 1 and count == 2, "repeated setup reuses the contrast layers")
assert(#env._errors == 0, tostring(env._errors[1]))
K.Options.Write("Skins", "restedXP.enabled", false)
env.RunTimers()
assert(not fill:IsShown() and not edge:IsShown(), "switching off the skin removes its contrast layers")
K.Options.Write("Skins", "restedXP.enabled", true)
env.RunTimers()
assert(fill:IsShown() and edge:IsShown(), "switching back on reuses both layers")
rawset(_G, "RENDER_SCENE_LIB", true)
local scene = dofile("Tools/render/scenes/restedxp_arrow.lua")()
assert(#scene.items == 4, "the focused arrow scene contains only the source, two contrast layers and distance")
assert(#dofile("Tools/render/guard.lua").Check(scene) == 0, "the arrow proof scene has no truncation or overflow")
print("skins restedxp arrow ok: theme/class/dark custom; bright silhouette, dark edge, readable distance; rotation, UV, size and visibility preserved")
