-- test-skins-encounter.lua: the encounter warnings skin narrows Forever's RaidWarningFrame (boss emotes, boss whispers, raid warnings) to the combat lane, sets its messages in the Lumen face and puts a glass plate behind them that grows with the messages, fades with them and stays inside the lane, through hooks only.
local S = dofile("Tools/regression/skins_env.lua")
local Warnings = dofile("Tools/regression/encounter_warnings.lua")

local SCREAM = "Bloodtalon Matriarch begins to cast Terrifying Screech!"
local HOOKED = { UpdateLayout = true }

local function New(opts)
	opts = opts or {}
	local B, frame, snap
	local env, K, ns = S.New({
		loaded = { Blizzard_RaidWarning = opts.loaded ~= false },
		before = function(env)
			B = S.Blizzard(env)
			frame = Warnings.Build(env, B)
			snap = B.snapshot()
		end,
	})
	if opts.off then
		K.Store.Module("Skins").encounterWarnings = { enabled = false }
	end
	K.Modules.Enable("Skins")
	return env, K, ns, frame, B, snap
end

local function Plate(ns)
	return ns.Encounter and ns.Encounter.Plate()
end

local function Near(a, b, what)
	assert(type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.51, what .. ": " .. tostring(a) .. " against " .. tostring(b))
end

-- The skin registers a switch, waits for nothing (Forever loads Blizzard_RaidWarning with the UI) and applies at once,
-- before the first warning, so every string the pool makes is born lane-wide.
do
	local env, K, ns, frame, B, snap = New()
	assert(K.Options.Row("Skins", "encounterWarnings.enabled"), "the encounter warnings have a switch")
	assert(ns.Skins.IsApplied("encounterWarnings"), "the skin applies when the module starts, before any warning shows")
	local lane = frame:GetWidth()
	Near(lane, K.Setup.EditMode.WARNING_LANE / K.Widgets.ScaleFactor(frame), "the warnings narrow to the lane setup places them in, in the frame's own units")
	assert(lane < Warnings.WIDTH, "narrower than Blizzard's 800 units")
	local plate = Plate(ns)
	assert(plate, "the skin keeps a glass plate behind the warnings")
	assert(plate.chrome and plate.chrome.shapeName == "panel", "the plate is Lumen panel glass")
	assert(plate:GetFrameStrata() == "BACKGROUND", "the plate sits under the HUD; only the words ride Blizzard's HIGH strata")
	assert(not plate:IsShown(), "no warning, no plate")

	frame:AddMessage(SCREAM, Warnings.BOSS, 6, Warnings.BOSS_EMOTE)
	local text = Warnings.Strings(frame)[1]
	local path, size = text:GetFont()
	assert(path == (ns.Style.Font("world")), "a warning is set in the Lumen world face, made to read over scenery: " .. tostring(path))
	Near(size, Warnings.MIN_TEXT_HEIGHT, "the face is cut at Blizzard's resting height, so the scale-up stays crisp")
	Near(text:GetWidth(), lane, "a new string is as wide as the lane, so Blizzard's line limit counts the lines it shows")
	local r, g, b = text:GetTextColor()
	assert(r == Warnings.BOSS.r and g == Warnings.BOSS.g and b == Warnings.BOSS.b, "Blizzard's colour stays: it tells a boss emote from a raid warning")
	assert(plate:IsShown(), "the plate shows under the first warning")

	-- The plate hugs the stack: its top above the frame's top, its bottom below the last line, its sides beyond the lane.
	local top, bottom = plate:GetTop(), plate:GetBottom()
	local one = top - bottom
	assert(top > frame:GetTop(), "the plate's top rises above the first line")
	assert(bottom < frame:GetTop() - Warnings.MIN_TEXT_HEIGHT, "the plate's foot falls below the line")
	assert(plate:GetLeft() < frame:GetLeft() and plate:GetRight() > frame:GetRight(), "the plate is wider than the lane's text on both sides")
	Near(plate:GetLeft() + plate:GetRight(), frame:GetLeft() + frame:GetRight(), "the plate is centred on the lane")
	assert(one < 2 * Warnings.MIN_TEXT_HEIGHT + 24, "one line keeps the plate short: " .. one)

	frame:AddMessage("Leduc: Spread out!", Warnings.WARNING, 0, Warnings.RAID_WARNING)
	local two = plate:GetTop() - plate:GetBottom()
	Near(two - one, Warnings.MIN_TEXT_HEIGHT, "a second warning grows the plate by one line")
	Warnings.Lines(frame, 2)
	frame:UpdateLayout()
	Near(plate:GetTop() - plate:GetBottom() - two, Warnings.MIN_TEXT_HEIGHT, "a warning that wraps grows the plate by its extra line")
	for _, s in ipairs(Warnings.Strings(frame)) do
		assert((s:GetFont()) == (ns.Style.Font("world")), "every warning wears the face")
	end

	-- The plate fades with the words, so it never outlives them.
	Warnings.Fade(frame, 0.4)
	Near(plate:GetAlpha() * 10, 4, "the plate fades with the warnings")
	Warnings.Fade(frame, 1)
	Near(plate:GetAlpha(), 1, "and comes back with a fresh one")
	Warnings.Expire(frame)
	assert(plate:IsShown(), "one warning left keeps the plate")
	Near(plate:GetTop() - plate:GetBottom(), one, "the plate shrinks back to one line")
	Warnings.Expire(frame)
	assert(not frame:IsShown() and not plate:IsShown(), "the last warning gone, the plate goes with the frame")

	B.check(snap, HOOKED)
	assert(not frame.kstyle and not frame.plate, "nothing is written onto Blizzard's frame")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A boss emote's text may be secret; then its anchoring is secret and its height reads secret. The plate counts the
