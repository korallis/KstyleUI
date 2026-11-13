-- test-groupframes-healer.lua: the healer's group frames: raid names off the fill in the class colour, the percent at the bar's end by default, three of your heals over time from the aura engine beside a whole name, the shield line, the click casting reminder and outlined text on the bar.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button), button
		end
		i = i + 1
	end
end

local SCREEN = { width = 2383, height = 1540, uiScale = 768 / 1080 }

local function raid(opts)
	opts = opts or {}
	local env, K, ns = G.New({ width = SCREEN.width, height = SCREEN.height, uiScale = SCREEN.uiScale, saved = opts.saved, setup = opts.setup })
	local members = G.Members(5, function(i, m)
		if i == 1 then
			m.class, m.name, m.health, m.absorb = "PRIEST", "Ysra", 70, 40
		end
	end)
	G.SetRoster(env, "raid", members, { name = "Tester", class = "PRIEST", role = "HEALER" })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

-- Defaults a healer can raid with: the name above the bar, the percent at its end, three of your heals over time,
-- the shield line and the click casting reminder.
local env, K, ns = raid()
local cfg = ns.Settings.current
eq(cfg.raid.textLayout, "ABOVE", "raid names sit above the bar, off the fill")
eq(cfg.raid.healthText, "PERCENT", "raid frames show the percent at the bar's end (KSTY-57)")
eq(cfg.raid.buffCount, 3, "three of your heals over time on a raid frame")
eq(cfg.buffs.enabled, true, "your heals over time are on")
eq(cfg.prediction.shield, true, "the shield line is on")
eq(cfg.clickCast.hint, true, "the click casting reminder is on")

-- A priest's white fill never sits under the name: the renderer resolves the name, the percent and the bar; the name
-- and the percent share the row above the bar, the percent ending at the bar's end (KSTY-57).
local f = content(ns, ns.Headers.raid[1], "raid1")
assert(f, "raid1 has a frame")
local scene = Scene.Build(env)
local name, percent, tile = find(scene, f.name), find(scene, f.healthText), { Scene.Rect(env, f) }
local bar = { rect = { Scene.Rect(env, f.health) } }
assert(name and percent and bar.rect[1] and tile[1], "the renderer resolves the name, the bar and the percent")
assert(not intersects(name.rect, bar.rect), "the name is off the fill")
assert(not intersects(percent.rect, bar.rect), "and so is the percent")
assert(not intersects(name.rect, percent.rect), "the name and the percent keep apart")
assert(math.abs(percent.rect[1] + percent.rect[3] - (bar.rect[1] + bar.rect[3])) <= 1, "the percent ends at the bar's end")
-- The bar is at least the 10-player mock-up's 12 units tall and spans the row.
assert(bar.rect[4] >= 12 - K.Scale.Pixel(1), "the bar is at least the mock-up's 12 units tall, within a pixel: " .. tostring(bar.rect[4]))
assert(bar.rect[3] >= tile[3] - 2 * ns.Geometry.EDGE - K.Scale.Pixel(1), "and spans the row's width: " .. tostring(bar.rect[3]))
for _, item in ipairs({ name, percent, bar }) do
	local r = item.rect
	assert(r[1] >= tile[1] - 0.01 and r[1] + r[3] <= tile[1] + tile[3] + 0.01 and r[2] >= tile[2] - 0.01 and r[2] + r[4] <= tile[2] + tile[4] + 0.01, "inside the tile")
end
local pr, pg, pb = K.Theme.ClassColorForWidget("PRIEST")
local nr, ng, nb = f.name:GetTextColor()
assert(W.Near(nr, pr) and W.Near(ng, pg) and W.Near(nb, pb), "names wear the class colour, off the fill")

-- The skull on a raid frame sits inside the tile, not on the seam between two tiles.
env._member("raid1").marker = 8
ns.Unit.Refresh(f)
scene = Scene.Build(env)
local marker = find(scene, f.marker)
assert(marker, "the marker draws")
assert(marker.rect[2] >= tile[2] - 0.01 and marker.rect[2] + marker.rect[4] <= tile[2] + tile[4] + 0.01, "the marker stays inside the tile's height")

