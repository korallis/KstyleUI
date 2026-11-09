-- gallery_groupframes.lua: the group frames in a representative state, each cropped as one frame of the gallery:
-- a five-player party on the secure party header (the player first; a tank leader with aggro, incoming heals and
-- two debuffs; a healer; a dead shaman; a mage with the star marker), a close crop of the tank's frame, a raid of
-- twenty in four groups on the raid headers (in a second environment, since a roster is a party or a raid), with
-- the missing health, your heals over time, a shield, a debuff and a Magic dispel highlight as a healer sees them,
-- and the options page's live preview with its sample party and raid frames.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local MAX = 41800
local PLAYER = { name = "Valerin", class = "WARRIOR", health = 34300, maxHealth = MAX, power = 45, maxPower = 100, powerType = "RAGE", role = "DAMAGER" }
local PARTY = {
	{ name = "Thaldren", class = "WARRIOR", health = 30100, maxHealth = MAX, power = 35, maxPower = 100, powerType = "RAGE", role = "TANK", leader = true, threat = 3, incoming = 5000, absorb = 2500, healAbsorb = 6200 },
	{ name = "Sylaen", class = "DRUID", health = 36400, maxHealth = MAX, power = 80, maxPower = 100, role = "HEALER" },
	{ name = "Kragar", class = "SHAMAN", health = 0, maxHealth = MAX, power = 0, maxPower = 100, dead = true, role = "DAMAGER" },
	{ name = "Lunara", class = "MAGE", health = 26800, maxHealth = MAX, power = 90, maxPower = 100, role = "DAMAGER", marker = 1 },
}
-- The role and leader icons are Blizzard atlases and the raid marker a cell of Blizzard's marker sheet, drawn from
-- the texture cache Tools/render/atlas.py builds (a grey box, and a log line, when the cache lacks them).
local ICONS = {}
local DEBUFF_ICONS = { I.rend, I.sunderArmor }
local MAGIC = "rare"
local RENEW, SHIELD, PAIN, POLYMORPH, EXTERNAL = 135953, 135940, 136207, 136071, 135936
local RAID_NAMES = {
	"Thaldren", "Sylaen", "Brakka", "Ysra", "Orrin", "Kesh", "Maela", "Durn", "Lunara", "Vexen",
	"Garrok", "Ilyra", "Tovan", "Kragar", "Seluna", "Harn", "Zuli", "Morwen", "Rask", "Elowen",
}
-- Your heals over time on five members (five on the first tank, more than fit), debuffs on two (six on Ysra:
-- a dispellable one, a boss one and four others, more than her two cells), and a Magic debuff you can dispel on one.
local RAID_HOTS = { [1] = { RENEW, SHIELD, RENEW, SHIELD, RENEW }, [2] = { RENEW }, [6] = { SHIELD }, [11] = { RENEW, SHIELD }, [17] = { RENEW } }
local RAID_DEBUFFS = {
	[4] = { dispels = { POLYMORPH }, boss = { PAIN }, debuffs = { PAIN, POLYMORPH, PAIN, POLYMORPH } },
	[12] = { debuffs = { POLYMORPH } },
}

-- Flow(env, ns, f, container, entries, size, columns): places the fake engine's shown buttons as the engine's flow
-- layout would: groups in their priority order (layoutIndex), each up to its maxFrameCount, wrapping at the column
-- count from the container's anchor, and sizes the container to its content as OnLayoutComplete does. Buttons past
-- the cells fall in the clip frame's hidden row; the first of them raises the "+" mark on the last cell.
local function Flow(env, ns, f, container, entries, size, columns)
	local flow = container._flow
	local point = flow.anchor or "TOPLEFT"
	local gx = flow.horizontal == env.AnchorUtil.FlowDirection.Left and -1 or 1
	local gy = flow.vertical == env.AnchorUtil.FlowDirection.Down and -1 or 1
	local spacing = container._groups[next(entries)].layout.elementSpacing or 0
	local step = size + spacing
	local keys = {}
	for key in pairs(entries) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return (container._groups[a].layout.layoutIndex or 0) < (container._groups[b].layout.layoutIndex or 0)
	end)
	local index = 0
	for _, key in ipairs(keys) do
		local group = container._groups[key]
		for i, icon in ipairs(entries[key]) do
			if i > group.maxFrameCount then
				break
			end
			local button = group.frames[i]
			local col, row = index % columns, math.floor(index / columns)
			button:ClearAllPoints()
			button:SetPoint(point, container, point, gx * col * step, gy * row * step)
			button._aura.icon:SetTexture(env.Secret(icon))
			button:Show()
			index = index + 1
		end
	end
	container:SetSize(math.max(1, math.min(index, columns)) * step, math.max(1, math.ceil(index / columns)) * step)
