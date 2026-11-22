-- test-unitframes-parity-r2-review.lua: the parity round 2 review's probes: guarded secret cast data, a long spell target leaves the Frames line's track, Frames' wide-bar icon offsets, the outline ends with the cast, preview dispel edges, the crest's own aura text, safe dispel and outline fallbacks, reused power gradient colours, real stack sizes and the offsets switched on.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local Scene = dofile("Tools/render/scene.lua")

local env, K, ns = U.New({ setup = function(e) e.C_Spell.IsSpellImportant = function() return true end end })
local function set(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end
local function row(key)
	for _, r in ipairs(ns.Settings.Schema()) do
		if r.key == key then return r end
	end
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local failures = {}
local function check(name, fn)
	local ok, why = pcall(fn)
	if not ok then failures[#failures + 1] = name .. ": " .. tostring(why) end
end
local function moved(region, key, value, index)
	local before = W.LastCall(region, "SetPoint")[index]
	set(key, value)
	local after = W.LastCall(region, "SetPoint")[index]
	set(key, 0)
	return after - before
end

-- 1. Secret cast data: the target name and spell ID are proven plain before any comparison.
check("1", function()
	local file = assert(io.open("KstyleUI_UnitFrames/CastBar.lua", "rb"))
	local source = file:read("*a")
	file:close()
	for line in source:gmatch("[^\n]+") do
		for name in line:gmatch("([%w_]+) ~= nil") do
			if name == "target" or name == "spellID" then
				assert(line:find("issecretvalue(" .. name .. ") or " .. name .. " ~= nil", 1, true), "CastBar.lua compares a possibly secret " .. name .. " to nil; check issecretvalue first: " .. line)
			end
		end
	end
end)

K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()

-- 2. On Frames a long spell target leaves the focus line's track its minimum width.
check("2", function()
	env._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
	local line = ns.Frames.Get("focus").views[1].castbar
	assert(line.line, "the focus cast bar is a line")
	ns.CastBars.Layout(line, 280, 18)
	local function natural(region)
		local path, size = region:GetFont()
		return Scene.TextWidth(U.Shown(env, region), size, path)
	end
	local function track()
		local width = W.LastCall(line.text, "SetWidth")[1]
		if width == 0 then width = natural(line.text) end
		return 280 - natural(line.label) - 5 - width - 8 - (line.timer:IsShown() and line.timer:GetWidth() + 5 or 0)
	end
	ns.CastBars.SetName(line, "Greater Shadow Bolt", "High Inquisitor Whitemane")
	assert(track() >= 24, "a long target name must leave the 24-unit track, left " .. track())
	ns.CastBars.SetName(line, "Greater Shadow Bolt", env.Secret("High Inquisitor Whitemane"))
	assert(track() >= 24, "a secret target name, never measured, leaves the track too")
	ns.CastBars.SetName(line, "Bolt", "Valerin")
	assert(W.LastCall(line.text, "SetWidth")[1] == 0 and track() > 24, "a short target keeps the name's natural width")
	ns.CastBars.SetName(line, "Greater Shadow Bolt")
	assert(W.LastCall(line.text, "SetWidth")[1] == 0, "no target, natural width")
	env._textWidth = nil
end)

-- 3. Frames' wide bar: the separate cast bar draws the icon, so its offsets show.
check("3", function()
	U.SetUnit(env, "target", { name = "Ogre", health = 3000, healthMax = 4000, power = 80, powerMax = 100, reaction = 2 })
	local style = K.Options.Read("UnitFrames", "target.style")
	set("target.style", "bar")
	set("edit", "target")
	set("target.castbarIcon", true)
	local solo = ns.CastBars.Get("target")[1]
	local drawn = ns.CastBars.ElementLive("target") and solo.iconFrame:IsShown()
	local hidden = {}
	for _, key in ipairs({ "target.castbarIconX", "target.castbarIconY", "target.castbarIconRight" }) do
		if not row(key).showWhen(ns.Settings.Module()) then hidden[#hidden + 1] = key end
	end
	local iconY = moved(solo.iconFrame, "target.castbarIconY", 3, 5)
	local timerX = moved(solo.timer, "target.castbarTimerX", -4, 4)
	set("target.castbarIcon", false)
	set("target.style", style)
	assert(drawn, "the wide bar's cast bar shows its icon")
	assert(#hidden == 0, table.concat(hidden, ", ") .. " must show where the icon is drawn")
	assert(near(iconY, K.Widgets.Snap(solo.frame, 3)), "the icon's vertical offset moves it")
	assert(near(timerX, K.Widgets.Snap(solo.frame, -4)), "the timer's horizontal offset moves it")
end)

K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
U.SetUnit(env, "target", { name = "Ogre", health = 3000, healthMax = 4000, power = 80, powerMax = 100, reaction = 2 })
set("edit", "target")
local cb = ns.CastBars.Inline("target")[1]

-- 4. The important outline goes the moment the cast ends, not after the hold.
check("4", function()
	set("target.castbarImportant", true)
	for _, ending in ipairs({ "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP" }) do
		env._units.target.cast = { name = "Bolt", texture = 1, start = 1000, finish = 3000, spellID = 686 }
		env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", 686)
		assert(cb.important:IsShown(), "an important cast shows the outline")
		env._units.target.cast = nil
		env.FireEvent(ending, "target", "Cast-1", 686)
		assert(not cb.important:IsShown(), ending .. " hides the outline at once")
		env.RunTimers()
	end
end)

-- 7b. A secret answer without SetAlphaFromBoolean leaves the bar unhighlighted.
check("7b", function()
	env.C_Spell.IsSpellImportant = function() return env.Secret(true) end
	cb.important.SetAlphaFromBoolean = false
	local ok, why = pcall(ns.CastBars.Important, cb, 686)
	assert(ok and not cb.important:IsShown(), "a missing SetAlphaFromBoolean falls back to no outline: " .. tostring(why))
	cb.important.SetAlphaFromBoolean = nil
	set("target.castbarImportant", false)
end)

-- 5. The preview's sample auras show each dispel edge toggle.
check("5", function()
	set("target.auraFilter", "both")
	local pane = ns.Preview.Build(env.UIParent)
	local function edges()
		pane:Refresh()
		local out = {}
		for i, tile in ipairs(pane.auraTiles.target) do
			out[i] = tile.dispel ~= nil and tile.dispel[1]:IsShown()
		end
		return out
	end
	local e = edges()
	assert(e[1] and not e[2] and not e[3], "a magic debuff has its edge; buffs have none until asked")
	set("target.auraBuffDispel", true)
	e = edges()
	assert(e[1] and e[2] and e[3], "buff dispel colours edge both sample buffs")
	set("target.auraStealable", true)
	e = edges()
	assert(e[1] and e[2] and not e[3], "stealable only edges the stealable buff")
	set("target.auraDispel", false)
	e = edges()
	assert(not e[1] and e[2], "debuff dispel colours off clears the debuff's edge")
	set("target.auraFilter", "mine")
	e = edges()
	assert(not e[2] and not e[3], "a debuff-only filter shows no buff edges")
	for key, value in pairs({ auraBuffDispel = false, auraStealable = false, auraDispel = true }) do set("target." .. key, value) end
end)

-- 6. The Medallions crest keeps its own aura text, and the target's rows say so.
check("6", function()
	local crest = "Not the Medallions crest."
	for _, key in ipairs({ "auraCountSize", "auraCountPoint", "auraCountX", "auraCountY", "auraTimerX", "auraTimerY" }) do
		assert(row("target." .. key).help:find(crest, 1, true), "target." .. key .. " names the crest exception")
		assert(not row("focus." .. key).help:find(crest, 1, true), "focus." .. key .. " has no crest")
	end
end)

-- 7a. Dispel edges need both engine methods before any edge is added.
check("7a", function()
	set("target.auraFilter", "both")
	local buffs = {}
	for _, entry in ipairs(ns.Frames.Get("target").views[1].auras.buttons) do
		if entry.key == "buffs" then buffs[#buffs + 1] = entry.button end
	end
	buffs[1].RemoveDispelTypeTexture = false
	buffs[2].AddDispelTypeTexture = false
	set("target.auraBuffDispel", true)
	assert(#(buffs[1]._aura.dispel or {}) == 0, "no Remove: no edge that could not be taken off")
	set("target.auraBuffDispel", false)
	assert(#(buffs[1]._aura.dispel or {}) == 0 and #(buffs[3]._aura.dispel or {}) == 0, "off leaves nothing registered")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a missing AddDispelTypeTexture is refused, not called: " .. tostring(env._errors[1]))
	buffs[1].RemoveDispelTypeTexture, buffs[2].AddDispelTypeTexture = nil, nil
	set("target.auraFilter", "mine")
end)

-- 8. The power gradient reuses its colours, and a real change still repaints.
check("8", function()
	local fill = ns.Frames.Get("player").views[1].power:GetStatusBarTexture()
	set("player.powerGradient", "HORIZONTAL")
	local create, made = env.CreateColor, 0
	env.CreateColor = function(...) made = made + 1 return create(...) end
	for _ = 1, 10 do env.FireEvent("UNIT_DISPLAYPOWER", "player") end
	assert(made == 0, "unchanged power notifications allocate no colours, made " .. made)
	set("player.powerColor", "custom")
	set("player.powerCustom", { r = 0, g = 1, b = 0 })
	local shade = W.LastCall(fill, "SetGradient")
	assert(shade[3].g == 1 and shade[3].r == 0 and near(shade[2].g, 0.55), "a real colour change repaints the gradient")
	env.CreateColor = create
	for key, value in pairs({ powerGradient = "", powerColor = "power" }) do set("player." .. key, value) end
end)

-- 9. The stack size offers only sizes it draws: automatic (0), then 6 upward.
check("9", function()
	local stack = row("target.auraCountSize")
	assert(stack.min >= 6 and stack.shown(0) >= stack.min, "the slider starts at the smallest drawn size and paints automatic in range")
	local count = ns.Frames.Get("target").views[1].auras.buttons[1].count
	local sizes = {}
	for _, v in ipairs({ stack.min, stack.min + 1 }) do
		set("target.auraCountSize", v)
		sizes[#sizes + 1] = select(2, count:GetFont())
	end
	assert(sizes[1] ~= sizes[2], "each offered size draws differently")
	set("target.auraCountSize", 0)
end)

-- The other new axes switched on.
check("offsets", function()
	local debuff = ns.Frames.Get("target").views[1].auras.buttons[1]
	assert(near(moved(debuff.timer, "target.auraTimerX", 5, 4), K.Widgets.Snap(debuff.skin, 5)), "the aura timer's horizontal offset moves it")
	assert(near(moved(debuff.count, "target.auraCountY", -3, 5), K.Widgets.Snap(debuff.skin, -3)), "the stack's vertical offset moves it")
end)

assert(#failures == 0, table.concat(failures, "\n"))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-unitframes-parity-r2-review: ok")
