-- test-fontstrings.lua: addon code makes FontStrings only through K.Widgets.FontString, so each has a font before SetText.
-- In the game, SetText on a FontString with no font raises "Font not set" and stops the caller, so a raw
-- CreateFontString that sets text before styling breaks its whole module. Core/Widgets/Base.lua holds the one
-- allowed call.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local HELPER = "Core/Widgets/Base.lua"
local FIX = "use K.Widgets.FontString(parent, layer), which gives the text a font before SetText"

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Calls(text) -> the line numbers of each CreateFontString call.
local function Calls(text)
	local lines, n = {}, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if line:find("CreateFontString", 1, true) then
			lines[#lines + 1] = n
		end
	end
	return lines
end

assert(#Calls("local t = f:CreateFontString(nil, \"OVERLAY\")\n") == 1, "a raw call is found")
assert(#Calls("local t = Widgets.FontString(f, \"OVERLAY\")\n") == 0, "the helper is not a raw call")
assert(#Calls("local ok, t = pcall(f.CreateFontString, f)\n") == 1, "a call by reference is found too")
assert(Calls("a\r\nb:CreateFontString()\r\n")[1] == 2, "CRLF lines are counted")

local problems, helperCalls, count = {}, 0, 0
for _, path in ipairs(TocFiles("%.lua$")) do
	if not (path:match("^Libs/") or path:find("/Libs/", 1, true)) then
		for _, line in ipairs(Calls(read(path))) do
			if path == HELPER then
				helperCalls = helperCalls + 1
			else
				problems[#problems + 1] = path .. ":" .. line .. ": a raw CreateFontString; " .. FIX
			end
		end
		count = count + 1
	end
end
assert(count > 0, "no TOC-loaded Lua files found")
assert(helperCalls == 1, HELPER .. " should call CreateFontString once, in Widgets.FontString; found " .. helperCalls)
if #problems > 0 then
	print(#problems .. " FontStrings made without a font:")
	for _, problem in ipairs(problems) do
		print(problem)
	end
	os.exit(1)
end
