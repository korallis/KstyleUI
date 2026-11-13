-- pixel_audit_lib.lua: walks every region KstyleUI's own code made in a render scene and lists each edge that is not on a whole physical pixel.
--
--   local Audit = dofile("Tools/regression/pixel_audit_lib.lua")
--   local offenders, judged = Audit.Scene("gallery_auras", { 5120, 1440 })   -- or Audit.Reference({ 5120, 1440 })
--
-- A texture, a line or a cooldown swipe must have all four edges on whole pixels, except the end of a status bar's
-- fill that its value moves, which the engine draws. A font string's glyphs are the font's, so only the points it is
-- anchored by must be whole: its left, centre or right, and its top, middle or bottom. An edge anchored to a font
-- string sits where that text's glyphs end, so the font decides it too and it is not judged. Edges come from the
-- scene's solved rects (screen units, 1080 tall) before the renderer rounds them, and are measured from the corner of
-- the nearest frame KstyleUI does not place (a Blizzard window, another addon's frame, a gallery's own arrangement),
-- whose own place is the game's or the scene's. Each offender names the file that placed the outermost frame above it
-- that is off the grid, or the file that placed or made the region itself.
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(_G, "PIXEL_AUDIT", true)
local Scene = dofile("Tools/render/scene.lua")

local Audit = {}

Audit.SCREENS = {
	{ 5120, 1440 }, { 3440, 1440 }, { 3840, 1080 }, { 2560, 1440 }, { 1920, 1080 }, { 3840, 2160 }, { 1280, 720 },
}
Audit.UI_SCALE = 768 / 1080
Audit.TOLERANCE = 0.01

local SHARE = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function off(v)
	return math.abs(v - math.floor(v + 0.5)) > Audit.TOLERANCE
end