-- Everything at once on a default raid tile: the leader, the skull, the role pip, the percent, a full debuff row and
-- your heals. Nothing overlaps, so no indicator hides another; the marker and the debuffs may sit on the bar (rank R5,
-- as Cell draws them), your heals never.
do
	local m = env._member("raid1")
	m.leader, m.role = true, "HEALER"
	ns.Unit.Refresh(f)
	ns.Style.Apply(f)
	scene = Scene.Build(env)
	local tileRect = { Scene.Rect(env, f) }
	local rects = {}
	for _, key in ipairs({ "leader", "marker", "role", "healthText", "name" }) do
		local region = key == "role" and f.pipEdge or f[key]
		local item = find(scene, region)
		assert(item, "the " .. key .. " draws")
		rects[key] = item.rect
	end
	local heals = f.buffs._groups.buffs
	-- Round 4: the debuff block and your heals' row are clip frames, so their rects bound everything they draw.
	rects.debuffs = { Scene.Rect(env, f.auraClip) }
	rects.heals = { Scene.Rect(env, f.buffClip) }
	rects.bar = { Scene.Rect(env, f.health) }
	-- One more heal than fits may fill the clipped cell beyond the row, for the overflow mark.
	eq(heals.maxFrameCount - 1, 3, "a healer's three heals fit on the name line")
	assert(not intersects(rects.heals, rects.bar), "your heals never sit on the bar")
	local names = { "leader", "marker", "role", "healthText", "name", "debuffs", "heals", "bar" }
	for i = 1, #names do
		local r = rects[names[i]]
		assert(r[1] >= tileRect[1] - 0.01 and r[1] + r[3] <= tileRect[1] + tileRect[3] + 0.01, "the " .. names[i] .. " stays within the tile's width")
		for j = i + 1, #names do
			-- The leader crown is a badge on the role pip's corner (round 2); every other pair stays apart.
			local badge = (names[i] == "leader" and names[j] == "role") and f.parts.icons.badge
			local onBar = names[j] == "bar" and (names[i] == "marker" or names[i] == "debuffs")
			if not badge and not onBar then
				assert(not intersects(r, rects[names[j]]), "the " .. names[i] .. " and the " .. names[j] .. " do not overlap")
			end
		end
	end
	-- Rank R5: your heals share the name line with a name that must stay whole up to twelve letters.
	ns.Names.Set(f, "Thaldrenwick")
	eq(f.name:GetText(), "Thaldrenwick", "a twelve-letter name stays whole beside three heals")
	ns.Names.Set(f, "Ysra")
	K.Options.Write("GroupFrames", "raid.auraColumns", 8)
	env.RunTimers()
	local block = ns.Auras.Block(f, ns.Settings.current.raid)
	assert(block.width <= 0.45 * f.parts.health.width + 0.01, "eight debuff columns would cover too much of the bar, so the block keeps " .. block.columns)
	eq(heals.maxFrameCount - 1, 3, "and your heals keep the name line")
	K.Options.Write("GroupFrames", "raid.auraColumns", 3)
	env.RunTimers()
	m.leader, m.marker = false, nil
	ns.Unit.Refresh(f)
end

