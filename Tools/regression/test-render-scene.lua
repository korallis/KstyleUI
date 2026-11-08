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

-- A font string with a width from two anchors, word wrap on and no height of its own is as tall as its wrapped
-- lines, so a text anchored under it sits below the whole paragraph, as the chat preview's sample lines do.
local column = env.CreateFrame("Frame", nil, UIParent)
column:SetSize(100, 200)
column:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
local paragraph = column:CreateFontString(nil, "ARTWORK")
paragraph:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 10, "")
paragraph:SetWordWrap(true)
paragraph:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
paragraph:SetPoint("RIGHT", column, "RIGHT", 0, 0)
paragraph:SetText("Anyone for the crocolisk hunt by the river tonight")
local under = column:CreateFontString(nil, "ARTWORK")
under:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 10, "")
under:SetPoint("TOPLEFT", paragraph, "BOTTOMLEFT", 0, 0)
under:SetText("next")
scene = Scene.Build(env)
local paragraphItem, underItem = find(scene, paragraph), find(scene, under)
local lineH = find(scene, oneLine).rect[4]
local lines = Scene.TextWidth("Anyone for the crocolisk hunt by the river tonight", 10, "SourceSans3-Semibold.ttf") / 100
assert(lines > 2, "the sample text needs more than two 100-unit lines at 10 units, got " .. tostring(lines))
assert(paragraphItem.rect[4] >= 3 * lineH - 1e-3, "a wrapped text is as tall as its wrapped lines, got " .. tostring(paragraphItem.rect[4]) .. " for a line of " .. tostring(lineH))
near(underItem.rect[2], paragraphItem.rect[2] + paragraphItem.rect[4], "the next text sits under the whole paragraph")
assert(paragraphItem.natural == nil or paragraphItem.natural.height == nil, "the page keeps the solver's height instead of re-deriving one line")
assert(paragraphItem.grow == "top", "a wrapped text anchored at its top grows down from it, so the page draws a shorter measured block at the top, not centred: " .. tostring(paragraphItem.grow))
local noWrap = column:CreateFontString(nil, "ARTWORK")
noWrap:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf", 10, "")
noWrap:SetWordWrap(false)
noWrap:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -100)
noWrap:SetPoint("RIGHT", column, "RIGHT", 0, 0)
noWrap:SetText("Anyone for the crocolisk hunt by the river tonight")
scene = Scene.Build(env)
near(find(scene, noWrap).rect[4], lineH, "a text with word wrap off stays one line tall")

-- An atlas draws from the atlas cache when it is known there: the region takes the sheet's file, the member's
-- texture coordinates, and with useAtlasSize the member's size; an unknown atlas stays a grey box and is logged.
Scene.ATLAS = {
	["ui-test-glyph"] = { file = "Media/Textures/Dot.png", left = 0.25, right = 0.75, top = 0, bottom = 0.5, width = 16, height = 8 },
	["ui-test-missing"] = { file = "Tools/render/out/no-such-sheet.png", left = 0, right = 1, top = 0, bottom = 1, width = 4, height = 4 },
}
local glyph = f:CreateTexture(nil, "ARTWORK")
glyph:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
glyph:SetAtlas("UI-Test-Glyph", true)
local sized = f:CreateTexture(nil, "ARTWORK")
sized:SetSize(30, 30)
sized:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
sized:SetAtlas("ui-test-glyph")
local resized = f:CreateTexture(nil, "ARTWORK")
resized:SetSize(30, 30)
resized:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
resized:SetAtlas("ui-test-glyph", true)
local unknown = f:CreateTexture(nil, "ARTWORK")
unknown:SetSize(10, 10)
unknown:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
unknown:SetAtlas("UI-Not-In-The-Client")
local missing = f:CreateTexture(nil, "ARTWORK")
missing:SetSize(10, 10)
missing:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
missing:SetAtlas("UI-Test-Missing")
scene = Scene.Build(env)
local glyphItem = find(scene, glyph)
assert(glyphItem.file == "Media/Textures/Dot.png", "a known atlas draws its sheet, got " .. tostring(glyphItem.file))
assert(glyphItem.atlas == "UI-Test-Glyph", "the item still names the atlas")
local tc = glyphItem.texCoord
assert(tc, "the member's coordinates become the texture coordinates")
near(tc[1], 0.25, "atlas left")
near(tc[2], 0.75, "atlas right")
near(tc[3], 0, "atlas top")
near(tc[4], 0.5, "atlas bottom")
near(glyphItem.rect[3], 16 * K, "useAtlasSize gives the region the member's width")
near(glyphItem.rect[4], 8 * K, "and its height")
near(find(scene, sized).rect[3], 30 * K, "a sized region keeps its own size")
near(find(scene, resized).rect[3], 16 * K, "useAtlasSize overrides a size the region had, as the game's SetAtlas sizes the region")
near(find(scene, resized).rect[4], 8 * K, "in both directions")
local unknownItem, missingItem = find(scene, unknown), find(scene, missing)
assert(unknownItem.file == nil and unknownItem.atlas == "UI-Not-In-The-Client", "an unknown atlas stays a grey box")
assert(missingItem.file == nil, "a known atlas whose sheet is not in the cache stays a grey box")
local sawUnknown, sawMissing, sawGlyph = false, false, false
for _, line in ipairs(scene.log) do
	sawUnknown = sawUnknown or (line:find("UI-Not-In-The-Client", 1, true) ~= nil and line:find("grey box", 1, true) ~= nil)
	sawMissing = sawMissing or (line:find("UI-Test-Missing", 1, true) ~= nil and line:find("atlas.py", 1, true) ~= nil)
	sawGlyph = sawGlyph or line:find("UI-Test-Glyph", 1, true) ~= nil
