-- _gallery.lua: what the gallery scenes share. A gallery scene builds one area's frames in a representative state
-- and lists each frame it wants cropped out of the render in scene.frames, which Tools/render/gallery.py reads:
--
--   local Gallery = dofile("Tools/render/scenes/_gallery.lua")
--   local frames = Gallery.Frames()
--   frames:Add(env, panel, { name = "options_window", title = "Options window", grade = "window", reference = "chat",
--                            caption = "...", match = "..." })
--   return frames:Finish(Gallery.Build(env), env, K, "gallery options")
--
-- Each entry becomes final/frames/kstyle_<name>.png, compared in the manifest against the mockup crop the
-- grade names (Gallery.REFERENCES): window and panel frames against the mockup's glass panels, button frames
-- against its action buttons, bar frames against its buff bars.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local Gallery = { Common = Common }

Gallery.GRADES = { panel = true, window = true, button = true, bar = true }

-- The mockup crops a frame may name as its reference, each a grade the theme spec measured. gallery.py cuts
-- them out of the mockup (REFERENCE_BOXES, mockup pixels) at the render's density.
Gallery.REFERENCES = {
	chat = "window", tracker = "window", player = "panel", target = "panel", cast = "bar", buffbars = "bar",
	actionbars = "button", cluster = "button", datastrip = "button", minimap = "panel", nameplate = "panel",
	bufficons = "button", xp = "bar",
}

local DEFAULT_PAD = 14

-- Every gallery scene renders as a player with the icon pack installed sees it: Build passes Common.IconDirs()
-- to Scene.Build, so a numeric file ID draws set B's repaint when the pack has it, else Blizzard's icon.

-- Saved(modules, extra) -> saved data that turns each named module on and marks the first-run setup seen.
-- modules is a list of names, or a table of name -> section fields merged over { enabled = true }.
function Gallery.Saved(modules, extra)
	local profile = {}
	for key, value in pairs(modules or {}) do
		local name, fields = key, value
		if type(key) == "number" then
			name, fields = value, {}
		end
		local section = { enabled = true }
		for k, v in pairs(fields) do
			section[k] = v
		end
		profile[name] = section
	end
	local saved = { version = 2, profiles = { Default = profile }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	for k, v in pairs(extra or {}) do
		saved[k] = v
	end
	return saved
end

-- Setup(env) gives an environment the owner's screen and the warrior's class colour; pass it as a loader's setup
-- hook, or call it from one.
function Gallery.Setup(env)
	Common.ForceScreen(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
	env.UnitClass = function(unit)
		if unit == "player" or unit == nil then
			return "Warrior", "WARRIOR", 1
		end
		return "Warrior", "WARRIOR", 1
	end
end

-- Build(env, opts) -> Scene.Build with the icon folders, unless opts names its own.
function Gallery.Build(env, opts)
	opts = opts or {}
	if opts.iconDirs == nil then
		opts.iconDirs = Common.IconDirs()
	end
	return Scene.Build(env, opts)
end

local Frames = {}
Frames.__index = Frames

function Gallery.Frames()
	return setmetatable({ list = {}, names = {}, pending = {} }, Frames)
end

local function check(spec)
	assert(type(spec.name) == "string" and spec.name:match("^[%l%d_]+$"), "a frame name is lower-case letters, digits and underscores: " .. tostring(spec.name))
	assert(type(spec.title) == "string" and spec.title ~= "", spec.name .. ": a title")
	assert(type(spec.caption) == "string" and spec.caption ~= "", spec.name .. ": a caption")
	assert(Gallery.GRADES[spec.grade], spec.name .. ": grade must be panel, window, button or bar, got " .. tostring(spec.grade))
	assert(Gallery.REFERENCES[spec.reference], spec.name .. ": reference must name a mockup crop, got " .. tostring(spec.reference))
	assert(type(spec.match) == "string" and spec.match ~= "", spec.name .. ": a match note")
end

-- Add(env, frame, spec) records a frame to crop. spec: name, title, caption, grade, reference, match, and pad
-- (screen units around the frame, default 14). The rect is read when Finish runs, after the scene settles,
-- or from spec.rect ({ x = , y = , w = , h = } in screen units, as Gallery.Union returns) for a frame the scene lays out itself.
function Frames:Add(env, frame, spec)
	check(spec)
	assert(not self.names[spec.name], "two frames named " .. spec.name)
	self.names[spec.name] = true
	self.pending[#self.pending + 1] = { env = env, frame = frame, spec = spec }
end

-- Union(env, frames) -> { x, y, w, h } around every frame in the list, or nil when none resolves.
function Gallery.Union(env, frames)
	local x0, y0, x1, y1
	for _, frame in ipairs(frames) do
		local x, y, w, h = Scene.Rect(env, frame)
		if x then
			x0 = x0 and math.min(x0, x) or x
			y0 = y0 and math.min(y0, y) or y
			x1 = x1 and math.max(x1, x + w) or (x + w)
			y1 = y1 and math.max(y1, y + h) or (y + h)
		end
	end
	if not x0 then
		return nil
	end
	return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

-- Finish(scene, env, K, what) resolves every pending frame onto scene.frames, prefixes the log with `what`,
-- and records the first error the environment caught, so test-render-scenes fails on it.
function Frames:Finish(scene, env, K, what)
	scene.frames = scene.frames or {}
	for _, entry in ipairs(self.pending) do
		local spec = entry.spec
		local rect = spec.rect
		if not rect then
			local x, y, w, h = Scene.Rect(entry.env, entry.frame)
			if x then
				rect = { x = x, y = y, w = w, h = h }
			end
		end
		if rect then
			scene.frames[#scene.frames + 1] = {
				name = spec.name, title = spec.title, caption = spec.caption, grade = spec.grade,
				reference = spec.reference, match = spec.match, pad = spec.pad or DEFAULT_PAD,
				rect = { rect.x, rect.y, rect.w, rect.h },
			}
		else
			scene.log[#scene.log + 1] = "error: the frame " .. spec.name .. " has no rect"
		end
	end
	self.pending = {}
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	if what then
		for i, line in ipairs(scene.log) do
			scene.log[i] = what .. ": " .. line
		end
	end
	return scene
end

-- Ticks(W, env, n) steps every OnUpdate n times at 50 ms, so hover tweens and fades settle mid-way or at the end.
function Gallery.Ticks(W, env, n)
	for _ = 1, n or 30 do
		W.Tick(env, 0.05)
	end
end

return Gallery
