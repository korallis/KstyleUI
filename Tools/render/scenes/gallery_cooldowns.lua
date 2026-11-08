-- gallery_cooldowns.lua: every frame KstyleUI_Cooldowns draws that the HUD scene does not already show, each cropped
-- as one frame of the gallery: the mirror's tracked buff icons with timers and a stack count, a column of four
-- tracked buff bars (one nearly expired, one with a count), the settings window's live preview, and Blizzard's
-- three viewers restyled in place on the reskin path, laid out by the scene the way Edit Mode would. The centre
-- cluster (essential and utility rows) is the HUD scene's, so it is not repeated here.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Scene = Common.Scene
local I = Hud.ICONS

local NOW = 10
local SCREEN_H = 1080
local PREVIEW_W, PREVIEW_H = 256, 350

-- The mirror's tracked buffs: cooldown ID, spell ID, icon, name, { total, left } and an optional stack text.
local BUFFS = {
	{ 301, 3001, "bloodrage", "Bloodrage", { 30, 24 } },
	{ 302, 3002, "bloodFury", "Blood Fury", { 25, 17 }, "2" },
	{ 303, 3003, "victoryRush", "Victory Rush", { 20, 12 } },
	{ 304, 3004, "shieldBlock", "Shield Block", { 600, 480 } },
	{ 305, 3005, "demoralizingShout", "Demoralizing Shout", { 300, 180 } },
}
local BARS = {
	{ 401, 4001, "battleShout", "Battle Shout", { 120, 24 } },
	{ 402, 4002, "enrage", "Enrage", { 12, 12 } },
	{ 403, 4003, "bloodFury", "Blood Fury", { 25, 1 } },
	{ 404, 4004, "shieldBlock", "Shield Block", { 600, 480 }, "3" },
}

-- Where the scene puts Blizzard's viewers (screen units from the top left) and the sizes Edit Mode gives their
-- items, as scenes/cooldowns.lua lays them out; that scene keeps its layout functions local, so the minimum is
-- copied here.
local ESSENTIAL = { x = 520, y = 80, size = 56, gap = 8, icons = { I.mortalStrike, I.whirlwind, I.execute }, cooldown = { [1] = { total = 8, left = 4 } }, charges = { [3] = "2" } }
local RESKIN_BUFFS = { x = 520, y = 190, size = 30, gap = 3, icons = { I.bloodrage, I.berserkerRage, I.victoryRush }, cooldown = { [2] = { total = 18, left = 10 } }, stacks = { [1] = "2" } }
local RESKIN_BARS = { x = 520, y = 270, width = 195, height = 24, gap = 3, icons = { I.battleShout, I.enrage }, names = { "Battle Shout", "Enrage" }, times = { "24s", "12s" }, values = { { 120, 24 }, { 12, 12 } } }
local NAME_INSET, NAME_END, DURATION_INSET, ICON_GAP = 5, -25, -8, 2

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

local function place(frame, relative, x, y, width, height)
	frame:ClearAllPoints()
	frame:SetSize(width, height)
	frame:SetPoint("TOPLEFT", relative, "TOPLEFT", x, -y)
end

-- Layout-registered holders move through Layout, as the player would move them: a BOTTOMLEFT anchor whose
-- y is measured up from the bottom, so top is the screen-unit y of the frame's top edge.
local function layout(K, key, x, top, height)
	assert(K.Layout.Update(key, { anchor = "BOTTOMLEFT", x = x, y = SCREEN_H - top - height }))
end

