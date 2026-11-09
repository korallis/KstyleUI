-- test-tokens.lua: no colour literal outside Core/Tokens.lua, and Tokens holds the spec's values.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Lint = dofile("Tools/regression/color_lint.lua")

local TOKENS_FILE = "Core/Tokens.lua"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function kinds(findings)
	local seen = {}
	for _, f in ipairs(findings) do
		seen[f.kind] = (seen[f.kind] or 0) + 1
	end
	return seen
end

-- The lint ----------------------------------------------------------------------------------------

local bad = kinds(Lint.Lua(read("Tools/regression/fixtures/tokens/bad.lua")))
for kind, count in pairs({ hex = 3, ["hex-number"] = 1, ["rgb-call"] = 3, ["rgb-table"] = 1 }) do
	assert(bad[kind] == count, "bad.lua: expected " .. count .. " " .. kind .. " findings, got " .. tostring(bad[kind]))
end
local good = Lint.Lua(read("Tools/regression/fixtures/tokens/good.lua"))
assert(#good == 0, "good.lua must be clean, got " .. (good[1] and (good[1].line .. " " .. good[1].kind .. " " .. good[1].text) or ""))

local badXml = Lint.Xml(read("Tools/regression/fixtures/tokens/bad.xml"))
assert(#badXml == 1 and badXml[1].kind == "xml-color" and badXml[1].line == 6, "bad.xml: expected one xml-color finding on line 6")
assert(#Lint.Xml(read("Tools/regression/fixtures/tokens/good.xml")) == 0, "good.xml must be clean")

-- Every TOC-loaded file -----------------------------------------------------------------------------

local files = TocFiles("%.lua$")
for _, path in ipairs(TocFiles("%.xml$")) do
	files[#files + 1] = path
end
local problems, scanned, sawTokens = {}, 0, false
for _, path in ipairs(files) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		local findings = path:match("%.lua$") and Lint.Lua(read(path)) or Lint.Xml(read(path))
		if path == TOKENS_FILE then
			sawTokens = true
			assert(#findings > 0, "the lint finds no colours in " .. TOKENS_FILE .. ", so it cannot see the literals it exempts")
		else
			for _, f in ipairs(findings) do
				problems[#problems + 1] = string.format("%s:%d: %s %s", path, f.line, f.kind, f.text)
			end
		end
		scanned = scanned + 1
	end
end
assert(sawTokens, TOKENS_FILE .. " is not TOC-loaded")
if #problems > 0 then
	print(#problems .. " colour literals outside " .. TOKENS_FILE .. ". Add a token there and read it with KstyleUI.Tokens.Color.")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end

-- The tokens ----------------------------------------------------------------------------------------

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end
local env = Load(core, Stubs.NewEnv())
local Tokens = env.KstyleUI.Tokens

local function near(a, b)
	return math.abs(a - b) < 0.5 / 255
end

local function hexColor(hex)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- The Lumen palette, from the mockup's :root (handoff arena2/parent/index.html), and the older names mapped onto it:
-- the surface is the deep tint under the frost, the panel edge is the rim light, the button body is the socket's
-- dark crystal, body text is the muted tone and emphasis the mockup's text colour. The deep tint, the body text and
-- the bar track are raised from the mockup's 62%, #a9b6c2 and 70% so text reads over bright scenery; test-legibility.lua
-- holds the contrast they buy.
for name, want in pairs({
	glass = { "e1f0fa", 0.22 },
	deep = { "0c141e", 0.88 },
	rim = { "d6eeff", 0.55 },
	rimSoft = { "d6eeff", 0.18 },
	giltLit = { "f3dca4", 1 },
	gilt = { "d9b46a", 1 },
	giltDim = { "8a6c34", 1 },
	muted = { "a9b6c2", 1 },
	dim = { "6f7d8a", 1 },
	hostile = { "e2524f", 1 },
	friend = { "62d58d", 1 },
	magic = { "5aa9ff", 1 },
	quest = { "f6d27a", 1 },
	surface = { "0c141e", 0.88 },
	raised = { "1a2633", 0.85 },
	edgeOuter = { "000000", 0.5 },
	edgeInner = { "d6eeff", 0.55 },
	edgeFaint = { "d6eeff", 0.08 },
	edgeBar = { "d6eeff", 0.14 },
	text = { "c8d1da", 1 },
	textEmphasis = { "f2f5f8", 1 },
	textHover = { "ffffff", 1 },
	textDisabled = { "6f7d8a", 1 },
	rare = { "4fc3ff", 1 },
	epic = { "b67cff", 1 },
	buttonFill = { "0a1018", 0.7 },
	track = { "05090e", 0.88 },
}) do
	local r, g, b, a = Tokens.Color(name)
	local wr, wg, wb = hexColor(want[1])
	assert(near(r, wr) and near(g, wg) and near(b, wb) and near(a, want[2]), "Tokens.Color(" .. name .. ") is not #" .. want[1])
end
do
	assert(not pcall(Tokens.Color, "powerTrack"), "powerTrack is gone: the power track is the button body")
	local r, g, b, a = Tokens.Color("shadow")
	assert(r == 0 and g == 0 and b == 0 and near(a, 0.45), "the panel shadow is black at 45%, between the mockup's 35% drop and 50% contact shadows")
end
for _, name in ipairs({ "neutral", "friendly", "accent", "accentDefault", "textShadow", "white", "black" }) do
	local r, g, b, a = Tokens.Color(name)
	for _, v in ipairs({ r, g, b, a }) do
		assert(type(v) == "number" and v >= 0 and v <= 1, "Tokens.Color(" .. name .. ") returns four numbers in 0..1")
	end
end
assert(not pcall(Tokens.Color, "surfaec"), "an unknown colour name is an error")
for _, name in ipairs({ "edgeWindowOuter", "edgeWindowInner", "edgeWindowFaint" }) do
	assert(not pcall(Tokens.Color, name), name .. " is gone: the mockup draws every panel with the one edge line")
end

-- Lumen's corner radii (cards, rails and windows 14, sockets and small tiles 8; the old chamfer names read the radii),
-- its spacing scale 4/8/12/16/20/28, the rail column and screen margin, the HUD sizes, type scale and motion.
for name, want in pairs({
	radius = 14, radiusTile = 8, chamferPanel = 14, chamferTile = 8, chamferWindow = 14, shadow = 14, shadowOffset = 3,
	gapSmall = 4, gapMedium = 8, gapLarge = 12, gapHuge = 16, gapXLarge = 20, gapXXLarge = 28,
	railWidth = 318, railPadding = 20, sectionGap = 22, rowGap = 12, socketGap = 8, screenMargin = 28,
	actionButton = 34, actionGap = 3, cooldownEssential = 40,
	cooldownUtility = 30, unitFrameWidth = 220, unitFrameHeight = 46, portrait = 46, buffBarWidth = 180,
	buffBarHeight = 18, display = 22, heading = 16, title = 12, body = 12, caption = 11, number = 12, world = 13, textShadowOffset = 1,
	pressOffset = 1, panelRise = 16, panelOvershoot = 2,
}) do
	assert(Tokens.Size(name) == want, "Tokens.Size(" .. name .. ") is " .. tostring(Tokens.Size(name)) .. ", spec says " .. want)
end
assert(not pcall(Tokens.Size, "nope"), "an unknown size is an error")
-- A socket rounds its corners 11 units on the mockup's 52-unit socket, as a share of its side.
assert(Tokens.Share("radiusSocket") == 11 / 52, "the socket's corner share")
for _, name in ipairs({ "chamfer", "chamferIcon" }) do
	assert(not pcall(Tokens.Share, name), "the " .. name .. " share is retired with the chamfers")
end
assert(not pcall(Tokens.Size, "buttonBezel"), "the chamfered button's bezel is retired")
assert(not pcall(Tokens.Share, "nope"), "an unknown share is an error")
-- Lumen's motion: hover 0.12, combat in 0.24, combat out 0.6 after 3 seconds, proc breathing 0.7.
for name, want in pairs({
	hover = 0.12, combatIn = 0.24, combatOut = 0.6, combatOutDelay = 3, panelOpen = 0.25, panelRise = 0.4, panelClose = 0.15,
	listStagger = 0.05, castSheen = 0.6, procPulse = 0.7,
}) do
	assert(Tokens.Duration(name) == want, "Tokens.Duration(" .. name .. ") is " .. tostring(Tokens.Duration(name)))
end
assert(not pcall(Tokens.Duration, "nope"), "an unknown duration is an error")
assert(Tokens.Easing("hover") == "outQuad" and Tokens.Easing("combatIn") == "outCubic" and Tokens.Easing("combatOut") == "inOutSine", "hover eases out-quad, combat in out-cubic, combat out in-out sine")
for _, name in ipairs({ "hover", "combatIn", "combatOut", "panelOpen", "panelRise", "panelClose", "fade" }) do
	assert(type(env.KstyleUI.Motion.Ease[Tokens.Easing(name)]) == "function", "Motion has the " .. Tokens.Easing(name) .. " easing")
end

-- A game path names a file in this repository: Interface\AddOns\KstyleUI\<path>.
local function onDisk(gamePath)
	local rel = assert(gamePath:match("^Interface\\AddOns\\KstyleUI\\(.+)$"), gamePath .. " is not under the KstyleUI folder")
	local handle = io.open((rel:gsub("\\", "/")), "rb")
	if handle then
		handle:close()
	end
	return handle ~= nil
end

-- Font roles: the default face set is Lumen, Cinzel for heads and section titles and Alegreya Sans Tabular for captions, body text and
-- numbers; test-lumen-material.lua covers each role's face and the Source Sans choice.
for role, size in pairs({ display = 22, heading = 16, title = 12, body = 12, caption = 11, number = 12, world = 13 }) do
	local path, got, flags = Tokens.Font(role)
	assert(onDisk(path), "Tokens.Font(" .. role .. ") names a missing file: " .. tostring(path))
	assert(got == size, "Tokens.Font(" .. role .. ") size is " .. tostring(got))
	assert(type(flags) == "string", "Tokens.Font(" .. role .. ") flags are a string")
end
assert(Tokens.Font("body"):match("AlegreyaSansTabular%-Regular%.ttf$"), "the default body face is Alegreya Sans Tabular")
assert(Tokens.Font("number"):match("AlegreyaSansTabular%-Bold%.ttf$"), "numbers use its bold, whose digits are tabular")
assert(select(3, Tokens.Font("world")) == "OUTLINE", "text over the 3D world gets a thin outline")
assert(select(3, Tokens.Font("body")) == "", "UI text uses a shadow, not an outline")
assert(not pcall(Tokens.Font, "nope"), "an unknown font role is an error")
local tracking, upper = Tokens.TextStyle("caption")
assert(tracking == 0.6 and upper == true, "captions are uppercase Alegreya Sans Medium, opened 0.6 units")
tracking, upper = Tokens.TextStyle("title")
assert(tracking == 1.4 and upper == true, "section titles are uppercase Cinzel tracked 1.4 units, the mockup's 0.14em rail caps")
assert(Tokens.TextStyle("display") == 0.6 and Tokens.TextStyle("heading") == 0.4, "Cinzel heads are tracked open, the mockup's 0.04em")

-- Media lists for the settings window and LibSharedMedia.
local fonts, bars = Tokens.MediaList("font"), Tokens.MediaList("statusbar")
assert(#fonts == 7 and #bars == 3, "seven fonts (Lumen's Cinzel and three Alegreya Sans weights, Source Sans 3 twice and Inter) and three status bars")
assert(fonts[1].key == "CinzelSemiBold", "Lumen's faces come first")
local sets = Tokens.MediaList("fontSet")
assert(#sets == 1 and sets[1].key == "Lumen" and Tokens.FontPath("Lumen") == sets[1].path, "Lumen is a font set, not a face: path pickers and LibSharedMedia never see it")
for _, list in ipairs({ fonts, bars }) do
	for _, item in ipairs(list) do
		assert(type(item.key) == "string" and type(item.label) == "string", "a media item has a key and a label")
		assert(onDisk(item.path), "media item " .. item.key .. " names a missing file")
	end
end
assert(Tokens.FontPath(fonts[1].key) == fonts[1].path and Tokens.FontPath("nope") == nil, "FontPath looks a face up by key")

-- Textures: each names a file on disk, and sliced ones say how big a corner piece draws.
for _, name in ipairs({
	"lumenShape", "lumenFrost", "lumenRim", "lumenRimSmall", "lumenOutline", "chamferTile", "gilt", "gem", "pillCapLeft",
	"pillCapRight", "barSheen", "lensMask", "ruleFade", "iconMask", "portraitMask", "shadow", "glow", "divider", "noise", "ring", "ringBevel",
	"barFlat", "barSoft", "barGlass", "minimapMask", "logo", "logoLarge", "dot", "pill", "glyphChevron", "glyphClose",
}) do
	local path = Tokens.Texture(name)
	assert(onDisk(path), "Tokens.Texture(" .. name .. ") names a missing file: " .. tostring(path))
end
for _, name in ipairs({ "chamferPanel", "chamferWindow", "line", "bevelPanelOuter", "bevelTileInner", "bevelWindowOuter" }) do
	assert(not pcall(Tokens.Texture, name), "the chamfer texture " .. name .. " is retired: Lumen rounds its corners")
end
for _, name in ipairs({ "chamferTile", "iconMask", "portraitMask" }) do
	assert(not Tokens.Texture(name):find("Chamfer", 1, true), name .. " is kept for its callers but draws a Lumen file")
end
local _, texels, units = Tokens.Texture("lumenShape")
assert(texels == 56 and units == 14, "the Lumen shape's corner is 56 texels drawn at 14 units; Chrome stretches it to the radius")
_, texels, units = Tokens.Texture("lumenRimSmall")
assert(texels == 32 and units == 8, "the small rim's corner is 32 texels drawn at 8 units")
_, texels, units = Tokens.Texture("shadow")
assert(texels == 24 and units == 12, "the shadow texture's corner is 12 units; Chrome stretches it to twice the shadow reach")
assert(select(2, Tokens.Texture("glow")) == nil, "an unsliced texture has no margin")
assert(not pcall(Tokens.Texture, "nope"), "an unknown texture is an error")

print("tokens ok: " .. scanned .. " files have no colour literal outside " .. TOKENS_FILE)
