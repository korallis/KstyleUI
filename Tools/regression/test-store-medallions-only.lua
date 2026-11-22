-- test-store-medallions-only.lua: migration 45 moves Orbs and implicit Frames profiles to Medallions and leaves a saved Frames choice with its keys, says so once on live data and never on a preview, drops the keys and positions only they read (named layouts and exports too), folds choices that now draw the same and keeps the rest; migration 46 drops the forged ornament and card material keys from staging's version 45 data and exports.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local MESSAGE = "Your HUD moved to Medallions. Played on Frames? Pick it again under HUD style at the top of the settings window's General page."

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
				Widgets = { ornaments = "Subtle", cardMaterial = "Slate", panelOpacity = 0.8 },
				OptionsPresentation = { samples = false, tasks = false },
			},
			Other = { HudStyle = { style = style }, DataBars = { strip = { placement = "top" } }, UnitFrames = { player = { style = "column" } }, Widgets = { cardMaterial = "Glass" } },
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

for _, style in ipairs({ "orbs" }) do
	local env, K = Boot(style)
	local db, profile = env.KstyleUIDB, env.KstyleUIDB.profiles.Default
	assert(db.version == K.Store.DB_VERSION, style .. ": the store reaches the current version")
	local said = 0
	for _, line in ipairs(env._printed) do
		if line:find(MESSAGE, 1, true) then said = said + 1 end
	end
	assert(said == 1, style .. ": the move is announced once, got " .. said)
	assert(K.HudStyle.Current() == "medallions", style .. ": the profile runs Medallions")
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
	assert(profile.Widgets.ornaments == "Full" and profile.Widgets.cardMaterial == "ForgedBrackets" and profile.Widgets.panelOpacity == 0.8, style .. ": the ornament level and card material go back to their defaults, panel opacity stays")
	assert(db.profiles.Other.Widgets.cardMaterial == nil, style .. ": a Glass card material goes once the Skins switch holds it")
	assert(profile.OptionsPresentation.samples == true and profile.OptionsPresentation.tasks == false, style .. ": the ornament samples switch goes back to its default, the other window choices stay")
	assert(#env._errors == 0, tostring(env._errors[1]))
	local again, AK = CoreEnv.New({ saved = CoreEnv.DeepCopy(db) })
	CoreEnv.Boot(again)
	assert(not CoreEnv.Printed(again, MESSAGE) and AK.Store.DB_VERSION == again.KstyleUIDB.version, style .. ": the next login says nothing")
end

do
	local env, K = Boot("frames")
	local profile = env.KstyleUIDB.profiles.Default
	assert(not CoreEnv.Printed(env, MESSAGE) and K.HudStyle.Current() == "frames", "a saved Frames choice stays Frames and nothing is said")
	assert(profile.ActionBars.useTray == true and profile.CombatText.fieldDistance == 60 and profile.UnitFrames.target.castbarInside == true
		and profile.UnitFrames.target.style == "bar" and profile.DataBars.strip.height == 20, "and keeps the keys Frames reads")
	assert(profile.UnitFrames.orbGlass == nil and profile.ActionBars.bar2.split == nil and profile.Chat.framing == nil, "while the Orbs-only keys still go")
	assert(env.KstyleUIDB.profiles.Other.DataBars.strip.placement == "top", "a Frames profile keeps its top data bar")
	local layout = env.KstyleUIDB.layouts.Default
	assert(layout["frames:unitframes.player"].x == -200 and layout["orbs:actionbars.bar1"] == nil, "its layout keeps the Frames positions and loses the Orbs ones")
	assert(profile.Nameplates.name.size == 16 and profile.GroupFrames.party.portrait == false and profile.DataBars.xp.text == "levelRested"
		and profile.DataBars.strip.height == 20, "the values Frames drew before the Medallions look became the defaults are written where nothing was saved")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local env = Boot("medallions")
assert(not CoreEnv.Printed(env, MESSAGE), "a Medallions profile moves nowhere, so nothing is said")
assert((env.KstyleUIDB.profiles.Default.HudStyle or {}).style ~= "orbs" and env.KstyleUIDB.layouts.Default["medallions:actionbars.bar1"].x == -12, "its saved style key goes and its positions stay")
-- An old export only previewed or decoded changes nothing live and says nothing; its retired positions are gone.
do
	local penv, K = CoreEnv.New()
	CoreEnv.Boot(penv)
	local slot = { ["orbs:actionbars.bar1"] = { anchor = "BOTTOM", x = 0, y = 90 }, ["medallions:actionbars.bar1"] = { anchor = "BOTTOM", x = -12, y = 40 } }
	local text = CoreEnv.CraftLua({ kind = "KstyleUI profile", version = 44, name = "Shared", settings = { HudStyle = { style = "orbs" }, Widgets = { ornaments = "Full", cardMaterial = "Slate" } }, layout = CoreEnv.DeepCopy(slot), namedLayouts = { MyHUD = CoreEnv.DeepCopy(slot) } })
	local start = #penv._printed
	for _ = 1, 2 do assert(K.Profiles.Preview(text)) end
	assert(#penv._printed == start, "previewing an old export prints nothing: " .. tostring(penv._printed[start + 1]))
	assert(K.Store.ProfileName() == "Default", "a preview leaves the active profile alone")
	local decoded = assert(K.Store.Decode(text))
	assert(#penv._printed == start, "decoding an old export prints nothing")
	assert(decoded.layout["orbs:actionbars.bar1"] == nil and decoded.namedLayouts.MyHUD["orbs:actionbars.bar1"] == nil
		and decoded.namedLayouts.MyHUD["medallions:actionbars.bar1"].x == -12, "a decoded old export loses its Orbs positions, named layouts included")
	assert(decoded.settings.Widgets.ornaments == nil and decoded.settings.Widgets.cardMaterial == nil, "a decoded old export loses its ornament level and card material")
	assert(#penv._errors == 0, tostring(penv._errors[1]))
end
-- Staging saved and exported version 45 with the ornament level, card material and samples switch still in place: migration 46 drops them and keeps a context-menu choice made since 45.
do
	local STAGING = "KSUI1:S1NMMToxNzQ6MjA3NDg4NjYyNzp7czQ6a2luZHMxNjpLc3R5bGVVSSBwcm9maWxlczY6bGF5b3V0e31zNDpuYW1lczc6RGVmYXVsdHM4OnNldHRpbmdze3MxOTpPcHRpb25zUHJlc2VudGF0aW9ue3M3OnNhbXBsZXNGfXM3OldpZGdldHN7czEyOmNhcmRNYXRlcmlhbHM1OkdsYXNzczk6b3JuYW1lbnRzczM6T2ZmfX1zNzp2ZXJzaW9ubjQ1O30="
	local senv, K = CoreEnv.New({ saved = { version = 45, profiles = { Default = {
		Widgets = { ornaments = "Off", cardMaterial = "Glass", panelOpacity = 0.8 }, OptionsPresentation = { samples = false, tasks = false }, Skins = { contextMenus = { enabled = true } },
	} } } })
	CoreEnv.Boot(senv)
	local profile = senv.KstyleUIDB.profiles.Default
	assert(profile.Widgets.ornaments == "Full" and profile.Widgets.cardMaterial == "ForgedBrackets" and profile.Widgets.panelOpacity == 0.8
		and profile.OptionsPresentation.samples == true and profile.OptionsPresentation.tasks == false, "a version 45 database loses the retired values to the defaults and keeps the rest")
	assert(profile.Skins.contextMenus.enabled == true, "context menus turned back on after migration 45 stay on")
	local decoded, err = K.Store.Decode(STAGING)
	assert(decoded, "a staging export at version 45 decodes: " .. tostring(err))
	assert(decoded.settings.Widgets.ornaments == nil and decoded.settings.Widgets.cardMaterial == nil and decoded.settings.OptionsPresentation.samples == nil, "and loses its retired keys")
	local ok, name = K.Store.Import(STAGING)
	assert(ok and K.Store.Decode(assert(K.Store.Export(name))), "the imported staging profile exports and decodes again")
	assert(#senv._errors == 0, tostring(senv._errors[1]))
end
print("store medallions only ok")