-- A dead or offline member's state takes the percent's place at the row's end (KSTY-57: off the bar and off the
-- name); the name stays whole. Alive again, the percent returns.
do
	local m = env._member("raid1")
	m.dead, m.health = true, 0
	env.FireEvent("UNIT_HEALTH", "raid1")
	eq(f.healthText:GetText(), "Dead", "the frame says Dead")
	local hp = f.healthText._points[1]
	assert(hp[1] == "TOPRIGHT" and #f.healthText._points == 1, "right-aligned at the row's end")
	scene = Scene.Build(env)
	local dead, barRect = find(scene, f.healthText), { Scene.Rect(env, f.health) }
	assert(dead and not intersects(dead.rect, barRect) and not intersects(dead.rect, find(scene, f.name).rect), "off the bar and out of the name")
	m.dead, m.health = false, 70
	env.FireEvent("UNIT_HEALTH", "raid1")
	eq(f.healthText._points[1][1], "TOPRIGHT", "alive, the percent is back at the bar's end")
	-- The percent's lane has a set width, and so does the name.
	assert(f.healthText._width > 0 and f.name:GetWidth() > 0, "the lane's and the name's widths are set")
	scene = Scene.Build(env)
	assert(not intersects(find(scene, f.name).rect, find(scene, f.healthText).rect), "and the name ends before it")
end

-- The shield line: the whole shield, unclamped, along the bar's foot, so a shield shows at full health.
eq(env.Reveal(W.LastCall(f.shield, "SetValue")[1]), 40, "the line carries UnitGetTotalAbsorbs, a secret passed straight to the bar")
eq(env.Reveal(W.LastCall(f.shield, "SetMinMaxValues")[2]), 100, "spanning the health maximum")
assert(f.shield:IsShown(), "the line shows")
local sp = f.shield._points[1]
assert(sp[1] == "BOTTOMLEFT" and sp[2] == f.health, "at the bar's foot")
assert(env.Look(f.shield:GetHeight()) < env.Look(f.health:GetHeight()) / 4, "a thin line, not a second bar")
env._member("raid1").absorb = 70
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "raid1")
eq(env.Reveal(W.LastCall(f.shield, "SetValue")[1]), 70, "a new shield moves the line")
K.Options.Write("GroupFrames", "prediction.shield", false)
env.RunTimers()
assert(not f.shield:IsShown(), "the line can be turned off")
K.Options.Write("GroupFrames", "prediction.shield", true)
env.RunTimers()

-- Your heals over time: a second engine container on the frame, Blizzard's unit frame processing keeping the
-- buffs you cast that raid frames show, in their own row under the bar.
local buffs = f.buffs
assert(buffs and buffs ~= f.auras, "the frame has its own container for your heals")
eq(buffs:GetObjectType(), "AuraContainer", "on the AuraContainer engine")
eq(buffs._unit, "raid1", "following the frame's unit")
local types = env.AuraUtil.AuraUpdateChangedType
eq(buffs._policy, env.CustomAuraContainerAuraProcessingPolicy.ProcessAura, "auras processed as Blizzard's raid frames do")
eq(buffs._policyOptions.ignoreBuffs, false, "buffs are classified")
eq(buffs._policyOptions.ignoreDebuffs, true, "debuffs are left to the debuff container")
local group = buffs._groups.buffs
assert(group, "a heals group")
eq(group.filter, "HELPFUL|PLAYER", "only the buffs you cast")
eq(group.candidateFilters.processedAuraType, types.Buff, "that Blizzard's raid frames would show")
eq(group.maxFrameCount, 4, "a healer's three on the name line, plus one for the overflow mark")
local row = f.parts.healRow
assert(W.Near(group.layout.elementWidth, row.height, 0.5), "icons as tall as the heal row, snapped to whole pixels: " .. tostring(group.layout.elementWidth))
do
	local cx, cy = Scene.Rect(env, f.buffClip)
	local fx, fy = Scene.Rect(env, f)
	assert(W.Near(cx - fx, row.left, 0.6) and W.Near(cy - fy, row.top, 0.6), "the clip holding them is the heal row on the name line")
	assert(row.top + row.height <= f.parts.health.top + 0.01, "above the bar")
end
eq(buffs._flow.horizontal, env.AnchorUtil.FlowDirection.Left, "growing left from the tile's right edge toward the name")
eq(f.auras._policyOptions.ignoreBuffs, true, "the debuff container still ignores buffs")
assert(f.ready:GetParent():GetFrameLevel() > buffs:GetFrameLevel() and f.ready:GetParent():GetFrameLevel() > f.auras:GetFrameLevel(), "a ready check's mark draws above your heals and the debuffs")
local icon = group.frames[1]
assert(icon._aura.icon and icon._aura.cooldown, "each heal icon has its icon and duration swipe bound")
assert(W.Near((icon:GetSize()), row.height, 0.5), "and is the row's height")

