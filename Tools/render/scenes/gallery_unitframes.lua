-- gallery_unitframes.lua: every unit frame the HUD scene does not already show, each cropped as one frame of the
-- gallery: the focus frame with its cast bar mid-cast and three debuff tiles under it, the focus target, the
-- target of target, the pet frame with its power bar, three boss frames (the first casting, with aggro), a
-- rogue's combo points (the class resource, in its own environment), and the options page's live preview on the
-- target frame. The player, the target and their cast bars are the HUD scene's (hud.lua) and stay hidden here.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local HUD_KEYS = { "unitframes.player", "unitframes.target", "unitframes.castbar.player", "unitframes.castbar.target" }
local FOCUS_SPELL, BOSS_SPELL = 6343, 1680
local DEBUFF_ICONS = { I.rend, I.sunderArmor, I.hamstring }
local MAGIC = "rare"

local UNITS = {
	player = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350, power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 },
	target = { name = "Riverglade Crocolisk", level = 38, health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	targettarget = { name = "Valerin", class = "WARRIOR", level = 38, health = 2750, healthMax = 3350, power = 45, powerMax = 100, powerType = 1, powerToken = "RAGE", isPlayer = true, reaction = 5 },
	focus = { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true,
		cast = { name = "Thunder Clap", texture = I.thunderClap, start = 8500, finish = 11500, spellID = FOCUS_SPELL } },
	focustarget = { name = "Krazhk", level = 38, health = 3300, healthMax = 4000, power = 1800, powerMax = 3600, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	pet = { name = "Rasha", level = 37, health = 1460, healthMax = 2000, power = 80, powerMax = 100, powerType = 2, powerToken = "FOCUS", reaction = 5 },
	boss1 = { name = "Magmatus", level = -1, classification = "worldboss", health = 72000, healthMax = 100000, power = 40, powerMax = 100, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true, threatOn = 3,
		cast = { name = "Whirlwind", texture = I.whirlwind, start = 9000, finish = 12000, spellID = BOSS_SPELL } },
	boss2 = { name = "Ashen Warden", level = -1, classification = "worldboss", health = 48000, healthMax = 100000, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	boss3 = { name = "Cinder Shade", level = -1, classification = "worldboss", health = 91000, healthMax = 100000, power = 65, powerMax = 100, powerType = 3, powerToken = "ENERGY", reaction = 2, canAttack = true },
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
	local scene = Scene.Build(env, { time = env._time })
	errors(scene, env, K)
	return scene
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
			unitClasses(env)
		end,
	}))
	local root = K.Scale.Root()
	local Widgets, Tokens = K.Widgets, K.Tokens
	local frames = Gallery.Frames()
	env._time = 10
	env.SetTarget(true)
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	env.FireEvent("UNIT_PET", "player")
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.FireEvent("UNIT_SPELLCAST_START", "focus", "Cast-1", FOCUS_SPELL)
	env.FireEvent("UNIT_SPELLCAST_START", "boss1", "Cast-1", BOSS_SPELL)
	env.RunTimers()
	hide(K, HUD_KEYS)
	hide(K, { "unitframes.resource" })
	move(K, "unitframes.focus", 60, 90)
	move(K, "unitframes.focustarget", 60, 240)
	move(K, "unitframes.targettarget", 60, 300)
	move(K, "unitframes.pet", 60, 360)
	-- The small frames leave their power bar off by default; the pet shows its focus bar with the option on.
	K.Options.Write("UnitFrames", "pet.power", true)
	move(K, "unitframes.boss", 400, 90)
	local Frames = ns.Frames

	-- The focus frame, casting, with its cast bar inside the frame.
	local focus = Frames.Get("focus").views[1]
	assert(focus.button:IsShown() and focus.castbar and focus.castbar.active, "the focus frame shows and casts")
	frames:Add(env, focus.button, {
		name = "unitframes_focus", title = "Focus frame", grade = "panel", reference = "player",
		caption = "The focus frame on a hostile caster mid-cast: glass panel, round portrait with the class-colour ring and the octagon level badge, health and mana on buttonFill tracks, and the cast bar inside the frame on the bar grade with its icon tile.",
		match = "Fill, two-line edge, 8-unit chamfer and drop shadow as the mockup's player glass; the cast bar panel is the bar grade (surface, edgeBar line, tile chamfer, shadow) as the mockup's cast bar.",
	})

	-- Its debuff tiles: the engine lays its buttons out in the game; here the scene places the fake engine's three
	-- debuff buttons where the AuraContainer would, gives each an icon, a count, a timer and one the Magic rim.
	local a = focus.auras
	assert(a and a.container and a.host:IsShown(), "the focus frame has shown auras")
	local size, spacing = Widgets.Snap(a.host, ns.Settings.Value("focus", "auraSize")), Widgets.Snap(a.host, ns.Settings.Value("focus", "auraSpacing"))
	a.container:SetSize(a.host:GetSize())
	local tiles = {}
	for i, button in ipairs(a.container._groups.debuffs.buttons) do
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
		entry.icon:SetTexture(DEBUFF_ICONS[i])
		Widgets.SetText(entry.count, i == 1 and "3" or "")
		Widgets.SetText(entry.timer, ({ "12s", "8s", "2s" })[i])
		if i == 2 and entry.dispel then
			local r, g, b = Tokens.Color(MAGIC)
			Widgets.ShowSlice(entry.dispel, true)
			Widgets.ColorSlice(entry.dispel, r, g, b, 1)
		end
		tiles[i] = button
	end
	frames:Add(env, a.host, {
		name = "unitframes_auras", title = "Frame auras", grade = "button", reference = "bufficons",
		caption = "Three debuff tiles under the focus frame from KstyleUI_UnitFrames/Auras.lua: IconChrome tiles on the button body with the accent rim, a stack count, timers, and the middle tile washed in the Magic dispel colour; the scene lays the engine's buttons out, as the game's AuraContainer would.",
		match = "Body #101214, 3.5-unit tile chamfer and one-border rim as the mockup's buff icons; the rim is the class accent where the mockup's is neutral grey, and the dispel wash has no mockup counterpart.",
		rect = Gallery.Union(env, tiles),
	})

	-- The small frames: the focus target, the target of target and the pet, all compact glass tiles.
	local small = {
		{ "focustarget", "unitframes_focustarget", "Focus target", "The focus target frame, a 120 by 24 compact unit: name and health percentage on one row over the health track, the glass on the tile chamfer." },
		{ "targettarget", "unitframes_targettarget", "Target of target", "The target of target frame, a 104 by 24 compact unit showing the player: name, health percentage and the class-coloured health fill on its buttonFill track." },
	}
	for _, entry in ipairs(small) do
		local view = Frames.Get(entry[1]).views[1]
		assert(view.button:IsShown(), entry[1] .. " shows")
		frames:Add(env, view.button, {
			name = entry[2], title = entry[3], grade = "panel", reference = "nameplate",
			caption = entry[4],
			match = "Glass fill, two-line edge and drop shadow as the mockup's nameplate frame, at the 3.5-unit tile chamfer a frame under 36 units tall takes.",
		})
	end
	local pet = Frames.Get("pet").views[1]
	assert(pet.button:IsShown() and pet.power:IsShown(), "the pet frame shows with its power bar")
	frames:Add(env, pet.button, {
		name = "unitframes_pet", title = "Pet frame", grade = "panel", reference = "nameplate",
		caption = "The pet frame, a 104 by 24 compact unit with its power bar option on (off by default): the pet's name and health percentage over the health fill, and its focus bar under it, both on buttonFill tracks.",
		match = "Glass fill, two-line edge and drop shadow as the mockup's nameplate frame, at the 3.5-unit tile chamfer a frame under 36 units tall takes.",
	})

	-- Three boss frames in the boss element's first three slots; the first casts and has aggro on the player.
	local boss = Frames.Get("boss")
	local shown = {}
	for i = 1, 3 do
		assert(boss.views[i].button:IsShown(), "boss" .. i .. " shows")
		shown[i] = boss.views[i].button
	end
	assert(boss.views[1].castbar.active, "boss1 casts")
	frames:Add(env, boss.holder, {
		name = "unitframes_boss", title = "Boss frames", grade = "panel", reference = "target",
		caption = "Three boss frames stacked in the boss element: each a glass panel with the round portrait, the ?? level badge, health on its buttonFill track and power under it; Magmatus casts Whirlwind in the cast bar below its frame and has aggro on the player.",
		match = "Fill, two-line edge, 8-unit chamfer and shadow as the mockup's target glass; the threat glow around the first frame (the shadow slice in ADD blend, red) reads only as a faint haze because most of it lies under the glass.",
		rect = Gallery.Union(env, shown),
	})

	-- The options page's live preview, on the target frame: sample values and the target cast bar with its icon
	-- tile. The target shows no frame auras by default, so the preview draws no tiles; its raid marker is a
	-- Blizzard texture the renderer has no file for.
	K.Options.Write("UnitFrames", "edit", "target")
	local pane = env.CreateFrame("Frame", nil, root)
	at(pane, 680, 90, 360, 240)
	local preview = K.Options.Preview("UnitFrames")(pane)
	assert(preview.kind == "target", "the preview shows the target frame")
	local parts = { preview.holders.target, preview.casts.target and preview.casts.target.frame, preview.auraHosts.target }
	local previewFrames = {}
	for _, part in ipairs(parts) do
		if part and part:IsShown() then
			previewFrames[#previewFrames + 1] = part
		end
	end
	frames:Add(env, pane, {
		name = "unitframes_preview", title = "Unit frames preview", grade = "panel", reference = "target",
		caption = "Preview.lua, the options page's live preview on the target frame: Frost Howler's sample values, the two-tone health fill with the incoming heal after it, and the target cast bar casting Frostbolt below the frame with its icon tile.",
		match = "The frame glass as the mockup's target panel; the cast bar is the bar grade (surface, edgeBar line, tile chamfer, shadow) and its icon the button body, as the mockup's cast bar.",
		rect = Gallery.Union(env, previewFrames),
	})

	env.RunTimers()
	Gallery.Ticks(U.W, env, 40)
	env.RunTimers()
	local note = portraits(env)
	local main = Scene.Build(env, { time = env._time })
	main.log[#main.log + 1] = note
	local scene = Scene.Merge({ main, resource(frames, 60, 430) })
	return frames:Finish(scene, env, K, "gallery unitframes")
end)
