-- gallery_auras_counts.lua: the Blessings card at four aura counts beside twelve debuffs, each cropped as one
-- frame: no buffs (the debuffs alone), eight buffs, twenty-four buffs (two rows show, "+12" at the cap) and forty
-- buffs with the "+28" count hovered, so the full list stands open beside the card at the compact tile. Each card
-- is its own environment, as the HUD scene builds one module several ways; the four scenes merge into one render.
-- The fake AuraContainer engine lays out no buttons and binds no icon or timer, so this scene fills the buttons
-- and places them as the engine's flow layout would, the way scenes/hud.lua does.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local COUNTS = { 0, 8, 24, 40 }
local DEBUFFS = 12
-- The screen is 1671 units wide at the owner's aspect. The fourth card sits at the right rail's place, so its
-- full list opens toward the screen's centre with room to spare; the third card takes a second row.
local AT = { { 60, 80 }, { 420, 80 }, { 60, 440 }, { 1293, 80 } }
local DISPEL = { "MAGIC", "CURSE", "POISON", "DISEASE", "NONE" }
local DEBUFF_ROW = {
	{ "Rend", 132155, "18s" }, { "Hamstring", 132316, "9s" }, { "Sunder Armor", 132363, "4s" },
	{ "Demoralizing Shout", 132366, "1m" }, { "Thunder Clap", 136105, "26s" }, { "Piercing Howl", 136147, "7s" },
}

local function fill(env, button, entry)
	local aura = button._aura
	if aura.icon then
		aura.icon:SetTexture(env.Secret(entry[2]))
	end
	if aura.timer then
		aura.timer:SetText(entry[3])
	end
end

local function dispel(env, Widgets, button, kind)
	local color = env["DEBUFF_TYPE_" .. kind .. "_COLOR"]
	local pieces = {}
	for i, entry in ipairs(button._aura.dispel) do
		pieces[i] = entry.texture
	end
	Widgets.ColorSlice(pieces, color:GetRGB())
	Widgets.ShowSlice(pieces, true)
end

-- buttons(env, A, container, key, n) -> the first n buttons of the container's group, made as the engine makes a
-- later batch when the first ten run out.
local function buttons(env, A, container, key, n)
	local group, out = container._groups[key], {}
	for i = 1, n do
		local button = group.frames[i]
		if not button then
			button = A.MakeButton(env, container, container._groups[key].initializeFrame)
			group.frames[i] = button
		end
		out[i] = button
	end
	return out
end

