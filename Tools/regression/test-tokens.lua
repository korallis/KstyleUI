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

-- The spec's colour table.
for name, want in pairs({
	surface = { "101010", 0.88 },
	raised = { "1c1c1c", 1 },
	edgeOuter = { "000000", 0.6 },
	edgeInner = { "ffffff", 0.08 },
	text = { "ababab", 1 },
	textEmphasis = { "ebebeb", 1 },
	textHover = { "ffffff", 1 },
	textDisabled = { "666666", 1 },
	rare = { "4fc3ff", 1 },
	epic = { "b67cff", 1 },
}) do
	local r, g, b, a = Tokens.Color(name)
	local wr, wg, wb = hexColor(want[1])
	assert(near(r, wr) and near(g, wg) and near(b, wb) and near(a, want[2]), "Tokens.Color(" .. name .. ") is not #" .. want[1])
end
for _, name in ipairs({ "hostile", "neutral", "friendly", "accent", "accentDefault", "shadow", "textShadow", "track", "white", "black" }) do
	local r, g, b, a = Tokens.Color(name)
	for _, v in ipairs({ r, g, b, a }) do
		assert(type(v) == "number" and v >= 0 and v <= 1, "Tokens.Color(" .. name .. ") returns four numbers in 0..1")
	end
end
assert(not pcall(Tokens.Color, "surfaec"), "an unknown colour name is an error")

-- The spec's shape and HUD sizes, type scale and motion.
for name, want in pairs({
	chamferPanel = 6, chamferTile = 3, shadow = 12, actionButton = 34, actionGap = 3, cooldownEssential = 40,
	cooldownUtility = 30, unitFrameWidth = 220, unitFrameHeight = 46, portrait = 46, buffBarWidth = 180,
	buffBarHeight = 18, display = 24, heading = 16, body = 11, caption = 9, textShadowOffset = 0.6,
	pressOffset = 1, panelRise = 16, panelOvershoot = 2,
}) do
	assert(Tokens.Size(name) == want, "Tokens.Size(" .. name .. ") is " .. tostring(Tokens.Size(name)) .. ", spec says " .. want)
end
assert(not pcall(Tokens.Size, "nope"), "an unknown size is an error")
for name, want in pairs({ hover = 0.15, panelOpen = 0.25, panelRise = 0.4, panelClose = 0.15, listStagger = 0.05, castSheen = 0.6, procPulse = 1.2 }) do
	assert(Tokens.Duration(name) == want, "Tokens.Duration(" .. name .. ") is " .. tostring(Tokens.Duration(name)))
end
assert(not pcall(Tokens.Duration, "nope"), "an unknown duration is an error")
assert(Tokens.Easing("hover") == "outQuart", "hover eases with outQuart")

-- A game path names a file in this repository: Interface\AddOns\KstyleUI\<path>.
local function onDisk(gamePath)
	local rel = assert(gamePath:match("^Interface\\AddOns\\KstyleUI\\(.+)$"), gamePath .. " is not under the KstyleUI folder")
	local handle = io.open((rel:gsub("\\", "/")), "rb")
	if handle then
		handle:close()
	end
	return handle ~= nil
end

-- Font roles: the default face is Source Sans 3 Semibold, and numbers keep its tabular digits.
for role, size in pairs({ display = 24, heading = 16, body = 11, caption = 9, number = 11, world = 12 }) do
	local path, got, flags = Tokens.Font(role)
	assert(onDisk(path), "Tokens.Font(" .. role .. ") names a missing file: " .. tostring(path))
	assert(got == size, "Tokens.Font(" .. role .. ") size is " .. tostring(got))
	assert(type(flags) == "string", "Tokens.Font(" .. role .. ") flags are a string")
end
assert(Tokens.Font("body"):match("SourceSans3%-Semibold%.ttf$"), "the default face is Source Sans 3 Semibold")
assert(Tokens.Font("number"):match("SourceSans3%-Semibold%.ttf$"), "numbers use Source Sans 3 for tabular digits")
assert(select(3, Tokens.Font("world")) == "OUTLINE", "text over the 3D world gets a thin outline")
assert(select(3, Tokens.Font("body")) == "", "UI text uses a shadow, not an outline")
assert(not pcall(Tokens.Font, "nope"), "an unknown font role is an error")
local tracking, upper = Tokens.TextStyle("caption")
assert(tracking == 1.5 and upper == true, "captions are uppercase with 1.5 tracking")
assert(Tokens.TextStyle("display") == -0.5 and Tokens.TextStyle("heading") == -0.3, "display and heading tracking from the kit")

-- Media lists for the settings window and LibSharedMedia.
local fonts, bars = Tokens.MediaList("font"), Tokens.MediaList("statusbar")
assert(#fonts == 3 and #bars == 3, "three fonts and three status bars")
for _, list in ipairs({ fonts, bars }) do
	for _, item in ipairs(list) do
		assert(type(item.key) == "string" and type(item.label) == "string", "a media item has a key and a label")
		assert(onDisk(item.path), "media item " .. item.key .. " names a missing file")
	end
end
assert(Tokens.FontPath(fonts[1].key) == fonts[1].path and Tokens.FontPath("nope") == nil, "FontPath looks a face up by key")

-- Textures: each names a file on disk, and sliced ones say how big a corner piece draws.
for _, name in ipairs({
	"chamferPanel", "chamferTile", "bevelPanelOuter", "bevelPanelInner", "bevelTileOuter", "bevelTileInner", "iconMask",
	"shadow", "glow", "divider", "noise", "ring", "barFlat", "barSoft", "barGlass", "minimapMask", "logo", "logoLarge",
	"dot", "pill", "glyphChevron", "glyphClose",
}) do
	local path = Tokens.Texture(name)
	assert(onDisk(path), "Tokens.Texture(" .. name .. ") names a missing file: " .. tostring(path))
end
local _, texels, units = Tokens.Texture("chamferPanel")
assert(texels == 24 and units == Tokens.Size("chamferPanel"), "a panel chamfer corner is 24 texels drawn at 6 units")
_, texels, units = Tokens.Texture("chamferTile")
assert(texels == 12 and units == Tokens.Size("chamferTile"), "a tile chamfer corner is 12 texels drawn at 3 units")
_, texels, units = Tokens.Texture("shadow")
assert(texels == 48 and units == 2 * Tokens.Size("shadow"), "shadow corners are centred on the panel's corners")
assert(select(2, Tokens.Texture("glow")) == nil, "an unsliced texture has no margin")
assert(not pcall(Tokens.Texture, "nope"), "an unknown texture is an error")

print("tokens ok: " .. scanned .. " files have no colour literal outside " .. TOKENS_FILE)
