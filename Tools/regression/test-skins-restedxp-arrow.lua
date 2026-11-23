-- test-skins-restedxp-arrow.lua: the waypoint's bright silhouette and dark edge survive dark art, accent changes and RestedXP's own updates without taking over its geometry or visibility.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local W = S.W
local rxp
local env, K, ns = S.New({ setup = function(e)
	e.ZoneTextFrame = e.CreateFrame("Frame", "ZoneTextFrame", e.UIParent)
	e.ZoneTextFrame:Hide()
	rxp = Fake.Install(e, { activeTheme = "DarkMode" })
	rxp.fake.trust(function()
		rxp.arrowFrame.texture:SetRotation(0.4)
		rxp.arrowFrame.texture:SetTexCoord(0.15, 0.85, 0.2, 0.8)
	end)()
end })
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
local regions = { arrow:GetRegions() }

local function Reused()
	local current = { arrow:GetRegions() }
	assert(#current == #regions, "reuse the arrow's existing layers and masks after every repaint; do not create more regions")
	for i, region in ipairs(regions) do assert(current[i] == region, "repaints must retain the original arrow regions") end
end

local function MasksFollow()
	local coords = { texture:GetTexCoord() }
	for _, layer in ipairs(layers) do
		local mask = layer._masks[1]
		assert(#layer._masks == 1 and mask:GetTexture() == texture:GetTexture(), "copy the current source artwork into each existing mask")
		assert(W.Near(mask:GetRotation(), texture:GetRotation()), "preserve the source rotation when the arrow is repainted")
		local actual = { mask:GetTexCoord() }
		assert(#actual == #coords, "preserve the source UV coordinate count")
		for i, value in ipairs(coords) do assert(W.Near(actual[i], value), "copy the source UV coordinates on initial paint and repaint") end
		local bounds, wanted = assert(Geometry.Rect(mask, arrow)), assert(Geometry.Rect(layer, arrow))
		for side, value in pairs(wanted) do assert(W.Near(bounds[side], value), "anchor each mask to its own layer, including the padded edge") end
	end
	Reused()
end
MasksFollow()

local function Visible()
	local c = W.LastCall(fill, "SetColorTexture")
	assert(c and Luminance(unpack(c)) >= 0.8, "keep the waypoint silhouette luminance >= 0.8 for dark zones, independent of the accent")
	c = W.LastCall(edge, "SetColorTexture")
	assert(c and Luminance(unpack(c)) <= 0.02 and c[4] == 1, "keep an opaque dark contrast layer for snow and desert")
	local layer, sublevel = fill:GetDrawLayer()
	assert(edge:GetDrawLayer() == "BACKGROUND" and texture:GetDrawLayer() == "ARTWORK" and layer == "ARTWORK" and sublevel == 1 and arrow.text:GetDrawLayer() == "OVERLAY", "draw the edge behind the source, its bright fill above it, and the label above both")
	assert(W.SameColor(texture, K.Tokens.Color("textEmphasis")), "keep the source texture bright beneath the silhouette")
	assert(edge:GetWidth() > texture:GetWidth() and edge:GetHeight() > texture:GetHeight(), "the dark silhouette extends beyond the bright arrow")
	local halfPixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(fill) / 2 + 1e-6
	assert(W.Near(fill:GetWidth(), texture:GetWidth(), halfPixel) and W.Near(fill:GetHeight(), texture:GetHeight(), halfPixel), "the bright silhouette follows the source size within pixel snapping")
	assert(Luminance(arrow.text:GetTextColor()) >= 0.8, "the distance remains bright")
	local shadow = W.LastCall(arrow.text, "SetShadowColor")
	assert(shadow and Luminance(unpack(shadow)) <= 0.02 and shadow[4] >= 0.85, "the distance needs a dark shadow on bright ground")
	local _, _, flags = arrow.text:GetFont()
	assert(flags and flags:find("OUTLINE", 1, true), "keep the distance outline after the skin applies its number font")
	local x, y = arrow.text:GetShadowOffset()
	assert(x > 0 and y < 0, "offset the distance shadow below and to the right so it stays visible")
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
MasksFollow()
rxp.fake.trust(function() texture:SetTexture("Interface/AddOns/RXPGuides/Textures/Green/rxp_navigation_arrow-1") end)()
MasksFollow()
for _, layer in ipairs(layers) do
	assert(W.Near(layer._masks[1]:GetRotation(), 1.25), "contrast layers rotate with RestedXP's DrawArrow")
end
rxp.fake.trust(function()
	texture:SetTexCoord(0.1, 0.9, 0.2, 0.8)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	texture:SetSize(48, 40)
end)()
MasksFollow()
for _, layer in ipairs(layers) do
	local a, b, c, d = layer._masks[1]:GetTexCoord()
	assert(a == 0.1 and b == 0.9 and c == 0.2 and d == 0.8, "copy, never replace, RestedXP's texture coordinates")
end
assert(texture:GetWidth() == 48 and texture:GetHeight() == 40 and fill:GetWidth() == 48 and fill:GetHeight() == 40, "both silhouettes follow a size RestedXP chooses")
assert(edge:GetWidth() > 48 and edge:GetHeight() > 40, "keep the dark edge padded after the source is resized")
local current = { texture:GetPoint(1) }
for _ = 1, 5 do
	rxp.SetupArrow()
	MasksFollow()
	arrow:UpdateVisuals()
	MasksFollow()
	ns.Style.RestyleAll()
	MasksFollow()
end
local after = { texture:GetPoint(1) }
assert(texture:GetNumPoints() == 1, "the skin must retain the source's single centre anchor")
for i = 1, 5 do assert(after[i] == current[i], "the skin must not move or re-anchor the source arrow") end
rxp.fake.trust(function()
	arrow.text:SetTextColor(0.01, 0.01, 0.01)
	arrow.text:SetShadowColor(1, 1, 1, 0)
	arrow.text:SetShadowOffset(0, 0)
end)()
arrow:UpdateVisuals()
Visible()
rxp.fake.trust(function() arrow:Hide() end)()
assert(not fill:IsVisible() and not edge:IsVisible(), "both layers hide with RestedXP")
rxp.fake.trust(function() arrow:Show(); arrow:SetAlpha(0.25) end)()
assert(fill:IsVisible() and edge:IsVisible() and arrow:GetAlpha() == 0.25, "RestedXP owns fading and showing")
rxp.SetupArrow()
MasksFollow()
assert(#env._errors == 0, tostring(env._errors[1]))
rxp.settings.profile.enableThemeLiveReload = false
local setups = rxp.arrows
K.Options.Write("Skins", "restedXP.enabled", false)
env.RunTimers()
assert(rxp.arrows == setups, "exercise switching the skin off without a RestedXP redraw")
assert(not fill:IsShown() and not edge:IsShown(), "switching off the skin removes its contrast layers")
K.Options.Write("Skins", "restedXP.enabled", true)
env.RunTimers()
assert(fill:IsShown() and edge:IsShown(), "switching back on reuses both layers")
Reused()
-- Blizzard's zone banner prints at the top centre, where players park the arrow: its step text makes way while
-- the banner shows and comes back when it fades (polish audit A #17), unless the setting is off.
local banner = env.ZoneTextFrame
local function Fade()
	banner:Hide()
	banner:GetScript("OnHide")(banner)
end
banner:Show()
assert(arrow.text:GetAlpha() == 0, "the arrow's text makes way while the zone name shows")
Fade()
assert(arrow.text:GetAlpha() == 1, "and comes back when it fades")
K.Options.Write("Skins", "restedXP.arrowYields", false)
banner:Show()
assert(arrow.text:GetAlpha() == 1, "switched off, the text stays over the banner")
K.Options.Write("Skins", "restedXP.arrowYields", true)
assert(arrow.text:GetAlpha() == 0, "switched on mid-banner, it makes way at once")
Fade()
assert(arrow.text:GetAlpha() == 1 and #env._errors == 0, tostring(env._errors[1]))
rawset(_G, "RENDER_SCENE_LIB", true)
local scene = dofile("Tools/render/scenes/restedxp_arrow.lua")()
assert(#scene.items == 4, "the focused arrow scene contains only the source, two contrast layers and distance")
assert(#dofile("Tools/render/guard.lua").Check(scene) == 0, "the arrow proof scene has no truncation or overflow")
-- A zone name already showing when the skin starts, a profile with the setting off, and an alpha RestedXP sets
-- while the setting is off (review of #773, findings 2 and 3): the skin restores only the alpha it took.
do
	local other
	local e2, K2 = S.New({ setup = function(e)
		e.ZoneTextFrame = e.CreateFrame("Frame", "ZoneTextFrame", e.UIParent)
		other = Fake.Install(e, { activeTheme = "DarkMode" })
	end })
	local text = other.arrowFrame.text
	K2.Modules.Enable("Skins")
	e2.RunTimers()
	assert(e2.ZoneTextFrame:IsShown() and text:GetAlpha() == 0, "a zone name already showing when the skin starts hides the text, got " .. text:GetAlpha())
	K2.Options.Write("Skins", "restedXP.arrowYields", false)
	K2.Store.CopyProfile(K2.Store.ProfileName(), "No yield")
	K2.Options.Write("Skins", "restedXP.arrowYields", true)
	K2.Store.SetProfile("No yield")
	e2.RunTimers()
	assert(text:GetAlpha() == 1, "a profile with the setting off gives the text back, got " .. text:GetAlpha())
	e2.ZoneTextFrame:Hide()
	other.fake.trust(function() text:SetAlpha(0.35) end)()
	e2.ZoneTextFrame:Show()
	assert(text:GetAlpha() == 0.35, "switched off, a zone name leaves RestedXP's own alpha alone, got " .. text:GetAlpha())
	assert(#e2._errors == 0, tostring(e2._errors[1]))
end
print("skins restedxp arrow ok: theme/class/dark custom; bright silhouette, dark edge, readable distance; rotation, UV, size and visibility preserved")