-- Mirror() -> scene, env, K: the mirror path's buff icons, buff bars and the options preview.
local function Mirror()
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local cooldowns, names, textures = {}, {}, {}
	for group, list in pairs({ buffs = BUFFS, bars = BARS }) do
		local category = group == "buffs" and C.CATEGORY.TrackedBuff or C.CATEGORY.TrackedBar
		for _, entry in ipairs(list) do
			cooldowns[entry[1]] = { spellID = entry[2], category = category, selfAura = true, hasAura = true }
			names[entry[2]], textures[entry[2]] = entry[4], I[entry[3]]
		end
	end
	local env, K, ns = C.New({
		saved = Gallery.Saved({ Cooldowns = { path = "mirror" } }),
		cooldowns = cooldowns,
		setup = function(env)
			Gallery.Setup(env)
			C.Game(env)
			env.C_Spell.GetSpellName = function(spell)
				return names[spell] or ("Spell " .. spell)
			end
			for spell, texture in pairs(textures) do
				env._cdm.textures[spell] = texture
			end
		end,
	})
	local cdm = env._cdm
	env._time = NOW
	local instance = 80
	for _, list in ipairs({ BUFFS, BARS }) do
		for _, entry in ipairs(list) do
			local spell, state, stacks = entry[2], entry[5], entry[6]
			instance = instance + 1
			cdm.auras[spell] = { auraInstanceID = instance }
			cdm.auraDurations[instance] = { kind = "aura", start = NOW - (state[1] - state[2]), finish = NOW + state[2], remaining = state[2], total = state[1] }
			if stacks then
				cdm.stacks[instance] = stacks
			end
		end
	end
	K.Options.Write("Cooldowns", "bars.count", #BARS)
	C.Enable(env, K)
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	env.RunTimers()

	local frames = Gallery.Frames()
	local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
	assert(buffs.count == #BUFFS, "five tracked buffs show, got " .. tostring(buffs.count))
	assert(bars.count == #BARS, "four tracked bars show, got " .. tostring(bars.count))
	local _, bh = buffs.holder:GetSize()
	layout(K, "cooldowns.buffs", 60, 80, bh)
	frames:Add(env, buffs.holder, {
		name = "cooldowns_buffs", title = "Tracked buff icons", grade = "button", reference = "bufficons",
		caption = "The mirror's tracked buff row (Row.lua): five Widgets.IconButton tiles with the reverse swipe, centred countdowns and one stack count, each on the button grade's body, bezel and accent rim.",
		match = "Body #101214, dark bezel, one-border lit rim and the icon 11% in, as the mockup's cluster buttons; the mockup's buff icons wear a neutral grey rim where these follow Widgets.SECONDARY_RIM at the full accent.",
	})
	local _, barsH = bars.holder:GetSize()
	layout(K, "cooldowns.bars", 60, 80 + bh + 40, barsH)
	frames:Add(env, bars.holder, {
		name = "cooldowns_bars", title = "Tracked buff bars", grade = "bar", reference = "buffbars",
		caption = "The mirror's tracked buff bars (Bars.lua): four 195 by 24 glass tiles on the bar grade, each with the icon on a buttonFill tile, the name, the subtle class-colour fill and a right-aligned countdown; the third is nearly expired and the fourth shows a stack count.",
		match = "Surface fill, the faint edgeBar line, 3.5-unit tile chamfer and no shadow, as the mockup's two buff bars; the icon tile is the button body with the plain hairline, no rim accent.",
	})

	-- The settings window's live preview, on a pane the width of the options window's preview holder.
	local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(pane, 60, 80 + bh + 40 + barsH + 40, PREVIEW_W, PREVIEW_H)
	local preview = ns.Preview.Build(pane)
	assert(preview and preview.rows and preview.rows.bars, "the preview built its rows")
	frames:Add(env, pane, {
		name = "cooldowns_preview", title = "Cooldowns preview", grade = "button", reference = "cluster",
		caption = "Preview.lua, the options window's live preview: sample essential, utility and buff rows of IconButton tiles with cooldowns, charges and a proc, and two buff bars, drawn with the current settings; the rows fit as many columns as the 256-unit pane holds.",
		match = "Icon tiles as the mockup's cluster buttons (body, bezel, rim); the bars as its buff bars (surface, edgeBar, tile chamfer). The pane itself has no chrome of its own: in the options window it sits on the preview panel's buttonFill tile.",
	})

	C.W.Settle(env)
	env.RunTimers()
	return frames, env, K
end

local function iconViewer(env, viewer, spec)
	local count = #viewer._items
	place(viewer, env.UIParent, spec.x, spec.y, count * spec.size + (count - 1) * spec.gap, spec.size)
	for i, item in ipairs(viewer._items) do
		place(item, viewer, (i - 1) * (spec.size + spec.gap), 0, spec.size, spec.size)
		item.Icon:SetAllPoints(item)
		item.Icon:SetTexture(spec.icons[i])
		item.Overlay:SetAllPoints(item)
		item.OutOfRange:SetAllPoints(item)
		item.Cooldown:SetAllPoints(item)
		local cooldown = spec.cooldown[i]
		if cooldown then
			item.Cooldown:SetCooldown(NOW - (cooldown.total - cooldown.left), cooldown.total)
		end
		-- Blizzard's template places these texts; the stand-in anchors them where its XML does.
		item.ChargeCount:SetAllPoints(item)
		item.ChargeCount.Current:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
		item.ChargeCount.Current:SetText(spec.charges and spec.charges[i] or "")
		item.Applications:SetAllPoints(item)
		item.Applications.Applications:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
		item.Applications.Applications:SetText(spec.stacks and spec.stacks[i] or "")
	end
end

local function barViewer(env, viewer, spec)
	local count = #viewer._items
	place(viewer, env.UIParent, spec.x, spec.y, spec.width, count * spec.height + (count - 1) * spec.gap)
	for i, item in ipairs(viewer._items) do
		place(item, viewer, 0, (i - 1) * (spec.height + spec.gap), spec.width, spec.height)
		local icon = item.Icon
		place(icon, item, 0, 0, spec.height, spec.height)
		icon.Icon:SetAllPoints(icon)
		icon.Icon:SetTexture(spec.icons[i])
		icon.Overlay:SetAllPoints(icon)
		local bar = item.Bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", ICON_GAP, 0)
		bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
		bar.BarBG:SetAllPoints(bar)
		bar.Pip:SetAllPoints(bar)
		bar.Name:ClearAllPoints()
		bar.Name:SetPoint("TOPLEFT", bar, "TOPLEFT", NAME_INSET, 0)
		bar.Name:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", NAME_END, 0)
		bar.Name:SetJustifyH("LEFT")
		bar.Name:SetText(spec.names[i])
		bar.Duration:ClearAllPoints()
		bar.Duration:SetPoint("RIGHT", bar, "RIGHT", DURATION_INSET, 0)
		bar.Duration:SetText(spec.times[i])
		bar:SetMinMaxValues(0, spec.values[i][1])
		bar:SetValue(spec.values[i][2])
	end
end

-- Reskin() -> scene, env, K: Blizzard's viewers restyled in place, in their own environment.
local function Reskin(frames)
	local C = dofile("Tools/regression/cooldowns_env.lua")
	local env, K = C.New({
		saved = Gallery.Saved({ Cooldowns = { path = "reskin" } }),
		setup = function(env)
			Gallery.Setup(env)
			C.Game(env)
		end,
	})
	env._time = NOW
	local viewers = env._viewers
	C.Enable(env, K)
	-- The module is running since boot, so a third item reaches it as Blizzard's viewer hands one over: through
	-- OnAcquireItemFrame, which the reskin hooks.
	for _, name in ipairs({ "EssentialCooldownViewer", "BuffIconCooldownViewer" }) do
		local viewer = viewers[name]
		viewer:OnAcquireItemFrame(C.Item(env, viewer, 3))
	end
	iconViewer(env, viewers.EssentialCooldownViewer, ESSENTIAL)
	iconViewer(env, viewers.BuffIconCooldownViewer, RESKIN_BUFFS)
	barViewer(env, viewers.BuffBarCooldownViewer, RESKIN_BARS)
	viewers.UtilityCooldownViewer:Hide()
	frames:Add(env, viewers.EssentialCooldownViewer, {
		name = "cooldowns_reskin_icons", title = "Reskinned cooldown viewer", grade = "button", reference = "cluster",
		caption = "Blizzard's EssentialCooldownViewer restyled in place by Reskin.lua: each item's overlay hushed, the icon cropped, and a Skin.Backdrop icon chrome two units outside it on the button grade, resting on SetRimAccent with the module's accent; one item on cooldown, one with a charge count.",
		match = "Body #101214 and the lit accent rim as the mockup's cluster buttons; no bezel, because Blizzard's item is the frame the chrome hangs on, so the dark plate is the two-unit outset only.",
	})
	frames:Add(env, viewers.BuffIconCooldownViewer, {
		name = "cooldowns_reskin_buffs", title = "Reskinned buff icon viewer", grade = "button", reference = "bufficons",
		caption = "Blizzard's BuffIconCooldownViewer restyled in place: 30-unit items with the same icon chrome, one with a stack count and one with a running swipe.",
		match = "Body and accent rim as the mockup's cluster buttons; the mockup's own buff icons wear a neutral rim.",
	})
	frames:Add(env, viewers.BuffBarCooldownViewer, {
		name = "cooldowns_reskin_bars", title = "Reskinned buff bar viewer", grade = "bar", reference = "buffbars",
		caption = "Blizzard's BuffBarCooldownViewer restyled in place: the bar's background and pip hushed, a Skin.Backdrop surface tile with the edgeBar line one unit outside the bar, the icon on a buttonFill tile, the fill in the class colour at the bars' alpha, and Blizzard's name and duration texts in the module's fonts.",
		match = "Surface fill, faint edgeBar line and tile chamfer as the mockup's buff bars; this branch passes edge = edgeBar, where before it took the panel's brighter edgeInner.",
	})
	C.W.Settle(env)
	return env, K
end

return Common.Run(function()
	local frames, env, K = Mirror()
	local env2, K2 = Reskin(frames)
	local mirror = Gallery.Build(env, { time = NOW })
	local reskin = Gallery.Build(env2, { time = NOW })
	for i, line in ipairs(reskin.log) do
		reskin.log[i] = "reskin: " .. line
	end
	local err = Common.Errors(env2, K2)
	if err then
		reskin.log[#reskin.log + 1] = "error: " .. err
	end
	reskin.log[#reskin.log + 1] = "Blizzard's viewers and their items are laid out by the scene as Edit Mode would; the charge and stack texts are the stand-in's"
	return frames:Finish(Scene.Merge({ mirror, reskin }), env, K, "gallery cooldowns")
end)
