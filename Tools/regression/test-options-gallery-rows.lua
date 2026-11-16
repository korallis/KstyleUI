-- test-options-gallery-rows.lua: the options gallery snapshots scrolling lists between rows so no slider value is cut in half.
rawset(_G, "RENDER_SCENE_LIB", true)
local build = dofile("Tools/render/scenes/gallery_options.lua")
local scene = build()
local count = 0
for _, item in ipairs(scene.items) do
	if item.kind == "text" and item.scroll and item.clip and item.text:match("^%-?%d+%.?%d*$") then
		local r, c = item.rect, item.clip
		assert(r[2] >= c[2] - 0.01 and r[2] + r[4] <= c[2] + c[4] + 0.01, "snapshot complete options rows: slider value " .. item.text .. " is cut by the scrolling list")
		count = count + 1
	end
end
assert(count >= 6, "the gallery exercises sliders in its scrolling options lists")
rawset(_G, "RENDER_SCENE_LIB", nil)
print("options gallery rows ok")
