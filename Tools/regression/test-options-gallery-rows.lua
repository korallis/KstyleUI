-- test-options-gallery-rows.lua: the options gallery retains the HUD style pictures and the tooltip slider in its normal scrolling lists.
rawset(_G, "RENDER_SCENE_LIB", true)
local scene = dofile("Tools/render/scenes/gallery_options.lua")()
local Scene = dofile("Tools/render/scene.lua")
local pictures, texts = {}, {}
for _, item in ipairs(scene.items) do
	if item.kind == "texture" and item.file then pictures[item.file:match("([^/]+)$")] = true end
	if item.kind == "text" then texts[Scene.PlainText(item.text)] = true end
end
assert(pictures["HudStyleFrames.png"] and pictures["HudStyleOrbs.png"], "keep the HUD style picture row visible in the gallery")
assert(texts["Tooltip size"] and texts["0.75"] and texts["1.50"], "keep the tooltip size slider and its endpoints visible in the gallery")
rawset(_G, "RENDER_SCENE_LIB", nil)
print("options gallery rows ok")
