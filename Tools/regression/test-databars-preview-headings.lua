-- test-databars-preview-headings.lua: in the Data Bars settings preview each bar's heading sits clear of the bar's own caption, in English, German and French.
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(_G, "RENDER_SCREEN", { width = 1920, height = 1080, uiScale = 768 / 1080 })
local function Cross(a, b)
	return math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1]) > 0.5 and math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2]) > 0.5
end
for _, locale in ipairs({ "enUS", "deDE", "frFR" }) do
	rawset(_G, "RENDER_LOCALE", locale)
	local scene = dofile("Tools/render/scenes/gallery_databars.lua")()
	local texts = {}
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.text ~= "" then texts[#texts + 1] = item end
	end
	for i = 1, #texts do
		for j = i + 1, #texts do
			assert(not Cross(texts[i].rect, texts[j].rect), locale .. ": " .. texts[i].text .. " crosses " .. texts[j].text)
		end
	end
	collectgarbage("collect")
end
print("databars preview headings ok")
