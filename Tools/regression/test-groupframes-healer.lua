-- test-groupframes-healer.lua: the healer's group frames: raid names off the class fill, missing health by default, your heals over time from the aura engine, the shield line, the click casting reminder and outlined text on the bar.
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
	G.SetRoster(env, "raid", members)
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

-- Defaults a healer can raid with: the name above the bar, the missing health beside it, three of your heals over
-- time, the shield line and the click casting reminder.
local env, K, ns = raid()
local cfg = ns.Settings.current
eq(cfg.raid.textLayout, "ABOVE", "raid names sit above the bar, off the class fill")
eq(cfg.raid.healthText, "DEFICIT", "raid frames show the missing health")
eq(cfg.raid.buffCount, 3, "three of your heals over time on a raid frame")
eq(cfg.buffs.enabled, true, "your heals over time are on")
eq(cfg.prediction.shield, true, "the shield line is on")
eq(cfg.clickCast.hint, true, "the click casting reminder is on")

-- A priest's white fill never sits under the name: the renderer resolves the name, the missing health and the bar,
-- and the texts sit above the bar inside the tile, on the glass.
local f = content(ns, ns.Headers.raid[1], "raid1")
assert(f, "raid1 has a frame")
local scene = Scene.Build(env)
local name, deficit, tile = find(scene, f.name), find(scene, f.healthText), { Scene.Rect(env, f) }
local bar = { rect = { Scene.Rect(env, f.health) } }
assert(name and deficit and bar.rect[1] and tile[1], "the renderer resolves the name, the bar and the missing health")
assert(not intersects(name.rect, bar.rect), "the name is off the class fill")
assert(not intersects(deficit.rect, bar.rect), "and so is the missing health")
assert(not intersects(name.rect, deficit.rect), "the name ends before the missing health")
assert(bar.rect[4] >= 16, "the bar is a solid band, at least 16 units tall: " .. tostring(bar.rect[4]))
for _, item in ipairs({ name, deficit, bar }) do
	local r = item.rect
	assert(r[1] >= tile[1] - 0.01 and r[1] + r[3] <= tile[1] + tile[3] + 0.01 and r[2] >= tile[2] - 0.01 and r[2] + r[4] <= tile[2] + tile[4] + 0.01, "inside the tile")
end
local er, eg, eb = K.Tokens.Color("textEmphasis")
local nr, ng, nb = f.name:GetTextColor()
assert(W.Near(nr, er) and W.Near(ng, eg) and W.Near(nb, eb), "names are the light text colour on the glass, never the class colour on the fill")

-- The skull on a raid frame sits inside the tile, not on the 3-unit seam between two tiles.
env._member("raid1").marker = 8
ns.Unit.Refresh(f)
scene = Scene.Build(env)
local marker = find(scene, f.marker)
assert(marker, "the marker draws")
assert(marker.rect[2] >= tile[2] - 0.01 and marker.rect[2] + marker.rect[4] <= tile[2] + tile[4] + 0.01, "the marker stays inside the tile's height")

K.Options.Write("GroupFrames", "raid.buffCount", 2)
env.RunTimers()
-- Everything at once on a default raid tile: the leader, the skull, the role icon, the missing health, a full debuff
-- strip and your heals. Nothing overlaps, so no indicator hides another.
do
	local m = env._member("raid1")
	m.leader, m.role = true, "HEALER"
	ns.Unit.Refresh(f)
	ns.Style.Apply(f)
	scene = Scene.Build(env)
	local tileRect = { Scene.Rect(env, f) }
	local rects = {}
	for _, key in ipairs({ "leader", "marker", "role", "healthText", "name" }) do
		local item = find(scene, f[key])
		assert(item, "the " .. key .. " draws")
		rects[key] = item.rect
	end
	local k = ns.Settings.current.raid
	local debuffs, heals = f.auras._groups, f.buffs._groups.buffs
	local cells = k.auraColumns * k.auraRows
	local columns = math.min(k.auraColumns, math.min(k.auraCount, cells) + math.min(k.auraDispelCount, cells))
	local dsize, dsp = debuffs.debuffs.layout.elementWidth, debuffs.debuffs.layout.elementSpacing
	local inset = K.Widgets.Snap(f, K.Tokens.Size("gapTiny"))
	local dwidth = columns * dsize + (columns - 1) * dsp
	rects.debuffs = { tileRect[1] + inset, tileRect[2] + tileRect[4] - inset - dsize, dwidth, dsize }
	local bx, by, bw, bh = Scene.Rect(env, f.health)
	-- One more heal than fits may fill the clipped cell beyond the row, for the overflow mark.
	local n, hsize, hsp = heals.maxFrameCount - 1, heals.layout.elementWidth, heals.layout.elementSpacing
	local hp = f.buffClip._points[1]
	assert(hp[1] == "TOPRIGHT" and hp[3] == "RIGHT", "your heals hang from the bar's right end")
	local hx, hy = bx + bw + hp[4], by + bh / 2 - hp[5]
	eq(n, 2, "the count setting of two stands")
	local hwidth = n * hsize + (n - 1) * hsp
	rects.heals = { hx - hwidth, hy, hwidth, hsize }
	local names = { "leader", "marker", "role", "healthText", "name", "debuffs", "heals" }
	for i = 1, #names do
		local r = rects[names[i]]
		assert(r[1] >= tileRect[1] - 0.01 and r[1] + r[3] <= tileRect[1] + tileRect[3] + 0.01, "the " .. names[i] .. " stays within the tile's width")
		for j = i + 1, #names do
			-- The leader crown is a badge on the role icon's corner on a raid tile (round 2); every other pair stays apart.
			local badge = (names[i] == "leader" and names[j] == "role") and f.parts.icons.badge
			if not badge then
				assert(not intersects(r, rects[names[j]]), "the " .. names[i] .. " and the " .. names[j] .. " do not overlap")
			end
		end
	end
	K.Options.Write("GroupFrames", "raid.buffCount", 3)
	env.RunTimers()
	eq(heals.maxFrameCount - 1, 3, "three heals fit beside the default two-column debuff strip")
	K.Options.Write("GroupFrames", "raid.auraColumns", 3)
	env.RunTimers()
	eq(heals.maxFrameCount - 1, 2, "a three-column strip leaves room for two")
	K.Options.Write("GroupFrames", "raid.auraColumns", 2)
	env.RunTimers()
	m.leader, m.marker = false, nil
	ns.Unit.Refresh(f)
