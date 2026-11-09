-- gallery_auracounts.lua: the aura rows at three loads, side by side, each cropped as one frame of the gallery:
-- low (3), medium (10) and high (24 on the sigil, 16 on the focus and boss cards, 16 tracked buffs, 6 tracked bars).
-- The sigil's debuffs wrap to a second row of ten, then the last socket reads "+N"; the focus card's single row and the
-- boss card's one row of four do the same; the KstyleUI tracked buff icons cap at six and the bars at two, a chip
-- reading the rest beside them, and Blizzard's own viewers (the automatic path on Forever) where Layout > Apply put
-- them in Edit Mode. The fake engine lays out nothing, so this scene places the engine's buttons as its flow layout
-- would (sorted, wrapped at the columns, from the container's corner) and sizes the hidden counting container the way
-- its one-element-per-line layout does; the chip shows and reads by anchors alone, as in the game.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local EditModeFake = dofile("Tools/regression/editmode_fake.lua")
local Scene = Common.Scene

local NOW = 10
local SCREEN_H = 1080
local COLUMN, LEFT = 548, 20
local LOADS = {
	{ key = "low", label = "3", target = 3, focus = 3, boss = 3, buffs = 3, bars = 1 },
	{ key = "medium", label = "10", target = 10, focus = 10, boss = 8, buffs = 10, bars = 3 },
	{ key = "high", label = "24", target = 24, focus = 16, boss = 16, buffs = 16, bars = 6 },
}

local ICONS = {}
do
	local names = {}
	for name in pairs(Hud.ICONS) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ICONS[#ICONS + 1] = Hud.ICONS[name]
	end
end

local function icon(i)
	return ICONS[(i * 7) % #ICONS + 1]
end

local UNITS = {
	target = { name = "Bloodtalon Matriarch", level = 38, classification = "elite", creature = "Beast", health = 864, healthMax = 1540, power = 0, powerMax = 0, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	focus = { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
	boss1 = { name = "Magmatus", level = 40, classification = "elite", health = 72000, healthMax = 100000, power = 40, powerMax = 100, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true },
}

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

-- Lay(env, K, ns, view, n) places min(n, cap) of the engine's debuff buttons as the flow layout would, soonest-expiring
-- first, and sizes the counting container for n; returns the timers it wrote, for the log.
local function Lay(env, K, ns, view, n)
	local Widgets, Settings = K.Widgets, ns.Settings
	local a = view.auras
	local c = a.container
	local group = c._groups.debuffs
	local cap = group.max
	local shown = math.min(n, cap)
	local buttons = c:_Acquire("debuffs", shown)
	local size = Widgets.Snap(a.host, Settings.Value(view.kind, "auraSize"))
	local spacing = group.layout.elementSpacing
	local lineGap = group.layout.lineSpacing
	local columns = Settings.Value(view.kind, "auraColumns")
	local corner = c._anchor or "TOPLEFT"
	local dx = (c._growth and c._growth[1] or 1) < 0 and -1 or 1
	local dy = (c._growth and c._growth[2] or -1) < 0 and -1 or 1
	local rows = math.ceil(shown / columns)
	local across = math.min(shown, columns)
	c:SetSize(math.max(1, across * size + (across - 1) * spacing), math.max(1, rows * size + (rows - 1) * lineGap))
	local byButton = {}
	for _, entry in ipairs(a.buttons) do
		byButton[entry.button] = entry
	end
	for i, button in ipairs(buttons) do
		local entry = byButton[button]
		if i <= shown and entry then
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			button:ClearAllPoints()
			button:SetSize(size, size)
			button:SetPoint(corner, c, corner, dx * col * (size + spacing), dy * row * (size + lineGap))
			button:Show()
			entry.icon:SetTexture(env.Secret(icon(i + n)))
			Widgets.SetText(entry.timer, (2 + i * 3) .. "s")
			Widgets.SetText(entry.count, i % 5 == 2 and "3" or "")
		else
			button:Hide()
		end
	end
	local chip = a.overflow and a.overflow.debuffs
	if chip then
		chip.ghost:SetSize(1, math.max(1, n * chip.pitch))
	end
	return shown, cap
end

-- Frames(load, k, frames) -> scene: the sigil, the focus card and the first boss card at one load.
local function Frames(load, k, frames)
	local U = dofile("Tools/regression/unitframes_env.lua")
	local env, K, ns = U.New(Common.ScreenOpts({
		saved = Gallery.Saved({ "UnitFrames" }),
		setup = function(env)
			Gallery.Setup(env)
			for token, unit in pairs(UNITS) do
				env._units[token] = unit
			end
		end,
	}))
	env._time = NOW
	local x = LEFT + (k - 1) * COLUMN
	move(K, "unitframes.target", x, 30)
	move(K, "unitframes.focus", x, 262)
	move(K, "unitframes.boss", x + 320, 240)
	hide(K, { "unitframes.player", "unitframes.castbar.player", "unitframes.castbar.target", "unitframes.resource", "unitframes.targettarget", "unitframes.pet", "unitframes.focustarget" })
	env.SetTarget(true)
	env.FireEvent("PLAYER_FOCUS_CHANGED")
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	local Ui = ns.Frames
	local target, focus, boss = Ui.Get("target").views[1], Ui.Get("focus").views[1], Ui.Get("boss").views[1]
	local log = {}
	for _, item in ipairs({ { target, load.target, "sigil" }, { focus, load.focus, "focus" }, { boss, load.boss, "boss" } }) do
		local view, n, name = item[1], item[2], item[3]
		local shown, cap = Lay(env, K, ns, view, n)
		log[#log + 1] = string.format("%s: %d debuffs, %d sockets of %d%s", name, n, shown, cap, n > cap and (", +" .. (n - cap + 1) .. " on the last") or "")
	end
	Gallery.Ticks(U.W, env, 20)
	env.RunTimers()
	frames:Add(env, target.button, {
		name = "auracounts_sigil_" .. load.key, title = "Sigil debuffs, " .. load.label, grade = "bar", reference = "target",
		caption = string.format("The target's sigil with %d of your debuffs: two rows of ten 24-unit sockets centred under it, sorted by the engine (yours, then priority, then time left), each timer on its socket's foot; past twenty the last socket reads +N.", load.target),
		match = "The mockup's sigil sockets, now in two rows inside the 136 units the layouts keep for the sigil, clear of the cooldown cluster under it.",
		rect = Gallery.Union(env, { target.button, target.auras.host }),
		pad = 10,
	})
	frames:Add(env, focus.button, {
		name = "auracounts_focus_" .. load.key, title = "Focus debuffs, " .. load.label, grade = "panel", reference = "player",
		caption = string.format("The focus card with %d of your debuffs over it: one row of eight 20-unit sockets, the last reading +N past eight.", load.focus),
		match = "The focus card's row stays in the 22 units the layouts keep over the card.",
		rect = Gallery.Union(env, { focus.button, focus.auras.host }),
		pad = 10,
	})
	frames:Add(env, boss.button, {
		name = "auracounts_boss_" .. load.key, title = "Boss debuffs, " .. load.label, grade = "panel", reference = "target",
		caption = string.format("A boss card with %d of your debuffs beside it: one row of four 22-unit sockets growing left, each timer in a corner badge, the last reading +N past four.", load.boss),
		match = "The boss column's 96 units of aura room, one row beside one 62-unit card, clear of its name and bar.",
		rect = Gallery.Union(env, { boss.button, boss.auras.host }),
		pad = 10,
	})
	local scene = Gallery.Build(env, { time = NOW })
	for _, line in ipairs(log) do
		scene.log[#scene.log + 1] = line
	end
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end

local function layout(K, key, x, top, height)
	assert(K.Layout.Update(key, { anchor = "BOTTOMLEFT", x = x, y = SCREEN_H - top - height }))
end

local BAR_NAMES = { "Battle Shout", "Enrage", "Blood Fury", "Shield Block", "Bloodrage", "Recklessness" }

-- Cooldowns(load, k, frames, path) -> scene: the tracked buff icons and bars at one load. path "auto" is what a player
-- on Forever gets: aura data can turn secret in combat, so the module restyles Blizzard's own viewers, which Layout >
-- Apply placed and sized in Edit Mode for this many tracked buffs and bars (Hud.NativeViewers); "mirror" is the
-- KstyleUI icons the player can pick instead, capped at six sockets and two bars with a +N chip beside them.
local function Cooldowns(load, k, frames, path)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local cooldowns, textures, items = {}, {}, { buffs = {}, bars = {} }
	local function left(spell)
		return 3 + (spell % 17)
	end
	for i = 1, load.buffs do
		cooldowns[500 + i] = { spellID = 5000 + i, category = C.CATEGORY.TrackedBuff, selfAura = true, hasAura = true }
		textures[5000 + i] = icon(i)
		items.buffs[i] = { id = 500 + i, icon = icon(i), name = "Spell " .. (5000 + i), left = left(5000 + i), total = 30 }
	end
	for i = 1, load.bars do
		cooldowns[600 + i] = { spellID = 6000 + i, category = C.CATEGORY.TrackedBar, selfAura = true, hasAura = true }
		textures[6000 + i] = icon(i + 40)
		items.bars[i] = { id = 600 + i, icon = icon(i + 40), name = BAR_NAMES[i], left = left(6000 + i), total = 30 }
	end
	local mirror = path == "mirror"
	local env, K, ns = C.New({
		saved = Gallery.Saved({ Cooldowns = mirror and { path = "mirror" } or {} }),
		cooldowns = cooldowns,
		setup = function(env)
			Gallery.Setup(env)
			C.Game(env)
			env.C_Spell.GetSpellName = function(spell)
				return spell > 6000 and BAR_NAMES[spell - 6000] or ("Spell " .. spell)
			end
			for spell, texture in pairs(textures) do
				env._cdm.textures[spell] = texture
			end
		end,
	})
	local cdm = env._cdm
	env._time = NOW
	local instance = 900
	for spell in pairs(textures) do
		instance = instance + 1
		local total = 30
		cdm.auras[spell] = { auraInstanceID = instance }
		cdm.auraDurations[instance] = { kind = "aura", start = NOW - (total - left(spell)), finish = NOW + left(spell), remaining = left(spell), total = total }
	end
	local x = LEFT + (k - 1) * COLUMN
	local told = {}
	if not mirror then
		local _
		-- The crop sets the viewers side by side: the icons at the column's foot, the bars 8 over a row of them,
		-- flush with its right edge, or 8 left of a column of them, on its foot. Past what the row beside the hands holds, Apply stands the icons in a column beside the
		-- cluster and the bars under the target of target, too far apart for one crop.
		_, told = Hud.NativeViewers(env, C, "DPS", items, function(entry, group, placed)
			local a = entry.anchorInfo
			if group == "buffs" or not placed.buffs then
				return x + 500 - a.offsetX, (SCREEN_H - 900) - a.offsetY
			end
			local l, b, r, t = EditModeFake.ViewerRect(placed.buffs, load.buffs, 1)
			local bl, _, br = EditModeFake.ViewerRect(entry, load.bars, 1, true)
			local width = br - bl
			if t - b > r - l then
				return l - 8 - (a.point:find("RIGHT") and 0 or width) - a.offsetX, b - a.offsetY
			end
			return r - (a.point:find("RIGHT") and 0 or width) - a.offsetX, t + 8 - a.offsetY
		end)
	end
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	env.RunTimers()
	local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
	for _, key in ipairs({ "cooldowns.essential", "cooldowns.utility" }) do
		layout(K, key, x + 230, 640, 44)
	end
	hide(K, { "cooldowns.essential", "cooldowns.utility" })
	local scene
	if mirror then
		local _, barsH = bars.holder:GetSize()
		local _, buffsH = buffs.holder:GetSize()
		layout(K, "cooldowns.bars", x + 40, 640, barsH)
		layout(K, "cooldowns.buffs", x + 40, 640 + barsH + 8, buffsH)
		local shown = { buffs.holder, bars.holder }
		for _, chip in ipairs({ buffs.chip, bars.chip }) do
			if chip and chip:IsShown() then
				shown[#shown + 1] = chip
			end
		end
		frames:Add(env, buffs.holder, {
			name = "auracounts_buffs_" .. load.key .. "_mirror", title = "Tracked buffs as KstyleUI icons, " .. load.label, grade = "button", reference = "bufficons",
			caption = string.format("%d tracked buffs and %d tracked bars on the KstyleUI icons path: all six sockets show a buff and a +N chip stands one socket to the left, away from the cluster; both bars show and a +N bar stands on top. Point at a chip to list the rest with their time left.", load.buffs, load.bars),
			match = "Every socket and bar stays readable; the chips grow the group by one socket on its open side.",
			rect = Gallery.Union(env, shown),
			pad = 10,
		})
		scene = Gallery.Build(env, { time = NOW })
		scene.log[#scene.log + 1] = string.format("tracked buffs (KstyleUI icons): %d active, %d shown%s; bars: %d active, %d shown%s", load.buffs, buffs.count,
			buffs.chip and buffs.chip:IsShown() and (", " .. buffs.chip.text:GetText() .. " beside them") or "", load.bars, bars.count,
			bars.chip and bars.chip:IsShown() and (", " .. bars.chip.text:GetText() .. " on top") or "")
	else
		local icons, barViewer = env._viewers.BuffIconCooldownViewer, env._viewers.BuffBarCooldownViewer
		frames:Add(env, icons, {
			name = "auracounts_buffs_" .. load.key, title = "Tracked buffs, " .. load.label, grade = "button", reference = "bufficons",
			caption = string.format("%d tracked buffs and %d tracked bars on Forever's automatic path: Blizzard's own viewers, restyled, at the size Layout > Apply gave them in Edit Mode. A few grow left from the slot beside the hands under bars as wide as their row; past what that row holds, the icons stand in a column beside the cluster and the bars under the target of target. The crop sets them side by side. %s", load.buffs, load.bars,
				#told > 0 and ("Apply told the player: " .. table.concat(told, " ")) or "Every tracked buff fits beside the action bars."),
			match = "The size and place Edit Mode gets fit every tracked item clear of every other element, or the setup summary names the counts.",
			rect = Gallery.Union(env, { icons, barViewer }),
			pad = 10,
		})
		scene = Gallery.Build(env, { time = NOW })
		scene.log[#scene.log + 1] = string.format("tracked buffs (automatic, %s): %d icons and %d bars in Blizzard's viewers%s", ns.Mirror.Report(), load.buffs, load.bars,
			#told > 0 and ("; Apply: " .. table.concat(told, " ")) or "")
	end
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
	return scene
end

return Common.Run(function()
	local frames = Gallery.Frames()
	local scenes = {}
	for k, load in ipairs(LOADS) do
		scenes[#scenes + 1] = Frames(load, k, frames)
		-- The high load's automatic frame is gallery_tracked.lua's: the column where Apply puts it, among the frames.
		if load.key ~= "high" then
			scenes[#scenes + 1] = Cooldowns(load, k, frames, "auto")
		end
		scenes[#scenes + 1] = Cooldowns(load, k, frames, "mirror")
	end
	local scene = Scene.Merge(scenes)
	scene.frames = {}
	for _, entry in ipairs(frames.pending) do
		local rect = entry.spec.rect
		scene.frames[#scene.frames + 1] = {
			name = entry.spec.name, title = entry.spec.title, caption = entry.spec.caption, grade = entry.spec.grade,
			reference = entry.spec.reference, match = entry.spec.match, pad = entry.spec.pad or 14,
			rect = { rect.x, rect.y, rect.w, rect.h },
		}
	end
	frames.pending = {}
	for i, line in ipairs(scene.log) do
		scene.log[i] = "gallery auracounts: " .. line
	end
	return scene
end)