-- debuffRow(env, A, Widgets, container, n, columns) fills n debuffs across the container's dispellable group and
-- the rest, the first five with the engine's dispel-type rims, and lays them out as one row sequence.
local function debuffRow(env, A, Widgets, container, n, columns)
	local dispellable = math.min(n, math.ceil(n / 2))
	local first = buttons(env, A, container, container._order[1], dispellable)
	local rest = buttons(env, A, container, container._order[2] or container._order[1], n - dispellable)
	local all = {}
	for i, button in ipairs(first) do
		fill(env, button, DEBUFF_ROW[(i - 1) % #DEBUFF_ROW + 1])
		dispel(env, Widgets, button, DISPEL[(i - 1) % 4 + 1])
		all[#all + 1] = button
	end
	for i, button in ipairs(rest) do
		fill(env, button, DEBUFF_ROW[(i + dispellable - 1) % #DEBUFF_ROW + 1])
		dispel(env, Widgets, button, "NONE")
		all[#all + 1] = button
	end
	Hud.PlaceAuras(container, container._groups[container._order[1]], all, columns)
end

local function card(index, n)
	local A = dofile("Tools/regression/auras_env.lua")
	local env, K, ns = A.New(Common.ScreenOpts({ saved = Gallery.Saved({ "Auras" }), setup = Gallery.Setup }))
	if not K.Modules.IsRunning("Auras") then
		K.Modules.Enable("Auras")
	end
	env.RunTimers()
	local Widgets = K.Widgets
	local frames = Gallery.Frames()
	for _, container in ipairs(env._containers) do
		for _, button in ipairs(A.Buttons(container)) do
			button:Hide()
		end
	end
	local x, top = AT[index][1], AT[index][2]
	assert(K.Layout.Update("auras.buffs", { anchor = "TOPLEFT", x = x, y = -top }))
	env.RunTimers()
	local settings = K.Store.Module("Auras")
	local Model = ns.Model
	local buffGroup, debuffGroup = Model.Group(settings, "buffs"), Model.Group(settings, "debuffs")
	local _, spec = Hud.Class({ class = "WARRIOR" })
	local row = Hud.BuffRow(spec, math.max(n, 1))
	local helpful = A.Container(env, "HELPFUL")
	local harmful = A.Container(env, "HARMFUL")
	local capacity = Model.Capacity(buffGroup, 0)
	local shown = buttons(env, A, helpful, "buffs", math.min(n, capacity))
	for i, button in ipairs(shown) do
		fill(env, button, row[(i - 1) % #row + 1])
	end
	Hud.PlaceAuras(helpful, helpful._groups.buffs, shown, buffGroup.columns)
	debuffRow(env, A, Widgets, harmful, DEBUFFS, debuffGroup.columns)
	-- The card counts the player's auras through C_UnitAuras.GetAuraSlots; the stub answers the counts laid out.
	local counts = { HELPFUL = n, HARMFUL = DEBUFFS }
	env.C_UnitAuras = {
		GetAuraSlots = function(_, filter, maxSlots, continuation)
			local total, from = counts[filter] or 0, (continuation or 0) + 1
			local out, last = {}, math.min(total, from + (maxSlots or total) - 1)
			for i = from, last do
				out[#out + 1] = i
			end
			return last < total and last or nil, unpack(out)
		end,
	}
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	A.Counters(ns, { n, 0, DEBUFFS })
	A.W.Settle(env)
	local desc = ns.Panel.Group("buffs")
	local element = K.Layout.Element("auras.buffs").frame
	local region = { element }
	local over = math.max(0, n - capacity)
	local caption
	if n == 0 then
		caption = "No buffs: the Blessings card holds the twelve debuffs alone, two rows of six, the dispellable ones first with their type rims, and ends one padding under them."
	elseif over == 0 then
		caption = string.format("%d buffs over two rows of six, the twelve debuffs under the hairline; every aura shows, so the cap carries no count.", n)
	else
		caption = string.format("%d buffs: the two rows the card allows show the first twelve by the sort, and the cap counts the rest, +%d, at its right.", n, over)
	end
	if n == COUNTS[#COUNTS] then
		-- The pointer rests on the count: the full list stands open left of the card.
		A.W.Enter(desc.card.moreButton)
		env.RunTimers()
		local more = desc.card.more
		local full = A.Container(env, "HELPFUL", 2)
		local fullHarm = A.Container(env, "HARMFUL", 2)
		local all = buttons(env, A, full, "buffs", math.min(n, Model.MORE.buffs))
		for i, button in ipairs(all) do
			fill(env, button, row[(i - 1) % #row + 1])
		end
		Hud.PlaceAuras(full, full._groups.buffs, all, Model.MORE.columns)
		debuffRow(env, A, Widgets, fullHarm, DEBUFFS, Model.MORE.columns)
		A.W.Settle(env)
		region[#region + 1] = more
		caption = caption .. string.format(" The pointer rests on the count, so the full list stands open beside the card: all %d buffs and the twelve debuffs on %d-unit tiles, %d to a row, on the panel grade's glass.", n, Model.MORE.iconSize, Model.MORE.columns)
	end
	frames:Add(env, element, {
		name = "auras_count_" .. n, title = string.format("Blessings, %d buffs", n), grade = "panel", reference = "bufficons",
		caption = caption,
		match = "The card, tiles and rims as the Blessings card frame; the mockup shows five buffs and no debuffs, so the rows, the count and the full list are this card's own.",
		rect = Gallery.Union(env, region),
	})
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "the aura buttons are laid out and filled by the scene as the AuraContainer engine would; the game binds each icon (as a secret), timer and dispel colour itself"
	return frames:Finish(scene, env, K, "gallery auras counts " .. n)
end

return Common.Run(function()
	local scenes = {}
	for i, n in ipairs(COUNTS) do
		scenes[i] = card(i, n)
	end
	local merged = Scene.Merge(scenes)
	merged.frames = {}
	for _, scene in ipairs(scenes) do
		for _, frame in ipairs(scene.frames or {}) do
			merged.frames[#merged.frames + 1] = frame
		end
	end
	return merged
end)
