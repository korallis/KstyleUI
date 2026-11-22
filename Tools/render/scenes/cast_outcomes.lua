-- cast_outcomes.lua: landed, interrupted and completed-channel acknowledgements at the peak of their own animation.
local Common = dofile("Tools/render/scenes/_common.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")

return Common.Run(function()
	local scenes = {}
	for row, state in ipairs({ "landed", "interrupted", "channel" }) do
		local env, K, ns = U.New(Common.ScreenOpts({ saved = Gallery.Saved({ "UnitFrames" }), setup = Gallery.Setup }))
		for _, kind in ipairs(ns.Settings.KINDS) do
			for _, view in ipairs(ns.Frames.Get(kind).views) do view.button:Hide() end
		end
		K.Layout.Update("unitframes.castbar.player", { anchor = "CENTER", x = 0, y = 240 - (row - 1) * 240 })
		env.C_DurationUtil = { CreateDuration = function()
			return { SetTimeSpan = function(duration, start, finish)
				duration.start, duration.finish = start, finish
			end }
		end }
		local channel = state == "channel"
		env._time = 2
		env._units.player[channel and "channel" or "cast"] = { name = "Terrifying Screech", texture = 136048, start = 1000, finish = 4000, spellID = 188196 }
		env.FireEvent(channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", "player")
		U.W.Tick(env, 0.3)
		env._units.player.cast, env._units.player.channel = nil, nil
		env.FireEvent(channel and "UNIT_SPELLCAST_CHANNEL_STOP" or state == "interrupted" and "UNIT_SPELLCAST_INTERRUPTED" or "UNIT_SPELLCAST_STOP", "player")
		local cb = ns.CastBars.Get("player")[1]
		local t = Common.Scene.AnimationPeak(cb.flash.group)
		cb.flash.group._playedAt = cb.flash.group._playedAt and env._time - t
		if cb.medStreak then cb.medStreak.anim._playedAt = env._time - t end
		local label = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
		K.Widgets.StyleText(label, "body")
		label:SetPoint("CENTER", K.Scale.Root(), "CENTER", -330, 240 - (row - 1) * 240)
		label:SetText(state)
		assert(#env._errors == 0, tostring(env._errors[1]))
		scenes[#scenes + 1] = Common.Scene.Build(env)
	end
	return Common.Scene.Merge(scenes)
end)
