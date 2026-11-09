-- gallery_auras.lua: every tile KstyleUI_Auras draws, each cropped as one frame of the gallery: the buff rows with
-- a weapon enchantment and eight buffs over two rows of eight (timers in the body face, two stack badges, one long
-- duration), the debuff rows with their five dispel-type plates, a close crop of three buff tiles, and the Auras
-- page's live preview. The fake AuraContainer engine lays out no buttons and binds no icon, timer or dispel colour,
-- so this scene fills the buttons and places them as the engine's flow layout would, the way scenes/hud.lua does.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local I = Hud.ICONS

local BUFFS_X, BUFFS_Y = 60, 80
local DEBUFFS_Y = BUFFS_Y + 88 + 16
local PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H = 400, 80, 300, 300
local TILE_PAD = 4

-- The enchantment first (the module places enchantments before the aura groups), then the buffs by time left.
local ENCHANT = { "sweepingStrikes", "28m" }
local BUFFS = {
	{ "battleShout", "24s" },
	{ "berserkerRage", "17s", "3" },
	{ "bloodrage", "12s" },
	{ "enrage", "9s", "5" },
	{ "shieldBlock", "8m" },
	{ "bloodFury", "3m" },
	{ "retaliation", "1h" },
	{ "victoryRush", "2.4s" },
}
-- Debuffs with the engine's dispel-type colours: magic, curse, poison, disease and none.
local DEBUFFS = {
	{ "rend", "18s", "MAGIC", "2" },
	{ "hamstring", "9s", "CURSE" },
	{ "sunderArmor", "4s", "POISON" },
	{ "demoralizingShout", "1m", "DISEASE" },
	{ "thunderClap", "26s", "NONE" },
}

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

local function move(K, key, x, y)
	local ok, why = K.Layout.Update(key, { anchor = "TOPLEFT", x = x, y = -y })
	assert(ok, key .. ": " .. tostring(why))
end

-- fill(env, button, icon, timer, count) binds what the engine would: the icon's texture, as a secret the way
-- Forever's engine writes it (so the watched tile keeps the game's art), the timer text, and the stack count with
-- its badge shown, as the engine shows the application bar from two applications.
local function fill(env, button, icon, timer, count)
	local aura = button._aura
	if aura.icon then
		aura.icon:SetTexture(env.Secret(I[icon]))
	end
	if aura.timer then
		aura.timer:SetText(timer)
	end
	if aura.count then
		aura.count:SetText(count or "")
	end
	if aura.bar then
		aura.bar:SetShown(count ~= nil)
	end
end

-- dispel(env, Widgets, button, kind) paints the debuff's nine-piece plate in the dispel type's colour, as the
-- engine's PreserveAsset style does with the pieces the module handed it.
local function dispel(env, Widgets, button, kind)
	local color = env["DEBUFF_TYPE_" .. kind .. "_COLOR"]
	local pieces = {}
	for i, entry in ipairs(button._aura.dispel) do
		pieces[i] = entry.texture
	end
	Widgets.ColorSlice(pieces, color:GetRGB())
	Widgets.ShowSlice(pieces, true)
end

return Common.Run(function()
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

	-- The buff rows: the main-hand enchantment, then eight buffs, over two rows of eight growing left.
	move(K, "auras.buffs", BUFFS_X, BUFFS_Y)
	move(K, "auras.debuffs", BUFFS_X, DEBUFFS_Y)
	local buffs, buffGroup = A.Container(env, "HELPFUL")
	assert(buffs, "the buff container")
	local tiles = {}
	local enchant = buffs._enchants[env.AuraContainerItemEnchantmentSlot.MainHand]
	if enchant then
		fill(env, enchant.frame, ENCHANT[1], ENCHANT[2])
		tiles[#tiles + 1] = enchant.frame
	end
	for i, buff in ipairs(BUFFS) do
		local button = buffGroup.frames[i]
		fill(env, button, buff[1], buff[2], buff[3])
		tiles[#tiles + 1] = button
	end
	Hud.PlaceAuras(buffs, buffGroup, tiles, 8)
	A.Counters(ns, { #BUFFS, 0, #DEBUFFS })
	frames:Add(env, K.Layout.Element("auras.buffs").frame, {
		name = "auras_buffs", title = "Buff rows", grade = "button", reference = "bufficons",
		caption = "The buff rows (Panel.lua): no card, cap or gem; a weapon enchantment tile first, then eight buffs by time left over two rows of eight growing left from the element's right edge, each a 30-unit icon in a thin rim with its timer under it in the body face and a stack count on a corner badge on two.",
		match = "Body-free tiles: the icon under the socket mask one border inside a half-strength edgeInner rim, as the mockup's quiet buff icons; no shadow, no bezel.",
	})

	-- The debuff rows: five debuffs, each plate in its dispel type's colour, on their own element under the buffs.
	local debuffs, debuffGroup = A.Container(env, "HARMFUL")
	assert(debuffs, "the debuff container")
	local harmful = {}
	for i, debuff in ipairs(DEBUFFS) do
		local button = debuffGroup.frames[i]
		fill(env, button, debuff[1], debuff[2], debuff[4])
		dispel(env, Widgets, button, debuff[3])
		harmful[#harmful + 1] = button
	end
	Hud.PlaceAuras(debuffs, debuffGroup, harmful, 8)
	frames:Add(env, K.Layout.Element("auras.debuffs").frame, {
		name = "auras_debuffs", title = "Debuff rows", grade = "button", reference = "bufficons",
		caption = "The debuff rows, their own element 16 under the buffs: five debuffs on the same bare tiles, the hostile rim under a nine-piece plate the engine colours magic, curse, poison, disease and none (red), timers under the icons and a stack badge on the first.",
		match = "Tiles as the buff rows; the rims are the dispel colours, not the mockup's neutral grey, since the mockup shows no debuffs.",
	})

	-- The Auras page's live preview: sample buffs and debuffs on the module's own tiles.
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(parent, PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H)
	local preview = K.Options.Preview("Auras")(parent)
	preview:Refresh()
	frames:Add(env, parent, {
		name = "auras_preview", title = "Auras preview", grade = "button", reference = "bufficons",
		caption = "The Auras page's live preview: six sample buffs and three sample debuffs on the module's own plain tiles with the settings' sizes, timers and badges, the buffs' rim neutral and the debuffs' hostile under dispel plates.",
		match = "The same tiles the rows draw, so the preview shows what a setting does.",
	})

	A.W.Settle(env)
	-- A close crop of the first three buff tiles.
	local closeup = Gallery.Union(env, { tiles[1], tiles[2], tiles[3] })
	assert(closeup, "the first three buff tiles resolve")
	frames:Add(env, tiles[1], {
		name = "auras_tile", title = "Buff tiles, close", grade = "button", reference = "bufficons", pad = TILE_PAD, rect = closeup,
		caption = "Three buff tiles close up: the icon one border inside the half-strength edgeInner rim, the socket chamfer, the timer under each in the body face with a soft shadow, and one stack count on its dark corner badge.",
		match = "A neutral rim as the mockup's buff icons (rim lum 50 to 80), one border wide; no body, no inner band.",
	})

	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "the aura buttons are laid out and filled by the scene as the AuraContainer engine would; the game binds each icon (as a secret, so the tiles show Blizzard's art), timer, badge and dispel colour itself"
	return frames:Finish(scene, env, K, "gallery auras")
end)
