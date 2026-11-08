-- gallery_actionbars.lua: KstyleUI_ActionBars' frames in a filled state, each cropped as one frame of the gallery:
-- bar 1 paged to the vehicle bar with the leave button beside it, the flyout open above a bar 2 button, a close
-- crop of a bar's backing strip, the pet bar with autocast marks, the stance bar with Battle stance selected,
-- bar 3 as the vertical column without a backing strip, and the settings window's live preview.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local ICON_SET = "B"
-- Warrior stances and pet abilities from Blizzard's icon table, by file ID.
local STANCES = { battle = 132349, defensive = 132341, berserker = 132275 }
local PET = { attack = 132152, follow = 132270, stay = 132111, bite = 132127, claw = 132159, growl = 136100, dash = 135744 }
local FLYOUT_ID = 9
local FLYOUT_SLOT = 63
local VEHICLE_PAGE = 12

-- place(frame, x, y) pins a Layout holder at a screen position; the bars are Layout elements, so the scene
-- moves their holders rather than the secure headers.
local function place(frame, x, y)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
end

return Common.Run(function()
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local saved = Gallery.Saved({
		ActionBars = { bar3 = { enabled = true } },
		Icons = Common.IconsSection(ICON_SET),
	})
	local env, K, ns = AB.New({
		class = "WARRIOR",
		width = Common.SCREEN.width,
		height = Common.SCREEN.height,
		saved = saved,
		setup = function(env)
			Gallery.Setup(env)
			Common.InstallAddOns(env)
			local g = env._game
			local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
			local keys2 = { "Q", "W", "E", "R", "T", "Y", "V", "I", "O", "P", "L", "K" }
			for i = 1, 12 do
				g.bindings["ACTIONBUTTON" .. i] = { keys[i] }
				g.bindings["MULTIACTIONBAR1BUTTON" .. i] = { keys2[i] }
			end
			for i = 1, 10 do
				g.bindings["BONUSACTIONBUTTON" .. i] = { "CTRL-" .. (i % 10) }
				g.bindings["SHAPESHIFTBUTTON" .. i] = { "F" .. i }
			end
			env.GetBindingText = function(key)
				return key
			end
			-- A vehicle: bar 1 pages to the vehicle bar and the leave button shows.
			env.CanExitVehicle = function()
				return true
			end
			env.VehicleExit = function() end
			-- A hunter's pet with seven commands, two of them autocasting, attack active.
			g.petExists = true
			g.pet[1] = { name = "PET_ACTION_ATTACK", texture = PET.attack, isActive = true }
			g.pet[2] = { name = "PET_ACTION_FOLLOW", texture = PET.follow }
			g.pet[3] = { name = "PET_ACTION_WAIT", texture = PET.stay }
			g.pet[4] = { name = "Bite", texture = PET.bite, spellID = 17253, autoCastAllowed = true, autoCastEnabled = true }
			g.pet[5] = { name = "Claw", texture = PET.claw, spellID = 16827, autoCastAllowed = true, autoCastEnabled = true }
			g.pet[6] = { name = "Growl", texture = PET.growl, spellID = 2649, autoCastAllowed = true, autoCastEnabled = false }
			g.pet[7] = { name = "Dash", texture = PET.dash, spellID = 23099, autoCastAllowed = true, autoCastEnabled = false }
			-- The warrior's three stances, Battle stance active.
			g.forms = {
				{ texture = STANCES.battle, spellID = 2457, isActive = true },
				{ texture = STANCES.defensive, spellID = 71 },
				{ texture = STANCES.berserker, spellID = 2458 },
			}
			-- A flyout of four shouts on bar 2, slot 3.
			g.flyouts[FLYOUT_ID] = {
				name = "Shouts",
				slots = {
					{ spellID = 6673, name = "Battle Shout" },
					{ spellID = 1160, name = "Demoralizing Shout" },
					{ spellID = 5242, name = "Battle Shout" },
					{ spellID = 18499, name = "Berserker Rage" },
				},
			}
			local textures = { [6673] = I.battleShout, [1160] = I.demoralizingShout, [5242] = I.battleShout, [18499] = I.berserkerRage }
			env.C_Spell.GetSpellTexture = function(id)
				return textures[id] or I.heroicStrike
			end
		end,
	})
	env._time = 10
	env.GetTime = function()
		return env._time
	end
	AB.Enable(env, K)
	local g = env._game
	-- Bar 1 in its own page, then the vehicle page it shows while the player drives.
	for i, icon in ipairs(Hud.BAR1) do
		if icon then
			g.slots[i] = { texture = icon, type = "spell", id = 1000 + i }
		end
	end
	local vehicle = { I.charge, I.thunderClap, I.intercept, I.shieldBash, I.pummel, I.taunt }
	for i, icon in ipairs(vehicle) do
		g.slots[(VEHICLE_PAGE - 1) * 12 + i] = { texture = icon, type = "spell", id = 3000 + i }
	end
	for i, icon in ipairs(Hud.BAR2) do
		g.slots[60 + i] = { texture = icon, type = "spell", id = 2000 + i }
	end
	g.slots[FLYOUT_SLOT] = { texture = I.battleShout, type = "flyout", id = FLYOUT_ID }
	for i = 1, 12 do
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", i)
		env.FireEvent("ACTIONBAR_SLOT_CHANGED", 60 + i)
	end
	env.RunTimers()
	-- Bar 1 pages to the vehicle bar, as the state driver would in a vehicle, and the leave button appears.
	local bar1, bar2, bar3, pet, stance = ns.bars.bar1, ns.bars.bar2, ns.bars.bar3, ns.bars.pet, ns.bars.stance
	bar1.header:SetAttribute("actionpage", VEHICLE_PAGE)
	env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
	env.RunTimers()
	assert(ns.leaveButton and ns.leaveButton:IsShown(), "the leave-vehicle button shows")
	-- Bar 3 was switched on through the saved profile; a bar that starts off is built on its first switch on.
	assert(bar3, "bar 3 is built")
	-- The flyout opens above its button, as a click does in the game, through the secure snippet the stub runs.
	local owner = AB.Button(ns, "bar2", 3)
	AB.Click(env, owner, "LeftButton", true)
	AB.Click(env, owner, "LeftButton", false)
	local flyout = ns.flyout
	assert(flyout and flyout.frame:IsShown(), "the flyout is open")

	-- Lay the bars out across the screen, not where the HUD puts them.
	place(bar1.holder, 60, 140)
	place(bar2.holder, 60, 420)
	place(pet.holder, 60, 540)
	place(stance.holder, 60, 620)
	place(bar3.holder, 700, 80)

	-- The preview on a plain frame, as the settings window shows it.
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(500, 60)
	place(parent, 800, 100)
	local preview = K.Options.Preview("ActionBars")(parent)
	preview:Refresh()

	env.RunTimers()
	AB.W.Settle(env)

	local frames = Gallery.Frames()
	local leave = ns.leaveButton
	frames:Add(env, bar1.holder, {
		name = "actionbars_vehicle", title = "Vehicle bar and leave button", grade = "button", reference = "actionbars",
		caption = "Bar 1 paged to the vehicle bar (Bar.lua, page 12 of the state driver) on its backing strip, with Vehicle.lua's leave button beside it: a primary IconButton showing the close glyph.",
		match = "Buttons wear the mockup's body, bezel, class-colour rim and shadow; the leave button is the same IconButton with a glyph instead of an icon. The backing strip is the mockup's opaque #101214 band with the light edge line (see actionbars_bar_backing).",
		rect = Gallery.Union(env, { bar1.backing, leave }),
	})
	frames:Add(env, flyout.frame, {
		name = "actionbars_flyout", title = "Spell flyout", grade = "button", reference = "actionbars",
		caption = "Flyout.lua open above bar 2's third button: four IconButtons in a column, each on the button grade with the accent rim; the flyout frame itself draws nothing, so the buttons sit on the scene with no panel behind them.",
		match = "Each flyout button matches the mockup's action buttons (body #101214, bezel, rim, shadow); the mockup has no open flyout, and the frame has no backing of its own.",
		rect = Gallery.Union(env, { flyout.frame, owner }),
	})
	local bx, by, _, bh = Scene.Rect(env, bar1.backing)
	frames:Add(env, bar1.backing, {
		name = "actionbars_bar_backing", title = "Bar backing strip", grade = "button", reference = "actionbars",
		caption = "A close crop of the left end of bar 1's backing strip (Bar.lua:52): the button grade's opaque buttonFill body as a tile chrome with 10-unit chamfered ends, 3 units beyond the buttons, the two-line edge and no shadow.",
		match = "Fill, reach and ends as the theme spec measured on the mockup's strip: opaque #101214, 3 units above and below the buttons, 10-unit ends, the light edge line; the mockup's line is a little brighter at the ends (lum 94) than the kit's edgeInner over this body.",
		rect = { x = bx, y = by, w = 130, h = bh },
		pad = 10,
	})
	frames:Add(env, pet.holder, {
		name = "actionbars_pet", title = "Pet bar", grade = "button", reference = "actionbars",
		caption = "The pet bar: ten 30-unit IconButtons, attack selected, Bite and Claw with the accent autocast dot, Growl and Dash with autocast off, three slots empty; the backing strip is off by default for the pet bar, so the buttons' bezels meet in one dark band.",
		match = "Buttons as the mockup's action buttons at 30 units; the mockup shows no pet bar, so the empty tiles and autocast marks have no reference.",
		rect = Gallery.Union(env, { pet.backing }),
	})
	frames:Add(env, stance.holder, {
		name = "actionbars_stance", title = "Stance bar", grade = "button", reference = "actionbars",
		caption = "The stance bar: Battle, Defensive and Berserker stance as 30-unit IconButtons, Battle stance selected with the full accent rim; no backing strip by default, the bezels meet in one band.",
		match = "Buttons as the mockup's action buttons at 30 units; the selected state lights the rim to the accent.",
		rect = Gallery.Union(env, { stance.backing }),
	})
	frames:Add(env, bar3.holder, {
		name = "actionbars_bar3", title = "Action bar 3", grade = "button", reference = "actionbars",
		caption = "Bar 3 switched on at its default shape: a column of twelve empty IconButtons with no backing strip, the default for bars 3 to 6.",
		match = "Empty tiles: body #101214, bezel and the plain edgeInner hairline, as the mockup's buttons without their icons and class-colour rim.",
	})
	frames:Add(env, parent, {
		name = "actionbars_preview", title = "Action bars preview", grade = "button", reference = "actionbars",
		caption = "Preview.lua in the settings window: plain primary IconButtons for the bar being edited, with a proc glow, a cooldown swipe, out-of-range and no-power tints and a stack count.",
		match = "Buttons as the mockup's action buttons: body, bezel, class-colour rim and shadow; the states are the kit's own.",
	})

	local scene = Scene.Build(env, { time = env._time, iconDirs = Common.IconDirs(ICON_SET) })
	scene.log[#scene.log + 1] = "bar 1 shows the vehicle page by a direct actionpage write; the game's state driver sets it in a vehicle"
	return frames:Finish(scene, env, K, "gallery actionbars")
end)
