-- test-render-layout-hud.lua: real Medallions modules and their Layout Mode tags clear each other at the video's size.
rawset(_G, "RENDER_SCENE_LIB", true)
rawset(_G, "RENDER_SCREEN", { width = 5120, height = 1440, size = "auto", uiScale = 768 / 1080 })
local scene = dofile("Tools/render/scenes/layout_hud.lua")()
local Guard = dofile("Tools/render/guard.lua")
local findings = Guard.Check(scene)
assert(#findings == 0, table.concat(Guard.Lines(findings, {}, {}, "default"), "\n"))
local function Overlap(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end
local function Rect(key) return assert(scene.movers[key], "draw the " .. key .. " mover").rect end
assert(not Overlap(Rect("cooldowns.essential"), Rect("cooldowns.utility")), "the current cooldown reserves must stand apart")
assert(not Overlap(Rect("databars.xp"), Rect("actionbars.bar1")), "the experience track must clear the action slots")
assert(not Overlap(scene.toolbar, Rect("integrations.announcementLane")), "the toolbar must clear boss announcements")
local shown = {}
for _, item in ipairs(scene.items) do
	if item.kind == "text" then shown[item.text] = true end
end
for _, name in ipairs({ "ESSENTIAL COOLDOWNS", "UTILITY COOLDOWNS", "EXPERIENCE BAR", "CHAT", "BOSS ANNOUNCEMENTS" }) do
	assert(shown[name], "keep the " .. name .. " label visible")
end
for _, art in ipairs(scene.items) do
	if art.file == "Media/Textures/Medallions/Ring256.png" then
		for _, item in ipairs(scene.items) do
			if item.kind == "text" and (item.text == "ACTION BAR 1" or item.text == "ACTION BAR 2" or item.text == "EXPERIENCE BAR") then
				assert(not Overlap(item.rect, art.rect), "keep mover labels clear of the plate-less Medallions crest")
			end
		end
	end
end
rawset(_G, "RENDER_SCREEN", nil)
print("layout HUD render ok: Medallions at 5120x1440, cooldown reserves, XP track, toolbar and all four video labels")
