-- test-options-gallery-rows.lua: the options gallery snapshots scrolling lists between rows so no text is cut in half.
rawset(_G, "RENDER_SCENE_LIB", true)
local build = dofile("Tools/render/scenes/gallery_options.lua")
local scene = build()
local Guard = dofile("Tools/render/guard.lua")
local count = 0
local failures = {}
for _, item in ipairs(scene.items) do
	if item.kind == "text" and item.scroll and item.clip then
		local whole = {}
		for key, value in pairs(item) do whole[key] = value end
		whole.clip = nil
		local r, c = Guard.Ink(whole), item.clip
		if r[2] < c[2] - 0.01 or r[2] + r[4] > c[2] + c[4] + 0.01 then
			failures[#failures + 1] = string.format("snapshot complete options rows: text %s at %.2f..%.2f is cut by %.2f..%.2f", item.text, r[2], r[2] + r[4], c[2], c[2] + c[4])
		end
		count = count + 1
	end
end
assert(#failures == 0, table.concat(failures, "\n"))
assert(count >= 6, "the gallery exercises sliders in its scrolling options lists")
rawset(_G, "RENDER_SCENE_LIB", nil)
print("options gallery rows ok")
