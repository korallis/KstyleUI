-- test-hud-style-gate.lua: while HudStyle.MEDALLIONS_READY is false the third HUD style is hidden from players (LEE-1533): neither the Options picker nor the setup window shows its card, a saved Medallions style falls back to Frames at load, and the style stays a valid value for the harness.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local W = O.W

local function Settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local K0 = select(2, CoreEnv.New({ medallions = false }))
assert(K0.HudStyle.MEDALLIONS_READY == false, "the flag ships off until Medallions is finished")

local saved = { profiles = { Default = { HudStyle = { style = "medallions" } } }, version = 1 }

do
	local env, K, ns = O.New({ medallions = false })
	assert(K.HudStyle.Valid("medallions"), "Medallions stays a valid style")
	assert(not K.HudStyle.Offered("medallions") and K.HudStyle.Offered("orbs") and K.HudStyle.Offered("frames"), "only Frames and Orbs are offered")
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
	assert(#shown == 2 and shown[1] == "frames" and shown[2] == "orbs", "the General page shows Frames and Orbs only, got " .. table.concat(shown, ","))
	assert(not K.HudStyle.schema[2].help:find("Medallions", 1, true), "the picker help does not name Medallions")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local WE = dofile("Tools/regression/widget_env.lua")
	local env, K = WE.New({ boot = false, medallions = false })
	WE.CoreEnv.Boot(env)
	K.Setup.Open()
	WE.Settle(env)
	K.Setup.Go(2)
	WE.Settle(env)
	local cards = K.Setup.window.styleCards
	assert(cards.frames and cards.orbs, "the setup shows Frames and Orbs")
	assert(cards.medallions == nil, "the setup shows no Medallions card")
	assert(K.Setup.Choice().hudStyle == "frames", "the pick starts on Frames")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CoreEnv.New({ saved = saved, medallions = false })
	CoreEnv.Boot(env)
	assert(K.HudStyle.Saved() == "frames" and K.HudStyle.Current() == "frames", "a saved Medallions style loads as Frames")
	assert(K.Store.Module("HudStyle").style == "medallions", "the saved choice is kept for when Medallions ships")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CoreEnv.New({ saved = saved })
	CoreEnv.Boot(env)
	assert(K.HudStyle.Offered("medallions"), "the dev flag offers Medallions")
	assert(K.HudStyle.Saved() == "medallions" and K.HudStyle.Current() == "medallions", "with the dev flag a saved Medallions style stays")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("hud style gate ok")
