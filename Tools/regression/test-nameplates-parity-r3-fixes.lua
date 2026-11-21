-- test-nameplates-parity-r3-fixes.lua: the round 3 review's probes, one block per finding: subtitles, text room, recycled and combat hover, guild and title data, the execute glow, bare rims, hot paths, preview and Options rows.
local N = dofile("Tools/regression/nameplates_env.lua")

local function boot()
	local env, K, ns = N.New({ setup = N.Curves, playerClass = "ROGUE" })
	local function set(key, value)
		K.Options.Write("Nameplates", key, value)
		env.RunTimers()
	end
	return env, K, ns, set
end

local function done(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

-- 1. A guild line hides, restores and releases its room with its name, and fades with it during casts.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate1", { name = "Thaldrin", isPlayer = true, canAttack = false, reaction = 5, guild = "Vanguard" })
	local p = ns.Plates.Get("nameplate1")
	set("friendly.guild", "plain")
	assert(p.subtitle:IsShown() and p.subtitleRoom > 0, "the guild shows under the name")
	set("name.show", false)
	assert(not p.subtitle:IsShown() and p.subtitleRoom == 0, "a hidden name takes its guild and its room with it")
	set("friendly.guild", "")
	set("name.show", true)
	assert(not p.subtitle:IsShown(), "guild off while the name was hidden stays off")
	set("friendly.guild", "plain")
	assert(p.subtitle:IsShown(), "and returns with the option")
	set("cast.hideUnitName", true)
	N.Cast(env, "nameplate1", { name = "Heal", text = "Heal", texture = 1, notInterruptible = false })
	assert(p.name:GetAlpha() == 0 and p.subtitle:GetAlpha() == 0, "a cast that hides the name hides its guild")
	done(env, K)
end
collectgarbage()

-- 2. Debuffs clear a friendly NPC's own name size, and a resource row on top clears the guild line.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate2", { name = "Vendor", canAttack = false, reaction = 5 })
	local npc = ns.Plates.Get("nameplate2")
	N.Debuffs(env, "nameplate2", 2)
	set("debuffs.nameGap", 0)
	local before, small = select(5, npc.auras:GetPoint(1)), select(2, npc.name:GetFont())
	set("friendly.npcSize", 20)
	local after, large = select(5, npc.auras:GetPoint(1)), select(2, npc.name:GetFont())
	assert(large > small and after - before >= large - small - 0.5, "debuffs rise with a larger NPC name: " .. before .. " -> " .. after)

	N.Add(env, "nameplate1", { name = "Thaldrin", isPlayer = true, canAttack = false, reaction = 5, guild = "Vanguard" })
	local p = ns.Plates.Get("nameplate1")
	N.Target(env, "nameplate1")
	set("resource.show", true)
	set("resource.place", "TOP")
	local bare = select(5, p.resource:GetPoint(1))
	set("friendly.guild", "plain")
	local raised = select(5, p.resource:GetPoint(1))
	assert(math.abs(raised - bare - p.subtitleRoom) < 0.01, "the resource row rises with the guild line: " .. bare .. " -> " .. raised)
	done(env, K)
end
collectgarbage()

-- 3 and 4. A recycled plate drops the old highlight, enabling applies the mouse at once, and combat refuses a scan.
do
	local env, K, ns, set = boot()
	local base = N.Add(env, "nameplate2", { name = "Vendor", canAttack = false, reaction = 5 })
	local npc = ns.Plates.Get("nameplate2")
	env._mouseUnit = "nameplate2"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	set("target.hover", true)
	assert(npc.targetFill:IsShown(), "enabling the highlight lights the plate already under the mouse")
	N.Remove(env, "nameplate2")
	env._mouseUnit = nil
	N.Add(env, "nameplate3", { name = "Other", canAttack = false, reaction = 5 }, { base = base })
	local other = ns.Plates.Get("nameplate3")
	assert(other == npc and not other.targetFill:IsShown(), "a recycled plate drops the old unit's highlight")

	N.Add(env, "nameplate4", { name = "Gnoll" })
	N.Add(env, "nameplate5", { name = "Kobold" })
	env.SetCombat(true)
	local scans, unitIsUnit = 0, env.UnitIsUnit
	env.UnitIsUnit = function(...) scans = scans + 1; return unitIsUnit(...) end
	env.C_NamePlate.GetNamePlateForUnit = function() error("unavailable") end
	env._mouseUnit = "nameplate4"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(scans == 0, "a refused lookup in combat does not scan the plates: " .. scans)
	env.UnitIsUnit = unitIsUnit
	done(env, K)
end
collectgarbage()

-- 5. Owner and guild data that may be secret are never tested for truth or compared.
do
	local f = assert(io.open("KstyleUI_Nameplates/Plate.lua", "rb"))
	local body = f:read("*a"):match("function Plate:UpdateSubtitle%(%)(.-)\r?\nend")
	f:close()
	assert(body, "UpdateSubtitle is found")
	assert(not body:find("UnitOwnerGUID, self.unit) or", 1, true), "the owner GUID is passed on without a truth test")
	assert(not body:find("text ~= nil", 1, true) and not body:find("text == nil", 1, true), "the subtitle's presence is known without comparing it")
end

-- 6. The guild line follows PLAYER_GUILD_UPDATE, titles fall back to the name, and apply in a name format.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate1", { name = "Thaldrin", isPlayer = true, canAttack = false, reaction = 5, guild = "Vanguard", pvpName = "Sergeant Thaldrin", level = 10 })
	local p = ns.Plates.Get("nameplate1")
	set("friendly.guild", "plain")
	env._units.nameplate1.guild = "Changed"
	env.FireEvent("PLAYER_GUILD_UPDATE", "nameplate1")
	assert(N.Last(p.subtitle, "SetFormattedText")[2] == "Changed", "the guild line follows the guild event")
	set("friendly.title", true)
	set("friendly.playerFormat", "[name] ([level])")
	assert(p.name:GetText() == "Sergeant Thaldrin (10)", "titles apply to the [name] tag: " .. tostring(p.name:GetText()))
	set("friendly.playerFormat", "")
	env.UnitPVPName = nil
	set("name.upper", false)
	assert(p.name:GetText() == "Thaldrin", "without the title API the name stays: " .. tostring(p.name:GetText()))
	done(env, K)
end
collectgarbage()

-- 7. The execute pulse follows a live Motion change, and the preview's sample glows only under the threshold.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate4", { health = 20 })
	local enemy = ns.Plates.Get("nameplate4")
	set("health.execute", true)
	assert(enemy.executePulse:IsPlaying(), "an enemy under the threshold pulses")
	K.Motion.SetLevel("off")
	env.FireEvent("UNIT_HEALTH", "nameplate4")
	assert(not enemy.executePulse:IsPlaying(), "Motion off stops the pulse on the next health update")
	K.Motion.SetLevel("full")
	env.FireEvent("UNIT_HEALTH", "nameplate4")
	assert(enemy.executePulse:IsPlaying(), "and Motion on starts it again")
	local f = ns.Preview.Build(env.UIParent)
	for _, pct in ipairs({ 5, 50 }) do
		set("health.executePercent", pct)
		f.Refresh()
		assert(f.plates[1]:SampleHealth() < pct / 100 and f.plates[1].executeGate:GetAlpha() == 1, "the target sample drops under " .. pct .. "% and glows")
		assert(f.plates[2].executeGate:GetAlpha() == 0, "the 81% enemy sample does not glow at " .. pct .. "%")
	end
	set("health.execute", false)
	assert(f.plates[1]:SampleHealth() == 0.64, "off, the sample keeps its health")
	done(env, K)
end
collectgarbage()

-- 8. With the border off, a black focus edge still shows.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate4", { health = 20 })
	local enemy = ns.Plates.Get("nameplate4")
	set("health.border", false)
	assert(not enemy.health.under.edgeHard:IsShown(), "no border, no edge")
	set("focus.color", { r = 0, g = 0, b = 0 })
	N.Focus(env, "nameplate4")
	assert(enemy.health.under.edgeHard:IsShown(), "a black focus edge shows")
	N.Focus(env, nil)
	assert(not enemy.health.under.edgeHard:IsShown(), "and goes with the focus")
	done(env, K)
end
collectgarbage()

-- 9. Health events leave the absorb alone, the range spell resolves once, and the preview builds what it draws.
do
	local env, K, ns, set = boot()
	N.Add(env, "nameplate4", { health = 20 })
	set("health.absorbs", true)
	local reads, absorbs = 0, env.UnitGetTotalAbsorbs
	env.UnitGetTotalAbsorbs = function(...) reads = reads + 1; return absorbs(...) end
	for _ = 1, 10 do env.FireEvent("UNIT_HEALTH", "nameplate4") end
	assert(reads == 0, "ordinary health events read no absorb: " .. reads)
	env.FireEvent("UNIT_MAXHEALTH", "nameplate4")
	assert(reads == 1, "a max health change rescales the shield")
	set("range.fade", true)
	set("range.spell", "Kick")
	local ids, lookup = 0, env.C_Spell.GetSpellIDForSpellIdentifier
	env.C_Spell.GetSpellIDForSpellIdentifier = function(...) ids = ids + 1; return lookup(...) end
	for _ = 1, 8 do env.RunTickers() end
	assert(ids == 0, "range ticks reuse the resolved spell: " .. ids)

	local built, newPlate = 0, ns.NewPlate
	ns.NewPlate = function(...) built = built + 1; return newPlate(...) end
	local f = ns.Preview.Build(env.UIParent)
	assert(built == 3 and #f.plates == 3, "the preview builds the three samples it draws by default: " .. built)
	set("friendly.owner", true)
	f.Refresh()
	assert(#f.plates == 5 and f.chosen == 5, "a pet option builds the pet sample when it is drawn")
	ns.NewPlate = newPlate
	done(env, K)
end
collectgarbage()

-- 10. Hover alone enables the highlight colour and opacity it uses.
do
	local env, K, ns = boot()
	local s = { target = { fill = false, hover = true }, focus = { fill = false } }
	assert(not ns.Settings.Row("target.fillColor").disableWhen(s), "hover enables the highlight colour")
	assert(not ns.Settings.Row("target.fillAlpha").disableWhen(s), "and its opacity")
	s.target.hover = false
	assert(ns.Settings.Row("target.fillColor").disableWhen(s), "neither, and the colour is off")
	done(env, K)
end
collectgarbage()

-- 11. The [title] tag writes the name with its title, falls back to the name without UnitPVPName, and passes a secret on.
do
	local env, K = boot()
	N.Add(env, "nameplate1", { name = "Thaldrin", isPlayer = true, canAttack = false, reaction = 5, pvpName = "Sergeant Thaldrin" })
	local text = K.Widgets.FontString(env.UIParent, "OVERLAY")
	K.Widgets.TagText(text, "[title]!", "nameplate1")
	assert(text:GetText() == "Sergeant Thaldrin!", "the tag writes the title: " .. tostring(text:GetText()))
	env.UnitPVPName = function() return env.Secret("Sergeant Thaldrin") end
	K.Widgets.TagText(text, "[title]", "nameplate1")
	assert(env.issecretvalue(N.Last(text, "SetText")[1]), "a secret title passes straight to the text")
	env.UnitPVPName = nil
	K.Widgets.TagText(text, "[title]", "nameplate1")
	assert(text:GetText() == "Thaldrin", "without UnitPVPName the tag writes the name")
	K.Widgets.TagText(text, "[title]", nil, { pvpName = "Sergeant Thaldrin" })
	assert(text:GetText() == "Sergeant Thaldrin", "samples carry their title")
	done(env, K)
end
collectgarbage()

print("nameplates parity round 3 fixes ok")