end
assert(sawUnknown, "the unknown atlas is logged as a grey box")
assert(sawMissing, "the missing sheet is logged with the command that fetches it")
assert(not sawGlyph, "a drawn atlas is not logged")
Scene.ATLAS = {}
glyph:Hide()
sized:Hide()
unknown:Hide()
missing:Hide()
resized:Hide()

-- A Blizzard texture named by file path draws from the texture cache's paths folder under a key that ignores
-- case, the separator and the extension; a path the cache lacks stays a grey box and is logged with the command
-- that fetches it; an addon's own file and a path outside Interface never look in the cache.
assert(Scene.PathKey("Interface\\TargetingFrame\\UI-RaidTargetingIcons") == "interface/targetingframe/ui-raidtargetingicons", "a key is lowercased with forward slashes")
assert(Scene.PathKey("interface/targetingframe/UI-RaidTargetingIcons.BLP") == "interface/targetingframe/ui-raidtargetingicons", "and drops the extension")
assert(Scene.PathKey("Interface\\AddOns\\KstyleUI\\Media\\Textures\\Dot.png") == nil, "an addon's file is not a client path")
assert(Scene.PathKey("Fonts\\FRIZQT__.TTF") == nil, "a font is not a texture path")
assert(Scene.PathKey(136235) == nil, "a file ID is not a path")
local pathsDir = "Tools/render/out/paths-test"
os.execute("mkdir -p " .. pathsDir .. "/interface/test")
do
	local source = assert(io.open("Media/Textures/Dot.png", "rb"))
	local bytes = source:read("*a")
	source:close()
	local copy = assert(io.open(pathsDir .. "/interface/test/glyph.png", "wb"))
	copy:write(bytes)
	copy:close()
end
Scene.PATHS_DIR = pathsDir
local byPath = f:CreateTexture(nil, "ARTWORK")
byPath:SetSize(10, 10)
byPath:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
byPath:SetTexture("Interface\\Test\\GLYPH.blp")
local bySlash = f:CreateTexture(nil, "ARTWORK")
bySlash:SetSize(10, 10)
bySlash:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
bySlash:SetTexture("interface/test/glyph")
local noSuch = f:CreateTexture(nil, "ARTWORK")
noSuch:SetSize(10, 10)
noSuch:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
noSuch:SetTexture("Interface\\Test\\NotCached")
local cellOf = f:CreateTexture(nil, "ARTWORK")
cellOf:SetSize(10, 10)
cellOf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
cellOf:SetTexture("Interface\\Test\\Glyph")
cellOf:SetSpriteSheetCell(env.Secret(8), 4, 4)
scene = Scene.Build(env)
assert(find(scene, byPath).file == pathsDir .. "/interface/test/glyph.png", "a path texture draws the cached PNG, got " .. tostring(find(scene, byPath).file))
assert(find(scene, bySlash).file == pathsDir .. "/interface/test/glyph.png", "whatever the separator, case and extension")
local noSuchItem = find(scene, noSuch)
assert(noSuchItem.file == nil and noSuchItem.missing == "Interface\\Test\\NotCached", "a path the cache lacks stays a grey box")
local sawPath = false
for _, line in ipairs(scene.log) do
	sawPath = sawPath or (line:find("Interface\\Test\\NotCached", 1, true) ~= nil and line:find("grey box", 1, true) ~= nil and line:find("atlas.py paths", 1, true) ~= nil)
end
assert(sawPath, "the missing path is logged as a grey box with the fetch command")
local cellCoords = find(scene, cellOf).texCoord
assert(cellCoords, "a sprite sheet cell sets the texture coordinates")
near(cellCoords[1], 0.75, "cell 8 of a 4 by 4 sheet: left")
near(cellCoords[2], 1, "right")
near(cellCoords[3], 0.25, "top")
near(cellCoords[4], 0.5, "bottom")
-- A flat colour set after a file replaces it, so the region draws the colour and is not a missing texture; a file
-- set after the colour draws the file.
local recoloured = f:CreateTexture(nil, "ARTWORK")
recoloured:SetSize(10, 10)
recoloured:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
recoloured:SetTexture("Interface\\Test\\NotCached")
recoloured:SetColorTexture(0.1, 0.2, 0.3, 1)
local refiled = f:CreateTexture(nil, "ARTWORK")
refiled:SetSize(10, 10)
refiled:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
refiled:SetColorTexture(0.1, 0.2, 0.3, 1)
refiled:SetTexture("Interface\\Test\\Glyph")
scene = Scene.Build(env)
local recolouredItem = find(scene, recoloured)
assert(recolouredItem.missing == nil and recolouredItem.file == nil and recolouredItem.color, "a colour set after the file draws the colour alone")
local notCachedLines = 0
for _, line in ipairs(scene.log) do
	if line:find("NotCached", 1, true) and line:find("grey box", 1, true) then
		notCachedLines = notCachedLines + 1
	end
