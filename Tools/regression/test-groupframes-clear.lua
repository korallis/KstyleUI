-- test-groupframes-clear.lua: no aura ever paints on a group frame's health bar, and the raid tile keeps its own lanes: a name lane that ellipsises at a measured width, the deficit right-aligned in its own lane, a 2x2 debuff block, your heals in a row under the bar and a status ("Dead") off the bar, at the default and the setup layouts' party and raid sizes.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local ELLIPSIS = "..."

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function describe(r)
	return string.format("[x %.1f to %.1f, y %.1f to %.1f]", r[1], r[1] + r[3], r[2], r[2] + r[4])
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local function find(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function saved(settings)
	return { version = 2, profiles = { Default = { GroupFrames = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

-- Every aura rect on the frame that shows: the debuff block, your heals, the six indicator slots.
local function Auras(env, f)
	local out = {}
	if f.auraClip and f.auraClip:IsShown() then
		out[#out + 1] = { "the debuff block", { Scene.Rect(env, f.auraClip) } }
	end
	if f.buffClip and f.buffs and f.buffs:IsShown() then
		local k = f.kind and env._addons.KstyleUI_GroupFrames.Settings.current[f.kind]
		local _, count = env._addons.KstyleUI_GroupFrames.Auras.HealIcons(f, k)
		if count > 0 then
			out[#out + 1] = { "your heals", { Scene.Rect(env, f.buffClip) } }
		end
	end
	if f.indicators then
		for i = 1, 6 do
			local slot = f.indicators._slots["indicator" .. i]
			if slot and slot.enabled then
				slot.frame:Show()
				out[#out + 1] = { "indicator " .. i, { Scene.Rect(env, slot.frame) } }
			end
		end
	end
	return out
end

local function Clear(env, f, what)
	local bar = { Scene.Rect(env, f.health) }
	assert(bar[1], what .. ": the bar resolves")
	local auras = Auras(env, f)
	assert(#auras > 0, what .. ": the frame shows auras to check")
	for _, aura in ipairs(auras) do
		assert(aura[2][1], what .. ": " .. aura[1] .. " resolves")
		assert(not intersects(aura[2], bar), what .. ": " .. aura[1] .. " " .. describe(aura[2]) .. " stays off the health bar " .. describe(bar))
	end
	return auras, bar
end

-- A raid of five in its own environment at one tile size, the first member a long-named tank, the second dead.
local function Raid(size, members)
	local settings = { enabled = true, raid = { width = size.width, height = size.height } }
	local env, K, ns = G.New({ saved = saved(settings) })
	G.SetRoster(env, "raid", G.Members(members or 5, function(i, m)
		if i == 1 then
			m.name, m.role, m.health = "Thaldrenwick", "TANK", 60
		elseif i == 2 then
			m.name, m.dead, m.health = "Maela", true, 0
		end
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

-- Grok R4 #1: party helpful auras crossed Thaldren's bar. Every aura on the party tank stays off the bar.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", dead = true, health = 0 },
	})
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank = content(ns, ns.Headers.party, "party1")
	local auras = Clear(env, tank, "party tank")
	local indicators = 0
	for _, aura in ipairs(auras) do
		indicators = indicators + (aura[1]:find("^indicator") and 1 or 0)
	end
	eq(indicators, 3, "party tank: the three default indicators stay on, off the bar")
	-- Muse R4 D9: the dead member's "Dead" is a status in the row, never drawn over the empty bar.
	local dead = content(ns, ns.Headers.party, "party2")
	local scene = Scene.Build(env)
	local text = find(scene, dead.healthText)
	eq(dead.healthText:GetText(), "Dead", "party: the dead member says so")
	assert(text, "party: the renderer draws the status")
	assert(not intersects(text.rect, { Scene.Rect(env, dead.health) }), "party: \"Dead\" " .. describe(text.rect) .. " stays off the bar")
	-- The status takes the class caption's place, so the dead member's name keeps its whole width.
	local nameItem = find(scene, dead.name)
	local path, size = dead.name:GetFont()
	assert(nameItem and nameItem.rect[3] + 0.01 >= Scene.TextWidth("Kragar", size, path), "party: the dead member's name stays whole beside \"Dead\"")
	-- Codex review, round 4: risen again, the class caption comes back with its text, not blank.
	env._member("party2").dead, env._member("party2").health = false, 60
	env.FireEvent("UNIT_HEALTH", "party2")
	assert(dead.classLine:IsShown(), "party: risen, the class caption shows again")
	local caption = dead.classLine:GetText()
	assert(type(caption) == "string" and caption:find("SHAMAN") ~= nil, "party: and says the class, got " .. tostring(caption))
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse R4 #2, Grok R4 #4: the raid tile at the default size and at the setup layouts' sizes (DPS and Tank 77 by
-- 40, Healer 77 by 46).
for _, size in ipairs({ { width = 72, height = 40 }, { width = 77, height = 40 }, { width = 77, height = 46 } }) do
	local what = "raid " .. size.width .. " by " .. size.height
	local env, _, ns = Raid(size)
	local f = content(ns, ns.Headers.raid[1], "raid1")
	local k = ns.Settings.current.raid
	local auras, bar = Clear(env, f, what)
	-- Muse R4 #2: the raid tile is the party's glass at reduced ornament, the same chrome without a drop shadow.
	eq(f.chrome.shadowOn, false, what .. ": a raid tile casts no drop shadow")
	-- Four debuffs, two by two, boss and dispellable ones first.
	local block = ns.Auras.Block(f, k)
	eq(block.columns, 2, what .. ": the debuff block is two wide")
	eq(block.rows, 2, what .. ": and two high")
	eq(block.cells, 4, what .. ": four debuffs show")
	local order = ns.Auras.Order()
	assert(order.dispels < order.debuffs and order.boss < order.debuffs, what .. ": dispellable and boss debuffs come first")
	-- Your heals keep a row of their own and at least two of them show.
	local _, heals = ns.Auras.HealIcons(f, k)
	assert(heals >= 2, what .. ": two or more of your heals have room, got " .. heals)
	-- The name lane and the deficit lane.
	local scene = Scene.Build(env)
	local name, deficit = find(scene, f.name), find(scene, f.healthText)
	assert(name and deficit, what .. ": the name and the deficit draw")
	assert(not intersects(name.rect, deficit.rect), what .. ": the name " .. describe(name.rect) .. " never competes with the deficit " .. describe(deficit.rect))
	local frame = { Scene.Rect(env, f) }
	local pad = ns.Geometry.PAD
	assert(math.abs(deficit.rect[1] + deficit.rect[3] - (frame[1] + frame[3] - pad)) < 0.6, what .. ": the deficit is right-aligned in its lane " .. describe(deficit.rect))
	assert(deficit.rect[2] + deficit.rect[4] <= bar[2] + 0.01, what .. ": and sits above the bar")
	for _, aura in ipairs(auras) do
		assert(not intersects(aura[2], name.rect), what .. ": " .. aura[1] .. " stays off the name")
		assert(not intersects(aura[2], deficit.rect), what .. ": " .. aura[1] .. " stays off the deficit")
	end
	-- Fable R4 D6: a long name ellipsises at the lane's measured width instead of losing letters silently.
	local shown = f.name:GetText()
	assert(shown ~= "Thaldrenwick" and shown:sub(-#ELLIPSIS) == ELLIPSIS, what .. ": a long name ends in an ellipsis, got " .. tostring(shown))
	assert(name.rect[3] <= f.nameWidth + 0.5, what .. ": and fits its lane")
	-- Muse R4 #2: "Dead" sits in the deficit lane, not on the bar.
	local dead = content(ns, ns.Headers.raid[1], "raid2")
	local status = find(scene, dead.healthText)
	eq(dead.healthText:GetText(), "Dead", what .. ": the dead member says so")
	assert(not intersects(status.rect, { Scene.Rect(env, dead.health) }), what .. ": \"Dead\" " .. describe(status.rect) .. " stays off the bar")
	assert(not intersects(status.rect, find(scene, dead.name).rect), what .. ": and off the name")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Every debuff position a player can choose keeps the debuffs, your heals and the indicators off the bar.
for _, position in ipairs({ "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT", "OUTSIDE_RIGHT", "OUTSIDE_LEFT" }) do
	for _, kind in ipairs({ "party", "raid" }) do
		local settings = { enabled = true, [kind] = { auraPosition = position } }
		local env, K, ns = G.New({ saved = saved(settings) })
		if kind == "party" then
			G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 } })
		else
			G.SetRoster(env, "raid", G.Members(5))
		end
		assert(K.Modules.Enable("GroupFrames"))
		env.RunTimers()
		local f = content(ns, kind == "party" and ns.Headers.party or ns.Headers.raid[1], kind .. "1")
		Clear(env, f, kind .. " with debuffs " .. position)
		eq(#env._errors, 0, tostring(env._errors[1]))
	end
end

-- Codex review, round 4: a party frame with the name on the bar has no side lane, so your heals take a row under the
-- bar instead of vanishing.
do
	local env, K, ns = G.New({ saved = saved({ enabled = true, party = { textLayout = "INSIDE" } }) })
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = content(ns, ns.Headers.party, "party1")
	local _, heals = ns.Auras.HealIcons(f, ns.Settings.current.party)
	assert(heals >= 2, "party, name on the bar: your heals keep a place, got " .. heals)
	Clear(env, f, "party, name on the bar")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review, round 4: at fractional pixel scales the fitted icon sizes are whole pixels, so the engine lays the
-- icons out at the size their buttons are drawn and the clips hold them whole.
for _, screen in ipairs({ { 2560, 1600 }, { 3456, 2234 } }) do
	local what = "raid at " .. screen[1] .. " by " .. screen[2]
	local env, K, ns = G.New({ width = screen[1], height = screen[2] })
	G.SetRoster(env, "raid", G.Members(5))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = content(ns, ns.Headers.raid[1], "raid1")
	for _, pair in ipairs({ { "debuffs", f.auras._groups.debuffs, f.auraClip }, { "your heals", f.buffs._groups.buffs, f.buffClip } }) do
		local group, clip = pair[2], pair[3]
		local laid, drawn = group.layout.elementWidth, group.frames[1]:GetWidth()
		assert(math.abs(laid - drawn) < 1e-6, what .. ": " .. pair[1] .. " are laid out at the size they are drawn, " .. laid .. " and " .. drawn)
		assert(clip:GetHeight() + 1e-6 >= drawn, what .. ": and their clip holds a whole icon")
	end
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- The options preview's sample frames draw the same lanes: no sample aura on a sample bar.
do
	local env, K = G.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(280, 700)
	parent:SetPoint("TOPLEFT", K.Scale.Root(), "TOPLEFT", 40, -40)
	local preview = K.Options.Preview("GroupFrames")(parent)
	local samples = {}
	for _, f in ipairs(preview.partyFrames) do
		samples[#samples + 1] = f
	end
	for _, f in ipairs(preview.raidFrames) do
		samples[#samples + 1] = f
	end
	local checked = 0
	for _, f in ipairs(samples) do
		if f:IsShown() then
			local bar = { Scene.Rect(env, f.health) }
			for _, list in ipairs({ f.sampleAuras, f.sampleBuffs, f.sampleSlots }) do
				for i, icon in ipairs(list or {}) do
					if icon:IsShown() then
						local r = { Scene.Rect(env, icon) }
						assert(not intersects(r, bar), "preview " .. f.kind .. " " .. f.sample.name .. ": sample aura " .. i .. " " .. describe(r) .. " stays off the bar " .. describe(bar))
						checked = checked + 1
					end
				end
			end
		end
	end
	assert(checked >= 10, "the preview shows sample auras to check, got " .. checked)
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes clear ok")
