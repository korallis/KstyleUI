-- test-unitframes-medallions-plaque.lua: under Medallions every medallion's level number stands at or over the HUD's 9-unit text floor (units of the 1080-line reference, ceil'd to whole pixels) at every CREW screen and on its plaque, which grows to hold it; Lee's warlock's imp is the smallest medallion (LEE-1539: 5 px at 1280x720, 6 px at 1600x900).
local U = dofile("Tools/regression/unitframes_env.lua")

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1600, 900 }, { 1920, 1080 }, { 2383, 1540 }, { 2560, 1080 }, { 2560, 1440 },
	{ 3456, 2234 }, { 3440, 1440 }, { 3840, 1080 }, { 3840, 2160 }, { 5120, 1440 },
}
local FLOOR, REFERENCE, UI_HEIGHT = 9, 1080, 768
local KINDS = { "pet", "player", "target", "focus" }

local checked = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local what = width .. "x" .. height
	local env, K, ns = U.New({
		width = width, height = height, uiScale = UI_HEIGHT / REFERENCE, size = "auto", fit = true,
		setup = function(e)
			e.GetPhysicalScreenSize = function()
				return width, height
			end
		end,
	})
	local player = env._units.player
	player.class, player.race, player.sex, player.level = "WARLOCK", "Scourge", 2, 38
	U.SetUnit(env, "target", { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, reaction = 2, canAttack = true, creature = "Beast" })
	U.SetUnit(env, "focus", { name = "Mirefin Oracle", level = 39, health = 980, healthMax = 1210, reaction = 2 })
	U.SetUnit(env, "pet", { name = "Zabnik", level = 38, health = 920, healthMax = 1500, reaction = 5 })
	env.SetTarget(true)
	K.Options.Write("HudStyle", "style", "medallions")
	env.RunTimers()
	local least = math.ceil(FLOOR * height / REFERENCE - 1e-6)
	for _, kind in ipairs(KINDS) do
		local view = ns.Frames.Get(kind).views[1]
		for _, key in ipairs({ "healthText", "powerText" }) do
			local font = view[key]:GetFont()
			assert(font:match("BarlowSemiCondensedTabular%-SemiBold.ttf$"), what .. ": " .. kind .. " " .. key .. " must use Barlow's number role, got " .. font)
		end
		local m = view.medallion
		assert(m and m:IsShown() and m.plaque:IsShown(), what .. ": the " .. kind .. " medallion shows its plaque")
		assert(U.Shown(env, m.levelText) == tostring(env._units[kind].level), what .. ": the " .. kind .. " plaque shows its level")
		local _, size = m.levelText:GetFont()
		local pixels = size * m.levelText:GetEffectiveScale() * height / UI_HEIGHT
		assert(pixels >= least - 1e-6, string.format("%s: the %s's level number is %.2f px, under the %d-unit floor's %d px", what, kind, pixels, FLOOR, least))
		local px = K.Widgets.Border(m)
		assert(size <= m.plaque:GetWidth() * 0.6 + px / 2 + 1e-6, string.format("%s: the %s's level number (%.2f units) outgrows its %.2f-unit plaque", what, kind, size, m.plaque:GetWidth()))
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
	checked = checked + 1
end
print("ok unitframes medallions plaque: " .. checked .. " screens")