end
assert(notCachedLines == 1, "only the uncoloured missing texture is logged as a grey box, got " .. notCachedLines .. " lines")
assert(find(scene, refiled).file == pathsDir .. "/interface/test/glyph.png", "a file set after the colour draws the file")
Scene.PATHS_DIR = nil
byPath:Hide()
bySlash:Hide()
noSuch:Hide()
cellOf:Hide()
recoloured:Hide()
refiled:Hide()

-- A playing animation group moves and fades its frame as the game would at the scene's clock: a Translation
-- shifts the frame by its offset times its progress, an Alpha animation scales the frame's alpha, a start delay
-- waits, and a finished group leaves the frame at the animation's end; a stopped group leaves it where it was.
env._now = 5
local mover = env.CreateFrame("Frame", nil, UIParent)
mover:SetSize(10, 10)
mover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
local moverFill = mover:CreateTexture(nil, "ARTWORK")
moverFill:SetAllPoints(mover)
moverFill:SetColorTexture(1, 1, 1, 1)
local group = mover:CreateAnimationGroup()
local move = group:CreateAnimation("Translation")
move:SetOffset(10, 20)
move:SetDuration(2)
local fade = group:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0)
fade:SetStartDelay(1)
fade:SetDuration(1)
scene = Scene.Build(env, { time = 6.5 })
rect(find(scene, moverFill), 100 * K, 100 * K, 10 * K, 10 * K, "before Play the frame sits where it is anchored")
group:Play()
assert(group:IsPlaying() == true, "a played group is playing")
scene = Scene.Build(env, { time = 6.5 })
local moving = find(scene, moverFill)
rect(moving, (100 + 7.5) * K, (100 - 15) * K, 10 * K, 10 * K, "at 1.5 s of a 2 s translation the frame has moved three quarters of its offset, up and right")
near(moving.alpha, 0.5, "the alpha animation, half a second into its second, halves the frame")
scene = Scene.Build(env, { time = 5.5 })
near(find(scene, moverFill).alpha, 1, "before its start delay the alpha animation leaves the frame opaque")
scene = Scene.Build(env, { time = 9 })
assert(find(scene, moverFill) == nil, "a finished fade leaves the frame transparent, so it is not drawn")
group:Stop()
assert(group:IsPlaying() == false, "a stopped group is not playing")
scene = Scene.Build(env, { time = 6.5 })
rect(find(scene, moverFill), 100 * K, 100 * K, 10 * K, 10 * K, "a stopped group leaves the frame where it is anchored")
mover:Hide()

-- SetAlphaFromBoolean(secret, onAlpha, offAlpha) picks the region's alpha from a secret boolean, as the game does
-- without the addon reading it; the later of it and SetAlpha wins.
local hiddenBySecret = f:CreateTexture(nil, "ARTWORK")
hiddenBySecret:SetSize(5, 5)
hiddenBySecret:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
hiddenBySecret:SetColorTexture(1, 1, 1, 1)
hiddenBySecret:SetAlphaFromBoolean(env.Secret(false), 1, 0)
local shownBySecret = f:CreateTexture(nil, "ARTWORK")
shownBySecret:SetSize(5, 5)
shownBySecret:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
shownBySecret:SetColorTexture(1, 1, 1, 1)
shownBySecret:SetAlpha(0)
shownBySecret:SetAlphaFromBoolean(env.Secret(true), 0.5, 0)
local plainAfter = f:CreateTexture(nil, "ARTWORK")
plainAfter:SetSize(5, 5)
plainAfter:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
plainAfter:SetColorTexture(1, 1, 1, 1)
plainAfter:SetAlphaFromBoolean(env.Secret(false), 1, 0)
plainAfter:SetAlpha(0.25)
scene = Scene.Build(env)
assert(find(scene, hiddenBySecret) == nil, "a secret false with an off alpha of 0 leaves the region transparent")
near(find(scene, shownBySecret).alpha, 0.5, "a secret true gives the on alpha, over an earlier SetAlpha")
near(find(scene, plainAfter).alpha, 0.25, "a later SetAlpha wins over SetAlphaFromBoolean")
hiddenBySecret:Hide()
shownBySecret:Hide()
plainAfter:Hide()

-- JSON: the encoder writes the scene without the object references and round-trips a number.
local json = Scene.ToJSON(scene)
assert(json:find('"items"', 1, true) and not json:find("table:", 1, true), "JSON has items and no table addresses")
assert(json:find('"fraction":0.25', 1, true), "numbers are written plainly")

print("ok")
