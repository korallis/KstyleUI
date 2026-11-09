-- test-grades.lua: every backdrop KstyleUI draws is one of Lumen's grades, and no addon file reaches for the retired chamfer drawing. The grades: the card (panel and card: shadow, deep tint, frost, rim), the window and rail (the card plus gilt tips), the socket (tile and socket: the dark crystal body, buttonFill, with a faint rim) and the bar (a pill track). No file fills a chrome with the old "raised" tone; Core/Tokens.lua defines it and Core/Widgets/IconButton.lua lifts a pressed button toward it, so those two files are allowed. No file calls Widgets.Line, LayoutLine or ColorLine, or names the chamferPanel, chamferWindow or line textures.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local ALLOWED = {
	["Core/Tokens.lua"] = true,
	["Core/Widgets/IconButton.lua"] = true,
}
local FIX = 'fill the chrome with "buttonFill" (the button grade) or "surface" (the panel and bar grades)'

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Uses(text) -> the line numbers that name the raised tone.
local function Uses(text)
	local lines, n = {}, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if line:find('"raised"', 1, true) or line:find("'raised'", 1, true) then
			lines[#lines + 1] = n
		end
	end
	return lines
end

assert(#Uses('x = Widgets.Chrome(f, { shape = "tile", fill = "raised" })\n') == 1, "a raised fill is found")
assert(#Uses('local TRACK = "raised"\n') == 1, "a raised track is found")
assert(#Uses('x = Widgets.Chrome(f, { fill = "buttonFill" })\n') == 0, "the button body passes")
assert(Uses('a\r\nb = "raised"\r\n')[1] == 2, "CRLF lines are counted")

local RETIRED = {
	{ "Widgets%.Line%(", "Widgets.Line" }, { "Widgets%.LayoutLine%(", "Widgets.LayoutLine" }, { "Widgets%.ColorLine%(", "Widgets.ColorLine" },
	{ 'Texture%("chamferPanel"%)', 'the "chamferPanel" texture' }, { 'Texture%("chamferWindow"%)', 'the "chamferWindow" texture' },
	{ 'Texture%("line"%)', 'the "line" texture' }, { 'NineSlice%([^)]*"chamferPanel"', 'a "chamferPanel" slice' },
	{ 'NineSlice%([^)]*"chamferWindow"', 'a "chamferWindow" slice' }, { 'Share%("chamfer', "a chamfer share" },
}
local RETIRED_FIX = "Lumen draws rounded corners: use Widgets.Chrome, or Widgets.NineSlice with lumenShape, lumenRim or lumenOutline"

-- Retired(text) -> { line, what } for each use of the retired chamfer drawing.
local function Retired(text)
	local out, n = {}, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		for _, rule in ipairs(RETIRED) do
			if line:find(rule[1]) then
				out[#out + 1] = { n, rule[2] }
			end
		end
	end
	return out
end

assert(#Retired('ring[i] = Widgets.Line(owner, layer)\n') == 1, "a bevel line is found")
assert(#Retired('x = Widgets.NineSlice(plate, "chamferPanel", "BACKGROUND", 0)\n') == 1, "a chamfer slice is found")
assert(#Retired('x = Widgets.NineSlice(plate, "lumenShape", "BACKGROUND", 0)\n') == 0, "a Lumen slice passes")
assert(#Retired('local c = Tokens.Size("chamferPanel")\n') == 0, "the chamfer size names still read the Lumen radii")

local problems, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	local text = read(path)
	if not ALLOWED[path] then
		for _, line in ipairs(Uses(text)) do
			problems[#problems + 1] = path .. ":" .. line .. ": the raised tone is not a grade; " .. FIX
		end
	end
	for _, hit in ipairs(Retired(text)) do
		problems[#problems + 1] = path .. ":" .. hit[1] .. ": " .. hit[2] .. " is retired; " .. RETIRED_FIX
	end
	count = count + 1
end
assert(count > 0, "no TOC-loaded Lua files found")
if #problems > 0 then
	print(#problems .. " backdrops off the grades:")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end
