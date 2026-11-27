-- scene.lua: walk a stub environment's frames and resolve every visible region to a drawable in screen units.
--
--   local Scene = dofile("Tools/render/scene.lua")
--   local scene = Scene.Build(env, opts)   -- { screen, items, log }
--   io.write(Scene.ToJSON(scene))
--
-- Screen units: the screen is 1080 units tall whatever the physical size, x grows right and y grows down
-- from the top left. That is KstyleUI's root unit when the user scale is 1. Each item carries its stub
-- object in item.object for tests; ToJSON leaves that field out.
--
-- opts:
--   roots      frames to walk (default: UIParent plus every parentless frame)
--   hover      a set of frames whose HIGHLIGHT regions draw
--   time       the clock for timer bars and cooldowns (default env._time or env.GetTime())
--   paths      a function(path) -> local file path, for textures and fonts (default Scene.ResolvePath)
--   iconDirs   folders searched for <fileID>.png, in order

local Scene = {}

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local unpack = unpack

local UI_HEIGHT = 768
local SCREEN_UNITS = 1080

local STRATA = {
	WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local LAYERS = { BACKGROUND = 0, BORDER = 1, ARTWORK = 2, OVERLAY = 3, HIGHLIGHT = 4 }

local POINTS = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}


-- Blizzard font objects the stub cannot load, as path, size and flags.
local BLIZZARD_FONTS = {
	GameFontNormal = { "Fonts\\FRIZQT__.TTF", 12, "", { 1, 0.82, 0 } },
	GameFontNormalSmall = { "Fonts\\FRIZQT__.TTF", 10, "", { 1, 0.82, 0 } },
	GameFontNormalLarge = { "Fonts\\FRIZQT__.TTF", 16, "", { 1, 0.82, 0 } },
	GameFontHighlight = { "Fonts\\FRIZQT__.TTF", 12, "", { 1, 1, 1 } },
	GameFontHighlightSmall = { "Fonts\\FRIZQT__.TTF", 10, "", { 1, 1, 1 } },
	GameFontHighlightLarge = { "Fonts\\FRIZQT__.TTF", 16, "", { 1, 1, 1 } },
	GameFontDisable = { "Fonts\\FRIZQT__.TTF", 12, "", { 0.5, 0.5, 0.5 } },
	GameTooltipText = { "Fonts\\FRIZQT__.TTF", 12, "", { 1, 1, 1 } },
	GameTooltipHeaderText = { "Fonts\\FRIZQT__.TTF", 14, "", { 1, 1, 1 } },
	GameTooltipTextSmall = { "Fonts\\FRIZQT__.TTF", 10, "", { 1, 1, 1 } },
	ChatFontNormal = { "Fonts\\ARIALN.TTF", 14, "", { 1, 1, 1 } },
	NumberFontNormal = { "Fonts\\ARIALN.TTF", 14, "OUTLINE", { 1, 1, 1 } },
	SystemFont_Shadow_Med1 = { "Fonts\\FRIZQT__.TTF", 12, "", { 1, 1, 1 } },
}
local DEFAULT_FONT = { "Fonts\\FRIZQT__.TTF", 12, "", { 1, 1, 1 } }

-- Average glyph widths in em for the kit's semibold face, for a text whose width nothing else gives and
-- whose font Tools/render/glyphs.lua does not list.
local GLYPH_EM = { upper = 0.60, lower = 0.48, digit = 0.52, space = 0.22, other = 0.30, thin = 0.10 }
local LINE_HEIGHT_EM = 1.2

local function lineEm(region)
	return region._lineEm or LINE_HEIGHT_EM
end

-- The kit fonts' real advances per ASCII glyph, by font file name, from gen_glyphs.py. Blizzard's faces
-- the repository lacks draw as Source Sans on the page, so they measure as Source Sans too.
local GLYPHS = {}
do
	local ok, table_ = pcall(dofile, "Tools/render/glyphs.lua")
	if ok and type(table_) == "table" then
		GLYPHS = table_
	end
end
local FONT_STAND_INS = { FRIZQT__ = "SourceSans3-Semibold", ARIALN = "SourceSans3-Regular" }

local function glyphTable(fontPath)
	if type(fontPath) ~= "string" then
		return nil
	end
	local name = fontPath:gsub("\\", "/"):match("([^/]+)$") or fontPath
	name = name:gsub("%.[^.]+$", "")
	return GLYPHS[name] or GLYPHS[FONT_STAND_INS[name] or ""]
end

-- Paths -------------------------------------------------------------------------------------------

local function fileExists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local HOME = os.getenv("HOME") or ""
Scene.ICON_DIRS = {
	"Tools/icons/setB/Icons",
	HOME .. "/.local/share/wow-dev/icons/blizzard",
}

local pathCache = {}

-- The atlas cache Tools/render/atlas.py builds outside the repository: atlas.tsv maps an atlas name to its
-- sheet's file ID and its rectangle, textures/<fileID>.png holds each sheet. Scene.ATLAS, when a test sets it,
-- stands in for the file: a table of lowercased names to { file, left, right, top, bottom, width, height }.
Scene.ATLAS = nil
Scene.ATLAS_DIR = HOME .. "/.local/share/wow-dev/atlas"
local atlasLoaded = nil

local function atlasTable()
	if Scene.ATLAS then
		return Scene.ATLAS
	end
	if atlasLoaded then
		return atlasLoaded
	end
	atlasLoaded = {}
	local f = io.open(Scene.ATLAS_DIR .. "/atlas.tsv", "rb")
	if not f then
		return atlasLoaded
	end
	local header = f:read("*l")
	if header then
		for line in f:lines() do
			local name, file, aw, ah, l, r, t, b, w, h, th, tv = line:match("^([^\t]*)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d)\t(%d)")
			if name and tonumber(aw) > 0 and tonumber(ah) > 0 then
				aw, ah = tonumber(aw), tonumber(ah)
				atlasLoaded[name] = {
					file = Scene.ATLAS_DIR .. "/textures/" .. file .. ".png", fileID = tonumber(file),
					left = tonumber(l) / aw, right = tonumber(r) / aw, top = tonumber(t) / ah, bottom = tonumber(b) / ah,
					width = tonumber(w), height = tonumber(h), tilesH = th == "1", tilesV = tv == "1",
				}
			end
		end
	end
	f:close()
	return atlasLoaded
end

-- AtlasInfo(name) -> the cache's entry for an atlas, or nil when the client has no atlas of that name or the
-- cache is not built.
function Scene.AtlasInfo(name)
	if type(name) ~= "string" then
		return nil
	end
	return atlasTable()[name:lower()]
end

-- Blizzard textures named by file path (`Interface\TargetingFrame\UI-RaidTargetingIcons`) come from the same cache:
-- `python3 Tools/render/atlas.py paths` writes each as paths/<key>.png, the key being the game path lowercased, with
-- forward slashes and no extension. Scene.PATHS_DIR, when a test sets it, replaces that folder.
Scene.PATHS_DIR = nil

-- PathKey(path) -> the cache key of a Blizzard texture path, or nil for anything else: a number, an addon's own
-- file, or a path outside Interface. The game matches paths without regard to case, separator or extension.
function Scene.PathKey(path)
	if type(path) ~= "string" then
		return nil
	end
	local key = path:gsub("\\", "/"):lower():gsub("^/+", "")
	if not key:match("^interface/") or key:match("^interface/addons/") then
		return nil
	end
	key = key:gsub("%.[a-z0-9]+$", "")
	if key == "interface/" or key:match("/$") then
		return nil
	end
	return key
end

-- PathFile(path) -> the cached PNG of a Blizzard texture path, or nil when the cache lacks it.
function Scene.PathFile(path)
	local key = Scene.PathKey(path)
	if not key then
		return nil
	end
	local dir = Scene.PATHS_DIR or (Scene.ATLAS_DIR .. "/paths")
	local candidate = dir .. "/" .. key .. ".png"
	if fileExists(candidate) then
		return candidate
	end
	return nil
end

-- ResolvePath(path) -> a repository-relative or absolute file, or nil when the game path has no local file.
function Scene.ResolvePath(path, iconDirs)
	if type(path) == "number" then
		local dirs = iconDirs or Scene.ICON_DIRS
		local key = "id:" .. path .. ":" .. table.concat(dirs, ";")
		if pathCache[key] == nil then
			pathCache[key] = false
			for _, dir in ipairs(dirs) do
				local candidate = dir .. "/" .. path .. ".png"
				if fileExists(candidate) then
					pathCache[key] = candidate
					break
				end
			end
		end
		return pathCache[key] or nil
	end
	if type(path) ~= "string" then
		return nil
	end
	local cached = Scene.PathFile(path)
	if cached then
		return cached
	end
	if pathCache[path] == nil then
		local local_ = path:gsub("\\", "/")
		local rel = local_:match("^[Ii]nterface/[Aa]dd[Oo]ns/(.+)$")
		if rel then
			-- The core addon's folder is the repository root.
			rel = rel:gsub("^KstyleUI/", "")
		end
		local found = false
		if rel then
			local companion = rel:gsub("%.[^.]+$", ".png")
			if rel:lower():match("%.tga$") and fileExists(companion) then
				found = companion
			elseif rel:lower():match("%.blp$") and fileExists(rel) then
				found = fileExists("Tools/render/out/standins/" .. companion) and "Tools/render/out/standins/" .. companion
			elseif fileExists(rel) then
				found = rel
			elseif rel:lower():match("%.tga$") or rel:lower():match("%.blp$") then
				local png = rel:gsub("%.[^.]+$", ".png")
				if fileExists(png) then
					found = png
				end
			end
		elseif fileExists(local_) then
			found = local_
		end
		pathCache[path] = found
	end
	return pathCache[path] or nil
