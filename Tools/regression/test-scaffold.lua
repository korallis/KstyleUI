-- test-scaffold.lua: each module folder has its TOC, XML, README, package line, taint area and luacheck line, and the core loads its service files.
local TocFiles = dofile("Tools/regression/toc_files.lua")

-- The modules the spec names. A folder on disk that is not listed here gets the same checks.
local SPEC_MODULES = {
	"Options", "UnitFrames", "GroupFrames", "ActionBars", "Cooldowns", "Auras", "Nameplates",
	"CombatText", "Minimap", "Chat", "Bags", "Tooltips", "DataBars", "Meters", "Skins", "Icons",
	"IconsColour",
}
local ON_DEMAND = { Options = true, Icons = true, IconsColour = true }

-- The core service files and area XML files, in the order Core.xml loads them.
local CORE_FILES = {
	"Init.lua", "Locale.lua", "Callbacks.lua", "Events.lua", "Tokens.lua", "Theme.lua", "Scale.lua",
	"Motion.lua", "Features.lua", "Store.lua", "Modules.lua", "Combat.lua", "Safe.lua", "DevTest.lua",
	"Icons.lua", "Options.lua", "Skin.lua", "Widgets/Widgets.xml", "Layout/Layout.xml", "Setup/Setup.xml",
}

local problems = {}
local function problem(message)
	problems[#problems + 1] = message
end

local function read(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

local function lines(text)
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		out[#out + 1] = (line:gsub("\r$", ""))
	end
	return out
end

local function list(glob)
	local out = {}
	local pipe = assert(io.popen("ls -1d " .. glob .. " 2>/dev/null"))
	for line in pipe:lines() do
		out[#out + 1] = line
	end
	pipe:close()
	table.sort(out)
	return out
end

-- Folders on disk, by module name.
local folders = {}
for _, dir in ipairs(list("KstyleUI_*/")) do
	local folder = dir:gsub("/+$", "")
	local module = folder:match("^KstyleUI_(%w+)$")
	if module then
		folders[module] = folder
	else
		problem(folder .. ": a module folder is named KstyleUI_<Module>, letters and digits only")
	end
end
for _, module in ipairs(SPEC_MODULES) do
	if not folders[module] then
		problem("KstyleUI_" .. module .. "/ is missing: the spec names this module")
	end
end

local loaded = {}
for _, path in ipairs(TocFiles(nil)) do
	loaded[path] = true
end

-- .pkgmeta move-folders, as { [source] = destination }.
local moves = {}
do
	local section = false
	for _, line in ipairs(lines(read(".pkgmeta") or "")) do
		if line:match("^%S") then
			section = line:match("^move%-folders:%s*$") ~= nil
		elseif section and line:match("%S") and not line:match("^%s*#") then
			local from, to = line:match("^%s+(%S+):%s*(%S+)%s*$")
			if from then
				moves[from] = to
			else
				problem(".pkgmeta: move-folders line is not 'source: destination': " .. line)
			end
		end
	end
end

local luacheckrc = read(".luacheckrc") or ""

local HEADER = {
	Interface = "16001",
	AllowLoadGameType = "camelot",
	Group = "KstyleUI",
	Dependencies = "KstyleUI",
	Version = "@project-version@",
}

local modules = {}
for module in pairs(folders) do
	modules[#modules + 1] = module
end
table.sort(modules)

for _, module in ipairs(modules) do
	local folder = folders[module]
	local tocPath = folder .. "/" .. folder .. ".toc"
	local toc = read(tocPath)
	if not toc then
		problem(tocPath .. " is missing")
	else
		local meta, entries = {}, {}
		for _, line in ipairs(lines(toc)) do
			local key, value = line:match("^##%s*([%w%-]+)%s*:%s*(.-)%s*$")
			if key then
				meta[key] = value
			elseif line:match("%S") and not line:match("^%s*#") then
				entries[#entries + 1] = line:match("^%s*(.-)%s*$")
			end
		end
		for key, want in pairs(HEADER) do
			if meta[key] ~= want then
				problem(tocPath .. ": ## " .. key .. " must be " .. want .. ", got " .. tostring(meta[key]))
			end
		end
		for _, key in ipairs({ "Title", "Notes" }) do
			if not (meta[key] and meta[key]:match("%S")) then
				problem(tocPath .. ": ## " .. key .. " is missing")
			end
		end
		if meta.Title and not meta.Title:match("^KstyleUI ") then
			problem(tocPath .. ": ## Title starts with 'KstyleUI ', got " .. meta.Title)
		end
		local wantOnDemand = ON_DEMAND[module] and "1" or nil
		if meta.LoadOnDemand ~= wantOnDemand then
			problem(tocPath .. ": ## LoadOnDemand must be " .. tostring(wantOnDemand) .. ", got " .. tostring(meta.LoadOnDemand))
		end
		if #entries ~= 1 or entries[1] ~= module .. ".xml" then
			problem(tocPath .. ": a module TOC lists only " .. module .. ".xml, got: " .. table.concat(entries, ", "))
		end
	end

	if not loaded[folder .. "/Init.lua"] then
		problem(folder .. "/" .. module .. ".xml must load Init.lua")
	end

	local readme = read(folder .. "/README.md")
	if not readme then
		problem(folder .. "/README.md is missing")
	else
		if not readme:match("^# " .. folder .. "\n") then
			problem(folder .. "/README.md must start with '# " .. folder .. "'")
		end
		if not readme:match("\n## Why\n") then
			problem(folder .. "/README.md needs a '## Why' section")
		end
	end

	if moves["KstyleUI/" .. folder] ~= folder then
		problem(".pkgmeta: move-folders needs 'KstyleUI/" .. folder .. ": " .. folder .. "'")
	end
	moves["KstyleUI/" .. folder] = nil

	if not read("Tools/regression/taint_allow/" .. folder .. ".lua") then
		problem("Tools/regression/taint_allow/" .. folder .. ".lua is missing")
	end

	if not luacheckrc:find('\nmodule_globals("' .. folder .. '", ', 1, true) then
		problem(".luacheckrc: the module section has no line for " .. folder)
	end
end

for from, to in pairs(moves) do
	problem(".pkgmeta: move-folders line '" .. from .. ": " .. to .. "' has no module folder")
end

if not read("Tools/regression/taint_allow/Core.lua") then
	problem("Tools/regression/taint_allow/Core.lua is missing")
end

-- The core loads every service file, Init.lua first.
local core = TocFiles("^Core/")
if core[1] ~= "Core/Core.xml" or core[2] ~= "Core/Init.lua" then
	problem("Core/Core.xml must load Core/Init.lua first, got " .. tostring(core[2]))
end
local coreLoaded = {}
for _, path in ipairs(core) do
	coreLoaded[path] = true
end
for _, file in ipairs(CORE_FILES) do
	if not coreLoaded["Core/" .. file] then
		problem("Core/Core.xml does not load Core/" .. file)
	end
end

if #problems > 0 then
	print(#problems .. " scaffold problems:")
	for _, message in ipairs(problems) do
		print(message)
	end
	os.exit(1)
end

print("scaffold ok: " .. #modules .. " modules")