end
local RAID_DISPEL = 12
-- Defensive indicators on two raid tiles, as the engine's aura slots would show them in the status lane: an external
-- on the first tank, a big defensive on Garrok.
local RAID_INDICATORS = { [1] = { indicator1 = EXTERNAL }, [11] = { indicator3 = 135919 } }

-- Count(f, entries) plays the "+N" chip's counting container: one line per debuff its groups take (each up to its
-- frame count), so the label that lines up with the window on the last cell is the count past the cells.
local function Count(f, entries)
	local chip = f.debuffChip
	if not chip then
		return
	end
	local n = 0
	for key, list in pairs(entries) do
		local group = chip.ghost._groups[key]
		if group and group.enabled then
			n = n + math.min(#list, group.maxFrameCount)
		end
	end
	chip.ghost:SetSize(1, math.max(1, n * chip.pitch))
end

local function move(K, key, x, y)
	assert(K.Layout.Set(key, "anchor", "TOPLEFT"))
	assert(K.Layout.Set(key, "x", x))
	assert(K.Layout.Set(key, "y", -y))
end

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	frame:SetSize(w, h)
end

-- A group environment on the owner's screen. Gallery.Setup makes every unit a warrior, so the roster's own
-- UnitClass comes back after it: the members keep their classes and the player is the warrior.
local function newEnv(G)
	return G.New(Common.ScreenOpts({
		saved = Gallery.Saved({ GroupFrames = ICONS }),
		setup = function(env)
			local unitClass = env.UnitClass
			Gallery.Setup(env)
			env.UnitClass = unitClass
		end,
	}))
end

-- Content(ns, header) -> the content frames of the header's shown buttons, by unit.
local function contents(ns, header)
	local out, i = {}, 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._shown and button._attributes.unit then
			out[button._attributes.unit] = ns.Button.Content(button)
		end
		i = i + 1
	end
	return out
end

local function errors(scene, env, K)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "error: " .. err
	end
end

-- The raid: twenty members in four groups, in its own environment.
local function raid(frames, x, y)
	local G = dofile("Tools/regression/group_env.lua")
	local env, K, ns = newEnv(G)
	local members = G.Members(20, function(i, m)
		m.name = RAID_NAMES[i]
		m.maxHealth = MAX
		m.health = math.floor(MAX * (100 - (i * 7) % 45) / 100)
		if i == 1 or i == 11 then
			m.absorb = math.floor(MAX * 0.3)
		end
		if i == 4 then
			m.healAbsorb = math.floor(MAX * 0.15)
		end
		m.role = i % 5 == 1 and "TANK" or (i % 5 == 2 and "HEALER" or "DAMAGER")
		if i == 1 then
			m.leader = true
			m.threat = 3
		elseif i == 7 then
			m.dead = true
			m.health = 0
		elseif i == 13 then
			m.online = false
		end
	end)
	G.SetRoster(env, "raid", members, PLAYER)
	if not K.Modules.IsRunning("GroupFrames") then
		assert(K.Modules.Enable("GroupFrames"))
	end
	env.RunTimers()
	move(K, "groupframes.raid", x, y)
	Gallery.Ticks(dofile("Tools/regression/widget_env.lua"), env, 20)
	local shown = {}
	for _, header in ipairs(ns.Headers.raid) do
		for _, f in pairs(contents(ns, header)) do
			shown[#shown + 1] = f
		end
	end
	assert(#shown == 20, "twenty raid frames show, got " .. #shown)
	-- The engine lays its aura buttons out in the game; the scene places the fake engine's buttons where the
	-- containers would: your heals from the name line's right end leftward, debuffs over the bar's right end.
	local Tokens = K.Tokens
	local k = ns.Settings.current.raid
	for _, header in ipairs(ns.Headers.raid) do
		for unit, f in pairs(contents(ns, header)) do
			local i = tonumber(unit:match("%d+"))
			if RAID_HOTS[i] and f.buffs then
				local _, count, size = ns.Auras.HealIcons(f, k)
				Flow(env, ns, f, f.buffs, { buffs = RAID_HOTS[i] }, size, math.max(1, count))
			end
			if RAID_DEBUFFS[i] and f.auras then
				local block = ns.Auras.Block(f, k)
				-- Boss debuffs flow in the row too (Astra #1); the first also takes the centred slot.
				local entries = RAID_DEBUFFS[i]
				local boss = entries.boss and ns.Auras.BossOn(f) and entries.boss[1]
				Flow(env, ns, f, f.auras, entries, block.size, math.max(1, block.columns))
				Count(f, entries)
				-- The boss debuff takes the centred boss slot, where the engine's aura slot would show it.
				local slot = boss and f.highlights and f.highlights:GetAuraSlotFrame("boss")
				if slot then
					slot._aura.icon:SetTexture(env.Secret(boss))
					slot:Show()
				end
			end
			for key, icon in pairs(RAID_INDICATORS[i] or {}) do
				local slot = f.indicators and f.indicators:GetAuraSlotFrame(key)
				if slot then
					slot._aura.icon:SetTexture(env.Secret(icon))
					slot:Show()
				end
			end
			if i == RAID_DISPEL and f.highlights then
				local slot = f.highlights:GetAuraSlotFrame("dispel")
				local r, g, b = Tokens.Color(MAGIC)
				for _, entry in ipairs(slot._aura.dispel) do
					entry.texture:SetVertexColor(r, g, b, 1)
					entry.texture:Show()
				end
				slot:Show()
			end
		end
	end
	frames:Add(env, ns.Headers.holders.raid, {
		name = "groupframes_raid", title = "Raid frames", grade = "panel", reference = "nameplate",
		caption = "Twenty raid frames in four groups of five on the secure raid headers: 72 by 40 Lumen glass tiles with a whole name lane over a class-coloured bar that spans the tile and fills 60% of its height; your Renew and Power Word: Shield on the name line's right end, never on the fill; the role icon, leader crown and missing health in the bar's left corner, with the status lane over the role icon showing the first tank's external defensive and Garrok's big defensive; Ysra's six debuffs two by two at 12 units over the bar's right end, three icons and a +3 chip on the last cell, and her boss debuff also in the centred 16-unit slot; a shield line under two bars, a Magic debuff you can dispel washing Ilyra's tile, Dead and Offline centred on the emptied bar, and the first tank's threat glow; role icons and the leader crown are Blizzard atlases from the atlas cache.",
		match = "Glass fill, one-line edge and 3.5-unit chamfer as the party rows and the mockup's nameplate frame; raid tiles draw no drop shadow (Style.lua keeps the shadow for party frames), so the 3-unit gaps between them stay clean.",
		rect = Gallery.Union(env, shown),
	})
	local scene = Gallery.Build(env)
	errors(scene, env, K)
	return scene
end

return Common.Run(function()
	local G = dofile("Tools/regression/group_env.lua")
	local W = dofile("Tools/regression/widget_env.lua")
	local env, K, ns = newEnv(G)
	local root = K.Scale.Root()
	local Widgets, Tokens = K.Widgets, K.Tokens
	local frames = Gallery.Frames()
	G.SetRoster(env, "party", PARTY, PLAYER)
	if not K.Modules.IsRunning("GroupFrames") then
		assert(K.Modules.Enable("GroupFrames"))
	end
	env.RunTimers()
	move(K, "groupframes.party", 60, 90)
	local party = contents(ns, ns.Headers.party)
	for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
		assert(party[unit], unit .. " has a frame")
	end

	-- The tank carries eight debuffs: a Magic one you can dispel, two boss debuffs and five others. The scene flows
	-- them as the engine would (dispellable, boss, the rest), so the three cells show the dispellable one and the two
	-- boss debuffs, and the rest fall in the clip frame's hidden row with a "+" on the last cell.
	local tank = party.party1
	local container = tank.auras
	assert(container, "party1 has a debuff container")
	local k = ns.Settings.current.party
	local block = ns.Auras.Block(tank, k)
	local tankDebuffs = {
		dispels = { DEBUFF_ICONS[2] },
		boss = { I.rend, PAIN },
		debuffs = { I.sunderArmor, POLYMORPH, PAIN, I.rend, POLYMORPH },
	}
	Flow(env, ns, tank, container, tankDebuffs, block.size, math.max(1, block.columns))
	Count(tank, tankDebuffs)
	local dispel = container._groups.dispels.frames[1]
	Widgets.SetText(container._groups.boss.frames[1]._aura.count, "2")
	local r, g, b = Tokens.Color(MAGIC)
	for _, entry in ipairs(dispel._aura.dispel) do
		entry.texture:SetVertexColor(r, g, b, 1)
		entry.texture:Show()
	end
	-- Five of your heals on the tank, two more than the name line holds.
	local _, healCount, healSize = ns.Auras.HealIcons(tank, k)
	Flow(env, ns, tank, tank.buffs, { buffs = { RENEW, SHIELD, RENEW, SHIELD, RENEW } }, healSize, math.max(1, healCount))
	-- The tank's external defensive in indicator slot 1, where the engine would show it at the frame's centre.
	local external = tank.indicators and tank.indicators:GetAuraSlotFrame("indicator1")
	if external then
		external._aura.icon:SetTexture(env.Secret(EXTERNAL))
		external:Show()
	end
	local tiles = { tank.auraClip, tank.auraClip }
	frames:Add(env, tank, {
		name = "groupframes_unit", title = "Party unit", grade = "panel", reference = "nameplate",
		caption = "One party frame close up, the tank Thaldren: a 230 by 46 glass tile with the round portrait and level disc, the name above the warrior-coloured health fill on its buttonFill track, incoming heals and an absorb after the fill, a heal absorb eating back from the fill's end in red, a 13-unit external defensive indicator between the name and the pill, five of your heals on the name line's right end, wholly above the pill, with a + for the two it cannot hold, the threat glow, and eight debuffs of which the six cells to its right show the dispellable one (washed in the Magic colour), the two boss debuffs and two others, with a +3 chip on the last cell; the tank's role icon and leader crown are Blizzard atlases from the atlas cache.",
		match = "Glass fill, two-line edge, 3.5-unit chamfer and drop shadow as the mockup's nameplate frame; the aura tiles are the button grade as the mockup's buff icons, with the class accent rim.",
		rect = Gallery.Union(env, { tank, tiles[1], tiles[2] }),
	})
	frames:Add(env, ns.Headers.holders.party, {
		name = "groupframes_party", title = "Party frames", grade = "panel", reference = "nameplate",
		caption = "The five-player party on the secure party header, the player first: glass tiles with portraits, class-coloured health on buttonFill tracks and power bars, the tank with aggro, eight debuffs (five shown in two rows and a +3 chip on the last cell, all inside the card), five heals on the tank's name line, clear of the pill that runs the row, with a + for the two that do not fit, the external defensive at 13 units between the name and the pill, a heal absorb, a healer, a dead shaman reading Dead with a dimmed name, and a mage with the star marker in the name row (a skull there read as a second dead state); each member's role icon and the tank's leader crown are Blizzard atlases and the star a cell of Blizzard's marker sheet, all from the texture cache.",
		match = "Glass fill, two-line edge, 3.5-unit chamfer and drop shadow on each tile as the mockup's nameplate frame.",
		rect = Gallery.Union(env, { ns.Headers.holders.party, tiles[1], tiles[2] }),
	})

	-- The options page's live preview: three sample party frames and two sample raid groups.
	local pane = env.CreateFrame("Frame", nil, root)
	at(pane, 460, 90, 280, 500)
	local preview = K.Options.Preview("GroupFrames")(pane)
	assert(#preview.partyFrames == 3 and #preview.raidFrames == 4, "the preview builds its samples")
	frames:Add(env, preview, {
		name = "groupframes_preview", title = "Group frames preview", grade = "panel", reference = "nameplate",
		caption = "Preview.lua, the options page's live preview at the settings window's default size: three sample party frames (a tank with aggro carrying two debuffs, two of your heals on the name line, a shield line, a heal absorb and an external defensive indicator at once; a healer with the Magic dispel highlight and a crowd control indicator; a targeted shaman) over four raid tiles at true scale (the tank with a boss debuff in the centred slot, the Magic-washed healer, a paladin with nine debuffs, three shown and a +6 chip, a dead mage), and under them the click casting panel: the game's Click Casting bindings, a slot to drop a spell on and a button to the game's own window.",
		match = "Party tiles on the glass with the two-line edge, 3.5-unit chamfer and shadow, raid tiles without the shadow, as the live frames; the dispel highlight washes a tile in the debuff colour.",
	})

	env.RunTimers()
	Gallery.Ticks(W, env, 40)
	env.RunTimers()
	-- The stub draws no portraits: the mockup's face, cut by standins.py, stands in on every party frame; a flat
	-- tone otherwise.
	local face = Common.StandIn("portrait-player.png")
	for _, f in pairs(party) do
		if face then
			f.portrait:SetTexture(face)
		else
			f.portrait:SetColorTexture(0.33, 0.28, 0.22, 1)
		end
	end
	local main = Gallery.Build(env)
	main.log[#main.log + 1] = face and "party portraits are one crop of the mockup; the game draws each unit's model" or "party portraits are flat stand-ins; run Tools/render/standins.py for the mockup's face"
	local scene = Scene.Merge({ main, raid(frames, 60, 420) })
	return frames:Finish(scene, env, K, "gallery groupframes")
end)
