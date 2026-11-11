-- test-ornament-settings.lua: painted native tiers, material gating, safe placement and tracked lifecycle controls.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local G = dofile("Tools/regression/ornament_guard_lib.lua")
local env, K = W.New()
local widgets, assets = K.Widgets, K.Widgets.OrnamentAssets
local profile = K.Store.Module("Widgets")
local reach = io.open("Tools/media/ornament_reach.json"):read("*a")
for name in pairs(assets) do assert(reach:find('"' .. name .. '"', 1, true), "only reachable tiers ship: " .. name) end
for name in reach:gmatch('"(%w+)": ') do assert(assets[name], "a reachable tier ships: " .. name) end
for name, spec in pairs(assets) do
	for i = 1, 4 do assert(type(spec[i]) == "number" and spec[i] > 0 and spec[i] == math.floor(spec[i]), "valid native metadata " .. name) end
	assert(spec[1] <= spec[3] and spec[2] <= spec[4], "native crop fits its sheet " .. name)
	local file = assert(io.open("Media/Textures/ForgedOrnaments/" .. name .. ".png", "rb"), "missing native texture " .. name)
	local header = file:read(24)
	file:close()
	assert(header and header:sub(1, 8) == "\137PNG\r\n\26\n", "malformed native PNG " .. name)
	local function number(offset)
		local a, b, c, d = header:byte(offset, offset + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	assert(number(17) == spec[3] and number(21) == spec[4], "PNG dimensions match native metadata " .. name)
end
local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
local pixel = K.Scale.Pixel(1) / widgets.ScaleFactor(frame)
frame:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 240.25 * pixel, -220.25 * pixel)
frame:SetSize(39 * pixel, 39 * pixel)
assert(widgets.Setting("ornaments") == "Full", "a new profile is Full")
profile.ornaments = nil
assert(widgets.Setting("ornaments") == "Full", "a profile saved before the setting existed reads Full, so it needs no migration")
for _, invalid in ipairs({ "wrong", true, env.Secret("Off") }) do
	profile.ornaments = invalid
	assert(widgets.Setting("ornaments") == "Full", "an invalid or secret stored level reads as the default, Full")
