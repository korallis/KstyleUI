-- test-hud-style-gate.lua: HudStyle.MEDALLIONS_READY ships true (LEE-1533, LEE-1538), so the shipped build, with no dev flag, offers all three HUD styles: the Options picker and the setup window show the Medallions card, the picker help names it, and a saved Medallions style loads as Medallions.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local W = O.W

local function Settle(env)
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local K0 = select(2, CoreEnv.New({ medallions = false }))
assert(K0.HudStyle.MEDALLIONS_READY == true, "Medallions ships to players")

local saved = { profiles = { Default = { HudStyle = { style = "medallions" } } }, version = 1 }

do
	local env, K, ns = O.New({ medallions = false })
	assert(K.HudStyle.Offered("medallions") and K.HudStyle.Offered("orbs") and K.HudStyle.Offered("frames"), "all three styles are offered without the dev flag")
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
	assert(table.concat(shown, ",") == "frames,orbs,medallions", "the General page shows Frames, Orbs and Medallions, got " .. table.concat(shown, ","))
	assert(K.Options.Get("HudStyle")[2].help:find("Medallions", 1, true), "the picker help names Medallions")
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
	assert(cards.frames and cards.orbs and cards.medallions, "the setup shows Frames, Orbs and Medallions")
	assert(K.Setup.Choice().hudStyle == "frames", "the pick starts on Frames")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = CoreEnv.New({ saved = saved, medallions = false })
	CoreEnv.Boot(env)
	assert(K.HudStyle.Saved() == "medallions" and K.HudStyle.Current() == "medallions", "a saved Medallions style loads as Medallions")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("hud style gate ok")
