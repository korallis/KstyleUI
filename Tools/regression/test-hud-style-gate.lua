-- test-hud-style-gate.lua: the shipped build offers two HUD styles, Medallions by default and Frames: the Options picker and the setup window show both, a saved Frames style loads as Frames, and switching fires HudStyleChanged once and back again.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local W = O.W

local function Settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

do
	local env, K, ns = O.New()
	assert(K.HudStyle.Current() == "medallions", "Medallions is the default")
	assert(K.HudStyle.Valid("frames") and not K.HudStyle.Valid("orbs"), "Frames is a style and Orbs is not")
	K.Options.Open("General")
	Settle(env)
	local shown = {}
	for _, row in ipairs(ns.Window.Parts().content.rows) do
		if row:IsShown() and row.item and row.item.kind == "pictures" then
			for _, card in ipairs(row.controls.pictures.cards) do
				if card:IsShown() then
					shown[#shown + 1] = card.value
				end
			end
		end
	end
	assert(table.concat(shown, ",") == "medallions,frames", "the General page shows Medallions and Frames, got " .. table.concat(shown, ","))
	local fired = {}
	K.Callbacks.Register("HudStyleChanged", "test", function(_, style) fired[#fired + 1] = style end)
	K.Options.Write("HudStyle", "style", "frames")
	K.Options.Write("HudStyle", "style", "medallions")
	assert(table.concat(fired, ",") == "frames,medallions", "each switch fires HudStyleChanged once, got " .. table.concat(fired, ","))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local WE = dofile("Tools/regression/widget_env.lua")
	local env, K = WE.New({ boot = false })
	WE.CoreEnv.Boot(env)
	K.Setup.Open()
	WE.Settle(env)
	K.Setup.Go(2)
	WE.Settle(env)
	local cards = K.Setup.window.styleCards
	assert(cards.frames and cards.medallions and not cards.orbs, "the setup shows Medallions and Frames")
	assert(K.Setup.Choice().hudStyle == "medallions", "the pick starts on Medallions")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	K.Options.Write("HudStyle", "style", "frames")
	env.FireEvent("PLAYER_LOGOUT")
	local saved = CoreEnv.DeepCopy(env.KstyleUIDB)
	env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	assert(K.HudStyle.Saved() == "frames" and K.HudStyle.Current() == "frames", "a saved Frames style loads as Frames")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("hud style gate ok")