end
profile.ornaments = "Off"
local h = widgets.Ornament(frame, "ring")
assert(widgets.Setting("ornaments") == "Off" and h.used == 0 and #h.textures == 0, "Off creates no textures")
profile.ornaments = "Full"
profile.cardMaterial = "Glass"
h:Restyle()
assert(h.used == 0 and #h.textures == 0, "Glass suppresses Full ornaments before allocating art")
profile.cardMaterial = "ForgedBrackets"
local function check(handle, expected, label)
	handle.expected = expected
	local scene = Scene.Build(env)
	G.Check(scene.items, { [label] = handle }, {}, label, { 1920, 1080 }, assets, 1)
end
for _, side in ipairs({ 24, 25, 39, 41, 57, 59, 99, 100, 118, 159, 160 }) do
	frame:SetSize(side * pixel, side * pixel)
	for _, rank in ipairs({ "normal", "player", "elite", "boss" }) do
		h.player, h.elite, h.boss = rank == "player", rank == "elite", rank == "boss"
		h:Restyle()
		check(h, G.Expected(h, assets), rank .. " " .. side)
	end
end
profile.ornaments = "Subtle"
h:Restyle()
check(h, {}, "Subtle draws no portrait ring: the band and its pendants belong to Full")
profile.ornaments = "Full"
h:Restyle()
local map = env.CreateFrame("Frame", nil, K.Scale.Root())
map:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 900.25 * pixel, -300.25 * pixel)
map:SetSize(200 * pixel, 200 * pixel)
local corners = widgets.Ornament(map, "map")
check(corners, { "Map24", "Map24" }, "small Full minimap leaves the zone label clear")
profile.ornaments = "Subtle"
corners:Restyle()
check(corners, { "Map20", "Map20" }, "small Subtle minimap keeps both quieter top corners and leaves the zone label clear")
profile.ornaments = "Full"
map:SetSize(300 * pixel, 300 * pixel)
corners:Restyle()
check(corners, { "Map40", "Map40", "Map40", "Map40", "Point12" }, "large Full minimap has space below its face")
local originalWidth = frame.GetWidth
for _, bad in ipairs({ 0, -1, "unknown", env.Secret(40) }) do
	frame.GetWidth = function() return bad end
	assert(pcall(h.Restyle, h), "unknown and secret dimensions are safe")
	assert(h.used == 0, "unknown and secret dimensions suppress ornaments")
end
frame.GetWidth = originalWidth
local originalLeft, originalTop = frame.GetLeft, frame.GetTop
for _, value in ipairs({ false, "unknown", env.Secret(240) }) do
	frame.GetLeft = function() return value or nil end
	assert(pcall(h.Restyle, h) and h.used == 0, "unknown or secret left omits all art")
	frame.GetLeft = originalLeft
	frame.GetTop = function() return value or nil end
	assert(pcall(h.Restyle, h) and h.used == 0, "unknown or secret top omits all art")
	frame.GetTop = originalTop
end
local absent = env.CreateFrame("Frame", nil, K.Scale.Root())
absent:SetSize(39 * pixel, 39 * pixel)
local unplaced = widgets.Ornament(absent, "ring")
assert(unplaced.used == 0 and #unplaced.textures == 0, "unplaced frames omit rather than guess an origin")
local bar = env.CreateFrame("Frame", nil, K.Scale.Root())
bar:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 500 * pixel, -300 * pixel)
bar:SetSize(100 * pixel, 7 * pixel)
local caps = widgets.Ornament(bar, "bar")
bar:SetSize(100 * pixel, 3 * pixel)
caps:Restyle()
assert(caps.used == 0, "bars under four pixels omit their frame")
bar:SetSize(100 * pixel, 4 * pixel)
profile.ornaments = "Subtle"
caps:Restyle()
check(caps, { "Rail1", "Rail1", "EndPointed8", "EndPointed8" }, "a 4 px bar takes the smallest plain end tier outside its hairline")
for _, height in ipairs({ 8, 9, 10, 16 }) do
	bar:SetSize(100 * pixel, height * pixel)
	profile.ornaments = "Subtle"
	caps:Restyle()
	local plain = "EndPointed" .. (height + 4)
	check(caps, { "Rail1", "Rail1", plain, plain }, "Subtle rails and plain ends " .. height)
	profile.ornaments = "Full"
	caps:Restyle()
	local clawed = "EndClawed" .. (height + 14)
	check(caps, { "Rail6", "Rail6", clawed, clawed }, "Full rails keep the bar's keyline beside clawed ends " .. height)
	for i = 1, 2 do
		assert(math.abs(caps.textures[i]:GetWidth() / pixel - 102) < 0.001, "a rail stretches along its own length only")
	end
end
bar:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 500.25 * pixel, -300.25 * pixel)
bar:SetSize(100 * pixel, 8 * pixel)
profile.ornaments = "Subtle"
caps:Restyle()
check(caps, { "Rail1", "Rail1", "EndPointed12", "EndPointed12" }, "a bar between physical pixels is framed where the game snaps its edges")
assert(math.abs(caps.textures[1]:GetWidth() / pixel - 102) < 0.001, "a fractional bar's rail spans its snapped width")
bar:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 500 * pixel, -300 * pixel)
bar:SetSize(100 * pixel, 16 * pixel)
profile.ornaments = "Full"
caps:Restyle()
local lane = env.CreateFrame("Frame", nil, K.Scale.Root())
lane:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4 * pixel)
lane:SetSize(100 * pixel, 6 * pixel)
caps.near = { lane }
local function ends(handle)
	local scene, drawn, out = Scene.Build(env), {}, {}
	for _, item in ipairs(scene.items) do drawn[item.object] = item end
	for i = 1, handle.used do
		local name = tostring(drawn[handle.textures[i]] and drawn[handle.textures[i]].file):match("(%w+)%.png$")
		if name and not name:find("^Rail") then out[#out + 1] = name end
	end
	return out
end
profile.ornaments = "Subtle"
caps:Restyle()
local subtle = ends(caps)
assert(#subtle == 2 and subtle[1] == subtle[2] and subtle[1]:find("^EndPointed"), "beside the lane Subtle draws pointed ends, not " .. table.concat(subtle, ", "))
profile.ornaments = "Full"
caps:Restyle()
check(caps, { "Rail1", "Rail1", subtle[1], subtle[2] }, "a neighbouring lane four pixels away keeps the frame one pixel clear; where it blocks the claws, Full takes the end Subtle draws there (Wing caps only when they are no smaller)")
caps.near = nil
caps:Restyle()
profile.ornaments = "Off"
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
assert(h.used == 0 and caps.used == 0, "Off roundtrip hides tracked handles")
profile.ornaments = "Full"
K.Callbacks.Fire("ThemeChanged")
assert(h.used > 0 and caps.used == 4, "Full roundtrip restores tracked handles")
profile.cardMaterial = "Glass"
K.Callbacks.Fire("SettingChanged", "Widgets", "cardMaterial")
assert(h.used == 0 and caps.used == 0, "Glass roundtrip hides all art")
profile.cardMaterial = "ForgedBrackets"
K.Callbacks.Fire("SettingChanged", "Widgets", "cardMaterial")
assert(h.used > 0 and caps.used == 4, "forged material roundtrip restores art")
local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
local target = env.CreateFrame("Frame", nil, owner)
target:SetPoint("CENTER", frame, "CENTER")
target:SetSize(100 * pixel, 10 * pixel)
local attached = widgets.Ornament(owner, "bar", target)
target.IsShown = function() error("must not read target visibility") end
target.IsVisible = function() error("must not read target visibility") end
target:GetScript("OnHide")(target)
assert(attached.enabled == false and attached.used == 0, "hide callback records the intended hidden state")
target:GetScript("OnShow")(target)
assert(attached.enabled == true and attached.used == 4, "show callback records the intended visible state")
local before = caps.used
caps:Piece("MissingAsset", "CENTER", "CENTER", 0, 0)
assert(caps.used == before, "unknown asset metadata creates no texture")
local texture = caps.textures[1]
local setTexture = texture.SetTexture
texture.SetTexture = function() return false end
caps:Restyle()
assert(not texture:IsShown(), "a rejected texture falls back to the original unornamented frame")
texture.SetTexture = setTexture
caps:Restyle()
assert(texture:IsShown(), "a restored valid texture can be shown again")
print("ok painted ornament settings, native dimensions, placement and lifecycle")