local function name(object)
	local parts, node = {}, object
	while node and #parts < 4 do
		parts[#parts + 1] = node._name or node._type
		node = node._parent
	end
	return table.concat(parts, " < ")
end

local function stored(object, field)
	local value = object._state[field]
	return value and value[1]
end

-- Relative(object, pack) -> the region a point is anchored to.
local function Relative(object, pack)
	local relative = pack[2]
	if type(relative) == "string" then
		relative = object._env[relative]
	end
	if type(relative) == "table" then
		return relative
	end
	return object._parent
end

-- Glyphs(object) -> x, y: whether an axis has a point anchored to a font string, so the font places that axis.
local function Glyphs(object)
	local x, y = false, false
	for _, pack in ipairs(object._points or {}) do
		local relative = Relative(object, pack)
		if relative and relative._type == "FontString" then
			local share = SHARE[type(pack[3]) == "string" and pack[3] or pack[1]]
			x = x or share == nil or share[1] ~= 0
			y = y or share == nil or share[2] ~= 1
		end
	end
	return x, y
end

-- Edges(item, px) -> the list of { what, value, axis } in physical pixels that must be whole for this item.
local function Edges(item, px)
	local r, object = item.rect, item.object
	local left, top, width, height = r[1] * px, r[2] * px, r[3] * px, r[4] * px
	local right, bottom = left + width, top + height
	local glyphX, glyphY = Glyphs(object)
	local out = {}
	local function add(what, value, axis)
		if not (axis == "x" and glyphX or axis == "y" and glyphY) then
			out[#out + 1] = { what, value, axis }
		end
	end
	if item.kind == "text" then
		local x = { [0] = left, [0.5] = left + width / 2, [1] = right }
		local y = { [0] = bottom, [0.5] = top + height / 2, [1] = top }
		local seenX, seenY = {}, {}
		for _, point in ipairs(object._points or {}) do
			local share = SHARE[point[1]]
			if share and not seenX[share[1]] then
				seenX[share[1]] = true
				add("anchor x", x[share[1]], "x")
			end
			if share and not seenY[share[2]] then
				seenY[share[2]] = true
				add("anchor y", y[share[2]], "y")
			end
		end
		return out
	end
	local skip
	local bar = object._barOwner
	if bar then
		local reverse = stored(bar, "ReverseFill") == true
		if stored(bar, "Orientation") == "VERTICAL" then
			skip = reverse and "bottom" or "top"
		else
			skip = reverse and "left" or "right"
		end
	end
	for _, edge in ipairs({ { "left", left, "x" }, { "right", right, "x" }, { "top", top, "y" }, { "bottom", bottom, "y" } }) do
		if edge[1] ~= skip then
			add(edge[1], edge[2], edge[3])
		end
	end
	return out
end

-- Host(object) -> the region itself when a scene or fake placed it, or else the nearest frame holding it that KstyleUI
-- does not place: a Blizzard window, another addon's frame, or one of our frames a scene or fake placed. nil when
-- KstyleUI places the whole chain up to UIParent.
local function Host(object)
	local node = object
	while node do
		if node._name == "UIParent" then
			return nil
		end
		if node ~= object and node._origin == false or node._placedBy == false then
			return node
		end
		node = node._parent
	end
	return nil
end

-- Culprit(object, host, solver, px, dx, dy) -> the outermost frame between the object and its host whose own edges are
-- off the grid: the code that placed it put everything under it off, so the offender is blamed on that code.
local function Culprit(object, host, solver, px, dx, dy)
	local culprit, node = object, object._parent
	while node and node ~= host and node._name ~= "UIParent" do
		local x, y, w, h = Scene.RectIn(solver, node)
		if x and node._placedBy and (off(x * px - dx) or off(y * px - dy) or off((x + w) * px - dx) or off((y + h) * px - dy)) then
			culprit = node
		end
		node = node._parent
	end
	return culprit
end

-- Check(scene, physicalHeight) -> offenders, judged. Each offender is { file, kind, name, edges = { "left 12.400", ... } }.
function Audit.Check(scene, physicalHeight)
	local px = physicalHeight / 1080
	local offenders, judged = {}, 0
	local solvers = {}
	for _, item in ipairs(scene.items) do
		local object = item.object
		if object and object._origin and item.rect then
			judged = judged + 1
			local host, dx, dy = Host(object), 0, 0
			if host then
				local env = object._env
				solvers[env] = solvers[env] or Scene.RectSolver(env)
				local x, y = Scene.RectIn(solvers[env], host)
				dx, dy = (x or 0) * px, (y or 0) * px
			end
			local bad
			for _, edge in ipairs(Edges(item, px)) do
				local v = edge[2] - (edge[3] == "x" and dx or dy)
				if off(v) then
					bad = bad or {}
					bad[#bad + 1] = string.format("%s %.3f", edge[1], v)
				end
			end
			if bad then
				local env = object._env
				solvers[env] = solvers[env] or Scene.RectSolver(env)
				local culprit = Culprit(object, host, solvers[env], px, dx, dy)
				offenders[#offenders + 1] = { file = culprit._placedBy or culprit._origin, kind = item.kind, name = name(object), edges = bad }
			end
		end
	end
	return offenders, judged
end

local function Screen(screen)
	return { width = screen[1], height = screen[2], uiScale = Audit.UI_SCALE, size = "auto" }
end

-- Scene(name, screen) -> offenders, judged for one scene script (a gallery) built at that screen.
function Audit.Scene(sceneName, screen)
	local build = dofile("Tools/render/scenes/" .. sceneName .. ".lua")
	local previous = rawget(_G, "RENDER_SCREEN")
	rawset(_G, "RENDER_SCREEN", Screen(screen))
	local ok, scene = pcall(build)
	rawset(_G, "RENDER_SCREEN", previous)
	assert(ok, scene)
	return Audit.Check(scene, screen[2])
end

-- Reference(screen, layout) -> offenders, judged for hud_reference (DPS unless a layout is named) at that screen.
function Audit.Reference(screen, layout)
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	Reference.SCREEN = Screen(screen)
	return Audit.Check(Reference.Build({ layout = layout }), screen[2])
end

-- Galleries() -> every gallery scene's name, in ls order.
function Audit.Galleries()
	local names = {}
	local pipe = assert(io.popen("ls -1 Tools/render/scenes/gallery_*.lua 2>/dev/null"))
	for line in pipe:lines() do
		names[#names + 1] = line:match("([^/]+)%.lua$")
	end
	pipe:close()
	return names
end

-- The matrix: every gallery and hud_reference (DPS), each at every screen. Jobs() lists one { scene, screen } per pair,
-- in a fixed order, and Part(index, parts) deals them into parts of about equal cost (WEIGHTS, in tenths of a second
-- under Lua 5.1), so each test-pixel-grid-<n>.lua stays inside its time and memory budget.
Audit.PARTS = 16
Audit.ALLOW = "Tools/regression/pixel_allow.tsv"
local WEIGHTS = { hud_reference = 26, gallery_groupframes = 44, gallery_options_modules = 15, gallery_options = 13 }

function Audit.Jobs()
	local jobs = {}
	local scenes = Audit.Galleries()
	table.insert(scenes, 1, "hud_reference")
	for _, sceneName in ipairs(scenes) do
		for _, screen in ipairs(Audit.SCREENS) do
			jobs[#jobs + 1] = { scene = sceneName, screen = screen, weight = WEIGHTS[sceneName] or 3 }
		end
	end
	return jobs
end

function Audit.Part(index, parts)
	local jobs = Audit.Jobs()
	local order = {}
	for i = 1, #jobs do
		order[i] = i
	end
	table.sort(order, function(a, b)
		if jobs[a].weight ~= jobs[b].weight then
			return jobs[a].weight > jobs[b].weight
		end
		return a < b
	end)
	local loads, picked = {}, {}
	for p = 1, parts do
		loads[p] = 0
	end
	for _, i in ipairs(order) do
		local best = 1
		for p = 2, parts do
			if loads[p] < loads[best] then
				best = p
			end
		end
		loads[best] = loads[best] + jobs[i].weight
		if best == index then
			picked[#picked + 1] = jobs[i]
		end
	end
	return picked
end

local function Key(job)
	return job.scene .. "	" .. job.screen[1] .. "x" .. job.screen[2]
end

-- Measure(job) -> { [file] = count }, offenders, judged for one job.
function Audit.Measure(job)
	local offenders, judged
	if job.scene == "hud_reference" then
		offenders, judged = Audit.Reference(job.screen)
	else
		offenders, judged = Audit.Scene(job.scene, job.screen)
	end
	local counts = {}
	for _, o in ipairs(offenders) do
		counts[o.file] = (counts[o.file] or 0) + 1
	end
	return counts, offenders, judged
end

-- LoadAllow() -> { [scene .. "\t" .. screen] = { [file] = count } } from pixel_allow.tsv.
function Audit.LoadAllow(path)
	local allow = {}
	local f = io.open(path or Audit.ALLOW, "r")
	if not f then
		return allow
	end
	for line in f:lines() do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local sceneName, screen, file, count = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(%d+)$")
			assert(sceneName, Audit.ALLOW .. ": a line must be scene, WIDTHxHEIGHT, file and count, got " .. line)
			local key = sceneName .. "\t" .. screen
			allow[key] = allow[key] or {}
			allow[key][file] = tonumber(count)
		end
	end
	f:close()
	return allow
end

-- Judge(job, counts, offenders, allow) -> problems: each file over its allowance, every Core file with an offender that
-- the list does not carry, and each allowance above what the job now counts, which the list must lower.
function Audit.Judge(job, counts, offenders, allow)
	local key, problems = Key(job), {}
	local allowed = allow[key] or {}
	for file, count in pairs(counts) do
		local limit = allowed[file] or 0
		if count > limit then
			local lines = {}
			for _, o in ipairs(offenders) do
				if o.file == file then
					lines[#lines + 1] = o
				end
			end
			problems[#problems + 1] = string.format("%s: %s has %d regions off the pixel grid, %d allowed:\n%s", key:gsub("\t", " at "), file, count, limit, table.concat(Audit.Lines(job.scene, lines, 6), "\n"))
		end
	end
	for file, limit in pairs(allowed) do
		local count = counts[file] or 0
		if count < limit then
			problems[#problems + 1] = string.format("%s: %s now has %d regions off the pixel grid, %d allowed; lower its line in %s (Tools/dev/pixel_allow.lua writes it)", key:gsub("\t", " at "), file, count, limit, Audit.ALLOW)
		end
	end
	table.sort(problems)
	return problems
end

-- Run(index, parts) runs one part of the matrix against pixel_allow.tsv and fails on any problem.
function Audit.Run(index, parts)
	local allow, problems, judged, offenders = Audit.LoadAllow(), {}, 0, 0
	local jobs = Audit.Part(index, parts or Audit.PARTS)
	assert(#jobs > 0, "part " .. index .. " has jobs")
	for _, job in ipairs(jobs) do
		local counts, list, seen = Audit.Measure(job)
		judged, offenders = judged + seen, offenders + #list
		for _, problem in ipairs(Audit.Judge(job, counts, list, allow)) do
			problems[#problems + 1] = problem
		end
		collectgarbage("collect")
	end
	assert(#problems == 0, table.concat(problems, "\n"))
	print(string.format("pixel grid part %d: %d jobs, %d regions judged, %d off the grid, all allowed", index, #jobs, judged, offenders))
end

Audit.Key = Key

-- Lines(where, offenders, limit) -> a readable list of the first offenders.
function Audit.Lines(where, offenders, limit)
	local out = {}
	for i = 1, math.min(#offenders, limit or 12) do
		local o = offenders[i]
		out[#out + 1] = string.format("  %s: %s %s (%s): %s", where, o.file, o.kind, o.name, table.concat(o.edges, ", "))
	end
	return out
end

return Audit
