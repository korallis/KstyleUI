-- gallery_auras.lua: every tile KstyleUI_Auras draws, each cropped as one frame of the gallery: the buff panel
-- with a weapon enchantment and eight buffs over two rows (timers, two stack counts, one long duration), the
-- debuff row with its five dispel-type rims, a close crop of three buff tiles, and the Auras page's live preview.
-- The fake AuraContainer engine lays out no buttons and binds no icon, timer or dispel colour, so this scene
-- fills the buttons and places them as the engine's flow layout would, the way scenes/hud.lua does.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local I = Hud.ICONS

local BUFFS_X, BUFFS_Y = 60, 80
local DEBUFFS_X, DEBUFFS_Y = 60, 230
local PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H = 400, 80, 248, 300
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
-- Forever's engine writes it (so the watched tile keeps the game's art), and the timer and count texts.
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
end

-- place(container, group, buttons) lays the buttons out as the container's flow layout would: from the top left,
-- rightwards, wrapping after the group's columns, and sizes the container to the rows it holds.
local function place(container, group, buttons, columns)
	local layout = group.layout or {}
	local width, height, spacing = layout.elementWidth or 38, layout.elementHeight or 51, layout.elementSpacing or 8
	local rows = math.ceil(#buttons / columns)
	container:SetSize(columns * width + (columns - 1) * spacing, rows * height)
	for i, button in ipairs(buttons) do
		local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
		button:ClearAllPoints()
		button:SetSize(width, height)
		button:SetPoint("TOPLEFT", container, "TOPLEFT", col * (width + spacing), -row * height)
		button:Show()
	end
end

-- dispel(env, Widgets, button, kind) paints the debuff's nine-piece rim in the dispel type's colour, as the
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
	local env, K = A.New(Common.ScreenOpts({ saved = Gallery.Saved({ "Auras" }), setup = Gallery.Setup }))
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

	-- The buff panel: the main-hand enchantment, then eight buffs over two rows of five.
	move(K, "auras.buffs", BUFFS_X, BUFFS_Y)
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
	place(buffs, buffGroup, tiles, 5)
	frames:Add(env, K.Layout.Element("auras.buffs").frame, {
		name = "auras_buffs", title = "Buffs", grade = "button", reference = "bufficons",
		caption = "The buff panel: a weapon enchantment tile first, then eight buffs by time left over two rows of five, timers under the icons, stack counts on two, one at 1h; each tile is the button grade's buttonFill body with the neutral edgeInner rim at the rest alpha, no bezel.",
		match = "Body #101214, a one-border neutral grey rim and the 3.5-unit tile chamfer as the mockup's buff icons; the mockup's rim is a shade lighter, and KstyleUI's tiles have no shadow where the mockup's show a faint one.",
	})

	-- The debuff row: five debuffs, each rim in its dispel type's colour.
	move(K, "auras.debuffs", DEBUFFS_X, DEBUFFS_Y)
	local debuffs, debuffGroup = A.Container(env, "HARMFUL")
	assert(debuffs, "the debuff container")
	local harmful = {}
	for i, debuff in ipairs(DEBUFFS) do
		local button = debuffGroup.frames[i]
		fill(env, button, debuff[1], debuff[2], debuff[4])
		dispel(env, Widgets, button, debuff[3])
		harmful[#harmful + 1] = button
	end
	place(debuffs, debuffGroup, harmful, 5)
	frames:Add(env, K.Layout.Element("auras.debuffs").frame, {
		name = "auras_debuffs", title = "Debuffs", grade = "button", reference = "bufficons",
		caption = "The debuff row: five debuffs on the same buttonFill tiles, the hostile rim at the rest alpha under a nine-piece dispel rim the engine colours magic, curse, poison, disease and none (red), timers under the icons and a stack count on the first.",
		match = "Body and tile chamfer as the mockup's buff icons; the rims are the dispel colours, not the mockup's neutral grey, since the mockup shows no debuffs.",
	})

	-- The Auras page's live preview: sample buffs and debuffs on the kit's icon buttons.
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(parent, PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H)
	local preview = K.Options.Preview("Auras")(parent)
	preview:Refresh()
	frames:Add(env, parent, {
		name = "auras_preview", title = "Auras preview", grade = "button", reference = "bufficons",
		caption = "The Auras page's live preview: six sample buffs and three sample debuffs on Widgets.IconButton with the settings' sizes and timers, the buffs' rim neutral and the debuffs' hostile with dispel rims.",
		match = "Body and rim as the mockup's buff icons; unlike the live aura tiles, the kit's IconButton adds the 3-unit buttonFill bezel and the drop shadow the mockup's action buttons have.",
	})

	A.W.Settle(env)
	-- A close crop of the first three buff tiles.
	local closeup = Gallery.Union(env, { tiles[1], tiles[2], tiles[3] })
	assert(closeup, "the first three buff tiles resolve")
	frames:Add(env, tiles[1], {
		name = "auras_tile", title = "Buff tiles, close", grade = "button", reference = "bufficons", pad = TILE_PAD, rect = closeup,
		caption = "Three buff tiles close up: the buttonFill body, the icon two borders in under the chamfer mask, the neutral edgeInner rim at half alpha with its dark outer line, and the timer under each.",
		match = "Body #101214 and a neutral rim as the mockup's buff icons (rim lum 50 to 80); KstyleUI's rim is edgeInner at 50%, the inner band two borders instead of the mockup's 2 to 4 px.",
	})

	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = "the aura buttons are laid out and filled by the scene as the AuraContainer engine would; the game binds each icon (as a secret, so the tiles show Blizzard's art), timer and dispel colour itself"
	return frames:Finish(scene, env, K, "gallery auras")
end)