end

-- Values ------------------------------------------------------------------------------------------

local function reveal(env, value)
	if env.issecretvalue and env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end

local function num(env, value, default)
	value = reveal(env, value)
	if type(value) == "number" and value == value then
		return value
	end
	return default
end

local function state(object, field)
	local stored = object._state[field]
	if stored then
		return unpack(stored, 1, stored.n)
	end
end

-- The units SetSpacing puts between two lines of one text (none above the first line or under the last); 0 when
-- the text never set a spacing.
local function spacingOf(region)
	local spacing = state(region, "Spacing")
	return type(spacing) == "number" and spacing > 0 and spacing or 0
end

-- An object's scale times its ancestors', stopping at an object that ignores its parent's scale, as the game does
-- for a nameplate's plate on a base the engine scales.
local function effectiveScale(object)
	local scale = type(object._scale) == "number" and object._scale or 1
	local node = object
	while not node._ignoreParentScale and node._parent do
		node = node._parent
		scale = scale * (type(node._scale) == "number" and node._scale or 1)
	end
	return scale
end

-- Animations ------------------------------------------------------------------------------------

-- The clock Scene.Build samples playing animation groups at, set for the duration of a build.
local animationClock = nil
-- The alpha each node's own calls give it, found once per build: a node's call log can run to thousands of
-- entries, and every drawable asks for the alpha of each of its ancestors.
local ownAlphaCache = {}

local function eased(p, smoothing)
	if smoothing == "IN" then
		return p * p
	elseif smoothing == "OUT" then
		return 1 - (1 - p) * (1 - p)
	elseif smoothing == "IN_OUT" then
		return p * p * (3 - 2 * p)
	end
	return p
end

