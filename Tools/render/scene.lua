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
	"KstyleUI_IconsColour/Icons",
	"KstyleUI_Icons/Icons",
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
			if fileExists(rel) then
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

-- animationState(frame, now) -> dx, dy (in the frame's own units), alpha scale: what the frame's playing
-- animation groups apply at the clock. A Translation moves the frame by its offset times its progress, an Alpha
-- animation scales the alpha between its from and to values once its start delay has passed, and a finished
-- group leaves each animation at its end, as the game does until OnFinished hides the frame.
local function animationState(frame, now)
	local dx, dy, alpha = 0, 0, 1
	if type(now) ~= "number" then
		return dx, dy, alpha
	end
	for _, group in ipairs(frame._groups or {}) do
		local started = group._playedAt
		if type(started) == "number" then
			local elapsed = now - started
			local total = 0
			for _, anim in ipairs(group._anims or {}) do
				total = math.max(total, (state(anim, "StartDelay") or 0) + (state(anim, "Duration") or 0))
			end
			if state(group, "Looping") == "REPEAT" and total > 0 then
				elapsed = elapsed % total
			end
			for _, anim in ipairs(group._anims or {}) do
				local delay, duration = state(anim, "StartDelay") or 0, state(anim, "Duration") or 0
				local p = 0
				if elapsed >= delay then
					p = duration > 0 and math.min(1, (elapsed - delay) / duration) or 1
				end
				p = eased(p, state(anim, "Smoothing"))
				if anim._type == "Translation" then
					local ox, oy = state(anim, "Offset")
					dx = dx + (type(ox) == "number" and ox or 0) * p
					dy = dy + (type(oy) == "number" and oy or 0) * p
				elseif anim._type == "Alpha" and elapsed >= delay then
					local from, to = state(anim, "FromAlpha"), state(anim, "ToAlpha")
					from = type(from) == "number" and from or 1
					to = type(to) == "number" and to or 1
					alpha = alpha * (from + (to - from) * p)
				end
			end
		end
	end
	return dx, dy, alpha
end

-- ownAlpha(node) -> the alpha the node's last SetAlpha or SetAlphaFromBoolean gave it. SetAlphaFromBoolean picks
-- the on or off alpha from a boolean the addon may not read, so the secret is revealed here, as the engine would.
local function ownAlpha(node)
	local calls = node._calls
	for i = #(calls or {}), 1, -1 do
		local call = calls[i]
		if call.method == "SetAlpha" then
			break
		elseif call.method == "SetAlphaFromBoolean" then
			local value = reveal(node._env, call.args[1])
			if type(value) == "boolean" then
				local on, off = call.args[2], call.args[3]
				if value then
					return type(on) == "number" and on or 1
				end
				return type(off) == "number" and off or 0
			end
			break
		end
	end
	local own = node._state.Alpha
	return own and type(own[1]) == "number" and own[1] or 1
end

local function effectiveAlpha(object)
	local alpha = 1
	local node = object
	while node do
		alpha = alpha * ownAlpha(node)
		if node._groups then
			local _, _, scale = animationState(node, animationClock)
			alpha = alpha * scale
		end
		if node._ignoreParentAlpha then
			break
		end
		node = node._parent
	end
	return alpha
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
		if ch == "\226\128\137" then
			em = em + GLYPH_EM.thin
		elseif glyphs and size == 1 and glyphs[c] then
			em = em + glyphs[c]
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

-- WrappedLines(text, size, fontPath, width) -> how many lines a word-wrapping text takes in a width, by the
-- page's rule: words fill a line while they fit, a word that fits nowhere takes a line of its own, and an
-- explicit break starts a new line.
function Scene.WrappedLines(text, size, fontPath, width)
	local lines = 0
	for paragraph in (plainText(text) .. "\n"):gmatch("(.-)\n") do
		local line = nil
		for word in (paragraph .. " "):gmatch("(.-) ") do
			local candidate = line and (line .. " " .. word) or word
			if line and textWidthEm(candidate, fontPath) * size > width then
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
	local calls = region._calls or {}
	for i = #calls, 1, -1 do
		local call = calls[i]
		if call.method == "SetText" then
			return formatText(env, call.args)
		elseif call.method == "SetFormattedText" then
			call.args.format = true
			return formatText(env, call.args)
		end
	end
	local formatted = region._state.FormattedText
	if formatted then
		formatted.format = true
		return formatText(env, formatted)
	end
	return formatText(env, region._state.Text) or ""
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
	local scale = effectiveScale(object)
	local width = num(env, object._width)
	local height = num(env, object._height)
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
	if object._groups then
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
		height = wrap.size * LINE_HEIGHT_EM * lines * scale
		object._wrapped = true
	end
	local bottom, top = self:span(ys, height)
	if not bottom then
		return nil, "height unknown"
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
	local reverse = state(bar, "ReverseFill") == true
	local l, b, r, t = full[1], full[2], full[3], full[4]
	if orientation == "VERTICAL" then
		local h = (t - b) * fraction
		if reverse then
			return { l, t - h, r, t }
		end
		return { l, b, r, b + h }
	end
	local w = (r - l) * fraction
	if reverse then
		return { r - w, b, r, t }
	end
	return { l, b, l + w, t }
end

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

local function color4(stored, default)
	if not stored then
		return default
	end
	local r, g, b, a = stored[1], stored[2], stored[3], stored[4]
	if type(r) ~= "number" then
		return default
	end
	return { r, type(g) == "number" and g or r, type(b) == "number" and b or r, type(a) == "number" and a or 1 }
end

local function round4(v)
	return floor(v * 10000 + 0.5) / 10000
end

function Scene.Build(env, opts)
	opts = opts or {}
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
		item.rect = toScreen(rect)
		item.object = object
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
		if not region._masks or #region._masks == 0 then
			return nil
		end
		local out = {}
		for _, mask in ipairs(region._masks) do
			local rect = solver:rect(mask)
			if rect then
				local path = state(mask, "Texture")
				out[#out + 1] = { rect = toScreen(rect), file = resolve(path), path = type(path) == "string" and path or nil }
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
				item.pendingLog = "no local file for texture " .. tostring(path)
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
		local colour = color4(region._state.ColorTexture)
		if colour then
			item.color = colour
		end
		item.vertex = color4(region._state.VertexColor, { 1, 1, 1, 1 })
		if region._barOwner and region._barOwner._state.StatusBarColor then
			item.vertex = color4(region._barOwner._state.StatusBarColor, item.vertex)
		end
		local coords = region._state.TexCoord
		if coords and coords.n >= 4 and not item.texCoord then
			local list = {}
			for i = 1, coords.n do
				list[i] = round4(num(env, coords[i], 0))
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
			item.fraction = round4(Scene.BarFraction(env, region._barOwner, now))
			item.bar = true
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
		local scale = effectiveScale(region)
		local item = {
			kind = "text", alpha = round4(alpha), text = text,
			font = { file = resolve(path), path = path, size = round4(size * scale * k), flags = flags },
			color = color4(region._state.TextColor, colour and { colour[1], colour[2], colour[3], 1 } or { 1, 1, 1, 1 }),
			justifyH = state(region, "JustifyH") or "CENTER",
			justifyV = state(region, "JustifyV") or "MIDDLE",
		}
		if not item.font.file then
			logLine("no local font for " .. tostring(path) .. "; the page falls back to Source Sans")
		end
		local sx, sy = state(region, "ShadowOffset")
		if type(sx) == "number" and type(sy) == "number" and (sx ~= 0 or sy ~= 0) then
			item.shadow = { color = color4(region._state.ShadowColor, { 0, 0, 0, 1 }), offset = { round4(sx * scale * k), round4(-sy * scale * k) } }
		end
		if state(region, "WordWrap") == false then
			item.wordWrap = false
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
		if state(frame, "DrawSwipe") == false then
			return nil
		end
		local item = { kind = "swipe", alpha = round4(alpha), fraction = round4(fraction), remaining = round4(left) }
		item.reverse = state(frame, "Reverse") == true
		item.color = color4(frame._state.SwipeColor, { 0, 0, 0, 0.8 })
		local swipe = state(frame, "SwipeTexture")
		if swipe then
			item.file = resolve(swipe)
			item.path = swipe
		end
		if state(frame, "HideCountdownNumbers") ~= true and not frame._countdown then
			item.countdown = countdownText(left, frame)
			local fontPath, size = DEFAULT_FONT[1], 12
			item.font = { file = resolve(fontPath), path = fontPath, size = round4(size * effectiveScale(frame) * k), flags = "OUTLINE" }
		end
		item.mark = frame._renderMark
		return item
	end

	-- An edit box draws its own text, as the game does: inside its text insets, from the left, and from the top
	-- when it is multi-line. A box with no text draws nothing, so a placeholder font string shows through.
	local function editBoxItem(frame, rect, alpha)
		local item = textItem(frame, frame, alpha)
		if not item then
			return nil
		end
		local s = effectiveScale(frame) * k
		local l, r, t, b = state(frame, "TextInsets")
		l, r, t, b = (type(l) == "number" and l or 0) * s, (type(r) == "number" and r or 0) * s, (type(t) == "number" and t or 0) * s, (type(b) == "number" and b or 0) * s
		local screen = toScreen(rect)
		item.rect = { round4(screen[1] + l), round4(screen[2] + t), round4(screen[3] - l - r), round4(screen[4] - t - b) }
		item.justifyH = state(frame, "JustifyH") or "LEFT"
		item.justifyV = state(frame, "MultiLine") == true and "TOP" or "MIDDLE"
		item.object = frame
		return item
	end

	local visited = {}
	local kidsOf, regionsOf = {}, {}

	-- A frame that clips its children (SetClipsChildren) bounds everything drawn under it, as a scroll list's
	-- view does; clip is that bound in screen units, or nil. An item outside it is dropped, one across it is
	-- drawn through it by the page.
	local function clipped(item, clip)
		if not clip then
			return true
		end
		local r = item.rect
		if r[1] + r[3] <= clip[1] or r[1] >= clip[1] + clip[3] or r[2] + r[4] <= clip[2] or r[2] >= clip[2] + clip[4] then
			skipped.clipped = (skipped.clipped or 0) + 1
			return false
		end
		item.clip = clip
		return true
	end

	local function intersect(a, b)
		if not a then
			return b
		end
		local x0, y0 = math.max(a[1], b[1]), math.max(a[2], b[2])
		local x1, y1 = math.min(a[1] + a[3], b[1] + b[3]), math.min(a[2] + a[4], b[2] + b[4])
		return { x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0) }
	end

	local function walkFrame(frame, inheritedHidden, clip)
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
		if frame._type == "Cooldown" and rect and alpha > 0 then
			local item = swipeItem(frame, alpha)
			if item then
				item.rect = toScreen(rect)
				item.object = frame
			end
			if item and clipped(item, clip) then
				seq = seq + 1
				item.strata, item.level, item.layer, item.sublevel, item.seq = strata, level, LAYERS.ARTWORK, 0, seq
				items[#items + 1] = item
			end
		elseif frame._type == "EditBox" and rect and alpha > 0 then
			local item = editBoxItem(frame, rect, alpha)
			if item and clipped(item, clip) then
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
					if item and mark(region, item) and clipped(item, clip) then
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
		local kidClip = clip
		if rect and state(frame, "ClipsChildren") == true then
			kidClip = intersect(clip, toScreen(rect))
		end
		for _, kid in ipairs(kidsOf[frame] or {}) do
			walkFrame(kid, false, kidClip)
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
	for _, frame in ipairs(env._frames) do
		adopt(kidsOf, frame)
		for _, region in ipairs(frame._regions or {}) do
			adopt(regionsOf, region)
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
				region._naturalW, region._naturalH, region._naturalSideW, region._naturalSideH = nil, nil, nil, nil
				region._wrapSpec, region._wrapped = nil, nil
				local text = textOf(env, region)
				if text ~= "" then
					local fontPath, size = fontOf(env, region, logLine)
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
						region._naturalW = textWidthEm(text, fontPath) * size
						region._naturalSideW = xs[1] and "right" or xs[0.5] and "center" or "left"
					end
					if not hasH and not (ys[0] and ys[1]) then
						local _, breaks = text:gsub("\n", "")
						region._naturalH = size * LINE_HEIGHT_EM * (breaks + 1)
						region._naturalSideH = ys[1] and "top" or ys[0.5] and "middle" or "bottom"
						if state(region, "WordWrap") ~= false then
							region._wrapSpec = { text = text, size = size, fontPath = fontPath }
						end
					end
				end
			end
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
		item.strata, item.level, item.layer, item.sublevel, item.seq = nil, nil, nil, nil, nil
	end

	animationClock = nil
	local physical = { width = width, height = height }
	return {
		screen = { width = round4(worldWidth * k), height = SCREEN_UNITS, physical = physical, pixelsPerUnit = round4(height / SCREEN_UNITS) },
		items = items,
		log = log,
		skipped = skipped,
	}
end

-- Font(env, region) -> path, size, flags for a font string, from its own font, its font object or its template,
-- as the page draws it. Scenes use it to pitch stand-in lines by the font the addon set.
function Scene.Font(env, region)
	local path, size, flags = fontOf(env, region, function() end)
	return path, size, flags
end

-- Rect(env, object) -> x, y, width, height in screen units for one frame or region, or nil when its anchors
-- do not resolve. Scenes use it to size stand-ins the way the game would.
function Scene.Rect(env, object)
	local solver = newSolver(env, {}, function() end)
	local width, height = env.GetPhysicalScreenSize()
	local uiParent = env.UIParent
	local parentScale = type(uiParent._scale) == "number" and uiParent._scale or 1
	solver.screen = { 0, 0, UI_HEIGHT * width / height, UI_HEIGHT }
	solver.rects[uiParent] = { 0, 0, uiParent._width * parentScale, uiParent._height * parentScale }
	local rect = solver:rect(object)
	if not rect then
		return nil
	end
	local k = SCREEN_UNITS / UI_HEIGHT
	return rect[1] * k, (UI_HEIGHT - rect[4]) * k, (rect[3] - rect[1]) * k, (rect[4] - rect[2]) * k
end

-- Merge(scenes) -> one scene whose items are every scene's items in order, for modules drawn in separate environments.
function Scene.Merge(scenes)
	local out = { screen = scenes[1].screen, items = {}, log = {}, skipped = { hidden = 0, transparent = 0, unresolved = 0, clipped = 0 } }
	for _, scene in ipairs(scenes) do
		for _, item in ipairs(scene.items) do
			out.items[#out.items + 1] = item
		end
		for _, line in ipairs(scene.log) do
			out.log[#out.log + 1] = line
		end
		for key, n in pairs(scene.skipped) do
			out.skipped[key] = (out.skipped[key] or 0) + n
		end
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
