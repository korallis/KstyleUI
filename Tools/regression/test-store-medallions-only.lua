-- test-store-medallions-only.lua: migration 45 moves Frames and Orbs profiles to Medallions, says so once on live data and never on a preview, drops the keys and positions only they read (named layouts and exports too), folds choices that now draw the same and keeps the rest.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local MESSAGE = "KstyleUI is now Medallions only; your HUD moved to Medallions."

local function Boot(style)
	local env, K = CoreEnv.New({ saved = {
		version = 43,
		profiles = {
			Default = {
				HudStyle = { style = style },
				ActionBars = { useTray = true, tray = "forged", trayColumn = 2, bar1 = { size = 40 }, bar2 = { split = "auto" }, bar3 = { split = "on" } },
				UnitFrames = { orbGlass = "soft", orbLedge = true, orbCastRoom = 12, castbarOnFrame = false, player = { style = "lumen" },
					target = { style = "bar", castbarIconRight = true, castbarIconSize = 30, castbarIconX = 12, castbarIconY = 4, castbarInside = true, castbarTextX = 3 } },
				CombatText = { fieldDistance = 60, critScale = 1.4 },
				Chat = { framing = "auto" },
				DataBars = { strip = { height = 20, modules = { { id = "fps", shown = true } }, placement = "rail" } },
			},
			Other = { DataBars = { strip = { placement = "top" } }, UnitFrames = { player = { style = "column" } }, Widgets = { cardMaterial = "Glass" } },
		},
		account = { namedLayouts = { MyHUD = { ["orbs:actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 90 }, ["medallions:actionbars.bar1"] = { anchor = "BOTTOM", x = -12, y = 40 } } } },
		layouts = { Default = {
			["orbs:actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 90 },
			["frames:unitframes.player"] = { anchor = "BOTTOM", x = -200, y = 160 },
			["medallions:actionbars.bar1"] = { anchor = "BOTTOM", x = -12, y = 40 },
			["chat.main"] = { anchor = "BOTTOMLEFT", x = 16, y = 16 },
		} },
	} })
	CoreEnv.Boot(env)
	return env, K
end

for _, style in ipairs({ "frames", "orbs" }) do
	local env, K = Boot(style)
	local db, profile = env.KstyleUIDB, env.KstyleUIDB.profiles.Default
	assert(db.version == K.Store.DB_VERSION, style .. ": the store reaches the current version")
	local said = 0
	for _, line in ipairs(env._printed) do
		if line:find(MESSAGE, 1, true) then said = said + 1 end
	end
	assert(said == 1, style .. ": the move is announced once, got " .. said)
	assert(profile.HudStyle == nil, style .. ": the HUD style setting is gone")
	local bars, units, text = profile.ActionBars, profile.UnitFrames, profile.CombatText
	assert(bars.useTray == nil and bars.tray == nil and bars.trayColumn == nil and bars.bar1.size == 40, style .. ": tray keys go, bar settings stay")
	assert(units.orbGlass == nil and units.orbLedge == nil and units.orbCastRoom == nil and units.castbarOnFrame == false, style .. ": orb keys go, unit frame settings stay")
	assert(text.fieldDistance == nil and text.critScale == 1.4, style .. ": the Frames field distance goes, combat text settings stay")
	assert(profile.Chat.framing == nil, style .. ": the Frames-only automatic chat framing falls back to the default")
	local strip = profile.DataBars.strip
	assert(strip.height == nil and strip.modules == nil and strip.placement == "rail", style .. ": the top bar's height and modules go, the placement stays")
	local layout = db.layouts.Default
	assert(layout["orbs:actionbars.bar1"] == nil and layout["frames:unitframes.player"] == nil, style .. ": Frames and Orbs positions go")
	assert(layout["medallions:actionbars.bar1"].x == -12 and layout["chat.main"].x == 16, style .. ": Medallions and shared positions stay")
	local named = db.account.namedLayouts.MyHUD
	assert(named["orbs:actionbars.bar1"] == nil and named["medallions:actionbars.bar1"].x == -12, style .. ": saved named layouts lose the Orbs positions too")
	local fresh = assert(K.Store.Decode(assert(K.Store.Export())))
	assert(fresh.namedLayouts.MyHUD["orbs:actionbars.bar1"] == nil, style .. ": a fresh export carries no Orbs position")
	local target, player = units.target, units.player
	assert(target.castbarIconRight == nil and target.castbarIconSize == nil and target.castbarIconX == nil and target.castbarIconY == nil
		and target.castbarInside == nil and target.castbarTextX == 3, style .. ": the Frames cast icon and inside keys go, the cast text nudge stays")
	assert(target.style == nil and player.style == nil, style .. ": a wide bar or vitals line style, which draws the slab, becomes the slab default")
	assert(db.profiles.Other.UnitFrames.player.style == "column", style .. ": a style that is already the default stays")
	assert(bars.bar2.split == nil and bars.bar3.split == "on", style .. ": the Orbs split choice becomes Never; Always stays")
	assert(db.profiles.Other.DataBars.strip.placement == "dock", style .. ": Top, which docks under the bars like Dock, becomes Dock")
	assert(db.profiles.Other.Skins.contextMenus.enabled == false, style .. ": Glass cards kept Blizzard's context menus; the Skins switch keeps them")
	assert(#env._errors == 0, tostring(env._errors[1]))
	local again, AK = CoreEnv.New({ saved = CoreEnv.DeepCopy(db) })
	CoreEnv.Boot(again)
	assert(not CoreEnv.Printed(again, MESSAGE) and AK.Store.DB_VERSION == again.KstyleUIDB.version, style .. ": the next login says nothing")
end

local env = Boot("medallions")
assert(not CoreEnv.Printed(env, MESSAGE), "a Medallions profile moves nowhere, so nothing is said")
assert(env.KstyleUIDB.profiles.Default.HudStyle == nil and env.KstyleUIDB.layouts.Default["medallions:actionbars.bar1"].x == -12, "its saved style key goes and its positions stay")
-- An old export only previewed or decoded changes nothing live and says nothing; its retired positions are gone.
do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local slot = { ["orbs:actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 90 }, ["medallions:actionbars.bar1"] = { anchor = "BOTTOM", x = -12, y = 40 } }
	local text = CoreEnv.CraftLua({ kind = "KstyleUI profile", version = 44, name = "Shared", settings = { HudStyle = { style = "orbs" } }, layout = CoreEnv.DeepCopy(slot), namedLayouts = { MyHUD = CoreEnv.DeepCopy(slot) } })
	local start = #env._printed
	for _ = 1, 2 do assert(K.Profiles.Preview(text)) end
	assert(#env._printed == start, "previewing an old export prints nothing: " .. tostring(env._printed[start + 1]))
	assert(K.Store.ProfileName() == "Default", "a preview leaves the active profile alone")
	local decoded = assert(K.Store.Decode(text))
	assert(#env._printed == start, "decoding an old export prints nothing")
	assert(decoded.layout["orbs:actionbars.bar1"] == nil and decoded.namedLayouts.MyHUD["orbs:actionbars.bar1"] == nil
		and decoded.namedLayouts.MyHUD["medallions:actionbars.bar1"].x == -12, "a decoded old export loses its Orbs positions, named layouts included")
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("store medallions only ok")
