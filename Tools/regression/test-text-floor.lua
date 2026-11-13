-- test-text-floor.lua: no KstyleUI text in the HUD under 11 px at 1080 lines (bible 3.6, KSTY-60 item 2), in both HUD styles, at 1920x1080 and on Lee's 5120x1440; text fitted inside a small icon or a dense group lane (Widgets.Fitted) keeps its own size.
rawset(_G, "RENDER_SCENE_LIB", true)

local FLOOR = 11

for _, case in ipairs({ { 1920, 1080, "Frames" }, { 1920, 1080, "Orbs" }, { 5120, 1440, "Orbs" } }) do
	local width, height, style = case[1], case[2], case[3]
	local label = width .. "x" .. height .. " " .. style
	rawset(_G, "RENDER_HUD_STYLE", style)
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	Reference.SCREEN = { width = width, height = height, uiScale = 768 / 1080, size = "auto" }
	local scene = Reference.Build({ layout = "DPS" })
	rawset(_G, "RENDER_HUD_STYLE", nil)
	local texts = 0
	for _, item in ipairs(scene.items) do
		local file = item.kind == "text" and item.font and tostring(item.font.file) or ""
		local K = item.object and item.object._env and item.object._env.KstyleUI
		if file:find("^Media/") and not (K and K.Widgets.IsFitted(item.object)) then
			texts = texts + 1
			assert(item.font.size * height / 1080 >= math.floor(FLOOR * height / 1080 + 0.5) - 0.01, string.format("%s: '%s' is %.2f px, under the %d px floor scaled to %d lines", label, tostring(item.text), item.font.size * height / 1080, FLOOR, height))
		end
	end
	assert(texts > 80, label .. ": the HUD draws its texts, got " .. texts)
	collectgarbage("collect")
end

print("text floor ok")
