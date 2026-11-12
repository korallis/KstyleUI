-- test-ornament-measure-guard.lua: every edge an ornament reads goes through Widgets.Edges, which checks IsAnchoringRestricted first, and the layout solver in Rects.lua reads no edge at all, so no ornament path can measure a region the game restricts.
local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local NAMES = { GetLeft = true, GetRight = true, GetTop = true, GetBottom = true, GetRect = true, GetCenter = true, GetScaledRect = true }

local function raw(text)
	local found = {}
	local line = 0
	for row in (text .. "\n"):gmatch("(.-)\r?\n") do
		line = line + 1
		for name in row:gmatch(":(Get%a+)%(") do
			if NAMES[name] then found[#found + 1] = { line = line, name = name, row = row } end
		end
	end
	return found
end

local ornaments = raw(read("Core/Widgets/Ornaments.lua"))
assert(#ornaments == 0, "Ornaments.lua measures a region without Widgets.Edges at line " .. tostring(ornaments[1] and ornaments[1].line) .. ": " .. tostring(ornaments[1] and ornaments[1].row))

local rects = raw(read("Core/Widgets/Rects.lua"))
assert(#rects == 0, "Rects.lua measures a region's edges at line " .. tostring(rects[1] and rects[1].line) .. ": " .. tostring(rects[1] and rects[1].row))

local base = read("Core/Widgets/Base.lua")
local edges = base:match("\nfunction Widgets%.Edges%(region%)\r?\n(.-)\nend")
assert(edges and edges:find("Widgets.Restricted(region)", 1, true), "Widgets.Edges checks Widgets.Restricted before it measures")
local restricted = base:match("\nfunction Widgets%.Restricted%(region%)\r?\n(.-)\nend")
assert(restricted and restricted:find("IsAnchoringRestricted", 1, true) and restricted:find("IsSecret(restricted)", 1, true),
	"Widgets.Restricted asks IsAnchoringRestricted and counts a secret answer as restricted")
local place = base:match("\nlocal function Place%(overlay, entry%)\r?\n(.-)\nend")
assert(place and place:find("Widgets.Restricted(visual)", 1, true) < place:find("visual:GetRect()", 1, true), "Cover checks Widgets.Restricted before it reads its visual's rect")
local allowed = 0
for _, hit in ipairs(raw(base)) do
	local inEdges = hit.row:find("return region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()", 1, true)
	local inPlace = hit.row:find("visual:GetRect()", 1, true)
	assert(inEdges or inPlace, "Base.lua measures a region outside Widgets.Edges and Cover at line " .. hit.line .. ": " .. hit.row)
	allowed = allowed + 1
end
assert(allowed == 5, "Base.lua reads edges in Widgets.Edges and Cover only, got " .. allowed)
print("ok every ornament edge read goes through Widgets.Edges, which checks IsAnchoringRestricted first")
