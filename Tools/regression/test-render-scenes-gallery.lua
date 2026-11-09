-- test-render-scenes-gallery.lua: every module gallery scene (gallery_*.lua, except the group frames scene and
-- the skinned windows, which test-render-scenes-gallery-groupframes.lua and test-render-scenes-gallery-skins.lua
-- build, so each file stays well under its memory budget) builds and lists its frames for gallery.py, and the
-- widget gallery draws and clips its edit boxes and scroll list.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check

-- The gallery scenes (gallery_*.lua): each lists the frames Tools/render/gallery.py crops out of its render, every
-- frame names one of the three grades and a mockup crop to compare it with, and each rect sits on the screen.
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local galleryScenes = L.galleryScenes(function(name)
	return name:match("^gallery_skins_") == nil and name ~= "gallery_groupframes"
end)
assert(#galleryScenes >= 1, "at least one gallery scene")
local galleryItems = {}
-- Only the widget checks below read a scene's items; keeping every scene's would hold most of the heap live, so
-- the collector could not reclaim the finished scenes and the test would peak over its 4096 MB.
local function keepsItems(name)
	return name == "gallery_widgets"
end
for _, name in ipairs(galleryScenes) do
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
	if keepsItems(name) then
		galleryItems[name] = scene.items
	end
end
L.globs({ partial = true })

-- The widget gallery: the renderer draws an edit box's own text and a text area's log (an edit box inside a scroll
-- frame, hung from the frame's corner), and clips a scroll list's rows to its view, so a row scrolled out of
-- sight is dropped and the rows in view carry the view as their clip.
do
	local widgetTexts, clips, inView = {}, {}, 0
	for _, item in ipairs(assert(galleryItems.gallery_widgets, "the widget gallery scene exists")) do
		if item.kind == "text" then
			widgetTexts[item.text] = item
			if item.clip then
				clips[item.text] = item.clip
			end
		end
	end
	assert(widgetTexts["Valerin"] and widgetTexts["Valerin"].justifyH == "LEFT", "the focused edit box draws its text")
	local log = widgetTexts["[14:31] You receive loot: [Crocolisk Hide] x2\n[14:31] You gain 168 experience.\n[14:31] You receive loot: [Rugged Hide]\n[14:32] [1. General] Riverglades: Anyone for croc hunt?\n[14:32] [1. General] Thargor: LFM tank for Razorfen Kraul"]
	assert(log and log.justifyV == "TOP" and log.clip, "the text area draws its log from the top, clipped to its scroll frame")
	assert(clips["Unit frames"], "a scroll list row in view carries the view's clip")
	assert(not widgetTexts["Combat text"], "a row scrolled out of the view is dropped")
	for text, clip in pairs(clips) do
		if widgetTexts[text] and text ~= log.text then
			inView = inView + 1
			assert(clip[4] < 200, "the clip is the 190-unit view, not the screen: " .. text)
		end
	end
	assert(inView >= 5, "several rows draw inside the view")
end

print("ok")
