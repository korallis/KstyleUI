-- test-pixels.lua: KstyleUI_Root is 1080 units tall, and borders, lines and chamfer slices are whole physical pixels on every screen.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end

-- The spec's four screens, with the border each gets at a user scale of 1.
local SCREENS = {
	{ 1920, 1080, border = 1, perUnit = 1.00 },
	{ 2560, 1440, border = 1, perUnit = 1.33 },
	{ 3840, 2160, border = 2, perUnit = 2.00 },
	{ 3456, 2234, border = 2, perUnit = 2.07 },
}
-- UIParent effective scales: the UI Scale slider's ends, a fractional value, and PixelUtil's 768/1440.
local UI_SCALES = { 1, 0.65, 0.71, 1.15, 768 / 1440 }
local USER_SCALES = { 0.75, 1, 1.25, 1.5 }
local UI_HEIGHT = 768 -- the screen is 768 units tall at an effective scale of 1

local function NewScale(width, height, uiScale)
	local env = Stubs.NewEnv({ width = width, height = height, uiScale = uiScale })
	env._physical = { width, height }
	function env.GetPhysicalScreenSize()
		return env._physical[1], env._physical[2]
	end
	Load(core, env)
	local ns = env.KstyleUI
	local fired = {}
	local dispatch = ns.Callbacks.Fire
	ns.Callbacks.Fire = function(event, ...)
		fired[#fired + 1] = event
		if dispatch then
			dispatch(event, ...)
		end
	end
	return env, ns, fired
end

local function whole(x)
	return math.abs(x - math.floor(x + 0.5)) < 1e-6
end

local function count(fired, event)
	local n = 0
	for _, e in ipairs(fired) do
		if e == event then
			n = n + 1
		end
	end
	return n
end

-- Physical pixels per root unit, from the root's real effective scale.
local function perUnit(env, ns)
	return env._physical[2] * ns.Scale.Root():GetEffectiveScale() / UI_HEIGHT
end

local function label(screen, uiScale, user)
	return string.format("%dx%d, UI scale %.3f, size %.2f", screen[1], screen[2], uiScale, user or 1)
end

local SIZE_NAMES = {
	"chamferPanel", "chamferTile", "shadow", "actionButton", "actionGap", "cooldownEssential", "cooldownUtility",
	"unitFrameWidth", "unitFrameHeight", "portrait", "buffBarWidth", "buffBarHeight", "pressOffset", "panelRise",
	"gapTiny", "gapSmall", "gapMedium", "gapLarge", "gapHuge", "panelPadding", "rowHeight",
}
local SLICED = { "chamferPanel", "chamferTile", "bevelPanelOuter", "bevelPanelInner", "bevelTileOuter", "bevelTileInner", "shadow" }

-- Every screen, UI scale and size: the root is 1080 / size units tall, and every snapped value is
-- a whole number of physical pixels.
for _, screen in ipairs(SCREENS) do
	for _, uiScale in ipairs(UI_SCALES) do
		local env, ns = NewScale(screen[1], screen[2], uiScale)
		local Scale, Tokens = ns.Scale, ns.Tokens
		env.FireEvent("PLAYER_LOGIN")
		local root = Scale.Root()
		assert(root:GetName() == "KstyleUI_Root" and root:GetParent() == env.UIParent, "the root is KstyleUI_Root on UIParent")

		local ppu = perUnit(env, ns)
		local where = label(screen, uiScale)
		assert(math.abs(UI_HEIGHT / root:GetEffectiveScale() - 1080) < 1e-6, where .. ": the root is 1080 units tall")
		assert(math.abs(ppu - screen.perUnit) < 0.005, where .. ": " .. ppu .. " pixels per unit, the spec says " .. screen.perUnit)
		assert(math.abs(Scale.Pixel(1) * ppu - 1) < 1e-6, where .. ": Pixel(1) is one physical pixel")
		assert(math.abs(Scale.Border() * ppu - screen.border) < 1e-6, where .. ": the border is " .. Scale.Border() * ppu .. " px, the spec says " .. screen.border)

		for _, user in ipairs(USER_SCALES) do
			assert(Scale.SetUserScale(user) == true, "a size in range is accepted")
			where = label(screen, uiScale, user)
			ppu = perUnit(env, ns)
			assert(math.abs(UI_HEIGHT / root:GetEffectiveScale() - 1080 / user) < 1e-6, where .. ": the root is 1080 / size units tall")
			assert(math.abs(Scale.Pixel(1) * ppu - 1) < 1e-6, where .. ": Pixel(1) is one physical pixel")
			assert(whole(Scale.Pixel(3) * ppu), where .. ": Pixel(3) is whole pixels")
			local border = Scale.Border() * ppu
			assert(whole(border) and border > 1 - 1e-6, where .. ": the border is a whole number of pixels, got " .. border)
			assert(math.abs(border - math.max(1, math.floor(ppu + 0.5))) < 1e-6, where .. ": the border is about one unit")
			for _, name in ipairs(SIZE_NAMES) do
				local snapped = Scale.Snap(Tokens.Size(name))
				assert(whole(snapped * ppu), where .. ": Snap(" .. name .. ") is whole pixels")
				assert(math.abs(snapped - Tokens.Size(name)) <= Scale.Pixel(1) / 2 + 1e-9, where .. ": Snap(" .. name .. ") moves less than half a pixel")
			end
			for _, name in ipairs(SLICED) do
				local _, _, units = Tokens.Texture(name)
				assert(whole(Scale.Snap(units) * ppu), where .. ": the " .. name .. " corner piece is whole pixels")
			end
			for _, v in ipairs({ 0.1, 0.5, 7.3, -4.6, 333.333 }) do
				assert(whole(Scale.Snap(v) * ppu), where .. ": Snap(" .. v .. ") is whole pixels")
			end
		end
	end
end

-- The size slider runs from 0.75 to 1.5, and only accepts plain numbers.
do
	local env, ns, fired = NewScale(1920, 1080, 1)
	env.FireEvent("PLAYER_LOGIN")
	local Scale = ns.Scale
	assert(Scale.UserScale() == 1, "the default size is 1")
	assert(Scale.SetUserScale(2) == true and Scale.UserScale() == 1.5, "a size above 1.5 is clamped")
	assert(Scale.SetUserScale(0.5) == true and Scale.UserScale() == 0.75, "a size below 0.75 is clamped")
	local before = #fired
	for _, bad in ipairs({ "1", 0 / 0, env.Secret(1), nil }) do
		assert(Scale.SetUserScale(bad) == false, "an invalid size is refused")
	end
	assert(Scale.UserScale() == 0.75 and #fired == before, "a refused size changes nothing")
	assert(Scale.SetUserScale(0.75) == true and #fired == before, "the same size again fires nothing")
	assert(Scale.MIN_USER_SCALE == 0.75 and Scale.MAX_USER_SCALE == 1.5)
end

-- Review Focus 2: the game window moves to a monitor with another resolution.
do
	local env, ns, fired = NewScale(1920, 1080, 1)
	local Scale = ns.Scale
	env.FireEvent("PLAYER_LOGIN")
	local before = count(fired, "ScaleChanged")
	env._physical = { 3840, 2160 }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	assert(count(fired, "ScaleChanged") == before + 1, "a display change fires ScaleChanged once")
	local ppu = perUnit(env, ns)
	assert(math.abs(ppu - 2) < 1e-6 and math.abs(Scale.Border() * ppu - 2) < 1e-6, "on 4K the border becomes two whole pixels")
	assert(math.abs(Scale.Pixel(1) - 0.5) < 1e-9, "on 4K one pixel is half a unit")
	env.RunTimers()
	assert(count(fired, "ScaleChanged") == before + 1, "the next-frame recheck fires nothing when nothing moved")

	-- The UI scale changes: the root compensates and stays 1080 units tall.
	env.UIParent:SetScale(0.8)
	env.FireEvent("UI_SCALE_CHANGED")
	assert(math.abs(UI_HEIGHT / Scale.Root():GetEffectiveScale() - 1080) < 1e-6, "the root stays 1080 units tall after a UI scale change")
	assert(count(fired, "ScaleChanged") == before + 2, "a UI scale change fires ScaleChanged")

	-- The engine settles the UI scale a frame late: the recheck catches it.
	env.UIParent:SetScale(0.9)
	env.RunTimers()
	assert(math.abs(UI_HEIGHT / Scale.Root():GetEffectiveScale() - 1080) < 1e-6, "the recheck applies a late UI scale")
end

-- In combat the rescale waits for combat to end, because secure frames on the root make it protected.
do
	local env, ns, fired = NewScale(1920, 1080, 1)
	local Scale = ns.Scale
	env.FireEvent("PLAYER_LOGIN")
	local before = count(fired, "ScaleChanged")
	local rootScale = Scale.Root():GetScale()
	env.SetCombat(true)
	env._physical = { 2560, 1440 }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
	assert(Scale.Root():GetScale() == rootScale, "no SetScale on the root in combat")
	assert(Scale.SetUserScale(1.25) == true and Scale.Root():GetScale() == rootScale, "the size slider waits for combat too")
	assert(count(fired, "ScaleChanged") == before, "nothing fires while the rescale waits")
	env.SetCombat(false)
	assert(count(fired, "ScaleChanged") == before + 1, "leaving combat applies the rescale once")
	assert(math.abs(Scale.Pixel(1) * perUnit(env, ns) - 1) < 1e-6 and Scale.UserScale() == 1.25, "the waiting values apply")
	env.SetCombat(true)
	env.SetCombat(false)
	assert(count(fired, "ScaleChanged") == before + 1, "a later combat with nothing waiting fires nothing")
end

-- With the Combat service, the rescale goes through Combat.Queue, once.
do
	local env, ns, fired = NewScale(1920, 1080, 1)
	local queued = {}
	ns.Combat.Queue = function(fn)
		if env.InCombatLockdown() then
			queued[#queued + 1] = fn
		else
			fn()
		end
	end
	env.FireEvent("PLAYER_LOGIN")
	local before = count(fired, "ScaleChanged")
	env.SetCombat(true)
	env._physical = { 3840, 2160 }
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.FireEvent("UI_SCALE_CHANGED")
	assert(#queued == 1, "one queued rescale for many events, got " .. #queued)
	env.SetCombat(false)
	queued[1]()
	assert(count(fired, "ScaleChanged") == before + 1, "the queued rescale applies")
	assert(math.abs(ns.Scale.Pixel(1) - 0.5) < 1e-9, "the queued rescale reads the new screen")
end

-- A reload in combat: PLAYER_LOGIN is the one moment protected setup may run in combat.
do
	local env, ns = NewScale(3840, 2160, 0.71)
	env._combat = true
	env.FireEvent("PLAYER_LOGIN")
	assert(math.abs(UI_HEIGHT / ns.Scale.Root():GetEffectiveScale() - 1080) < 1e-6, "login scales the root even in combat")
end

-- A missing or secret screen size falls back to the 1080 reference without an error.
do
	local env, ns = NewScale(1920, 1080, 1)
	env._physical = { env.Secret(3840), env.Secret(2160) }
	env.FireEvent("PLAYER_LOGIN")
	assert(math.abs(ns.Scale.Pixel(1) - 1) < 1e-9, "a secret screen size falls back to 1080 lines")
	env._physical = {}
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	assert(math.abs(ns.Scale.Pixel(1) - 1) < 1e-9, "a missing screen size falls back to 1080 lines")
end

print("pixels ok")
