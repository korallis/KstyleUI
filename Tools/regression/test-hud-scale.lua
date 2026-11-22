-- test-hud-scale.lua: the HUD's default scale and canvas, the LEE-20 picture's centre sizes, and the unchanged optional bar and migration contracts.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local C = dofile("Tools/regression/cooldowns_env.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- The owner's client: 2383 by 1540 at WoW's default UI scale, 768 / 1080.
local OWNER = { width = 2383, height = 1540, uiScale = 768 / 1080, size = "default" }
local BLIZZARD_BUTTON, ELVUI_BUTTON = 45, 32

-- The default size: 16 / 19, so a 38-unit button is 32 UIParent units at WoW's default UI scale ------------------
do
	local env, K = CoreEnv.New(OWNER)
	CoreEnv.Boot(env)
	local Scale, Layouts = K.Scale, K.Setup.Layouts
	local default = Scale.DEFAULT_USER_SCALE
	assert(type(default) == "number" and near(default, 16 / 19), "the default size is 16 / 19, got " .. tostring(default))
	assert(K.Appearance.defaults.uiScale == default and near(Scale.UserScale(), default), "Appearance starts at that size")
	assert(Scale.MIN_USER_SCALE <= 0.65 and Scale.MAX_USER_SCALE >= 1.5, "the size slider still reaches smaller and back past the old size")
	local button = Layouts.BUTTON
	assert(button == 38, "the optional action bars retain the 38-unit module")
	local rootToParent = Scale.Root():GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	assert(near(button * rootToParent, 32, 1e-3), "a 38-unit button is 32 UIParent units, got " .. button * rootToParent)
	-- Pixels on the owner's screen: UIParent is 1080 units tall on 1540 pixels.
	local px = OWNER.height / 1080
	local before, after = button * px, button * rootToParent * px
	local blizzard, elvui = BLIZZARD_BUTTON * px, ELVUI_BUTTON
	assert(near(before, 54.19, 0.01) and near(after, 45.63, 0.01), string.format("the button was 54.2 px and is 45.6 px, got %.2f and %.2f", before, after))
	assert(after < before and after > elvui and after < blizzard, string.format("between ElvUI's %d px and Blizzard's %.1f px", elvui, blizzard))
	-- The text stays legible: KstyleUI's smallest role, the 11-unit caption, keeps at least 13 pixels.
	assert(K.Tokens.Size("caption") * rootToParent * px >= 13, "the caption keeps 13 px on the owner's screen")
	-- The layouts are drawn on the canvas the default size gives: 1080 / (16 / 19) units tall.
	assert(near(Layouts.HEIGHT, 1080 / default), "Layouts.HEIGHT is the default canvas, got " .. tostring(Layouts.HEIGHT))
	local _, rh = K.Layout.RootSize()
	assert(near(rh, Layouts.HEIGHT, 1e-3), "the root is that tall at the default size, got " .. tostring(rh))
end

-- LEE-20: essential icons match the central action tiles; utility and tracked buff rows have distinct sizes. -----
do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	assert(near(Layouts.Element("actionbars.bar1").height, 38 * 19 / 16), "bar 1 takes the KSTY-44 tray's 38 px tile")
	assert(near(Layouts.Element("cooldowns.essential").height, 36.7), "LEE-20 essential icons keep the 36.7 action tile")
	assert(near(Layouts.Element("cooldowns.utility").height, 38), "optional utility icons retain their 38-unit height")
	assert(near(Layouts.Element("cooldowns.buffs").height, 41.6), "LEE-20 tracked buffs reserve their icons and timer row")
	assert(near(Layouts.Element("cooldowns.essential").width, 6 * 36.7 + 5 * 4.6), "LEE-20 six essential icons at the 41.3-unit action pitch")
	assert(Layouts.Element("cooldowns.utility").width == 4 * 38 + 3 * 3, "four utility icons at the bars' pitch")
	assert(near(Layouts.Element("cooldowns.buffs").width, 6 * 27.6 + 5 * 3.4), "LEE-20 tracked buffs reserve six smaller icons at 31-unit pitch")
	assert(Layouts.Element("cooldowns.bars").width == 243, "optional tracked buff bars retain their 243-unit width")
end
do
	local _, _, ns = C.New()
	local _, _, abns = AB.New()
	local d = ns.Settings.defaults
	local button = abns.defaults.bar1.size
	assert(near(button, 38 * 19 / 16) and near(abns.defaults.bar1.spacing, 3 * 19 / 16), "bar 1's tiles are the KSTY-44 tray's 38 px with 3 px gaps at 1080p")
	assert(near(abns.defaults.bar2.size, button) and near(abns.defaults.bar2.spacing, abns.defaults.bar1.spacing), "bar 2 matches bar 1's pitch")
	assert(abns.defaults.bar2.enabled and abns.defaults.bar1.showEmpty and abns.defaults.bar2.showEmpty, "LEE-20 both action rows show their empty tiles by default")
	local sizes = { essential = { 36.7, 4.6 }, utility = { 38, 3 }, buffs = { 27.6, 3.4 } }
	for group, want in pairs(sizes) do
		assert(near(d[group].size, want[1]), "LEE-20 " .. group .. " icons have their reference size")
		assert(near(d[group].spacing, want[2]), "LEE-20 " .. group .. " icons have their reference gap")
	end
	assert(d.bars.width == 6 * 38 + 5 * 3, "the optional mirrored buff bars retain their original width")
end

-- The action bar grids: bars 2 and 3 are rows of twelve like bar 1 at the KSTY-44 gap; bars 4 to 6 are columns -----
do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	for _, key in ipairs({ "actionbars.bar2", "actionbars.bar3" }) do
		local grid = Layouts.Grid(key)
		assert(grid.rows == 1, key .. " is one row of twelve, like bar 1")
	end
	assert(near(Layouts.Grid("actionbars.bar1").spacing, 3 * 19 / 16) and near(Layouts.Grid("actionbars.bar2").spacing, 3 * 19 / 16), "the central grids expose the KSTY-44 tray's gap")
	for _, key in ipairs({ "actionbars.bar4", "actionbars.bar5", "actionbars.bar6" }) do
		assert(Layouts.Grid(key).rows == 12, key .. " is a column of twelve")
	end
end

-- A layout reset or a first registration puts the sigil on the cluster at any size, as Apply does --------------
do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	local _, rh = K.Layout.RootSize()
	assert(near(rh, 1080), "this test runs at size 1, where the root is 1080 units tall")
	local default, applied = Layouts.Default("unitframes.target"), Layouts.Get("DPS", rh)["unitframes.target"]
	assert(default.anchor == applied.anchor and near(default.y, applied.y), "Default follows the live root as Apply does, got " .. default.y .. " for " .. applied.y)
	assert(near(Layouts.Default("unitframes.player").y, Layouts.Get("DPS")["unitframes.player"].y), "an element placed from the bottom needs no lift")
end

-- Saved layouts from before owner pass 1 move with the layouts (Store migration 7) ------------------------------
-- Store drops a position equal to its default, so DPS positions follow the new layouts by themselves; a Healer or
-- Tank profile keeps the positions where it differed (the group frames over the old cluster, the threat card), and
-- those would sit on the risen sigil. A position the player moved stays where the player put it.
do
	local function saved(preset, layout, size)
		return {
			version = 5,
			profiles = { Default = { Layout = { preset = preset }, Appearance = size and { uiScale = size } or nil } },
			layouts = { Default = layout },
		}
	end
	local env, K = CoreEnv.New({ size = "default", saved = saved("Healer", {
		["groupframes.party"] = { anchor = "BOTTOM", x = -311, y = 466 },
		["groupframes.raid"] = { anchor = "BOTTOM", x = -311, y = 466, width = 318, height = 487 },
		["combattext.player"] = { anchor = "BOTTOM", x = 232, y = 466 },
		-- Layout saves only the fields that differ from the default: bar 3's y was the old DPS default's -28.
		["actionbars.bar3"] = { anchor = "TOPRIGHT", x = -362 },
		["unitframes.focus"] = { anchor = "BOTTOM", x = -400, y = 300 },
		["unitframes.target"] = { anchor = "TOP", x = 0, y = -630 },
	}) })
	CoreEnv.Boot(env)
	local Layouts = K.Setup.Layouts
	assert(env.KstyleUIDB.version >= 7, "the saved data is upgraded")
	local layout, healer = env.KstyleUIDB.layouts.Default, Layouts.Get("Healer")
	for _, key in ipairs({ "groupframes.party", "groupframes.raid", "combattext.player", "actionbars.bar3", "unitframes.target" }) do
		local got, want = layout[key], healer[key]
		assert(got.anchor == want.anchor and near(got.x, want.x) and near(got.y, want.y), key .. " moves to the Healer layout's new place, got " .. got.anchor .. " " .. got.x .. " " .. got.y)
	end
	assert(layout["groupframes.raid"].width == 318 and layout["groupframes.raid"].height == 487, "a saved size stays")
	local focus = layout["unitframes.focus"]
	assert(focus.x == -400 and focus.y == 300, "a position the player moved stays")
	-- A profile at size 1 gets the sigil placed for a 1080-unit root.
	env, K = CoreEnv.New({ saved = saved("DPS", { ["unitframes.target"] = { anchor = "TOP", x = 0, y = -630 }, ["meters.threat"] = { anchor = "BOTTOM", x = 357, y = 312 } }, 1) })
	CoreEnv.Boot(env)
	layout = env.KstyleUIDB.layouts.Default
	assert(near(layout["unitframes.target"].y, K.Setup.Layouts.Get("DPS", 1080)["unitframes.target"].y), "at size 1 the sigil is placed on a 1080-unit root")
	local threat = layout["meters.threat"] or K.Setup.Layouts.Get("DPS")["meters.threat"]
	local tank = K.Setup.Layouts.Get("Tank")["meters.threat"]
	assert(threat.x == tank.x and threat.y == tank.y, "a position from another preset's old place moves with that preset")
end

print("hud scale ok")
