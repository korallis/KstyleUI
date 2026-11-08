-- gallery_groupframes.lua: the group frames in a representative state, each cropped as one frame of the gallery:
-- a five-player party on the secure party header (the player first; a tank leader with aggro, incoming heals and
-- two debuffs; a healer; a dead shaman; a mage with the skull marker), a close crop of the tank's frame, a raid of
-- twenty in four groups on the raid headers (in a second environment, since a roster is a party or a raid), and
-- the options page's live preview with its sample party and raid frames.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local PLAYER = { name = "Valerin", class = "WARRIOR", health = 82, maxHealth = 100, power = 45, maxPower = 100, powerType = "RAGE", role = "DAMAGER" }
local PARTY = {
	{ name = "Thaldren", class = "WARRIOR", health = 92, maxHealth = 100, power = 35, maxPower = 100, powerType = "RAGE", role = "TANK", leader = true, threat = 3, incoming = 12, absorb = 6 },
	{ name = "Sylaen", class = "DRUID", health = 87, maxHealth = 100, power = 80, maxPower = 100, role = "HEALER" },
	{ name = "Kragar", class = "SHAMAN", health = 0, maxHealth = 100, power = 0, maxPower = 100, dead = true, role = "DAMAGER" },
	{ name = "Lunara", class = "MAGE", health = 64, maxHealth = 100, power = 90, maxPower = 100, role = "DAMAGER", marker = 8 },
}
-- The role and leader icons are Blizzard atlases and the raid marker a cell of Blizzard's marker sheet, drawn from
-- the texture cache Tools/render/atlas.py builds (a grey box, and a log line, when the cache lacks them).
local ICONS = {}
local DEBUFF_ICONS = { I.rend, I.sunderArmor }
local MAGIC = "rare"

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
		m.health = 100 - (i * 7) % 45
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
	frames:Add(env, ns.Headers.holders.raid, {
		name = "groupframes_raid", title = "Raid frames", grade = "panel", reference = "nameplate",
		caption = "Twenty raid frames in four groups of five on the secure raid headers: 72 by 40 glass tiles with the class-coloured health fill on a buttonFill track, the name on the bar, a dead and an offline member in grey, and the first tank's threat glow; the role icons are Blizzard's micro role atlases and the tank's leader crown is Blizzard's leader atlas, drawn from the atlas cache.",
		match = "Glass fill, two-line edge and 3.5-unit chamfer as the mockup's nameplate frame; raid tiles draw no drop shadow (Style.lua keeps the shadow for party frames), so the 3-unit gaps between them stay clean.",
		rect = Gallery.Union(env, shown),
	})
	local scene = Scene.Build(env)
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

	-- The tank's debuffs: the engine lays its buttons out in the game; the scene places the fake engine's two
	-- debuff buttons where the AuraContainer would, with an icon each, a count, and the Magic dispel rim on one.
	local tank = party.party1
	local container = tank.auras
	assert(container, "party1 has a debuff container")
	local k = ns.Settings.current.party
	local size, spacing = Widgets.Snap(tank, k.auraSize), Widgets.Snap(tank, k.auraSpacing)
	container:SetSize(ns.Geometry.AuraLine(k.auraColumns, size, spacing), size)
	local tiles = {}
	for i, icon in ipairs(DEBUFF_ICONS) do
		local button = container._groups.debuffs.frames[i]
		assert(button, "the engine made debuff button " .. i)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * (size + spacing), 0)
		button:SetSize(size, size)
		button._aura.icon:SetTexture(icon)
		Widgets.SetText(button._aura.count, i == 1 and "2" or "")
		if i == 2 then
			local r, g, b = Tokens.Color(MAGIC)
			for _, entry in ipairs(button._aura.dispel) do
				entry.texture:SetVertexColor(r, g, b, 1)
				entry.texture:Show()
			end
		end
		tiles[i] = button
	end
	frames:Add(env, tank, {
		name = "groupframes_unit", title = "Party unit", grade = "panel", reference = "nameplate",
		caption = "One party frame close up, the tank Thaldren: a 230 by 46 glass tile with the round portrait and level disc, the name above the warrior-coloured health fill on its buttonFill track, incoming heals and an absorb after the fill, the rage bar under it, the threat glow, and two debuff tiles to its right, one washed in the Magic dispel colour; the tank's role icon and leader crown are Blizzard atlases from the atlas cache.",
		match = "Glass fill, two-line edge, 3.5-unit chamfer and drop shadow as the mockup's nameplate frame; the aura tiles are the button grade as the mockup's buff icons, with the class accent rim.",
		rect = Gallery.Union(env, { tank, tiles[1], tiles[2] }),
	})
	frames:Add(env, ns.Headers.holders.party, {
		name = "groupframes_party", title = "Party frames", grade = "panel", reference = "nameplate",
		caption = "The five-player party on the secure party header, the player first: glass tiles with portraits, class-coloured health on buttonFill tracks and power bars, the tank with aggro and two debuffs, a healer, a dead shaman in grey and a mage with the skull marker on the frame's top edge; each member's role icon and the tank's leader crown are Blizzard atlases and the skull a cell of Blizzard's marker sheet, all from the texture cache.",
		match = "Glass fill, two-line edge, 3.5-unit chamfer and drop shadow on each tile as the mockup's nameplate frame.",
		rect = Gallery.Union(env, { ns.Headers.holders.party, tiles[1], tiles[2] }),
	})

	-- The options page's live preview: three sample party frames and two sample raid groups.
	local pane = env.CreateFrame("Frame", nil, root)
	at(pane, 460, 90, 300, 420)
	local preview = K.Options.Preview("GroupFrames")(pane)
	assert(#preview.partyFrames == 3 and #preview.raidFrames == 10, "the preview builds its samples")
	frames:Add(env, preview.canvas, {
		name = "groupframes_preview", title = "Group frames preview", grade = "panel", reference = "nameplate",
		caption = "Preview.lua, the options page's live preview: three sample party frames (a tank with aggro, two debuff tiles and an absorb; a healer with the Magic dispel highlight; a targeted shaman with the target ring) over two sample raid groups of five, including a dead mage and an offline warlock.",
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
	local main = Scene.Build(env)
	main.log[#main.log + 1] = face and "party portraits are one crop of the mockup; the game draws each unit's model" or "party portraits are flat stand-ins; run Tools/render/standins.py for the mockup's face"
	local scene = Scene.Merge({ main, raid(frames, 60, 420) })
	return frames:Finish(scene, env, K, "gallery groupframes")
end)