-- line at the resting height without comparing the secret.
do
	local env, _, ns, frame = New()
	frame:AddMessage(SCREAM, Warnings.BOSS, 6, Warnings.BOSS_EMOTE)
	local plate = Plate(ns)
	local one = plate:GetTop() - plate:GetBottom()
	frame:AddMessage(env.Secret("Bloodtalon Matriarch fixates on Valerin!"), Warnings.BOSS, 6, Warnings.BOSS_EMOTE)
	Warnings.Secret(frame, env)
	frame:UpdateLayout()
	Near(plate:GetTop() - plate:GetBottom() - one, Warnings.MIN_TEXT_HEIGHT, "a secret warning counts as one line")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A scale change resizes the lane and every string the pool already made; a change to the skins' shared text settings
-- reaches the warnings already on screen.
do
	local env, K, ns, frame = New()
	frame:AddMessage(SCREAM, Warnings.BOSS, 6, Warnings.BOSS_EMOTE)
	local text = Warnings.Strings(frame)[1]
	local before = frame:GetWidth()
	K.Scale.Root():SetScale(0.5)
	K.Widgets.RestyleAll()
	local lane = K.Setup.EditMode.WARNING_LANE / K.Widgets.ScaleFactor(frame)
	assert(math.abs(lane - before) > 20, "the scale change moves the lane: " .. before .. " to " .. lane)
	Near(frame:GetWidth(), lane, "the lane follows the scale")
	Near(text:GetWidth(), lane, "a string the pool made before the change follows the lane")
	local plate = Plate(ns)
	assert(plate:GetWidth() > text:GetWidth(), "the string stays inside the glass")
	K.Options.Write("Skins", "text.outline", "outline")
	local _, _, flags = text:GetFont()
	assert(flags == select(3, ns.Style.Font("world")) and flags ~= "", "the shared outline setting reaches a warning on screen: " .. tostring(flags))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Off: Blizzard's frame is left alone.
do
	local _, _, ns, frame = New({ off = true })
	assert(not ns.Skins.IsApplied("encounterWarnings"), "switched off, the skin does nothing")
	assert(frame:GetWidth() == Warnings.WIDTH and not Plate(ns), "the frame keeps Blizzard's width and gets no plate")
end

print("test-skins-encounter: ok")