K.Options.Write("GroupFrames", "auto.role", false)
K.Options.Write("GroupFrames", "raid.buffCount", 2)
env.RunTimers()
eq(group.maxFrameCount, 3, "the count setting reaches the engine, plus one for the overflow mark")
K.Options.Write("GroupFrames", "auto.role", true)
K.Options.Write("GroupFrames", "buffs.enabled", false)
env.RunTimers()
eq(group.enabled, false, "turning them off disables the group")
assert(not buffs:IsShown(), "and hides the container")
K.Options.Write("GroupFrames", "buffs.enabled", true)
env.RunTimers()
assert(buffs:IsShown() and group.enabled, "back on")

-- A frame that first gets a unit in combat makes its heals container after combat, never in it.
env.SetCombat(true)
G.SetRoster(env, "raid", G.Members(7))
env.RunTimers()
local late = content(ns, ns.Headers.raid[2], "raid6")
assert(late, "raid6 has a frame")
eq(late.buffs, nil, "no container is made in combat")
env.SetCombat(false)
env.RunTimers()
assert(late.buffs, "it is made when combat ends")
eq(#env._blocked, 0, "no protected call: " .. tostring(env._blocked[1]))

-- Text on the bar gets an outline, so it reads on any class fill, white priests included.
K.Options.Write("GroupFrames", "raid.textLayout", "INSIDE")
env.RunTimers()
eq(W.LastCall(f.name, "SetFont")[3], "OUTLINE", "a name on the bar is outlined")
eq(W.LastCall(f.healthText, "SetFont")[3], "OUTLINE", "and so is the health text")
K.Options.Write("GroupFrames", "raid.textLayout", "ABOVE")
env.RunTimers()
eq(W.LastCall(f.name, "SetFont")[3], "", "above the bar, on the glass, the soft shadow stays")
eq(#env._errors, 0, tostring(env._errors[1]))

-- Click casting: the frames are SecureUnitButtonTemplate buttons, which run the game's Click Casting bindings
-- (SecureUnitButton_OnClick asks C_ClickBindings first). Until a spell is bound, the tooltip says where to bind it.
local profile = {}
env = raid({
	setup = function(e)
		e.C_ClickBindings = {
			GetProfileInfo = function()
				return profile
			end,
		}
		e.Enum.ClickBindingType = { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
	end,
})
ns = env._addons.KstyleUI_GroupFrames
K = env.KstyleUI
local lines = {}
rawset(env.GameTooltip, "SetUnit", function(_, unit)
	lines = { unit }
end)
rawset(env.GameTooltip, "AddLine", function(_, text)
	lines[#lines + 1] = text
end)
local _, button = content(ns, ns.Headers.raid[1], "raid1")
eq(button:GetAttribute("template") or ns.Headers.raid[1]:GetAttribute("template"), "SecureUnitButtonTemplate", "the buttons are secure unit buttons")
profile[1] = { type = 3, actionID = 1, button = "LeftButton", modifiers = 0 }
button:GetScript("OnEnter")(button)
eq(#lines, 2, "with only the default target and menu clicks, the tooltip adds the reminder")
assert(lines[2]:find("Click Casting", 1, true), "naming the game's Click Casting: " .. tostring(lines[2]))
button:GetScript("OnLeave")(button)
profile[2] = { type = 1, actionID = 774, button = "LeftButton", modifiers = 1 }
button:GetScript("OnEnter")(button)
eq(#lines, 1, "once a spell is bound, no reminder")
profile[2] = nil
env.SetCombat(true)
button:GetScript("OnEnter")(button)
eq(#lines, 1, "never in combat")
env.SetCombat(false)
K.Options.Write("GroupFrames", "clickCast.hint", false)
env.RunTimers()
button:GetScript("OnEnter")(button)
eq(#lines, 1, "and never with the reminder off")
eq(#env._errors, 0, tostring(env._errors[1]))

print("groupframes healer ok")
