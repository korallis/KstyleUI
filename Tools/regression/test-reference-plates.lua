-- test-reference-plates.lua: the Healer reference scene seats a fixture nameplate off the party card when the
-- picture's point would spill past that card, and leaves the owner's 3456 by 2234 occlusion where it is.
local Reference = dofile("Tools/render/scenes/_reference.lua")
local Guard = dofile("Tools/render/guard.lua")

local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local picture = {}
for i, plate in ipairs(Reference.STATE.plates) do
	picture[i] = plate.x
end

local function widthOf(screen)
	return screen[1] * 1080 / screen[2]
end

for _, screen in ipairs(screens) do
	local seated = Reference.SeatPlates(Reference.STATE.plates, widthOf(screen))
	local kept = screen[1] == 3456 or screen[1] == 2383 or screen[1] == 5120
	for i, plate in ipairs(seated) do
		if kept then
			assert(plate.x == picture[i], screen[1] .. " moves plate " .. i .. " off the picture")
		end
	end
	if screen[1] == 1920 then
		assert(seated[1].x < picture[1], "1080p leaves the spilling plate on the party card")
	end
end

local function guard(screen)
	local saved = Reference.SCREEN
	Reference.SCREEN = { width = screen[1], height = screen[2], uiScale = 768 / 1080 }
	local scene = Reference.Build({ layout = "Healer" })
	Reference.SCREEN = saved
	local fresh = Guard.Sort(Guard.Check(scene), Guard.LoadAllow(), "hud_reference")
	collectgarbage("collect")
	local detail = fresh[1] and (fresh[1].subject or "") .. " " .. (fresh[1].detail or "") or ""
	assert(#fresh == 0, screen[1] .. "x" .. screen[2] .. " Healer fails the render guard: " .. detail)
end

guard({ 3440, 1440 })

print("reference plates ok")
