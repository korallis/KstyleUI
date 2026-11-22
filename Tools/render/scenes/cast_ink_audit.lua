-- cast_ink_audit.lua: long casts and interruptions on pale fills at all three motion levels.
local Common = dofile("Tools/render/scenes/_common.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local Classes = dofile("Tools/render/scenes/_classes.lua")

return Common.Run(function()
	local scenes = {}
	for row, class in ipairs({ "WARRIOR", "PRIEST", "ROGUE", "GILT" }) do
		for level, motion in ipairs({ "full", "reduced", "off" }) do
			local env, K, ns = U.New(Common.ScreenOpts({ saved = Gallery.Saved({ "UnitFrames" }) }))
			K.Motion.SetLevel(motion)
			local r, g, b
			if class == "GILT" then
				r, g, b = K.Tokens.Color("gilt")
			else
				r, g, b = unpack(Classes[class].colour)
			end
			K.Options.Write("UnitFrames", "player.castbarColor", "custom")
			K.Options.Write("UnitFrames", "player.castbarCustom", { r = r, g = g, b = b })
			local y = 300 - ((row - 1) * 3 + level - 1) * 45
			K.Layout.Update("unitframes.castbar.player", { anchor = "CENTER", x = -320, y = y })
			for _, kind in ipairs({ "player", "target", "targettarget", "pet", "focus", "focustarget", "boss" }) do
				local frame = ns.Frames.Get(kind)
				for _, view in ipairs(frame and frame.views or {}) do
					view.button:Hide()
				end
			end
			local label = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
			K.Widgets.StyleText(label, "body")
			label:SetPoint("CENTER", K.Scale.Root(), "CENTER", -580, y + 10)
			label:SetText(class .. " / " .. motion)
			env._time = 2.2
			env._units.player.cast = { name = "Terrifying Screech", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
			env.FireEvent("UNIT_SPELLCAST_START", "player", "Audit-Cast", 188196)
			U.W.Tick(env, 0.25)
			assert(ns.CastBars.Get("player")[1].frame:IsShown(), class .. " / " .. motion .. ": the cast or interrupt must draw")
			assert(ns.CastBars.Get("player")[1].frame:GetAlpha() == 1, "capture the settled cast ink, after the entry fade")
			scenes[#scenes + 1] = Scene.Build(env)
			label:Hide()
			K.Layout.Update("unitframes.castbar.player", { x = 0 })
			env._units.player.cast = nil
			env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Audit-Cast", 188196)
			U.W.Tick(env, 0.25)
			assert(ns.CastBars.Get("player")[1].frame:IsShown(), class .. " / " .. motion .. ": the cast or interrupt must draw")
			assert(ns.CastBars.Get("player")[1].frame:GetAlpha() == 1, "capture the settled cast ink, after the entry fade")
			scenes[#scenes + 1] = Scene.Build(env)
			K.Layout.Update("unitframes.castbar.player", { x = 320 })
			env._units.player.cast = { name = "Terrifying Screech", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
			env.FireEvent("UNIT_SPELLCAST_START", "player", "Audit-Cast", 188196)
			U.W.Tick(env, 0.25)
			env._units.player.cast = nil
			env.FireEvent("UNIT_SPELLCAST_FAILED", "player", "Audit-Cast", 188196)
			U.W.Tick(env, 0.25)
			assert(ns.CastBars.Get("player")[1].frame:IsShown(), class .. " / " .. motion .. ": the failed cast must draw")
			scenes[#scenes + 1] = Scene.Build(env)
			assert(#env._errors == 0, tostring(env._errors[1]))
		end
	end
	return Scene.Merge(scenes)
end)
