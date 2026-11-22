local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local keys = { "readableBars", "worldText", "chatTabs", "barColors", "snapEdges" }
for _, key in ipairs(keys) do
	assert(K.Options.Row("Appearance", key), "expose readability in Appearance: " .. key)
	assert(K.Appearance.Readability(key), "readability defaults on: " .. key)
end
local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
frame:SetSize(300, 20)
K.Layout.Register(frame, "unitframes.castbar.player", K.Setup.Layouts.Default("unitframes.castbar.player"), { label = "Cast" })
K.Layout.Update("unitframes.castbar.player", { x = 137, y = 321 })
local function moved()
	local place = K.Layout.Get("unitframes.castbar.player")
	assert(place.x == 137 and place.y == 321, "readability preserves saved layout moves")
end
local changed = 0
K.Callbacks.Register("ReadabilityChanged", "readability-test", function() changed = changed + 1 end)
env.SetCombat(true)
local before = changed
for _, key in ipairs(keys) do K.Options.Write("Appearance", key, false) end
assert(changed == before and K.Combat.Pending() > 0, "defer the complete restyle in combat")
for _, key in ipairs(keys) do assert(K.Appearance.Readability(key), "pending options do not change live rendering") end
env.SetCombat(false)
assert(changed == before + 1, "coalesce combat choices into one restyle")
for _, key in ipairs(keys) do assert(not K.Appearance.Readability(key), "apply the latest saved choice after combat") end
moved()
assert(K.Setup.Layouts.MEDALLIONS_UNITS.castGap == 22 and K.Setup.Layouts.MEDALLIONS_UNITS.castStack == 6, "off restores original cast spacing")
assert(select(4, K.Tokens.Color("barLoss")) == 0.85 and K.Tokens.Color("hudMana") == 61 / 255, "off restores original loss and mana colours")
assert(K.Tokens.FaceShadow(K.Tokens.FontPath("FolioNames")).alpha == 0.5, "off restores name shadows")
local text = K.Widgets.FontString(K.Scale.Root(), "OVERLAY")
K.Widgets.ApplyFont(text, K.Tokens.Font("body"), 11, "")
K.Widgets.TextScrim(text, true)
assert(not text.inkScrim, "world text off creates no scrim")
env.SetCombat(true)
for _, key in ipairs(keys) do K.Options.Write("Appearance", key, true) end
for _, key in ipairs(keys) do assert(not K.Appearance.Readability(key), "enabling also waits for combat to end") end
env.SetCombat(false)
K.Widgets.TextScrim(text, true)
assert(text.inkScrim[5]:IsShown(), "switching on adds backing immediately")
K.Options.Write("Appearance", "worldText", false)
K.Widgets.TextScrim(text, true)
assert(not text.inkScrim[5]:IsShown(), "switching off removes existing backing")
before = changed
K.Appearance.Apply()
assert(changed == before, "unchanged readability values must not trigger another restyle")
env.SetCombat(true)
K.Options.Write("Appearance", "readableBars", false)
K.Options.Write("Appearance", "readableBars", true)
env.SetCombat(false)
assert(changed == before, "a combat round trip to the applied values must not trigger another restyle")
moved()
assert(#env._errors == 0, tostring(env._errors[1]))
print("readability switches and combat deferral passed")