end

-- A dead or offline member's state reads on the grey bar, so the name keeps the whole row; alive again, the missing
-- health returns to the row.
do
	local m = env._member("raid1")
	m.dead, m.health = true, 0
	env.FireEvent("UNIT_HEALTH", "raid1")
	eq(f.healthText:GetText(), "Dead", "the frame says Dead")
	local hp = f.healthText._points[1]
	assert(hp[1] == "CENTER" and #f.healthText._points == 1, "centred on the bar")
	local np = f.name._points
	assert(#np == 1 and np[1][1] == "TOPLEFT" and f.name:GetWidth() > 30, "the name keeps the row: " .. tostring(f.name:GetWidth()))
	scene = Scene.Build(env)
	local dead, barRect = find(scene, f.healthText), { Scene.Rect(env, f.health) }
	assert(dead and intersects(dead.rect, barRect) and not intersects(dead.rect, find(scene, f.name).rect), "on the bar, clear of the name")
	m.dead, m.health = false, 70
	env.FireEvent("UNIT_HEALTH", "raid1")
	eq(f.healthText._points[1][1], "TOPRIGHT", "alive, the missing health is back at the row's end")
	-- The missing health keeps a fixed reserve, so the name gets a known width that ends a gap before it.
	assert(f.healthText._width > 0 and f.name:GetWidth() > 0, "the reserve and the name's width are set")
	scene = Scene.Build(env)
	assert(not intersects(find(scene, f.name).rect, find(scene, f.healthText).rect), "and the name ends before it")
end

-- The shield line: the whole shield, unclamped, along the bar's foot, so a shield shows at full health.
eq(env.Reveal(W.LastCall(f.shield, "SetValue")[1]), 40, "the line carries UnitGetTotalAbsorbs, a secret passed straight to the bar")
eq(env.Reveal(W.LastCall(f.shield, "SetMinMaxValues")[2]), 100, "spanning the health maximum")
assert(f.shield:IsShown(), "the line shows")
local sp = f.shield._points[1]
assert(sp[1] == "BOTTOMLEFT" and sp[2] == f.health, "at the bar's foot")
assert(f.shield:GetHeight() < f.health:GetHeight() / 4, "a thin line, not a second bar")
env._member("raid1").absorb = 70
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "raid1")
eq(env.Reveal(W.LastCall(f.shield, "SetValue")[1]), 70, "a new shield moves the line")
K.Options.Write("GroupFrames", "prediction.shield", false)
env.RunTimers()
assert(not f.shield:IsShown(), "the line can be turned off")
K.Options.Write("GroupFrames", "prediction.shield", true)
env.RunTimers()

-- Your heals over time: a second engine container on the frame, Blizzard's unit frame processing keeping the
-- buffs you cast that raid frames show, at the bar's right end.
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
eq(group.maxFrameCount, 4, "three at most, plus one for the overflow mark")
assert(W.Near(group.layout.elementWidth, 10, 0.5), "10-unit icons on a raid frame, snapped to whole pixels: " .. tostring(group.layout.elementWidth))
local bp = f.buffClip._points[1]
assert(bp[1] == "TOPRIGHT" and bp[2] == f.health and bp[3] == "RIGHT", "the clip holding them is anchored to the bar's right end")
eq(buffs._flow.horizontal, env.AnchorUtil.FlowDirection.Left, "growing left along the bar")
eq(f.auras._policyOptions.ignoreBuffs, true, "the debuff container still ignores buffs")
assert(f.ready:GetParent():GetFrameLevel() > buffs:GetFrameLevel() and f.ready:GetParent():GetFrameLevel() > f.auras:GetFrameLevel(), "a ready check's mark draws above your heals and the debuffs")
local icon = group.frames[1]
assert(icon._aura.icon and icon._aura.cooldown, "each heal icon has its icon and duration swipe bound")
assert(W.Near((icon:GetSize()), 10, 0.5), "and is 10 units")

K.Options.Write("GroupFrames", "raid.buffCount", 2)
env.RunTimers()
eq(group.maxFrameCount, 3, "the count setting reaches the engine, plus one for the overflow mark")
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
