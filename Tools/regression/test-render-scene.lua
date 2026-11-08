-- test-render-scene.lua: Tools/render/scene.lua resolves frame rects as the game's anchor solver does and orders the drawables.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Scene = dofile("Tools/render/scene.lua")

local K = 1080 / 768

local function near(a, b, what)
	assert(type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-3, what .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local function rect(item, x, y, w, h, what)
	near(item.rect[1], x, what .. " x")
	near(item.rect[2], y, what .. " y")
	near(item.rect[3], w, what .. " w")
	near(item.rect[4], h, what .. " h")
end

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local env = Stubs.NewEnv({ width = 1920, height = 1080 })
local UIParent = env.UIParent

-- A frame anchored at an offset from UIParent's top left, in 1080-unit screen coordinates from the top left.
local f = env.CreateFrame("Frame", "F", UIParent)
f:SetSize(100, 50)
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -20)
local full = f:CreateTexture(nil, "BACKGROUND")
full:SetAllPoints(f)
full:SetColorTexture(1, 1, 1, 1)

-- Two-point stretch: TOPLEFT and BOTTOMRIGHT with insets.
local stretch = f:CreateTexture(nil, "ARTWORK")
stretch:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
stretch:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
stretch:SetColorTexture(1, 0, 0, 1)

-- A scaled child: its offsets and size are in its own units, so they double on screen.
local child = env.CreateFrame("Frame", nil, f)
child:SetScale(2)
child:SetSize(10, 10)
child:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
local childTexture = child:CreateTexture(nil, "OVERLAY")
childTexture:SetAllPoints(child)
childTexture:SetColorTexture(0, 1, 0, 1)

-- A child that ignores its parent's scale draws at its own scale alone, as a plate on a nameplate base the game
-- scaled to 0.58 does.
local base = env.CreateFrame("Frame", nil, f)
base:SetScale(0.58)
base:SetSize(10, 10)
base:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
local held = env.CreateFrame("Frame", nil, base)
held:SetIgnoreParentScale(true)
held:SetScale(1)
held:SetSize(10, 10)
held:SetPoint("TOPLEFT", base, "TOPLEFT", 5, -5)
local heldTexture = held:CreateTexture(nil, "OVERLAY")
heldTexture:SetAllPoints(held)
heldTexture:SetColorTexture(1, 1, 0, 1)

-- Relative to a frame by name, at another point of it.
local g = env.CreateFrame("Frame", nil, UIParent)
g:SetSize(10, 10)
g:SetPoint("CENTER", "F", "BOTTOM", 0, 0)
local gTexture = g:CreateTexture(nil, "BACKGROUND")
gTexture:SetAllPoints(g)
gTexture:SetColorTexture(0, 0, 1, 1)

-- A status bar fills a quarter of its width.
local bar = env.CreateFrame("StatusBar", nil, f)
bar:SetAllPoints(f)
bar:SetStatusBarTexture("Interface\\AddOns\\KstyleUI\\Media\\Textures\\BarFlat.png")
bar:SetMinMaxValues(0, 200)
bar:SetValue(50)

-- Hidden frames and their regions are left out. Alpha multiplies down the chain.
local hidden = env.CreateFrame("Frame", nil, f)
hidden:SetAllPoints(f)
hidden:Hide()
local hiddenTexture = hidden:CreateTexture()
hiddenTexture:SetAllPoints(hidden)
hiddenTexture:SetColorTexture(1, 1, 1, 1)
local faded = env.CreateFrame("Frame", nil, f)
faded:SetAllPoints(f)
faded:SetAlpha(0.5)
local fadedTexture = faded:CreateTexture()
fadedTexture:SetAllPoints(faded)
fadedTexture:SetColorTexture(1, 1, 1, 1)
fadedTexture:SetAlpha(0.5)

