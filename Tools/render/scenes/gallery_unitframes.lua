-- gallery_unitframes.lua: every unit frame in its Lumen style, each cropped as one frame of the gallery, at the
-- footprints S6 gives them: the player's vitals line mid-cast with its gilt ring and level disc, the target's sigil
-- with your three debuffs centred under it and its gold cast line, the boss column's five compact cards (the first
-- casting, with aggro; the second your target, marked Targeted while the sigil carries its cast),
-- the focus card, the pill rows (focus target, target of target, the pet with its power pill), a rogue's combo points
-- (the class resource, in its own environment), and the options page's live preview on the sigil.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local HUD_KEYS = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local FOCUS_SPELL, BOSS_SPELL, PLAYER_SPELL, TARGET_SPELL = 6343, 1680, 1464, 5000
local DEBUFF_ICONS = { I.rend, I.sunderArmor, I.hamstring }
local MAGIC = "rare"

local UNITS = {
	player = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350, power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5,
		cast = { name = "Slam", texture = I.slam, start = 8500, finish = 11000, spellID = PLAYER_SPELL } },
	target = { name = "Bloodtalon Matriarch", level = 38, classification = "elite", creature = "Beast", health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true,
		cast = { name = "Terrifying Screech", texture = I.demoralizingShout, start = 8800, finish = 11800, spellID = TARGET_SPELL } },
	targettarget = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350, power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 },
	focus = { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true,
		cast = { name = "Thunder Clap", texture = I.thunderClap, start = 8500, finish = 11500, spellID = FOCUS_SPELL } },
	focustarget = { name = "Krazhk", level = 38, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	pet = { name = "Rasha", level = 37, health = 1460, healthMax = 2000, power = 80, powerMax = 100, powerType = 2, powerToken = "FOCUS", reaction = 5 },
	boss1 = { name = "Magmatus", level = 40, classification = "elite", health = 72000, healthMax = 100000, power = 40, powerMax = 100, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, threatOn = 3,
		cast = { name = "Whirlwind", texture = I.whirlwind, start = 9000, finish = 12000, spellID = BOSS_SPELL } },
	boss2 = { name = "Ashen Warden", level = -1, classification = "worldboss", health = 48000, healthMax = 100000, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	boss3 = { name = "Cinder Shade", level = -1, classification = "worldboss", health = 91000, healthMax = 100000, power = 65, powerMax = 100, powerType = 3, powerToken = "ENERGY", reaction = 2, canAttack = true },
	boss4 = { name = "Emberling", level = -1, classification = "worldboss", health = 30000, healthMax = 100000, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	boss5 = { name = "Smoulder", level = -1, classification = "worldboss", health = 100000, healthMax = 100000, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
}

local ROGUE = { name = "Valerin", class = "ROGUE", level = 38, health = 2750, healthMax = 3350, power = 70, powerMax = 100, powerType = 3, powerToken = "ENERGY", isPlayer = true, reaction = 5 }

local function move(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

local function hide(K, keys)
	for _, key in ipairs(keys) do
		assert(K.Layout.Set(key, "shown", "never"))
	end
end

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	frame:SetSize(w, h)
end

-- UnitClass by unit, so NPCs have no class and the player is the class the scene gives them.
local function unitClasses(env)
	env.UnitClass = function(token)
		local u = env._units[token]
		if u and u.class then
			return u.class:sub(1, 1) .. u.class:sub(2):lower(), u.class, 1
		end
	end
end

-- The stub draws no portraits: the mockup's faces, cut by standins.py, stand in; a flat tone otherwise.
local function portraits(env)
	local flat = false
	for texture, token in pairs(env._portraits) do
		local u = env._units[token]
		local file = Common.StandIn(u and u.isPlayer and "portrait-player.png" or "portrait-target.png")
		if file then
			texture:SetTexture(file)
		else
			texture:SetColorTexture(0.33, 0.28, 0.22, 1)
			flat = true
		end
	end
	return flat and "portraits are flat stand-ins; run Tools/render/standins.py for the mockup's faces" or "portraits are crops of the mockup; the game draws the unit's model"
end

local function errors(scene, env, K)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
end

-- The class resource needs a rogue, so it draws in its own environment: everything else hidden, the pips moved
-- under the other frames.
local function resource(frames, x, y)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "UnitFrames" }),
		setup = function(env)
			Gallery.Setup(env)
			env.RAID_CLASS_COLORS.ROGUE = { r = 1, g = 0.96, b = 0.41 }
			env._units.player = ROGUE
			env._units.target = UNITS.target
			unitClasses(env)
		end,
	}))
	env._time = 10
	env.SetTarget(true)
	env._comboPoints = 3
	env.FireEvent("COMBO_TARGET_CHANGED")
	env.RunTimers()
	hide(K, HUD_KEYS)
	hide(K, { "unitframes.targettarget", "unitframes.pet", "unitframes.focus", "unitframes.focustarget", "unitframes.boss" })
	move(K, "unitframes.resource", x, y)
	Gallery.Ticks(U.W, env, 20)
	local state = ns.Resource.state
	assert(state.showCombo and state.content:IsShown(), "the rogue's combo points show")
	frames:Add(env, state.holder, {
		name = "unitframes_resource", title = "Class resource", grade = "bar", reference = "xp",
		caption = "The class resource under a rogue's player frame: five combo point pips, three lit in the rogue's class colour; each pip is a one-point status bar on a dot, its empty disc the button body.",
		match = "Draws no chrome of its own: the empty pips are buttonFill discs, the bar grade's dark track, as the mockup's experience bar track; the mockup shows a warrior, so it has no combo points to compare.",
	})
	local scene = Gallery.Build(env, { time = env._time })
	errors(scene, env, K)
	return scene
