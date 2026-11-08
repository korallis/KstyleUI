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

local function effectiveScale(object)
	local scale = type(object._scale) == "number" and object._scale or 1
	local parent = object._parent
	while parent do
		scale = scale * (type(parent._scale) == "number" and parent._scale or 1)
		parent = parent._parent
	end
	return scale
end

local function effectiveAlpha(object)
	local alpha = 1
	local node = object
	while node do
		local own = node._state.Alpha
		alpha = alpha * (own and type(own[1]) == "number" and own[1] or 1)
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
	if (not width or width == 0) and object._naturalW then
		width = object._naturalW
	end
	if (not height or height == 0) and object._naturalH then
		height = object._naturalH
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
		if object._rect then
			local l, b, w, h = unpack(object._rect, 1, 4)
			return { l, b, l + w, b + h }
		end
		return nil, "no anchors"
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
	local left, right = self:span(xs, width)
	local bottom, top = self:span(ys, height)
	if not left then
		return nil, "width unknown"
	end
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
	local skipped = { hidden = 0, transparent = 0, unresolved = 0 }

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

	local function textureItem(region, frame, alpha)
		local item = { kind = "texture", alpha = round4(alpha) }
		local path, wrapH, wrapV = state(region, "Texture")
		if path ~= nil then
			local resolved = resolve(path)
			if resolved then
				item.file = resolved
			else
				logLine("no local file for texture " .. tostring(path))
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
			logLine("atlas " .. tostring(atlas) .. " is drawn as a grey box")
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
		if coords and coords.n >= 4 then
			local list = {}
			for i = 1, coords.n do
				list[i] = round4(num(env, coords[i], 0))
			end
			item.texCoord = list
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
		if state(frame, "HideCountdownNumbers") ~= true then
			item.countdown = left >= 60 and string.format("%dm", floor(left / 60 + 0.5)) or string.format("%d", floor(left + 0.5))
			local fontPath, size = DEFAULT_FONT[1], 12
			item.font = { file = resolve(fontPath), path = fontPath, size = round4(size * effectiveScale(frame) * k), flags = "OUTLINE" }
		end
		item.mark = frame._renderMark
		return item
	end

	local visited = {}
	local kidsOf, regionsOf = {}, {}

	local function walkFrame(frame, inheritedHidden)
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
					if item and mark(region, item) then
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
			walkFrame(kid, false)
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

	-- A status bar's fill texture is the stub's _barTexture, which it lists among the bar's regions. A font
	-- string with no width or height of its own takes its natural size from its text, approximately.
	for _, frame in ipairs(env._frames) do
		if frame._barTexture then
			frame._barTexture._barOwner = frame
		end
		for _, region in ipairs(frame._regions or {}) do
			if region._type == "FontString" then
				region._naturalW, region._naturalH, region._naturalSideW, region._naturalSideH = nil, nil, nil, nil
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
						region._naturalH = size * LINE_HEIGHT_EM
						region._naturalSideH = ys[1] and "top" or ys[0.5] and "middle" or "bottom"
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

	local physical = { width = width, height = height }
	return {
		screen = { width = round4(worldWidth * k), height = SCREEN_UNITS, physical = physical, pixelsPerUnit = round4(height / SCREEN_UNITS) },
		items = items,
		log = log,
		skipped = skipped,
	}
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
	local out = { screen = scenes[1].screen, items = {}, log = {}, skipped = { hidden = 0, transparent = 0, unresolved = 0 } }
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
