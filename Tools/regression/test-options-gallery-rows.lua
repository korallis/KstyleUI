-- test-options-gallery-rows.lua: the options gallery retains the tooltip slider in its normal scrolling lists.
rawset(_G, "RENDER_SCENE_LIB", true)
local scene = dofile("Tools/render/scenes/gallery_options.lua")()
local Scene = dofile("Tools/render/scene.lua")
local texts = {}
for _, item in ipairs(scene.items) do
	if item.kind == "text" then texts[Scene.PlainText(item.text)] = true end
end
assert(texts["Tooltip size"] and texts["0.75"] and texts["1.50"], "keep the tooltip size slider and its endpoints visible in the gallery")
rawset(_G, "RENDER_SCENE_LIB", nil)
print("options gallery rows ok")
