-- test-grades.lua: every backdrop KstyleUI draws is one of the mockup's three grades, so no addon file fills a
-- chrome with the kit's old "raised" tone. The grades (THEME_SPEC.md): the glass panel (surface, the two-line
-- edge, shadow), the button (buttonFill body) and the bar (surface with the edgeBar line). Inputs, text
-- buttons, tab strips, cards, plates and bar tracks take the button body, the mockup's one solid dark tone.
-- Core/Tokens.lua still defines the colour, Core/Widgets/IconButton.lua lifts a pressed button toward it,
-- and the Blizzard skins (Core/Skin.lua, KstyleUI_Skins) belong to the skins wave, so those files are allowed.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local ALLOWED = {
	["Core/Tokens.lua"] = true,
	["Core/Widgets/IconButton.lua"] = true,
	["Core/Skin.lua"] = true,
}
local SKINS = "^KstyleUI_Skins/"
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

local problems, count = {}, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not ALLOWED[path] and not path:match(SKINS) then
		for _, line in ipairs(Uses(read(path))) do
			problems[#problems + 1] = path .. ":" .. line .. ": the raised tone is not a grade; " .. FIX
		end
		count = count + 1
	end
end
assert(count > 0, "no TOC-loaded Lua files found")
if #problems > 0 then
	print(#problems .. " backdrops off the grades:")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end
