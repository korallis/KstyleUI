-- gallery_combattext.lua: what KstyleUI_CombatText draws, each cropped as one frame of the gallery: your field
-- with a damage number, a crit and a heal (the numbers wear no chrome: the theme spec gives combat text none), and
-- the CombatText page's live preview with its sample field and its sample target frame tile. The scene advances
-- the stub clock as it ticks the preview, so the renderer samples each number's rise and fade mid-flight, as the
-- game shows them; a number whose animation has ended is transparent and not drawn.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

-- Both frames sit over the plate's sky, where the numbers read; the field is widened so its three lanes clear
-- each other at the start of the rise. The preview ticks for PREVIEW_TICKS frames of TICK seconds (five of its
-- six samples spawned, the oldest faded out); the field's hits land after that and rise for FIELD_TICKS frames.
local FIELD_X, FIELD_Y, FIELD_W = 320, 80, 240
local TICK, PREVIEW_TICKS, FIELD_TICKS = 0.05, 46, 6
local PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H = 640, 80, 320, 300

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

return Common.Run(function()
	local CT = dofile("Tools/regression/combattext_env.lua")
	local env, K, ns = CT.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "CombatText" }),
		setup = function(env)
			Gallery.Setup(env)
			-- The combat text stub labels its formatters; the gallery wants the plain number.
			env.AbbreviateNumbers = function(n)
				return tostring(n)
			end
			env.BreakUpLargeNumbers = env.AbbreviateNumbers
			env._now = 10
		end,
	}))
	if not K.Modules.IsRunning("CombatText") then
		CT.Enable(env, K)
	end
	local frames = Gallery.Frames()
	local function tick(n)
		for _ = 1, n do
			CT.W.Tick(env, TICK)
			env._now = env._now + TICK
		end
	end

	-- The CombatText page's live preview: the sample field over its accent base line, and the sample target frame.
	-- Its samples spawn every 0.45 s as it ticks; the clock advances with the ticks so each one is mid-flight.
	local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(holder, PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H)
	local preview = K.Options.Preview("CombatText")(holder)
	preview:Refresh()
	tick(PREVIEW_TICKS)

	-- Your field, with a hit, a crit and a heal early in their rise, one per lane.
	local ok, why = K.Layout.Update("combattext.player", { anchor = "TOPLEFT", x = FIELD_X, y = -FIELD_Y, width = FIELD_W })
	assert(ok, "combattext.player: " .. tostring(why))
	env.RunTimers()
	CT.Hit(env, "player", "WOUND", "", 1274, 4)
	CT.Hit(env, "player", "WOUND", "CRITICAL", 2431, 32)
	CT.Hit(env, "player", "HEAL", "", 438, 2)
	tick(FIELD_TICKS)
	frames:Add(env, ns.Module.field, {
		name = "combattext_numbers", title = "Your combat text", grade = "panel", reference = "player",
		caption = "Your combat text field with a fire hit in the centre lane, a shadow crit (larger, in the crit tint) to the left and a heal to the right, a third of a second into their rise; the numbers draw no chrome, as the theme spec gives combat text none, and the field itself is an invisible Layout element.",
		match = "Nothing to match: the mockup draws no backdrop under its combat numbers either; the frame is listed for completeness, cropped to the field's footprint.",
	})
	frames:Add(env, holder, {
		name = "combattext_preview", title = "Combat text preview", grade = "button", reference = "datastrip",
		caption = "The CombatText page's live preview: sample numbers rising in YOUR COMBAT TEXT over its accent base line, and the TARGET FRAME sample, a buttonFill tile holding a hostile bar with numbers over it; each sample is sampled mid-flight, where the game's animation has it 2.3 s into the preview.",
		match = "The sample target frame is the button grade: body #101214 with the one-border light line and no shadow, as the mockup's data strip pill; the live target frame is the glass panel grade, which the preview stands in for.",
	})

	local scene = Scene.Build(env, { time = env._now })
	scene.log[#scene.log + 1] = "the numbers are sampled mid-flight at the stub clock; the game animates them"
	return frames:Finish(scene, env, K, "gallery combattext")
end)
