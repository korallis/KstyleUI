-- gallery_auras_counts.lua: the aura rows at five buff counts beside twelve debuffs, each cropped as one frame: no
-- buffs (the debuff rows alone), two, eight, twenty-four (two rows show, "+9" on the last cell) and forty ("+25").
-- Each pair of rows is its own environment, as the HUD scene builds one module several ways; the five scenes merge
-- into one render. The fake AuraContainer engine lays out no buttons and binds no icon or timer, so this scene
-- fills the buttons and places them as the engine's flow layout would, the way scenes/hud.lua does.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene

local COUNTS = { 0, 2, 8, 24, 40 }
local DEBUFFS = 12
local ROW_GAP = 16
local AT = { { 60, 80 }, { 420, 80 }, { 780, 80 }, { 60, 360 }, { 420, 360 } }
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
	if aura.bar then
		aura.bar:Hide()
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

local function rows(index, n)
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
	assert(K.Layout.Update("auras.debuffs", { anchor = "TOPLEFT", x = x, y = -(top + 88 + ROW_GAP) }))
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
	local harm = buttons(env, A, harmful, "debuffs", DEBUFFS)
	for i, button in ipairs(harm) do
		fill(env, button, DEBUFF_ROW[(i - 1) % #DEBUFF_ROW + 1])
		dispel(env, Widgets, button, DISPEL[(i - 1) % #DISPEL + 1])
	end
	Hud.PlaceAuras(harmful, harmful._groups.debuffs, harm, debuffGroup.columns)
	A.Counters(ns, { n, 0, DEBUFFS })
	A.W.Settle(env)
	local buffElement = K.Layout.Element("auras.buffs").frame
	local debuffElement = K.Layout.Element("auras.debuffs").frame
	local over = math.max(0, n - capacity)
	local caption
	if n == 0 then
		caption = "No buffs: the buff element stands empty and the twelve debuffs fill their own two rows of eight under it, dispel plates on each."
	elseif over == 0 then
		caption = string.format("%d buffs over two rows of eight growing left, the twelve debuffs 16 under them; every aura shows, so no cell counts.", n)
	else
		caption = string.format("%d buffs: the two rows show the first fifteen by the sort and the last cell reads +%d, the covered buff and the %d past the rows, counted by the engine's own layout.", n, over + 1, over)
	end
	frames:Add(env, buffElement, {
		name = "auras_count_" .. n, title = string.format("Aura rows, %d buffs", n), grade = "button", reference = "bufficons",
		caption = caption,
		match = "Bare tiles as the buff rows frame; the mockup shows five buffs and no debuffs, so the second row, the count and the debuff rows are these rows' own.",
		rect = Gallery.Union(env, { buffElement, debuffElement }),
	})
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "the aura buttons are laid out and filled by the scene as the AuraContainer engine would; the game binds each icon (as a secret), timer and dispel colour itself"
	return frames:Finish(scene, env, K, "gallery auras counts " .. n)
end

return Common.Run(function()
	local scenes = {}
	for i, n in ipairs(COUNTS) do
		scenes[i] = rows(i, n)
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
