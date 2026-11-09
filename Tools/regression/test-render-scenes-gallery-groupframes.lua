-- test-render-scenes-gallery-groupframes.lua: the group frames gallery scene (a 40-player raid and a party, the
-- heaviest scene, about 1.7 GB of heap under Lua 5.1) builds and lists its frames for gallery.py; split from
-- test-render-scenes-gallery.lua so each file stays well under its memory budget.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check

local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local name = "gallery_groupframes"
local build = dofile("Tools/render/scenes/" .. name .. ".lua")
assert(type(build) == "function", name .. ".lua returns its builder")
local scene = L.guard(name, check(name, build()))
assert(type(scene.frames) == "table" and #scene.frames > 0, name .. " lists the frames to crop")
local seenNames = {}
for _, frame in ipairs(scene.frames) do
	assert(not seenNames[frame.name], name .. ": two frames named " .. tostring(frame.name))
	seenNames[frame.name] = true
	assert(Gallery.GRADES[frame.grade], name .. ": " .. frame.name .. " names a grade")
	assert(Gallery.REFERENCES[frame.reference], name .. ": " .. frame.name .. " names a mockup crop")
	assert(type(frame.caption) == "string" and type(frame.match) == "string" and type(frame.title) == "string", name .. ": " .. frame.name .. " has its texts")
	local r = frame.rect
	assert(r[3] > 0 and r[4] > 0, name .. ": " .. frame.name .. " has a size")
	assert(r[1] >= -1 and r[2] >= -1 and r[1] + r[3] <= scene.screen.width + 1 and r[2] + r[4] <= scene.screen.height + 1, name .. ": " .. frame.name .. " sits on the screen")
end
L.globs({ partial = true })

print("ok")
