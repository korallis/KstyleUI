-- test-render-scenes-gallery-skins.lua: every skinned window's gallery scene (gallery_skins_*.lua, one per window
-- Tools/regression/skins_windows.lua stands in) builds, lists one frame named skins_<window> with its skins applied,
-- and draws the window-grade glass; split from test-render-scenes-gallery.lua so each file stays well under its
-- memory budget.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check

local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Skins = dofile("Tools/render/scenes/_skins.lua")
local galleryScenes = L.galleryScenes(function(name)
	return name:match("^gallery_skins_") ~= nil
end)
assert(#galleryScenes == #Skins.Windows.LIST, "one skins scene per stand-in window: " .. #galleryScenes .. " vs " .. #Skins.Windows.LIST)
local galleryItems, galleryNames = {}, {}
for _, name in ipairs(galleryScenes) do
	local build = dofile("Tools/render/scenes/" .. name .. ".lua")
	assert(type(build) == "function", name .. ".lua returns its builder")
	local scene = L.guard(name, check(name, build()))
	assert(type(scene.frames) == "table" and #scene.frames > 0, name .. " lists the frames to crop")
	for _, frame in ipairs(scene.frames) do
		assert(Gallery.GRADES[frame.grade], name .. ": " .. frame.name .. " names a grade")
		assert(Gallery.REFERENCES[frame.reference], name .. ": " .. frame.name .. " names a mockup crop")
		assert(type(frame.caption) == "string" and type(frame.match) == "string" and type(frame.title) == "string", name .. ": " .. frame.name .. " has its texts")
		local r = frame.rect
		assert(r[3] > 0 and r[4] > 0, name .. ": " .. frame.name .. " has a size")
		assert(r[1] >= -1 and r[2] >= -1 and r[1] + r[3] <= scene.screen.width + 1 and r[2] + r[4] <= scene.screen.height + 1, name .. ": " .. frame.name .. " sits on the screen")
	end
	galleryItems[name] = scene.items
	galleryNames[name] = scene.frames[1].name
end
L.globs({ partial = true })

-- Each window Tools/regression/skins_windows.lua stands in is one gallery_skins_<window>.lua scene. Each lists one
-- frame named skins_<window>, its skins applied (the scene logs an error line otherwise, which check fails on), and
-- draws the window-grade glass, or the loot rolls' panel grade.
for _, spec in ipairs(Skins.Windows.LIST) do
	local name = "gallery_skins_" .. spec.key
	local items = assert(galleryItems[name], name .. " is one of the gallery scenes")
	assert(Skins.WINDOWS[spec.key], spec.key .. " has a gallery entry")
	local grade = spec.key == "lootrolls" and "LumenFrost" or "LumenGilt"
	local drawn = false
	for _, item in ipairs(items) do
		if item.kind == "texture" and item.file and item.file:find(grade, 1, true) then
			drawn = true
		end
	end
	assert(drawn, spec.key .. " draws its " .. grade .. " glass")
	assert(galleryNames[name] == "skins_" .. spec.key, name .. " lists its window as skins_<window>")
end

print("ok")
