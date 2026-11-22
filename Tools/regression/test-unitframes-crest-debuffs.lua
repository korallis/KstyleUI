-- test-unitframes-crest-debuffs.lua: your target debuffs move into a bounded native-engine fan only under Medallions, including control effects and restricted combat updates.
local U = dofile("Tools/regression/unitframes_env.lua")
local Engine = dofile("Tools/regression/aura_fixture_engine.lua")
local Scene = dofile("Tools/render/scene.lua")
local env, K, ns = U.New({ before = function(_, core)
	core.Store.Module("UnitFrames").auraLayout = "fan"
end })
local view = ns.Frames.Get("target").views[1]
local fan = assert(view.auras.fan, "Medallions builds the crest fan")
assert(not fan.failed and #fan.containers == ns.Fan.MAX, "seven engine windows")
for rank, window in ipairs(fan.windows) do
	assert(U.W.LastCall(window, "SetClipsChildren")[1] == true, "native clipping must exclude hidden siblings from drawing and mouse hit testing")
	assert(fan.containers[rank]:GetParent() == window, "every rank container inherits its own window's clip")
end
assert(K.Layout.Element(ns.Fan.KEY).opts.scalable, "the fan has its own scalable Layout Mode element")
assert(ns.Settings.Value("target", "crestDebuffs"), "the fan defaults on")
K.Layout.Set(ns.Fan.KEY, "scale", 0.5)
local _, scaledFont = fan.buttons[1].timer:GetFont()
assert(scaledFont * K.Widgets.ScaleFactor(fan.holder) / K.Scale.Pixel(1) >= K.Scale.TextFloor() - 0.01,
	"restyle crest timer fonts after Layout Mode scaling so they keep the physical text floor")
K.Layout.Set(ns.Fan.KEY, "scale", 1)

local fixtures = {
	{ id = 1, icon = 135813, left = 9, harmful = true, mine = true },
	{ id = 2, icon = 136026, left = 3, harmful = true, mine = true, control = true, pandemic = true },
	{ id = 3, icon = 136207, left = 6, harmful = true, mine = false },
	{ id = 4, icon = 136118, left = 12, harmful = false, mine = false },
}
U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = fixtures })
env.SetTarget(true)
Engine.Install(env)
local function refresh() env.FireEvent("UNIT_AURA", "target", { isFullUpdate = true }) end
local function assigned() return view.auras.container._groups.debuffs.assigned end
assert(fan.containers[1]._groups.debuffs.assigned[1] == 2, "your non-damaging control debuff is first because it expires first")
assert(fan.containers[2]._groups.debuffs.assigned[2] == 1, "your damage debuff is second")
assert(#assigned() == 0, "Your debuffs leaves no medallion debuffs when they are in the fan")
assert(fan.containers[1]._groups.debuffs.buttons[1]._aura.AddPandemicRegion[1]._shown == true, "the engine owns the pandemic cue")
K.Options.Write("UnitFrames", "target.auraFilter", "both")
refresh()
assert(view.auras.container._groups.buffs.assigned[1] == 4, "other helpful auras keep their target-frame group")
K.Options.Write("UnitFrames", "target.auraFilter", "buffs")
refresh()
assert(#assigned() == 0 and fan.containers[1]._groups.debuffs.assigned[1] == 2, "buff-only medallions retain their filter while your fan remains independent")
K.Options.Write("UnitFrames", "target.auraFilter", "debuffs")
refresh()

-- The native clipping must reveal each of your icons exactly once, including its text floor and sweep binding.
local scene = Scene.Build(env)
local counts = {}
for _, item in ipairs(scene.items) do
	if item.fileID then counts[item.fileID] = (counts[item.fileID] or 0) + 1 end
end
assert(counts[135813] == 1 and counts[136026] == 1, "the arc reveals each of your debuffs once")
K.Layout.Set(ns.Fan.KEY, "scale", 0.5)
local nativeTimer = fan.containers[1]._groups.debuffs.buttons[1]._aura.SetDurationText[1]
local timerDrawn = false
for _, item in ipairs(Scene.Build(env).items) do
	if item.object == nativeTimer then
		timerDrawn = true
		assert(item.rect[2] + item.rect[4] <= item.clip[2] + item.clip[4] + 0.01,
			"keep vertical clipping room for timers after the physical text floor grows them at small Layout scales")
	end
end
assert(timerDrawn, "the scaled fan draws its timer")
K.Layout.Set(ns.Fan.KEY, "scale", 1)
for _, entry in ipairs(fan.buttons) do
	assert(entry.button._aura.SetDurationCooldown[1] == entry.cooldown, "native cooldown sweeps")
	assert(select(2, entry.timer:GetFont()) >= 10, "readable timer floor")
end

-- Forbid all addon access to live fan buttons; native fixture work uses the engine's access context.
for _, entry in ipairs(fan.buttons) do
	for _, method in ipairs({ "SetSize", "SetPoint", "ClearAllPoints", "IsShown", "GetPoint", "GetWidth", "GetHeight", "EnableMouse", "SetMouseMotionEnabled", "SetHitRectInsets" }) do
		local original = entry.button[method]
		entry.button[method] = function(self, ...)
			assert(not env._restricted, "addon touched a secret aura button: " .. method)
			return original(self, ...)
		end
	end
end
env._restricted = true
env.SetCombat(true)
env.C_UnitAuras = setmetatable({}, { __index = function() error("addon must never query aura data") end })
fixtures[1].left = 1
refresh()
assert(fan.containers[1]._groups.debuffs.assigned[1] == 1, "the engine reorders during restricted combat")
K.Callbacks.Fire("ThemeChanged")
refresh()
assert(#env._errors == 0 and K.ErrorCount() == 0, "combat and theme changes touch no secret button")

-- Fill past the cap: every window remains bounded and the engine count drives the overflow chip.
for i = 5, 14 do fixtures[#fixtures + 1] = { id = i, icon = 135813, left = i, harmful = true, mine = true } end
refresh()
for rank, container in ipairs(fan.containers) do
	assert(#container._groups.debuffs.assigned == rank, "each clipped view holds only its prefix")
	assert(container._groups.debuffs.max == rank, "the maximum cannot grow with aura count")
end
assert(fan.overflow and fan.overflow.cap == ns.Fan.MAX, "overflow is counted without reading aura values")
assert(#assigned() == 1, "overflow does not duplicate your debuffs on the medallion")
local icons, timers = {}, {}
for _, entry in ipairs(fan.buttons) do icons[entry.icon], timers[entry.timer] = true, true end
local iconCount, timerCount = 0, 0
for _, item in ipairs(Scene.Build(env).items) do
	if icons[item.object] then iconCount = iconCount + 1 end
	if timers[item.object] then timerCount = timerCount + 1 end
end
assert(iconCount == ns.Fan.MAX and timerCount == ns.Fan.MAX, "native clips reveal exactly seven complete icons and timers at capacity")

-- Native target and aura events clear every old assignment, including death and no target.
U.SetUnit(env, "target", { name = "Next target", health = 50, healthMax = 50, reaction = 2, auras = {} })
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(#fan.containers[1]._groups.debuffs.assigned == 0, "target change clears the old fan")
env._units.target.auras = { fixtures[1] }
refresh()
env._units.target.dead = true
env._units.target.auras = {}
refresh()
env.FireEvent("UNIT_HEALTH", "target")
assert(#fan.containers[1]._groups.debuffs.assigned == 0, "aura removals on death clear the fan")
U.SetUnit(env, "target", nil)
env.SetTarget(false)
assert(fan.content._shown == false, "losing the target hides the fan")
env._restricted = false
env.SetCombat(false)
K.Layout.Set(ns.Fan.KEY, "scale", 0.5)
local _, counterSize = fan.overflow.texts[5]:GetFont()
assert(counterSize * K.Widgets.ScaleFactor(fan.holder) / K.Scale.Pixel(1) >= K.Scale.TextFloor() - 0.01,
	"restyle the native overflow counter after Layout Mode scaling so it keeps the physical text floor")
K.Layout.Set(ns.Fan.KEY, "scale", 1)
U.SetUnit(env, "target", { name = "Target", health = 100, healthMax = 100, reaction = 2, auras = fixtures })
env.SetTarget(true)

local settings = K.Store.Module("UnitFrames")
settings.target.crestDebuffs = false
K.Callbacks.Fire("SettingChanged", "UnitFrames", "target.crestDebuffs", false)
refresh()
assert(fan.content._shown == false and not K.Layout.Live(ns.Fan.KEY), "switching off hides the fan and its mover")
assert(#assigned() == ns.Settings.Value("target", "auraColumns"), "the original target cap returns with the fan off")
settings.target.crestDebuffs = true
K.Callbacks.Fire("SettingChanged", "UnitFrames", "target.crestDebuffs", true)
refresh()
assert(fan.content._shown ~= false, "switching on restores the fan")
for _, style in ipairs({ "frames", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	refresh()
	assert(fan.content._shown == (style == "medallions"), "only Medallions has a fan")
end
K.Modules.Disable("UnitFrames")
for _, container in ipairs(fan.containers) do assert(container._enabled == false, "off modules stop every fan engine") end
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors across the lifecycle")

-- Both casts are real fixture-driven bars; keep every fan icon and timer clear of them at both acceptance sizes.
local Hud = dofile("Tools/render/scenes/hud.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
	local entries = {}
	for i = 1, 7 do entries[i] = { 135813, i * 3 .. "s" } end
	local rendered, units = Hud.Module("unitframes", { class = "SHAMAN", layout = "DPS", applyPreset = true, targetAuras = entries, settings = { UnitFrames = { auraLayout = "fan" } } })
	local crest = units.Frames.Get("target").views[1].auras.fan
	local regions = {}
	for _, entry in ipairs(crest.buttons) do regions[entry.icon], regions[entry.timer] = true, true end
	local casts = { units.CastBars.Inline("player")[1].frame, units.CastBars.Inline("target")[1].frame }
	local castTop = {}
	for _, item in ipairs(rendered.items) do
		local object = item.object
		while object do
			for _, frame in ipairs(casts) do
				if object == frame then castTop[frame] = math.min(castTop[frame] or math.huge, item.rect[2]) end
			end
			object = object._parent
		end
	end
	for _, item in ipairs(rendered.items) do
		if regions[item.object] then
			for _, frame in ipairs(casts) do
				local top = assert(castTop[frame], "both casts must draw in the fan clearance fixture")
				local r = item.rect
				assert(r[2] + r[4] <= top - 4, "raise the crest fan default so its outer icons and timers clear both cast bars")
			end
		end
	end
end
rawset(_G, "RENDER_SCREEN", nil)

-- An unsupported native sort is a construction failure, so the original target display must survive.
local fallbackEnv, fallbackK, fallback = U.New({ before = function(game, core)
	core.Store.Module("UnitFrames").auraLayout = "fan"
	game.AuraContainerSortMethod = nil
end })
local original = fallback.Frames.Get("target").views[1].auras
assert(original.fan.failed and original.container._groups.debuffs.filter == "HARMFUL|PLAYER", "failed fan construction retains the original debuff group")
assert(original.fan.content._shown == false and #fallbackEnv._errors == 0 and fallbackK.ErrorCount() == 0, "failed fan construction is contained and hidden")

local delayedEnv, delayedK, delayed = U.New({ before = function(_, core)
	core.Store.Module("UnitFrames").auraLayout = "fan"
	core.Store.Module("UnitFrames").target = { crestDebuffs = false }
end })
local delayedView = delayed.Frames.Get("target").views[1]
assert(not delayedView.auras.fan, "disabled fans allocate no engines")
delayedEnv._restricted = true
delayedEnv.SetCombat(true)
delayedK.Options.Write("UnitFrames", "target.crestDebuffs", true)
assert(not delayedView.auras.fan, "first construction waits while buttons are restricted")
delayedEnv._restricted = false
delayedEnv.SetCombat(false)
delayedEnv.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
assert(delayedView.auras.fan and not delayedView.auras.fan.failed, "opening the aura gate finishes the pending fan construction")
print("ok unitframes crest debuffs")