local scene = Scene.Build(env)
assert(type(scene.items) == "table" and #scene.items > 0, "the scene has drawables")
near(scene.screen.width, 1920, "screen width in units")
near(scene.screen.height, 1080, "screen height in units")

rect(find(scene, full), 10 * K, 20 * K, 100 * K, 50 * K, "the frame's full texture")
rect(find(scene, stretch), 20 * K, 30 * K, 80 * K, 30 * K, "the stretched texture")
rect(find(scene, childTexture), 20 * K, 30 * K, 20 * K, 20 * K, "the scaled child")
rect(find(scene, heldTexture), 15 * K, 25 * K, 10 * K, 10 * K, "a child ignoring its parent's 0.58 scale")
rect(find(scene, gTexture), (10 + 50 - 5) * K, (20 + 50 - 5) * K, 10 * K, 10 * K, "relative by name")

local fill = find(scene, bar:GetStatusBarTexture())
rect(fill, 10 * K, 20 * K, 25 * K, 50 * K, "the status bar fill")
near(fill.fraction, 0.25, "the fill fraction")

assert(find(scene, hiddenTexture) == nil, "a hidden frame's texture is left out")
near(find(scene, fadedTexture).alpha, 0.25, "alpha multiplies down the chain")

-- Draw order: BACKGROUND under ARTWORK under a child frame's OVERLAY; the frame on UIParent after the child.
local function index(object)
	for i, item in ipairs(scene.items) do
		if item.object == object then
			return i
		end
	end
	error("not in the scene")
end
assert(index(full) < index(stretch), "BACKGROUND draws before ARTWORK")
assert(index(stretch) < index(childTexture), "a parent's regions draw before its children's")
assert(index(full) < index(gTexture), "a lower frame level draws first")

-- Every item resolves to colours and no item is silently dropped.
local colors = find(scene, stretch)
near(colors.color[1], 1, "the colour texture's red")
assert(type(scene.log) == "table", "the scene keeps a log")

-- A frame with no anchors is logged, not drawn.
local loose = env.CreateFrame("Frame", nil, UIParent)
loose:SetSize(10, 10)
local looseTexture = loose:CreateTexture()
looseTexture:SetAllPoints(loose)
looseTexture:SetColorTexture(1, 1, 1, 1)
scene = Scene.Build(env)
assert(find(scene, looseTexture) == nil, "an unanchored frame is not drawn")
local logged = false
for _, line in ipairs(scene.log) do
	logged = logged or line:find("no anchors", 1, true) ~= nil
end
assert(logged, "the unanchored frame is logged")

-- A frame moved under a hidden parent with SetParent stops drawing; a gradient keeps both stops in JSON.
local moved = env.CreateFrame("Frame", nil, UIParent)
moved:SetAllPoints(UIParent)
local movedTexture = moved:CreateTexture()
movedTexture:SetAllPoints(moved)
movedTexture:SetColorTexture(1, 1, 1, 1)
movedTexture:SetGradient("HORIZONTAL", { r = 1, g = 0, b = 0, a = 1 }, { r = 0, g = 0, b = 1, a = 1 })
scene = Scene.Build(env)
local gradient = find(scene, movedTexture).gradient
assert(gradient and gradient.from[1] == 1 and gradient.to[3] == 1, "the gradient keeps its stops")
assert(Scene.ToJSON(scene):find('"from":[1,0,0,1]', 1, true), "the stops reach the JSON")
moved:SetParent(hidden)
scene = Scene.Build(env)
assert(find(scene, movedTexture) == nil, "a frame reparented under a hidden frame is not drawn")

-- A cooldown shows its swipe from SetCooldown against the clock, and none once Clear came last.
local cooldown = env.CreateFrame("Cooldown", nil, f)
cooldown:SetAllPoints(f)
cooldown:SetCooldown(6, 8)
local fraction, left = Scene.CooldownFraction(env, cooldown, 10)
near(fraction, 0.5, "half the cooldown remains")
near(left, 4, "four seconds remain")
assert(find(Scene.Build(env, { time = 10 }), cooldown).kind == "swipe", "the swipe is a drawable")
cooldown:Clear()
assert(Scene.CooldownFraction(env, cooldown, 10) == nil, "a cleared cooldown has no swipe")
assert(find(Scene.Build(env, { time = 10 }), cooldown) == nil, "a cleared cooldown draws nothing")

-- The countdown draws through the font string GetCountdownFontString gives, as the game does, so the
-- addon's font, colour and anchor place the number; the swipe carries no number of its own.
local timed = env.CreateFrame("Cooldown", nil, f)
timed:SetAllPoints(f)
timed:SetCooldown(6, 8)
local countdown = timed:GetCountdownFontString()
assert(countdown and countdown:GetObjectType() == "FontString" and countdown:GetParent() == timed, "a Cooldown has a countdown font string")
assert(timed:GetCountdownFontString() == countdown, "the same one each time")
countdown:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 11, "")
countdown:SetPoint("CENTER", timed, "BOTTOM", 0, 10)
local built = Scene.Build(env, { time = 10 })
local swipe = find(built, timed)
assert(swipe and swipe.kind == "swipe" and swipe.countdown == nil, "the swipe draws no number of its own")
local number = find(built, countdown)
assert(number and number.kind == "text" and number.text == "4", "the font string draws the seconds left")
assert(number.font.path:find("SourceSans3%-Semibold") and number.font.size > 0, "in the font the addon set")
near(number.rect[2] + number.rect[4] / 2, (20 + 50 - 10) * K, "centred where the font string is anchored")
timed:SetCountdownFormatter({ Format = function(_, seconds) return string.format("%ds", seconds) end })
built = Scene.Build(env, { time = 10 })
assert(find(built, countdown).text == "4s", "a countdown formatter on the Cooldown writes the number, as the engine would")
timed:SetCountdownFormatter(nil)
timed:SetHideCountdownNumbers(true)
built = Scene.Build(env, { time = 10 })
assert(find(built, countdown) == nil and find(built, timed).countdown == nil, "hidden numbers draw nothing")
timed:SetHideCountdownNumbers(false)
timed:Clear()
built = Scene.Build(env, { time = 10 })
assert(find(built, countdown) == nil, "a cleared cooldown leaves the font string empty")

-- A font string with no size of its own is as tall as its lines: a title that keeps a blank second line for a
-- caption ("NAME\n ") is two lines tall, so a caption anchored to its bottom sits under the name.
local twoLines = f:CreateFontString(nil, "ARTWORK")
twoLines:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 10, "")
twoLines:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
twoLines:SetText("NAME\n ")
local oneLine = f:CreateFontString(nil, "ARTWORK")
oneLine:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 10, "")
oneLine:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
oneLine:SetText("NAME")
scene = Scene.Build(env)
near(find(scene, twoLines).rect[4], 2 * find(scene, oneLine).rect[4], "a two-line text is twice as tall as a one-line text")
local h = select(4, Scene.Rect(env, twoLines))
near(h, 2 * select(4, Scene.Rect(env, oneLine)), "Rect sees the two lines too")

-- JSON: the encoder writes the scene without the object references and round-trips a number.
local json = Scene.ToJSON(scene)
assert(json:find('"items"', 1, true) and not json:find("table:", 1, true), "JSON has items and no table addresses")
assert(json:find('"fraction":0.25', 1, true), "numbers are written plainly")

print("ok")