local function animationSchedule(group)
	local orders, lengths, offsets = {}, {}, {}
	for _, anim in ipairs(group._anims or {}) do
		local order = state(anim, "Order") or 1
		if not lengths[order] then
			orders[#orders + 1] = order
		end
		lengths[order] = max(lengths[order] or 0, (state(anim, "StartDelay") or 0) + (state(anim, "Duration") or 0) + (state(anim, "EndDelay") or 0))
	end
	table.sort(orders)
	local total = 0
	for _, order in ipairs(orders) do
		offsets[order], total = total, total + lengths[order]
	end
	return offsets, total
end

function Scene.AnimationPeak(group)
	local offsets = animationSchedule(group)
	for _, anim in ipairs(group._anims or {}) do
		if anim._type == "Alpha" and (state(anim, "ToAlpha") or 1) > (state(anim, "FromAlpha") or 1) then
			return offsets[state(anim, "Order") or 1] + (state(anim, "StartDelay") or 0) + (state(anim, "Duration") or 0)
		end
	end
	return 0
end

-- An animation aimed at another region (SetTarget, or an XML childKey) plays on that region, not on its group's
-- owner (Blizzard_ActionBar/Shared/ActionButtonComponentTemplate.xml:50-53 turns its Glow child): Scene.Build lists
-- each region's aimed animations here. Only a clip (env._clip, Tools/render/clip.lua) plays aimed, Rotation and BOUNCE
-- animations, so every other render stays as it was.
local aimed, clipping = {}, false
local function targetOf(anim)
	local target = anim._state.Target
	return target and type(target[1]) == "table" and target[1] or nil
end
local function animated(object)
	return object._groups or aimed[object]
end

-- animationState(frame, now, scales) -> dx, dy (in the frame's own units), alpha, absolute, sx, sy, turn: what the
-- frame's playing animation groups apply at the clock. A Translation moves the frame by its offset times its progress, an
-- Alpha animation sets the alpha between its from and to values once its start delay has passed, in place of the
-- frame's own alpha as the game does (absolute is true then), a Rotation turns it by its degrees or radians times its
-- progress (SimpleAnimRotationAPIDocumentation.lua), a BOUNCE group plays forward then back, and a finished group
-- leaves each animation at its end, as the game does until OnFinished hides the frame. A Scale counts only once its
-- start delay has passed, and every started Scale multiplies the others, each holding its end value until its group's
-- pass ends: Blizzard's own templates chain them that way (the prey widget grows 1 to 1.1 and then 1 to 0.909091,
-- Blizzard_UIWidgetTemplatePreyHuntProgress.xml:66-67). The client keeps no final scale once a group that does not
-- loop has ended (SetToFinalAlpha keeps only alpha), so such a group's Scales stop counting then. Each counted Scale is
-- appended to scales as { anim, x, y } when a list is given, for its origin.
local function animationState(frame, now, scales)
	local dx, dy, alpha, absolute, sx, sy, turn = 0, 0, 1, false, 1, 1, 0
	if type(now) ~= "number" then
		return dx, dy, alpha, absolute, sx, sy, turn
	end
	local groups, only = {}, {}
	for _, group in ipairs(frame._groups or {}) do
		groups[#groups + 1] = group
	end
	for _, pair in ipairs(aimed[frame] or {}) do
		groups[#groups + 1], only[pair[1]] = pair[1], only[pair[1]] or {}
		only[pair[1]][pair[2]] = true
	end
	for _, group in ipairs(groups) do
		local started = group._playedAt
		if type(started) == "number" and now >= started then
			local elapsed = now - started
			local offsets, total = animationSchedule(group)
			local looping = state(group, "Looping")
			local ended = (looping == nil or looping == "NONE") and elapsed > total
			if looping == "REPEAT" and total > 0 then
				elapsed = elapsed % total
			elseif clipping and looping == "BOUNCE" and total > 0 then
				elapsed = elapsed % (2 * total)
				elapsed = elapsed > total and 2 * total - elapsed or elapsed
			end
			local alphaStart = -1
			for _, anim in ipairs(group._anims or {}) do
				local target = targetOf(anim)
				local mine = not clipping or only[group] and only[group][anim] or not only[group] and (target == nil or target == frame)
				local delay = offsets[state(anim, "Order") or 1] + (state(anim, "StartDelay") or 0)
				local duration = state(anim, "Duration") or 0
				local p = 0
				if elapsed >= delay then
					p = duration > 0 and math.min(1, (elapsed - delay) / duration) or 1
				end
				p = eased(p, state(anim, "Smoothing"))
				if mine and anim._type == "Translation" then
					local ox, oy = state(anim, "Offset")
					dx = dx + (type(ox) == "number" and ox or 0) * p
					dy = dy + (type(oy) == "number" and oy or 0) * p
				elseif mine and anim._type == "Alpha" and elapsed >= delay and delay >= alphaStart then
					local from, to = state(anim, "FromAlpha"), state(anim, "ToAlpha")
					from = type(from) == "number" and from or 1
					to = type(to) == "number" and to or 1
					alpha = from + (to - from) * p
					alphaStart = delay
					absolute = true
				elseif mine and anim._type == "Scale" and elapsed >= delay and not ended then
					local fx, fy = state(anim, "ScaleFrom")
					local tx, ty = state(anim, "ScaleTo")
					local x = (fx or 1) + ((tx or 1) - (fx or 1)) * p
					local y = (fy or 1) + ((ty or 1) - (fy or 1)) * p
					sx, sy = sx * x, sy * y
					if scales then
						scales[#scales + 1] = { anim, x, y }
					end
				elseif clipping and mine and anim._type == "Rotation" then
					local degrees, radians = state(anim, "Degrees"), state(anim, "Radians")
					turn = turn + (type(degrees) == "number" and math.rad(degrees) or type(radians) == "number" and radians or 0) * p
				end
			end
		end
	end
	return dx, dy, alpha, absolute, sx, sy, turn
end

-- The stub keeps current opacity, including Texture colour writes and boolean/secret alpha writes.
local function findOwnAlpha(node)
	local value = reveal(node._env, node._alpha)
	return type(value) == "number" and value or 1
end

-- ownAlpha(node) -> findOwnAlpha(node), remembered for the rest of the build.
local function ownAlpha(node)
	local cached = ownAlphaCache[node]
	if cached then
		return cached
	end
	local alpha = findOwnAlpha(node)
	ownAlphaCache[node] = alpha
	return alpha
end

local function effectiveAlpha(object)
	local alpha = 1
	local node = object
	while node do
		local own = ownAlpha(node)
		if animated(node) then
			local _, _, scale, absolute = animationState(node, animationClock)
			own = absolute and scale or own * scale
		end
		alpha = alpha * own
		if node._ignoreParentAlpha then
			break
		end
		node = node._parent
	end
	return alpha
end

-- A Scale animation changes what is drawn, not the layout: the client scales the object and everything drawn under a
-- frame about the animation's origin (SetOrigin, CENTER when unset, SimpleAnimScaleAPIDocumentation.lua), and nothing
-- anchored to it moves. drawMap(solver, object) -> { ax, bx, ay, by }: that transform in world units,
-- x -> ax * x + bx and y -> ay * y + by, the object's own Scales first and then each ancestor's, found once per object
-- per build.
local IDENTITY = { 1, 0, 1, 0 }
local drawMaps = {}

local function drawMap(solver, object)
	local map = drawMaps[object]
	if map then
		return map
	end
	map = object._parent and drawMap(solver, object._parent) or IDENTITY
	local scales = {}
	if animated(object) then
		animationState(object, animationClock, scales)
	end
	local rect = #scales > 0 and solver:rect(object)
	if rect then
		local ax, bx, ay, by, unit = 1, 0, 1, 0, effectiveScale(object)
		for _, entry in ipairs(scales) do
			local point, ox, oy = state(entry[1], "Origin")
			local at = POINTS[point] or POINTS.CENTER
			local cx = rect[1] + (rect[3] - rect[1]) * at[1] + num(solver.env, ox, 0) * unit
			local cy = rect[2] + (rect[4] - rect[2]) * at[2] + num(solver.env, oy, 0) * unit
			ax, bx = entry[2] * ax, cx + entry[2] * (bx - cx)
			ay, by = entry[3] * ay, cy + entry[3] * (by - cy)
		end
		map = { map[1] * ax, map[1] * bx + map[2], map[3] * ay, map[3] * by + map[4] }
	end
	drawMaps[object] = map
	return map
end

-- drawn(map, rect) -> the rect { left, bottom, right, top } as the map draws it.
local function drawn(map, rect)
	if map == IDENTITY then
		return rect
	end
	local l, r = map[1] * rect[1] + map[2], map[1] * rect[3] + map[2]
	local b, t = map[3] * rect[2] + map[4], map[3] * rect[4] + map[4]
	return { min(l, r), min(b, t), max(l, r), max(b, t) }
end

local function frameStrata(frame)
	local node = frame
	while node do
		local strata = node._state.FrameStrata and node._state.FrameStrata[1]
		if type(strata) == "string" and STRATA[strata] then
			return strata
		end
		node = node._parent
	end
	return "MEDIUM"
end

local function frameLevel(frame)
	if frame._state.UsingParentLevel and frame._state.UsingParentLevel[1] == true and frame._parent then
		return frameLevel(frame._parent)
	end
	if type(frame._level) == "number" then
		return frame._level
	end
	if frame._parent then
		return frameLevel(frame._parent) + 1
	end
	return 0
end

-- Text measurement ------------------------------------------------------------------------------

local function textWidthEm(text, fontPath)
	local glyphs = glyphTable(fontPath)
	local em = 0
	local i, n = 1, #text
	while i <= n do
		local c = text:byte(i)
		local size = 1
		if c >= 0xF0 then
			size = 4
		elseif c >= 0xE0 then
			size = 3
		elseif c >= 0xC0 then
			size = 2
		end
		local ch = text:sub(i, i + size - 1)
		local code = c
		if size > 1 and i + size - 1 <= n then
			code = c % (2 ^ (7 - size))
			for j = 1, size - 1 do
				code = code * 64 + text:byte(i + j) % 64
			end
		end
		if glyphs and glyphs[code] then
			em = em + glyphs[code]
		elseif ch == "\226\128\137" then
			em = em + (glyphs and glyphs[8201] or GLYPH_EM.thin)
		elseif ch == "\194\183" then
			em = em + (glyphs and glyphs[183] or 0.228)
		elseif ch == " " then
			em = em + GLYPH_EM.space
		elseif size > 1 then
			em = em + GLYPH_EM.lower
		elseif ch:match("%u") then
			em = em + GLYPH_EM.upper
		elseif ch:match("%l") then
			em = em + GLYPH_EM.lower
		elseif ch:match("%d") then
			em = em + GLYPH_EM.digit
		else
			em = em + GLYPH_EM.other
		end
		i = i + size
	end
	return em
end

-- TextWidth(text, size, fontPath) -> the width of a text in a font of the given size, in the same units:
-- exact for a kit font (or a Blizzard face the page draws as one), approximate for any other.
function Scene.TextWidth(text, size, fontPath)
	return textWidthEm(text, fontPath) * size
end

-- plainText(text) -> the text without its escapes, as the page draws it: colour codes, links and textures go,
-- "||" stays a pipe.
local function plainText(text)
	local out, i, n = {}, 1, #text
	while i <= n do
		local c = text:sub(i, i)
		if c == "|" and i < n then
			local code = text:sub(i + 1, i + 1)
			if code == "|" then
				out[#out + 1] = "|"
				i = i + 2
			elseif code == "c" and i + 9 <= n then
				i = i + 10
			elseif code == "r" or code == "h" then
				i = i + 2
			elseif code == "H" then
				local close = text:find("|h", i + 2, true)
				i = close and close + 2 or n + 1
			elseif code == "T" or code == "A" then
				local close = text:find(code == "T" and "|t" or "|a", i + 2, true)
				i = close and close + 2 or n + 1
			elseif code == "n" then
				out[#out + 1] = "\n"
				i = i + 2
			else
				out[#out + 1] = c
				i = i + 1
			end
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return table.concat(out)
end

Scene.PlainText = plainText

-- WrappedLines(text, size, fontPath, width) -> how many lines a word-wrapping text takes in a width, by the
-- page's rule: words fill a line while they fit, a word that fits nowhere takes a line of its own, and an
-- explicit break starts a new line. A line fits within WRAP_SLACK of the width, so a text as wide as its own
-- words (a natural-width text, its width back from a rounded number) stays on one line, as it does in the game.
local WRAP_SLACK = 0.01

function Scene.WrappedLines(text, size, fontPath, width)
	local lines = 0
	for paragraph in (plainText(text) .. "\n"):gmatch("(.-)\n") do
		local line = nil
		for word in (paragraph .. " "):gmatch("(.-) ") do
			local candidate = line and (line .. " " .. word) or word
			if line and textWidthEm(candidate, fontPath) * size > width + WRAP_SLACK then
				lines = lines + 1
				line = word
			else
				line = candidate
			end
		end
		lines = lines + 1
	end
	return lines
end

local function formatText(env, stored)
	if not stored then
		return nil
	end
	local args = {}
	for i = 1, stored.n do
		args[i] = reveal(env, stored[i])
	end
	if stored.format then
		local ok, result = pcall(string.format, unpack(args, 1, stored.n))
		if ok then
			return result
		end
		return tostring(args[1])
	end
	local value = args[1]
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function textOf(env, region)
	if region._renderText ~= nil then
		return region._renderText
	end
	-- The stubs keep the last setter's arguments (_lastText); a fixture may set _state alone.
	local formatted = region._state.FormattedText
	local stored = region._lastText or formatted or region._state.Text
	if stored then
		stored.format = stored == formatted or nil
	end
	return formatText(env, stored) or ""
end

-- fontSpec(env, object, log, depth) -> { path, size, flags, color } from a Font object, a font string
-- standing in for one, or a Blizzard font name.
local function fontSpec(env, object, log, depth)
	depth = depth or 0
	if depth > 4 or object == nil then
		return nil
	end
	if type(object) == "string" then
		local named = env[object]
		if type(named) == "table" and named._state then
			return fontSpec(env, named, log, depth + 1)
		end
		local spec = BLIZZARD_FONTS[object]
		if not spec then
			log("font object " .. object .. " is unknown; using the default font")
		end
		return spec
	end
	if type(object) == "table" and object._state then
		local p, s, f = state(object, "Font")
		if type(p) == "string" and p ~= "" then
			local c = object._state.TextColor
			return { p, s, f, c and { c[1], c[2], c[3] } or nil }
		end
		local inner = object._state.FontObject and object._state.FontObject[1]
		if inner ~= nil then
			return fontSpec(env, inner, log, depth + 1)
		end
		if object._template then
			return fontSpec(env, object._template, log, depth + 1)
		end
	end
	return nil
end

local function fontOf(env, region, log)
	local path, size, flags = state(region, "Font")
	local color
	if type(path) ~= "string" or path == "" then
		local object = region._state.FontObject and region._state.FontObject[1]
		local spec = fontSpec(env, object, log) or fontSpec(env, region._template, log) or DEFAULT_FONT
		path, size, flags, color = spec[1], spec[2], spec[3], spec[4]
	end
	if type(size) ~= "number" or size <= 0 then
		size = 12
	end
	return path, size, type(flags) == "string" and flags or "", color
end

-- Anchors -----------------------------------------------------------------------------------------

-- natural(env, region, log): a font string with no width or height of its own takes its natural size from its text,
-- approximately, as the game sizes it.
local function natural(env, region, log)
	region._naturalW, region._naturalH, region._naturalSideW, region._naturalSideH = nil, nil, nil, nil
	region._wrapSpec, region._wrapped = nil, nil
	local text = textOf(env, region)
	if text ~= "" then
		local fontPath, size = fontOf(env, region, log)
		local xs, ys = {}, {}
		for _, pack in ipairs(region._points or {}) do
			local point = POINTS[(pack[1])]
			if point then
				xs[point[1]] = true
				ys[point[2]] = true
			end
		end
		local hasW = type(region._width) == "number" and region._width > 0
		local hasH = type(region._height) == "number" and region._height > 0
		if not hasW and not (xs[0] and xs[1]) then
			-- The natural width is the drawn words', without colour codes, links and textures, as the game sizes it,
			-- plus each inline atlas (|A:name:height:width|a) at its width.
			region._naturalW = textWidthEm(plainText(text), fontPath) * size
			for _, _, width in text:gmatch("|A:([^:|]+):(%d+):(%d+)[^|]*|a") do region._naturalW = region._naturalW + tonumber(width) end
			region._naturalSideW = xs[1] and "right" or xs[0.5] and "center" or "left"
		end
		if not hasH and not (ys[0] and ys[1]) then
			local _, breaks = text:gsub("\n", "")
			local spacing = spacingOf(region)
			region._naturalH = size * lineEm(region) * (breaks + 1) + spacing * breaks
			region._naturalSideH = ys[1] and "top" or ys[0.5] and "middle" or "bottom"
			if state(region, "WordWrap") ~= false then
				region._wrapSpec = { text = text, size = size, fontPath = fontPath, spacing = spacing, em = lineEm(region) }
			end
		end
	end
end

local Solver = {}
Solver.__index = Solver

local function newSolver(env, opts, log)
	return setmetatable({
		env = env, opts = opts, log = log,
		rects = {}, solving = {},
		screen = nil,
	}, Solver)
end

local function parsePoint(pack)
	local point = pack[1]
	local relative, relativePoint, x, y
	local i = 2
	local a = pack[i]
	if type(a) == "table" or type(a) == "string" then
		relative = a
		i = i + 1
		local b = pack[i]
		if type(b) == "string" then
			relativePoint = b
			i = i + 1
		end
	end
	x, y = pack[i], pack[i + 1]
	return point, relative, relativePoint or point, type(x) == "number" and x or 0, type(y) == "number" and y or 0
end

function Solver:target(object, relative)
	if type(relative) == "string" then
		local named = self.env[relative]
		if type(named) ~= "table" then
			self.log("anchor to unknown frame " .. relative .. " falls back to the parent")
			return object._parent or "screen"
		end
		return named
	end
	if type(relative) == "table" then
		return relative
	end
	return object._parent or "screen"
end

-- rect(object) -> { left, bottom, right, top } in world units (768 tall at scale 1), or nil.
function Solver:rect(object)
	if object == "screen" then
		return self.screen
	end
	local known = self.rects[object]
	if known ~= nil then
		return known or nil
	end
	if self.solving[object] then
		self.log("anchor cycle through " .. (object._name or object._type))
		return nil
	end
	self.solving[object] = true
	local rect = self:solve(object)
	self.solving[object] = nil
	self.rects[object] = rect or false
	return rect
end

function Solver:solve(object)
	local env = self.env
	if object == env.UIParent then
		return self.screen
	end
	-- A Line's unturned rect lies around the middle of its start and end points, as long as they are apart and as tall
	-- as its thickness; object._turn is the angle the page turns the whole quad by, as the game draws it.
	if object._type == "Line" then
		local scale, ends = effectiveScale(object), {}
		for i, key in ipairs({ "StartPoint", "EndPoint" }) do
			local pack = object._state[key]
			local p = pack and POINTS[pack[1]]
			local r = p and self:rect(self:target(object, pack[2]))
			if not r then
				return nil, "line end unresolved"
			end
			ends[i] = { r[1] + (r[3] - r[1]) * p[1] + num(env, pack[3], 0) * scale, r[2] + (r[4] - r[2]) * p[2] + num(env, pack[4], 0) * scale }
		end
		local dx, dy = ends[2][1] - ends[1][1], ends[2][2] - ends[1][2]
		local half, thick = math.sqrt(dx * dx + dy * dy) / 2, num(env, state(object, "Thickness"), 1) * scale / 2
		local cx, cy = (ends[1][1] + ends[2][1]) / 2, (ends[1][2] + ends[2][2]) / 2
		object._turn = math.atan2(dy, dx)
		return { cx - half, cy - thick, cx + half, cy + thick }
	end
	local width, height = num(env, object._width), num(env, object._height)
	if self.natural and object._type == "FontString" and not ((width or 0) > 0 and (height or 0) > 0) then
		natural(env, object, self.log)
	end
	local scale = effectiveScale(object)
	if object._atlasSize then
		width, height = object._atlasSize[1], object._atlasSize[2]
	end
	if (not width or width == 0) and object._naturalW then
		width = object._naturalW
	end
	local wrap = object._wrapSpec
	if (not height or height == 0) and object._naturalH then
		height = object._naturalH
	else
		wrap = nil
	end
	if width then
		width = width * scale
	end
	if height then
		height = height * scale
	end
	local owner = object._barOwner
	if owner then
		return self:barFill(object, owner)
	end
	local points = object._points or {}
	if #points == 0 then
		-- A scroll frame's child hangs from the frame's top left corner, moved by the scroll offsets, as the game
		-- places it; the addon never anchors it.
		local parent = object._parent
		if parent and parent._type == "ScrollFrame" and state(parent, "ScrollChild") == object then
			points = { { "TOPLEFT", parent, "TOPLEFT", -(num(env, (state(parent, "HorizontalScroll")), 0)), num(env, (state(parent, "VerticalScroll")), 0) } }
		elseif object._rect then
			local l, b, w, h = unpack(object._rect, 1, 4)
			return { l, b, l + w, b + h }
		else
			return nil, "no anchors"
		end
	end
	local xs, ys = {}, {}
	for _, pack in ipairs(points) do
		local point, relative, relativePoint, dx, dy = parsePoint(pack)
		local p, rp = POINTS[point], POINTS[relativePoint]
		if not p then
			self.log("unknown anchor point " .. tostring(point))
		elseif not rp then
			self.log("unknown relative point " .. tostring(relativePoint))
		else
			local target = self:target(object, relative)
			local tr = self:rect(target)
			if not tr then
				return nil, "anchor target unresolved"
			end
			local ax = tr[1] + (tr[3] - tr[1]) * rp[1] + dx * scale
			local ay = tr[2] + (tr[4] - tr[2]) * rp[2] + dy * scale
			xs[#xs + 1] = { p[1], ax }
			ys[#ys + 1] = { p[2], ay }
		end
	end
	if animated(object) then
		local dx, dy = animationState(object, self.opts.time)
		if dx ~= 0 or dy ~= 0 then
			for _, a in ipairs(xs) do
				a[2] = a[2] + dx * scale
			end
			for _, a in ipairs(ys) do
				a[2] = a[2] + dy * scale
			end
		end
	end
	local left, right = self:span(xs, width)
	if not left then
		return nil, "width unknown"
	end
	-- A wrapping text with a width from its anchors is as tall as the lines it wraps into.
	object._wrapped = nil
	local lo, hi = false, false
	for _, a in ipairs(ys) do
		lo, hi = lo or a[1] == 0, hi or a[1] == 1
	end
	if wrap and not (lo and hi) then
		local lines = Scene.WrappedLines(wrap.text, wrap.size, wrap.fontPath, (right - left) / scale)
		height = (wrap.size * wrap.em * lines + wrap.spacing * (lines - 1)) * scale
		object._wrapped = lines > 1
	end
	local bottom, top = self:span(ys, height)
	if not bottom then
		return nil, "height unknown"
	end
	-- The client shifts a frame clamped to the screen back inside it (a tooltip asked to open past the top edge
	-- comes down over its owner), and its children follow.
	local screen = self.screen
	if screen and state(object, "ClampedToScreen") == true then
		local dx = left < screen[1] and screen[1] - left or right > screen[3] and screen[3] - right or 0
		local dy = bottom < screen[2] and screen[2] - bottom or top > screen[4] and screen[4] - top or 0
		left, right, bottom, top = left + dx, right + dx, bottom + dy, top + dy
	end
	return { left, bottom, right, top }
end

-- span(anchors, size) -> low, high from { share, position } anchors and an optional size.
function Solver:span(anchors, size)
	local lo, hi, mid
	for _, a in ipairs(anchors) do
		if a[1] == 0 then
			lo = a[2]
		elseif a[1] == 1 then
			hi = a[2]
		else
			mid = a[2]
		end
	end
	if lo and hi then
		return lo, hi
	end
	if size then
		if lo then
			return lo, lo + size
		elseif hi then
			return hi - size, hi
		elseif mid then
			return mid - size / 2, mid + size / 2
		end
	end
	if lo and mid then
		return lo, 2 * mid - lo
	elseif hi and mid then
		return 2 * mid - hi, hi
	end
	return nil
end

-- The texture of a status bar covers the bar's rect times its fill fraction.
function Solver:barFill(texture, bar)
	local env = self.env
	local full = self:rect(bar)
	if not full then
		return nil, "bar unresolved"
	end
	local fraction = Scene.BarFraction(env, bar, self.opts.time)
	texture._fraction = fraction
	local orientation = state(bar, "Orientation") or "HORIZONTAL"
	local reverse, center = state(bar, "ReverseFill") == true, (state(bar, "FillStyle") == "CENTER" or state(bar, "FillStyle") == 2)
	local l, b, r, t = full[1], full[2], full[3], full[4]
	if orientation == "VERTICAL" then
		local h = (t - b) * fraction
		if center then
			return { l, (b + t - h) / 2, r, (b + t + h) / 2 }
		elseif reverse then
			return { l, t - h, r, t }
		end
		return { l, b, r, b + h }
	end
	local w = (r - l) * fraction
	if center then
		return { (l + r - w) / 2, b, (l + r + w) / 2, t }
	elseif reverse then
		return { r - w, b, r, t }
	end
	return { l, b, l + w, t }
end

local EASE_HALF = 0.05

-- BarFraction(env, bar, now) -> the share of the bar that is filled, from SetValue over SetMinMaxValues or
-- from a timer duration ({ start, finish } in seconds) against the clock.
function Scene.BarFraction(env, bar, now)
	local timer = bar._state.TimerDuration
	if timer and type(timer[1]) == "table" then
		local duration = reveal(env, timer[1])
		local start, finish = num(env, duration.start), num(env, duration.finish)
		if start and finish and finish > start then
			now = now or env._time or (type(env.GetTime) == "function" and env.GetTime()) or start
			local elapsed = (now - start) / (finish - start)
			elapsed = max(0, min(1, elapsed))
			local direction = timer[3]
			local remaining = env.Enum and env.Enum.StatusBarTimerDirection and env.Enum.StatusBarTimerDirection.RemainingTime
			if direction ~= nil and direction == remaining then
				return 1 - elapsed
			end
			return elapsed
		end
	end
	local low, high = state(bar, "MinMaxValues")
	low, high = num(env, low, 0), num(env, high, 1)
	local value = num(env, (state(bar, "Value")), low)
	-- An aura slot's bar eased by the game (Tools/regression/aura_slots.lua) closes half its gap every EASE_HALF seconds.
	local ease = bar._ease
	if ease and ease.at and now and now >= ease.at then
		value = ease.to + (ease.from - ease.to) * 0.5 ^ ((now - ease.at) / EASE_HALF)
	end
	if high <= low then
		return 0
	end
	return max(0, min(1, (value - low) / (high - low)))
end

-- Cooldowns ---------------------------------------------------------------------------------------

-- CooldownFraction(env, cooldown, now) -> the share still remaining and the seconds left, or nil when the
-- swipe is clear. SetCooldown(start, duration) and duration objects with start and finish (seconds), or
-- remaining and total, are understood.
function Scene.CooldownFraction(env, cooldown, now)
	now = now or env._time or (type(env.GetTime) == "function" and env.GetTime()) or 0
	-- The stub keeps every setter's last arguments; the latest call decides, and Clear wins when it came last.
	local calls = cooldown._calls or {}
	for i = #calls, 1, -1 do
		local method = calls[i].method
		if method == "Clear" then
			return nil
		elseif method == "SetCooldown" or method == "SetCooldownFromDurationObject" then
			break
		end
	end
	local object = cooldown._state.CooldownFromDurationObject and cooldown._state.CooldownFromDurationObject[1]
	if type(object) == "table" then
		local remaining, total = num(env, object.remaining), num(env, object.total)
		if remaining and total and total > 0 then
			return max(0, min(1, remaining / total)), remaining
		end
		local start, finish = num(env, object.start), num(env, object.finish)
		if start and finish and finish > start then
			local left = finish - now
			if left <= 0 then
				return nil
			end
			return min(1, left / (finish - start)), left
		end
		return nil
	end
	local start, duration = state(cooldown, "Cooldown")
	start, duration = num(env, start), num(env, duration)
	if start and duration and duration > 0 then
		local left = start + duration - now
		if left <= 0 then
			return nil
		end
		return min(1, left / duration), left
	end
	return nil
end

-- Walk ------------------------------------------------------------------------------------------------

local DRAW = setmetatable({}, { __mode = "k" })

local function sortKey(a, b)
	if a.strata ~= b.strata then
		return a.strata < b.strata
	end
	if a.level ~= b.level then
		return a.level < b.level
	end
	if a.layer ~= b.layer then
		return a.layer < b.layer
	end
	if a.sublevel ~= b.sublevel then
		return a.sublevel < b.sublevel
	end
	return a.seq < b.seq
end

local function color4(stored, default, env)
	if not stored then
		return default
	end
	local r, g, b, a = stored[1], stored[2], stored[3], stored[4]
	if env then
		r, g, b, a = reveal(env, r), reveal(env, g), reveal(env, b), reveal(env, a)
	end
	if type(r) ~= "number" then
		return default
	end
	return { r, type(g) == "number" and g or r, type(b) == "number" and b or r, type(a) == "number" and a or 1 }
end

local function round4(v)
	return floor(v * 10000 + 0.5) / 10000
end

-- Material textures depend on the final anchored size. The lightweight stubs do not propagate
-- anchor-driven size events, so refresh paint against the same resolved rect the renderer draws.
-- Do not run layout/restyle or alter stored sizes: Glass, text and bar geometry must stay untouched.
local function paintMaterials(env, solver)
	for _, chrome in ipairs(env._materialChromes or {}) do
		local material = not chrome.released and chrome:Material()
		local owner = chrome.owner
		if material and material.texture and owner:IsVisible() then
			local rect = solver:rect(owner)
			local scale = effectiveScale(owner)
			if rect and scale > 0 then
				local oldWidth, oldHeight = rawget(owner, "GetWidth"), rawget(owner, "GetHeight")
				owner.GetWidth = function() return (rect[3] - rect[1]) / scale end
				owner.GetHeight = function() return (rect[4] - rect[2]) / scale end
				local ok, err = pcall(chrome.PaintMaterial, chrome)
				owner.GetWidth, owner.GetHeight = oldWidth, oldHeight
				assert(ok, err)
			end
		end
	end
end

-- An ornament sizes its pieces to its target, and the stubs do not fire OnSizeChanged when anchors resize a frame.
-- So a scene that draws ornaments is built once, each ornament is restyled at the size the renderer solved for its
-- target, as the game restyles it on OnSizeChanged, and the scene is built again. Off draws none and skips the pass.
-- A target whose anchoring is secret answers that size as a secret, as the game does, so the ornament gets no size the
-- game would not give it.
local function restyleOrnaments(env, opts)
	local handles = env._ornamentHandles
	local K = env._addons and env._addons.KstyleUI
	if opts._ornamentPass or not handles or #handles == 0 or not K or K.Widgets.Setting("ornaments") == "Off" then
		return
	end
	opts._ornamentPass = true
	Scene.Build(env, opts)
	opts._ornamentPass = nil
	env._rectSolver = nil
	local solver = Scene.RectSolver(env)
	for _, handle in ipairs(handles) do
		local target = handle.target
		local _, _, w, h = Scene.RectIn(solver, target)
		if w and h then
			local factor = target:GetEffectiveScale() * SCREEN_UNITS / UI_HEIGHT
			local secret = target.IsAnchoringSecret and target:IsAnchoringSecret()
			target.GetWidth = function()
				return secret and env.Secret(w / factor) or w / factor
			end
			target.GetHeight = function()
				return secret and env.Secret(h / factor) or h / factor
			end
			handle:Restyle()
		end
	end
end

function Scene.Build(env, opts)
	opts = opts or {}
	restyleOrnaments(env, opts)
	local log = {}
	local counts = {}
	local function logLine(line)
		counts[line] = (counts[line] or 0) + 1
		if counts[line] == 1 then
			log[#log + 1] = line
		end
	end
	local solver = newSolver(env, opts, logLine)
	animationClock = opts.time
	ownAlphaCache, drawMaps = {}, {}
	aimed, clipping = {}, env._clip == true
	local function aim(object)
		for _, group in ipairs(object._groups or {}) do
			for _, anim in ipairs(group._anims or {}) do
				local target = targetOf(anim)
				if target and target ~= object then
					aimed[target] = aimed[target] or {}
					table.insert(aimed[target], { group, anim })
				end
			end
		end
	end
	for _, frame in ipairs(clipping and env._frames or {}) do
		aim(frame)
		for _, region in ipairs(frame._regions or {}) do aim(region) end
	end
	local width, height = env.GetPhysicalScreenSize()
	local uiParent = env.UIParent
	local parentScale = type(uiParent._scale) == "number" and uiParent._scale or 1
	local worldHeight = UI_HEIGHT
	local worldWidth = UI_HEIGHT * width / height
	solver.screen = { 0, 0, worldWidth, worldHeight }
	solver.rects[uiParent] = { 0, 0, uiParent._width * parentScale, uiParent._height * parentScale }
	local k = SCREEN_UNITS / worldHeight
	local resolve = opts.paths or function(path)
		return Scene.ResolvePath(path, opts.iconDirs)
	end
	local hover = opts.hover or {}
	local now = opts.time

	local function toScreen(r)
		return { round4(r[1] * k), round4((worldHeight - r[4]) * k), round4((r[3] - r[1]) * k), round4((r[4] - r[2]) * k) }
	end

	-- The object's rect as its playing Scales and its ancestors' draw it, in screen units.
	local function drawnRect(object, rect)
		return toScreen(drawn(drawMap(solver, object), rect))
	end

	-- zoom(object) -> the horizontal and vertical factors those Scales draw the object at, for sizes inside its rect.
	local function zoom(object)
		local map = drawMap(solver, object)
		return abs(map[1]), abs(map[3])
	end

	local items = {}
	local seq = 0
	local skipped = { hidden = 0, transparent = 0, unresolved = 0, clipped = 0 }

	local function describe(object)
		local name = object._name
		local node = object._parent
		while not name and node do
			name = node._name
			node = node._parent
		end
		return (object._type or "object") .. (name and (" under " .. name) or "")
	end

	local function mark(object, item)
		local rect, why = solver:rect(object)
		if not rect then
			if why then
				logLine(why .. ": " .. describe(object))
			end
			skipped.unresolved = skipped.unresolved + 1
			return nil
		end
		item.rect = drawnRect(object, rect)
		item.object = object
		-- A Rotation animation turns the whole quad about its middle, as a line's own turn does.
		local turn = (object._turn or 0) + (animated(object) and select(7, animationState(object, animationClock)) or 0)
		if turn ~= 0 then item.turn = round4(turn) end
		-- A wrapped text's height came from the solver; the page keeps it instead of re-deriving one line, and
		-- draws a block it measures shorter from the side the text grows from, as the game does.
		if object._wrapped and item.natural then
			item.grow = item.natural.height
			item.natural.height = nil
			if next(item.natural) == nil then
				item.natural = nil
			end
		end
		return item
	end

	local function masks(region)
		if not region._masks or #region._masks == 0 or not solver:rect(region) then
			return nil
		end
		local out = {}
		for _, mask in ipairs(region._masks) do
			local rect = solver:rect(mask)
			if rect then
				local path, wrapH = state(mask, "Texture")
				out[#out + 1] = {
					rect = drawnRect(mask, rect), file = resolve(path), path = type(path) == "string" and path or nil,
					clampWhite = wrapH == "CLAMPTOWHITE" or nil,
				}
			else
				logLine("mask unresolved: " .. describe(region))
			end
		end
		return out
	end

	-- A flat colour set after the file replaces it, as SetColorTexture does in the game; a file set after the
	-- colour replaces the colour.
	local function colourWins(region)
		if not region._state.ColorTexture then
			return false
		end
		for i = #region._calls, 1, -1 do
			local method = region._calls[i].method
			if method == "SetColorTexture" then
				return true
			elseif method == "SetTexture" or method == "SetAtlas" then
				return false
			end
		end
		return true
	end

	local function textureItem(region, frame, alpha)
		local item = { kind = "texture", alpha = round4(alpha) }
		local path, wrapH, wrapV = state(region, "Texture")
		-- A secret file ID (the aura engine's secretwrap) is revealed here, as the engine draws it.
		path = reveal(env, path)
		if path ~= nil and colourWins(region) then
			path = nil
		end
		if path ~= nil then
			local resolved = resolve(path)
			if resolved then
				item.file = resolved
			elseif Scene.PathKey(path) then
				item.pendingLog = "texture " .. tostring(path) .. " is drawn as a grey box: the client's file is not in the texture cache; run python3 Tools/render/atlas.py paths --scan"
				item.missing = tostring(path)
			else
				item.pendingLog = (tostring(path):lower():match("%.blp$") and "texture %s is drawn as a grey box: run python3 Tools/render/standins.py to decode it"
					or "no local file for texture %s"):format(tostring(path))
				item.missing = tostring(path)
			end
			if type(path) == "number" then
				item.fileID = path
			else
				item.path = path
			end
			item.wrap = (wrapH == "REPEAT" or wrapV == "REPEAT") and { wrapH == "REPEAT", wrapV == "REPEAT" } or nil
		end
		local atlas = state(region, "Atlas")
		if atlas then
			item.atlas = atlas
			local info = Scene.AtlasInfo(atlas)
			if info and fileExists(info.file) then
				item.file = info.file
				item.texCoord = { round4(info.left), round4(info.right), round4(info.top), round4(info.bottom) }
			elseif info then
				item.pendingLog = "atlas " .. tostring(atlas) .. ": its sheet is not in the atlas cache, so it is drawn as a grey box; run python3 Tools/render/atlas.py fetch " .. tostring(atlas)
			else
				item.pendingLog = "atlas " .. tostring(atlas) .. " is drawn as a grey box: the client's atlas tables have no such name, or the atlas cache is not built (python3 Tools/render/atlas.py build --scan)"
			end
		end
		local colour = color4(region._state.ColorTexture, nil, env)
		if colour and (item.file == nil or colourWins(region)) then
			item.color = colour
			item.color[4] = 1
		end
		item.vertex = color4(region._state.VertexColor, { 1, 1, 1, 1 }, env)
		item.vertex[4] = 1
		if region._barOwner and region._barOwner._state.StatusBarColor then
			item.vertex = color4(region._barOwner._state.StatusBarColor, item.vertex, env)
		end
		if item.vertex[4] <= 0 then
			skipped.transparent = skipped.transparent + 1
			return nil
		end
		local coords = region._state.TexCoord
		if coords and coords.n >= 4 and not item.texCoord then
			local list = {}
			for i = 1, coords.n do
				list[i] = num(env, coords[i], 0)
			end
			item.texCoord = list
		end
		-- SetSpriteSheetCell(index, rows, columns) shows one cell of a grid sheet, counted along the rows from
		-- the top left, as the raid target icons are; the index may be a secret.
		local cell, rows, columns = state(region, "SpriteSheetCell")
		if cell ~= nil and not item.atlas then
			local index = num(env, cell, 0)
			rows, columns = num(env, rows, 1), num(env, columns, 1)
			if index >= 1 and rows >= 1 and columns >= 1 and index <= rows * columns then
				local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
				item.texCoord = { round4(column / columns), round4((column + 1) / columns), round4(row / rows), round4((row + 1) / rows) }
			end
		end
		-- A playing FlipBook animation shows the cell its progress has reached, counted along the rows from the top
		-- left, as the engine steps it; a repeating group starts over each cycle.
		for _, group in ipairs(region._groups or {}) do
			local started = group._playedAt
			for _, anim in ipairs(type(started) == "number" and type(animationClock) == "number" and group._anims or {}) do
				if anim._type == "FlipBook" then
					local fRows, fColumns = num(env, state(anim, "FlipBookRows"), 1), num(env, state(anim, "FlipBookColumns"), 1)
					local frames, duration = num(env, state(anim, "FlipBookFrames"), fRows * fColumns), num(env, state(anim, "Duration"), 0)
					local elapsed = animationClock - started - num(env, state(anim, "StartDelay"), 0)
					if state(group, "Looping") == "REPEAT" and duration > 0 then
						elapsed = elapsed % duration
					end
					local index = duration > 0 and math.floor(math.max(0, elapsed) / duration * frames) or frames - 1
					index = math.max(0, math.min(frames - 1, index))
					local column, row = index % fColumns, math.floor(index / fColumns)
					item.texCoord = { round4(column / fColumns), round4((column + 1) / fColumns), round4(row / fRows), round4((row + 1) / fRows) }
				end
			end
		end
		local blend = state(region, "BlendMode")
		if blend and blend ~= "BLEND" then
			item.blend = blend
		end
		if state(region, "Desaturated") == true then
			item.desaturated = true
		end
		local rotation = state(region, "Rotation")
		if type(rotation) == "number" and rotation ~= 0 then
			item.rotation = round4(rotation)
		end
		if state(region, "HorizTile") == true or state(region, "VertTile") == true then
			item.tile = { state(region, "HorizTile") == true, state(region, "VertTile") == true }
		end
		local gradient = region._state.Gradient
		if gradient then
			local a, b = gradient[2], gradient[3]
			if type(a) == "table" and type(b) == "table" then
				item.gradient = {
					orientation = gradient[1],
					from = { a.r or a[1] or 1, a.g or a[2] or 1, a.b or a[3] or 1, a.a or a[4] or 1 },
					to = { b.r or b[1] or 1, b.g or b[2] or 1, b.b or b[3] or 1, b.a or b[4] or 1 },
				}
			end
		end
		item.masks = masks(region)
		if region._barOwner then
			local bar, f = region._barOwner, Scene.BarFraction(env, region._barOwner, now)
			item.fraction = round4(f)
			item.bar = true
			-- The client crops a status bar's texture to its fill rather than squeezing it (the fill-up widgets anchor a
			-- spark to the fill's top over shaped fill art, Blizzard_UIWidgetTemplateFillUpFrames.lua:203-205).
			if not item.texCoord then
				local reverse, center = state(bar, "ReverseFill") == true, (state(bar, "FillStyle") == "CENTER" or state(bar, "FillStyle") == 2)
				local from = center and (1 - f) / 2 or reverse and 0 or 1 - f
				item.texCoord = state(bar, "Orientation") == "VERTICAL" and { 0, 1, round4(from), round4(from + f) }
					or { round4(center and from or reverse and 1 - f or 0), round4((center and from or reverse and 1 - f or 0) + f), 0, 1 }
			end
		end
		item.mark = region._renderMark or frame._renderMark
		return item
	end

	local function textItem(region, frame, alpha)
		local text = textOf(env, region)
		if text == nil or text == "" then
			return nil
		end
		local path, size, flags, colour = fontOf(env, region, logLine)
		local scale, zx, zy = effectiveScale(region), zoom(region)
		local item = {
			kind = "text", alpha = round4(alpha), text = text,
			maxLines = state(region, "MaxLines"),
			font = { file = resolve(path), path = path, size = round4(size * scale * k * zy), flags = flags },
			color = color4(region._state.TextColor, colour and { colour[1], colour[2], colour[3], 1 } or { 1, 1, 1, 1 }, env),
			justifyH = state(region, "JustifyH") or "CENTER",
			justifyV = state(region, "JustifyV") or "MIDDLE",
		}
		if not item.font.file then
			logLine("no local font for " .. tostring(path) .. "; the page falls back to Source Sans")
		end
		-- Inline atlases (|A:name:height:width|a, as CreateAtlasMarkup writes them) draw as images in the line.
		for atlas, h, w in text:gmatch("|A:([^:|]+):(%d+):(%d+)[^|]*|a") do
			local info, glyph = Scene.AtlasInfo(atlas), { atlas = atlas, height = round4(tonumber(h) * scale * k * zy), width = round4(tonumber(w) * scale * k * zx) }
			if info and fileExists(info.file) then
				glyph.file, glyph.texCoord = info.file, { round4(info.left), round4(info.right), round4(info.top), round4(info.bottom) }
			else
				logLine("atlas " .. atlas .. ": its sheet is not in the atlas cache, so it is drawn as a grey box; run python3 Tools/render/atlas.py fetch " .. atlas)
			end
			item.glyphs = item.glyphs or {}
			item.glyphs[#item.glyphs + 1] = glyph
		end
		local sx, sy = state(region, "ShadowOffset")
		if type(sx) == "number" and type(sy) == "number" and (sx ~= 0 or sy ~= 0) then
			item.shadow = { color = color4(region._state.ShadowColor, { 0, 0, 0, 1 }), offset = { round4(sx * scale * k * zx), round4(-sy * scale * k * zy) } }
		end
		if state(region, "WordWrap") == false then
			item.wordWrap = false
		end
		local spacing = spacingOf(region)
		if spacing > 0 then
			item.spacing = round4(spacing * scale * k * zy)
		end
		if region._lineEm then
			item.lineEm = region._lineEm
		end
		if region._naturalW then
			item.natural = { width = region._naturalSideW }
		end
		if region._naturalH then
			item.natural = item.natural or {}
			item.natural.height = region._naturalSideH
		end
		item.mark = region._renderMark or frame._renderMark
		return item
	end

	-- The countdown numbers as the engine formats them: through the formatter SetCountdownFormatter gave the
	-- frame when it has one, else whole seconds, or minutes past a minute.
	local function countdownText(left, frame)
		local formatter = frame and state(frame, "CountdownFormatter")
		if type(formatter) == "table" then
			local fn = formatter.Format or formatter.FormatNumber
			if type(fn) == "function" then
				local ok, text = pcall(fn, formatter, left)
				if ok and type(text) == "string" then
					return text
				end
			end
		end
		return left >= 60 and string.format("%dm", floor(left / 60 + 0.5)) or string.format("%d", floor(left + 0.5))
	end

	local function swipeItem(frame, alpha)
		local fraction, left = Scene.CooldownFraction(env, frame, now)
		if not fraction then
			return nil
		end
		local item = { kind = "swipe", alpha = round4(alpha), fraction = round4(fraction), remaining = round4(left) }
		if state(frame, "DrawSwipe") == false then
			item.drawSwipe = false
		end
		item.reverse = state(frame, "Reverse") == true
		item.color = color4(frame._state.SwipeColor, { 0, 0, 0, 0.8 })
		if state(frame, "DrawEdge") == true then
			item.edge = color4(frame._state.EdgeColor, { 1, 1, 1, 1 })
			item.edgeScale = num(env, state(frame, "EdgeScale"), 1)
			local art = state(frame, "EdgeTexture")
			item.edgeFile = art and resolve(art) or nil
		end
		local swipe = state(frame, "SwipeTexture")
		if swipe then
			item.file = resolve(swipe)
			item.path = swipe
		end
		if state(frame, "HideCountdownNumbers") ~= true and not frame._countdown then
			item.countdown = countdownText(left, frame)
			local fontPath, size = DEFAULT_FONT[1], 12
			local _, zy = zoom(frame)
			item.font = { file = resolve(fontPath), path = fontPath, size = round4(size * effectiveScale(frame) * k * zy), flags = "OUTLINE" }
		end
		item.mark = frame._renderMark
		if item.drawSwipe == false and not item.edge and not item.countdown then
			return nil
		end
		return item
	end

	-- An edit box draws its own text, as the game does: inside its text insets, from the left, and from the top
	-- when it is multi-line. A box with no text draws nothing, so a placeholder font string shows through.
	local function editBoxItem(frame, rect, alpha)
		local item = textItem(frame, frame, alpha)
		if not item then
			return nil
		end
		local zx, zy = zoom(frame)
		local sx, sy = effectiveScale(frame) * k * zx, effectiveScale(frame) * k * zy
		local l, r, t, b = state(frame, "TextInsets")
		l, r, t, b = (type(l) == "number" and l or 0) * sx, (type(r) == "number" and r or 0) * sx, (type(t) == "number" and t or 0) * sy, (type(b) == "number" and b or 0) * sy
		local screen = drawnRect(frame, rect)
		item.rect = { round4(screen[1] + l), round4(screen[2] + t), round4(screen[3] - l - r), round4(screen[4] - t - b) }
		item.justifyH = state(frame, "JustifyH") or "LEFT"
		item.justifyV = state(frame, "MultiLine") == true and "TOP" or "MIDDLE"
		item.object = frame
		return item
	end

	local visited = {}
	local kidsOf, regionsOf = {}, {}

	-- A frame that clips its children (SetClipsChildren) bounds everything drawn under it, as a scroll list's
	-- view does; clip is that bound in screen units, or nil. An item outside it is dropped, one across it (or a
	-- turned line, whose rect is unturned) is drawn through it by the page, and carries scroll = true when the
	-- nearest clipping frame is a scroll view (a ScrollFrame, or a frame that takes the mouse wheel, or whose
	-- parent does), which cuts rows by design.
	local function clipped(item, clip, scroll)
		if not clip then
			return true
		end
		local r = item.rect
		if not item.turn and (r[1] + r[3] <= clip[1] or r[1] >= clip[1] + clip[3] or r[2] + r[4] <= clip[2] or r[2] >= clip[2] + clip[4]) then
			skipped.clipped = (skipped.clipped or 0) + 1
			return false
		end
		item.clip = clip
		item.scroll = scroll or nil
		return true
	end

	local function takesWheel(frame)
		local enabled = false
		for _, call in ipairs(frame._calls or {}) do
			if call.method == "EnableMouseWheel" then
				enabled = call.args[1] ~= false
			end
		end
		return enabled
	end

	local function scrolls(frame)
		if frame._parent and frame._parent._name == "KstyleUI_QuestCard" then return false end
		if frame._type == "ScrollFrame" or frame._type == "ScrollingMessageFrame"
			or (frame._parent and frame._parent._type == "ScrollingMessageFrame" and frame._parent.FontStringContainer == frame) then
			return true
		end
		return takesWheel(frame) or (frame._parent ~= nil and takesWheel(frame._parent))
	end

	local function intersect(a, b)
		if not a then
			return b
		end
		local x0, y0 = math.max(a[1], b[1]), math.max(a[2], b[2])
		local x1, y1 = math.min(a[1] + a[3], b[1] + b[3]), math.min(a[2] + a[4], b[2] + b[4])
		return { x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0) }
	end

	local function walkFrame(frame, inheritedHidden, clip, scroll)
		if visited[frame] then
			return
		end
		visited[frame] = true
		local shown = frame._shown ~= false
		if not shown or inheritedHidden then
			skipped.hidden = skipped.hidden + 1
			return
		end
		local alpha = effectiveAlpha(frame)
		local strata, level = STRATA[frameStrata(frame)], frameLevel(frame)
		local rect = solver:rect(frame)
		if not rect then
			local _, why = solver:solve(frame)
			if #(frame._regions or {}) > 0 then
				logLine((why or "unresolved") .. ": " .. describe(frame))
			end
			skipped.unresolved = skipped.unresolved + 1
		end
		if rect and state(frame, "ClipsChildren") == true then
			clip = intersect(clip, drawnRect(frame, rect))
			scroll = scrolls(frame)
		end
		if frame._type == "Cooldown" and rect and alpha > 0 then
			local item = swipeItem(frame, alpha)
			if item then
				item.rect = drawnRect(frame, rect)
				item.object = frame
			end
			if item and clipped(item, clip, scroll) then
				seq = seq + 1
				item.strata, item.level, item.layer, item.sublevel, item.seq = strata, level, LAYERS.ARTWORK, 0, seq
				items[#items + 1] = item
			end
		elseif frame._type == "EditBox" and rect and alpha > 0 then
			local item = editBoxItem(frame, rect, alpha)
			if item and clipped(item, clip, scroll) then
				seq = seq + 1
				item.strata, item.level, item.layer, item.sublevel, item.seq = strata, level, LAYERS.ARTWORK, 0, seq
				items[#items + 1] = item
			end
		end
		for _, region in ipairs(regionsOf[frame] or {}) do
			if region._shown ~= false and region._type ~= "MaskTexture" then
				local regionAlpha = effectiveAlpha(region)
				local layerName, sublevel = state(region, "DrawLayer")
				layerName = layerName or (region._type == "FontString" and "ARTWORK" or "ARTWORK")
				local layer = LAYERS[layerName] or LAYERS.ARTWORK
				if layerName == "HIGHLIGHT" and not hover[frame] then
					layer = nil
				end
				if layer and regionAlpha > 0 then
					local item
					if region._type == "FontString" then
						item = textItem(region, frame, regionAlpha)
					elseif region._type == "Texture" or region._type == "Line" then
						item = textureItem(region, frame, regionAlpha)
					end
					if item and mark(region, item) and clipped(item, clip, scroll) then
						if item.pendingLog then
							-- A grey box is worth a log line only when the region is drawn: a faded or clipped one is not.
							logLine(item.pendingLog)
							item.pendingLog = nil
						end
						seq = seq + 1
						item.strata, item.level, item.layer, item.sublevel, item.seq = strata, level, layer, type(sublevel) == "number" and sublevel or 0, seq
						items[#items + 1] = item
					end
				elseif layer and regionAlpha <= 0 then
					skipped.transparent = skipped.transparent + 1
				end
			end
		end
		for _, kid in ipairs(kidsOf[frame] or {}) do
			walkFrame(kid, false, clip, scroll)
		end
	end

	-- SetParent moves a frame or region without touching the stub's _kids and _regions lists, so the tree
	-- is built from each object's current parent, in creation order.
	local function adopt(map, object)
		local parent = object._parent
		if parent ~= nil then
			map[parent] = map[parent] or {}
			map[parent][#map[parent] + 1] = object
		end
	end
	-- A status bar's fill texture is the stub's _barTexture, which it lists among the bar's regions. A
	-- Cooldown frame with a countdown font string draws its numbers through that string, so the addon's
	-- anchors, font and justification place them. A font string with no width or height of its own takes
	-- its natural size from its text, approximately.
	for _, frame in ipairs(env._frames) do
		if frame._barTexture then
			frame._barTexture._barOwner = frame
		end
		local countdown = frame._countdown
		if countdown then
			local text
			if state(frame, "HideCountdownNumbers") ~= true then
				local _, left = Scene.CooldownFraction(env, frame, now)
				if left then
					text = countdownText(left, frame)
				end
			end
			countdown._renderText = text
		end
		for _, region in ipairs(frame._regions or {}) do
			if region._type == "Texture" then
				-- SetAtlas(name, true) sizes the region to the atlas, over any size it had, as the game does.
				region._atlasSize = nil
				local atlas, useAtlasSize = state(region, "Atlas")
				local info = useAtlasSize == true and Scene.AtlasInfo(atlas)
				if info then
					region._atlasSize = { info.width, info.height }
				end
			elseif region._type == "FontString" then
				natural(env, region, logLine)
			end
		end
	end

	paintMaterials(env, solver)
	for _, frame in ipairs(env._frames) do
		adopt(kidsOf, frame)
		for _, region in ipairs(frame._regions or {}) do
			adopt(regionsOf, region)
		end
	end

	local roots = opts.roots
	if not roots then
		roots = {}
		for _, frame in ipairs(env._frames) do
			if frame._parent == nil then
				roots[#roots + 1] = frame
			end
		end
		roots[#roots + 1] = uiParent
	end
	for _, root in ipairs(roots) do
		walkFrame(root, false)
	end

	table.sort(items, sortKey)
	for _, item in ipairs(items) do
		DRAW[item] = { item.strata, item.level, item.layer, item.sublevel }
		item.strata, item.level, item.layer, item.sublevel, item.seq = nil, nil, nil, nil, nil
	end

	animationClock = nil
	ownAlphaCache, drawMaps = {}, {}
	local physical = { width = width, height = height }
	return {
		screen = { width = round4(worldWidth * k), height = SCREEN_UNITS, physical = physical, pixelsPerUnit = round4(height / SCREEN_UNITS) },
		items = items,
		log = log,
		skipped = skipped,
		time = now,
	}
end

-- Font(env, region) -> path, size, flags for a font string, from its own font, its font object or its template,
-- as the page draws it. Scenes use it to pitch stand-in lines by the font the addon set.
function Scene.Font(env, region)
	local path, size, flags = fontOf(env, region, function() end)
	return path, size, flags
end

-- RectSolver(env) -> a solver on the owner's screen and UIParent that RectIn resolves objects with. It caches
-- each rect it resolves, so a caller that reads many rects between layout changes (the stubs' GetLeft and
-- friends) makes one and keeps it until an anchor, size, scale or text changes.
function Scene.RectSolver(env)
	local solver = newSolver(env, {}, function() end)
	solver.natural = true
	local width, height = env.GetPhysicalScreenSize()
	local uiParent = env.UIParent
	local parentScale = type(uiParent._scale) == "number" and uiParent._scale or 1
	solver.screen = { 0, 0, UI_HEIGHT * width / height, UI_HEIGHT }
	solver.rects[uiParent] = { 0, 0, uiParent._width * parentScale, uiParent._height * parentScale }
	return solver
end

-- RectIn(solver, object) -> x, y, width, height in screen units, or nil when the anchors do not resolve.
function Scene.RectIn(solver, object)
	local rect = solver:rect(object)
	if not rect then
		return nil
	end
	local k = SCREEN_UNITS / UI_HEIGHT
	return rect[1] * k, (UI_HEIGHT - rect[4]) * k, (rect[3] - rect[1]) * k, (rect[4] - rect[2]) * k
end

-- Rect(env, object) -> x, y, width, height in screen units for one frame or region, or nil when its anchors
-- do not resolve. Scenes use it to size stand-ins the way the game would.
function Scene.Rect(env, object)
	return Scene.RectIn(Scene.RectSolver(env), object)
end

-- Merge(scenes) -> one scene whose items are every scene's items in order, for modules drawn in separate environments,
-- with their animation clock (time) when every scene shares one.
-- Merge(scenes, ordered) -> one scene drawing every scene's items in turn; with ordered, the items sort across
-- scenes by strata, frame level, draw layer and sublevel as the client stacks them, scene order breaking ties.
function Scene.Merge(scenes, ordered)
	local out = { screen = scenes[1].screen, items = {}, log = {}, skipped = { hidden = 0, transparent = 0, unresolved = 0, clipped = 0 }, time = scenes[1].time }
	local turn, stack = {}, {}
	for _, scene in ipairs(scenes) do
		if scene.time ~= out.time then
			out.time = nil
		end
		local last = { 0, 0, 0, 0 }
		for _, item in ipairs(scene.items) do
			out.items[#out.items + 1] = item
			turn[item] = #out.items
			last = DRAW[item] or last
			stack[item] = last
		end
		for _, line in ipairs(scene.log) do
			out.log[#out.log + 1] = line
		end
		for key, n in pairs(scene.skipped) do
			out.skipped[key] = (out.skipped[key] or 0) + n
		end
	end
	if ordered then
		table.sort(out.items, function(a, b)
			local x, y = stack[a], stack[b]
			for i = 1, 4 do
				if x[i] ~= y[i] then
					return x[i] < y[i]
				end
			end
			return turn[a] < turn[b]
		end)
	end
	return out
end

-- JSON --------------------------------------------------------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end

local function encodeNumber(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "null"
	end
	if n == floor(n) and abs(n) < 1e15 then
		return string.format("%d", n)
	end
	local s = string.format("%.6f", n):gsub("0+$", ""):gsub("%.$", "")
	if tonumber(s) ~= n then s = string.format("%.17g", n) end
	return s
end

local encode

local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		n = n + 1
	end
	return n == #t
end

function encode(value, out, skip)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = encodeString(value)
	elseif kind == "number" then
		out[#out + 1] = encodeNumber(value)
	elseif kind == "boolean" then
		out[#out + 1] = value and "true" or "false"
	elseif kind == "nil" then
		out[#out + 1] = "null"
	elseif kind == "table" then
		if isArray(value) then
			out[#out + 1] = "["
			for i = 1, #value do
				if i > 1 then
					out[#out + 1] = ","
				end
				encode(value[i], out, skip)
			end
			out[#out + 1] = "]"
		else
			local keys = {}
			for k in pairs(value) do
				if type(k) == "string" and not skip[k] then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys)
			out[#out + 1] = "{"
			for i, k in ipairs(keys) do
				if i > 1 then
					out[#out + 1] = ","
				end
				out[#out + 1] = encodeString(k) .. ":"
				encode(value[k], out, skip)
			end
			out[#out + 1] = "}"
		end
	else
		out[#out + 1] = encodeString(tostring(value))
	end
end

-- ToJSON(scene) -> the scene as JSON, without the stub objects.
function Scene.ToJSON(scene)
	local out = {}
	encode(scene, out, { object = true })
	return table.concat(out)
end

return Scene
