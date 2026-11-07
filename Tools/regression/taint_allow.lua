-- taint_allow.lua: merge the reviewed taint-scan exceptions from one file per area in Tools/regression/taint_allow/.
--
--   local allow = dofile("Tools/regression/taint_allow.lua")
--   local allow = assert(loadfile("Tools/regression/taint_allow.lua"))(otherFolder)
--
-- Each area file is named after the addon folder it covers (Core.lua, KstyleUI_UnitFrames.lua) and
-- lists only that folder's files, so agents that build different modules never edit the same file.
-- It runs with no globals and returns { ["<Folder>/<File>.lua"] = { why = "...", calls = { [call] =
-- count } } }. The merged table has the same shape, and each entry also gets file, the area file
-- that holds it. Tools/regression/README.md describes the format.

local dir = ... or "Tools/regression/taint_allow"

local function fail(file, message)
	error(file .. ": " .. message, 0)
end

local function list(folder)
	local names = {}
	local pipe = assert(io.popen("ls -1A '" .. folder:gsub("'", "'\\''") .. "' 2>/dev/null"))
	for name in pipe:lines() do
		names[#names + 1] = name
	end
	pipe:close()
	table.sort(names)
	return names
end

local function loadArea(file)
	local chunk, err = loadfile(file)
	if not chunk then
		fail(file, err)
	end
	setfenv(chunk, {})
	local ok, result = pcall(chunk)
	if not ok then
		fail(file, tostring(result))
	end
	if type(result) ~= "table" then
		fail(file, "must return a table of { [path] = { why = ..., calls = { [call] = count } } }.")
	end
	return result
end

local function checkEntry(file, area, path, entry)
	if type(path) ~= "string" or path:sub(1, #area + 1) ~= area .. "/" then
		fail(file, tostring(path) .. " is outside " .. area .. "/. List it in that folder's own area file.")
	end
	if not path:match("%.lua$") then
		fail(file, path .. " is not a .lua file path.")
	end
	if type(entry) ~= "table" then
		fail(file, path .. " must be a table with why and calls.")
	end
	for field in pairs(entry) do
		if field ~= "why" and field ~= "calls" then
			fail(file, path .. " has unknown field " .. tostring(field) .. "; use why and calls.")
		end
	end
	if type(entry.why) ~= "string" or not entry.why:match("%S") then
		fail(file, path .. " needs a why: the reason each listed call is safe.")
	end
	if type(entry.calls) ~= "table" or next(entry.calls) == nil then
		fail(file, path .. " needs at least one call.")
	end
	for call, count in pairs(entry.calls) do
		if type(call) ~= "string" or call == "" then
			fail(file, path .. " has a call that is not a string.")
		end
		if type(count) ~= "number" or count < 1 or count % 1 ~= 0 then
			fail(file, path .. " " .. call .. " needs a whole number of 1 or more.")
		end
	end
end

local merged = {}
for _, name in ipairs(list(dir)) do
	local file = dir .. "/" .. name
	local area = name:match("^(.+)%.lua$")
	if not area then
		fail(file, "the allow-list folder holds only area files named Core.lua or KstyleUI_<Module>.lua.")
	end
	if area ~= "Core" and not area:match("^KstyleUI_%w+$") then
		fail(file, "name an area file after its folder: Core.lua or KstyleUI_<Module>.lua.")
	end
	for path, entry in pairs(loadArea(file)) do
		checkEntry(file, area, path, entry)
		merged[path] = { why = entry.why, calls = entry.calls, file = file }
	end
end
return merged