end

local FOOTPRINTS = {
	{ "unitframes.player", 60, 80, 490, 80 },
	{ "unitframes.target", 600, 70, 490, 84 },
	{ "unitframes.focus", 60, 250, 200, 90 },
	{ "unitframes.focustarget", 60, 400, 120, 22 },
	{ "unitframes.targettarget", 220, 400, 120, 22 },
	{ "unitframes.pet", 380, 400, 120, 22 },
	{ "unitframes.boss", 1360, 70, 258, 334 },
}

-- Debuff stand-ins: the engine lays its buttons out in the game; here the scene places the fake engine's three debuff
-- buttons where the AuraContainer would, centred under the sigil, with timers under each socket.
local function sockets(env, K, ns, view, timers, magic)
	local Widgets, Tokens = K.Widgets, K.Tokens
	local a = view.auras
	assert(a and a.container and a.host:IsShown(), view.kind .. " has shown auras")
	local size, spacing = Widgets.Snap(a.host, ns.Settings.Value(view.kind, "auraSize")), Widgets.Snap(a.host, ns.Settings.Value(view.kind, "auraSpacing"))
	local buttons = a.container._groups.debuffs.buttons
	a.container:SetSize(#buttons * size + (#buttons - 1) * spacing, size)
	local tiles = {}
	for i, button in ipairs(buttons) do
		local entry
		for _, e in ipairs(a.buttons) do
			if e.button == button then
				entry = e
			end
		end
		assert(entry, "the engine button is dressed")
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", a.container, "TOPLEFT", (i - 1) * (size + spacing), 0)
		button:SetSize(size, size)
		entry.icon:SetTexture(env.Secret(DEBUFF_ICONS[i]))
		Widgets.SetText(entry.count, i == 3 and "3" or "")
		Widgets.SetText(entry.timer, timers[i])
		if magic and i == 2 and entry.dispel then
			local r, g, b = Tokens.Color(MAGIC)
			Widgets.ShowSlice(entry.dispel, true)
			Widgets.ColorSlice(entry.dispel, r, g, b, 1)
		end
		tiles[i] = button
	end
	return tiles
end

return Common.Run(function()
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "UnitFrames" }),
		setup = function(env)
			Gallery.Setup(env)
			for token, unit in pairs(UNITS) do
				env._units[token] = unit
			end
			env._forms, env._form = { { 2457, "Battle Stance" } }, 1
			unitClasses(env)
		end,
	}))
	local root = K.Scale.Root()
	local frames = Gallery.Frames()
	env._time = 10
	for _, place in ipairs(FOOTPRINTS) do
		move(K, place[1], place[2], place[3])
		assert(K.Layout.Set(place[1], "width", place[4]) and K.Layout.Set(place[1], "height", place[5]), place[1] .. " takes its Lumen footprint")
	end
	K.Options.Write("UnitFrames", "pet.power", true)
	env.SetTarget(true)
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	env.FireEvent("UNIT_PET", "player")
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", PLAYER_SPELL)
	env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-1", TARGET_SPELL)
	env.FireEvent("UNIT_SPELLCAST_START", "focus", "Cast-1", FOCUS_SPELL)
	env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", BOSS_SPELL)
	env.RunTimers()
	hide(K, { "unitframes.resource", "unitframes.castbar.player", "unitframes.castbar.target" })
	local Frames = ns.Frames

	local player = Frames.Get("player").views[1]
	assert(player.button:IsShown() and player.geometry.form == "vitals" and player.castbar.active, "the vitals line shows and casts")
	frames:Add(env, player.button, {
		name = "unitframes_vitals", title = "Vitals line", grade = "bar", reference = "player",
		caption = "The player's vitals line at 490 by 80: a 62-unit round portrait in the gilt ring with the level disc on its lower right, the name in the heading face with the stance after it, the health value with its max right-aligned, the 12-unit class-coloured health pill over the 5-unit rage pill, and the cast line (Casting Slam, a thin gold-free pill) under the column.",
		match = "The Lumen mockup's centre floor (arena2/parent, board 1): ring 62, disc 22, name 17, value 15 over a muted 13-unit max, pills 12 and 5 four units apart; no glass behind it. The ring is the bevelled ring texture tinted gilt until S1's conic ring lands.",
		pad = 10,
	})

	local target = Frames.Get("target").views[1]
	assert(target.button:IsShown() and target.geometry.form == "sigil" and target.castbar.active, "the sigil shows with its cast line")
	local targetTiles = sockets(env, K, ns, target, { "14s", "9s", "21s" }, false)
	local sigilParts = { target.button }
	for _, tile in ipairs(targetTiles) do
		sigilParts[#sigilParts + 1] = tile
	end
	frames:Add(env, target.button, {
		name = "unitframes_sigil", title = "Target sigil", grade = "bar", reference = "target",
		caption = "The target's sigil at 490 units, as wide as the vitals line it sits over: the name centred in the heading face over a soft dark scrim, the level line (Level 38 elite and the creature type), the 12-unit hostile pill between two gems, the bold gold cast line centred under it (13-unit text, Locked in red when it cannot be interrupted), and your three debuffs as sockets centred under the sigil, each rimmed in the class colour with its timer underneath.",
		match = "The Lumen mockup's combat board: name 20, level line 13, gem 7 then 14 units to the pill, debuff sockets with timers under them. The gems are the rotated icon mask in gilt until S1's gem texture lands.",
		rect = Gallery.Union(env, sigilParts),
		pad = 10,
	})

	local focus = Frames.Get("focus").views[1]
	assert(focus.button:IsShown() and focus.geometry.form == "card" and focus.castbar.active, "the focus card shows and casts")
	frames:Add(env, focus.button, {
		name = "unitframes_focus", title = "Focus card", grade = "panel", reference = "player",
		caption = "The focus card at 200 by 90, beside the sigil in the combat cluster: the section cap (gem, FOCUS, a gilt rule, the level at its right), the name with the percentage on its row, the 10-unit hostile pill and the bold gold cast line inside the card, its debuffs in a row over it.",
		match = "The Lumen mockup's boss card language on today's glass: S1 turns the chamfered panel into the frost card with rounded corners.",
	})

	local boss = Frames.Get("boss")
	env._units.boss2 = env._units.target
	env.FireEvent("PLAYER_TARGET_CHANGED")
	local shown = {}
	for i = 1, 5 do
		assert(boss.views[i].button:IsShown() and boss.views[i].geometry.form == "card", "boss" .. i .. " shows as a card")
		shown[i] = boss.views[i].button
	end
	assert(boss.views[1].castbar.active, "boss1 casts")
	assert(boss.views[2].chip:IsShown() and boss.views[2].body:GetAlpha() < 0.5, "boss2, your target, folds to its Targeted chip")
	frames:Add(env, boss.holder, {
		name = "unitframes_boss", title = "Boss cards", grade = "panel", reference = "target",
		caption = "The boss column at 258 by 334: five compact cards 6 apart, each the name and percentage, a hostile pill and the cast line, no cap; Magmatus casts Whirlwind on its gold cast line and has aggro on the player; the Bloodtalon Matriarch is your target, so its card folds to a slim Targeted chip, as the sigil already shows its name, health and cast; the cards with no cast hug their pill.",
		match = "The Lumen mockup's boss card (combat board, right rail): cap 13, name 16 with 62% at its right, a 10-unit pill, then Casting and the spell in gold over a thin line.",
		rect = Gallery.Union(env, shown),
	})

	local rows = {}
	for _, kind in ipairs({ "focustarget", "targettarget", "pet" }) do
		local view = Frames.Get(kind).views[1]
		assert(view.button:IsShown() and view.geometry.form == "row", kind .. " shows as a pill row")
		rows[#rows + 1] = view.button
	end
	frames:Add(env, rows[1], {
		name = "unitframes_rows", title = "Pill rows", grade = "bar", reference = "nameplate",
		caption = "The compact frames as pill rows, 120 by 22: the focus target, the target of target (the player, in the class colour) and the pet with its power option on; the name and percentage over a 6-unit pill, no glass.",
		match = "The party rows of the Lumen mockup: name over a thin pill in the unit's colour, the value at the right.",
		rect = Gallery.Union(env, rows),
		pad = 8,
	})

	K.Options.Write("UnitFrames", "edit", "target")
	local pane = env.CreateFrame("Frame", nil, root)
	at(pane, 560, 470, 720, 260)
	local preview = K.Options.Preview("UnitFrames")(pane)
	assert(preview.kind == "target" and preview.views.target.geometry.form == "sigil", "the preview shows the sigil")
	local parts = { preview.holders.target, preview.casts.target and preview.casts.target.frame, preview.auraHosts.target }
	local previewFrames = {}
	for _, part in ipairs(parts) do
		if part and part:IsShown() then
			previewFrames[#previewFrames + 1] = part
		end
	end
	frames:Add(env, pane, {
		name = "unitframes_preview", title = "Unit frames preview", grade = "panel", reference = "target",
		caption = "Preview.lua, the options page's live preview on the sigil: Frost Howler's sample values, its level line, the hostile pill between the gems, the sample cast line and four sample sockets centred under it.",
		match = "The same parts as the live sigil, drawn from sample values.",
		rect = Gallery.Union(env, previewFrames),
	})

	env.RunTimers()
	Gallery.Ticks(U.W, env, 40)
	env.RunTimers()
	local note = portraits(env)
	local main = Gallery.Build(env, { time = env._time })
	main.log[#main.log + 1] = note
	local scene = Scene.Merge({ main, resource(frames, 60, 560) })
	return frames:Finish(scene, env, K, "gallery unitframes")
end)
