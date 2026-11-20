-- test-auras-parity-review.lua: the PR #589 review's probes, switched on: rule timers round the whole time before splitting it and keep the minutes-and-seconds cutoff, the row and the preview share one formatter (FormatNumber, as Forever's NumericRuleFormatter), the preview filters its samples and warns as the row does, filter edits in combat reach the container at once (its documented exception) while button restyles wait, a stack count moves beside a type icon in its corner, the +N text keeps its own colour, and unchanged settings do no repeated work.
local A = dofile("Tools/regression/auras_env.lua")
local env, K, ns = A.New()
K.Modules.Enable("Auras")
env.RunTimers()
local failures = {}
local function check(ok, message)
	if not ok then failures[#failures + 1] = message end
end
local function write(key, value) K.Options.Write("Auras", key, value); env.RunTimers() end
local buffs, debuffs = ns.Panel.Group("buffs"), ns.Panel.Group("debuffs")
local entry = buffs.buttons[1]
local helpful = select(2, A.Container(env, "HELPFUL"))
local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
holder:SetSize(280, 300)
local preview = ns.Preview.Build(holder)
local function shown(samples)
	local n = 0
	for _, sample in ipairs(samples) do
		if sample.button:IsShown() then n = n + 1 end
	end
	return n
end

-- 1 and 7. The row's rule formatter answers FormatNumber only; whole times round before they split, the cutoff holds, and the preview writes the row's text.
local function times(precise, cases)
	write("timer.precise", precise)
	local f = entry.button._aura.timerOptions.textFormatter
	check(rawget(f, "Format") == nil and type(f.FormatNumber) == "function", "the rule formatter has FormatNumber and no Format, as Forever's NumericRuleFormatter")
	local format = f.FormatNumber or f.Format
	for _, case in ipairs(cases) do
		local ok, text = pcall(format, f, case[1])
		check(ok and text == case[2], ("under %d minutes, %s seconds reads %s, not %s"):format(precise, case[1], case[2], tostring(text)))
	end
	preview:Refresh()
	for _, sample in ipairs(preview.buffs) do
		local seconds = sample.spec.seconds
		if seconds then
			local ok, text = pcall(format, f, seconds)
			check(ok and sample.timer:GetText() == text, ("the preview writes the row's %s for %s seconds, not %s"):format(tostring(text), seconds, tostring(sample.timer:GetText())))
		end
	end
end
times(5, { { 119.9, "2:00" }, { 65.1, "1:06" }, { 245, "4:05" }, { 300, "5m" } })
times(1, { { 75, "75s" }, { 90, "90s" }, { 91, "2m" } })
K.Options.Write("Appearance", "auraEndings", false)
env.RunTimers()
times(5, { { 119.9, "1:59" }, { 65.1, "1:05" } })
K.Options.Write("Appearance", "auraEndings", true)
write("timer.precise", 0)

-- 2. The preview's samples carry spell IDs, categories and a permanent aura, so Show, timed-only and the spell lists filter them.
local all = shown(preview.buffs)
write("buffs.allowSpells", "99999999")
preview:Refresh()
check(shown(preview.buffs) == 0, "an allow list no sample matches leaves no sample buff, not " .. shown(preview.buffs))
write("buffs.allowSpells", "")
write("buffs.blockSpells", "139")
preview:Refresh()
check(shown(preview.buffs) == all - 1, "a block list hides its sample")
write("buffs.blockSpells", "")
write("buffs.show", "cancelable")
preview:Refresh()
check(shown(preview.buffs) == all - 1, "a category shows only its samples: the permanent aura is not one you can cancel")
write("buffs.show", "all")
local permanent
for _, sample in ipairs(preview.buffs) do
	if not sample.spec.seconds then permanent = sample end
end
check(permanent ~= nil, "the preview has a permanent sample")
write("buffs.timed", true)
preview:Refresh()
check(permanent and not permanent.button:IsShown() and shown(preview.buffs) == all - 1, "timed-only hides the permanent sample")
write("buffs.timed", false)
write("debuffs.show", "dispellable")
preview:Refresh()
check(shown(preview.debuffs) == #preview.debuffs - 1, "a debuff category filters the debuff samples: the typeless one is not dispellable")
write("debuffs.show", "all")

-- 2. The preview warns as the live curve does: under Warn under a sample takes the hostile colour, above it the custom colour.
write("timer.color", { r = 0, g = 1, b = 0 })
write("timer.customColor", true)
preview:Refresh()
local hr, hg, hb = K.Tokens.Color("hostile")
for _, sample in ipairs(preview.buffs) do
	local seconds, c = sample.spec.seconds, A.W.LastCall(sample.timer, "SetTextColor")
	if seconds and seconds < 5 then
		check(c[1] == hr and c[2] == hg and c[3] == hb, "a " .. seconds .. "-second sample previews the warning colour")
	elseif seconds then
		check(c[1] == 0 and c[2] == 1 and c[3] == 0, "a " .. seconds .. "-second sample previews the custom colour")
	end
end
write("timer.customColor", false)

-- 4. The +N text keeps its own colour: Stack colour colours stack counts only.
write("count.color", { r = 1, g = 0, b = 1 })
write("count.customColor", true)
local er, eg, eb = K.Tokens.Color("textEmphasis")
local chip = A.W.LastCall(buffs.chip.texts[1], "SetTextColor")
check(chip[1] == er and chip[2] == eg and chip[3] == eb, "the +N text keeps the kit colour, not the stack colour")
check(A.W.LastCall(entry.count, "SetTextColor")[2] == 0, "the stack count takes the stack colour")
write("count.customColor", false)

-- 4. A type icon in the stack count's corner keeps the corner and the count moves beside it; in another corner, or with counts hidden, the count keeps its place.
for _, corner in ipairs({ "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "CENTER" }) do
	write("count.position", corner)
	write("debuffs.typeIcon", corner)
	local d = debuffs.buttons[1]
	local p, q = d.count._points[1], d.typeIcon._points[1]
	check(#d.count._points == 1 and p[2] == d.typeIcon and p[3] ~= p[1] and q[2] == d.skin, corner .. ": the stack count sits beside the type icon, not under it")
end
write("count.shown", false)
local p = debuffs.buttons[1].count._points[1]
check(p[2] == debuffs.buttons[1].skin and p[1] == "CENTER", "with stack counts hidden the count keeps its place")
write("count.shown", true)
write("count.position", "TOPRIGHT")
write("debuffs.typeIcon", "TOPLEFT")
p = debuffs.buttons[1].count._points[1]
check(p[2] == debuffs.buttons[1].skin and p[1] == "TOPRIGHT" and debuffs.buttons[1].typeIcon._points[1][1] == "TOPLEFT", "in another corner each keeps its own")

-- 3. In combat while auras are secret, filter edits reach the container at once (it has no access restriction) and button restyles wait.
env.SetCombat(true)
env._aurasSecret = true
write("buffs.show", "important")
write("buffs.timed", true)
write("debuffs.typeIcon", "BOTTOMRIGHT")
check(helpful.filter == "HELPFUL|IMPORTANT" and helpful.candidateFilters and helpful.candidateFilters.maxDuration, "filters reach the container at once in combat")
check(debuffs.buttons[1].typeIcon._points[1][1] == "TOPLEFT", "a button restyle waits for combat to end")
env._aurasSecret = false
env.SetCombat(false)
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
check(debuffs.buttons[1].typeIcon._points[1][1] == "BOTTOMRIGHT", "the restyle applies when combat ends")
write("buffs.timed", false)
write("debuffs.typeIcon", "none")

-- 8. One weapon enchantment event validates the category once, and an unrelated restyle leaves the swipe direction alone.
local checks, valid = 0, env.AuraUtil.IsValidFilterString
env.AuraUtil.IsValidFilterString = function(...)
	checks = checks + 1
	return valid(...)
end
env.FireEvent("WEAPON_ENCHANT_CHANGED")
env.RunTimers()
check(checks == 1, "one weapon enchantment event validates the category once, not " .. checks .. " times")
env.AuraUtil.IsValidFilterString = valid
write("buffs.swipe", true)
local before = #A.W.Calls(entry.swipe, "SetReverse")
write("count.x", 1)
check(#A.W.Calls(entry.swipe, "SetReverse") == before, "an unrelated restyle does not set the swipe direction again")
write("buffs.swipeReverse", false)
check(A.W.LastCall(entry.swipe, "SetReverse")[1] == false, "a direction change still applies")

check(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
assert(#failures == 0, "\n" .. table.concat(failures, "\n"))
print("auras parity review ok")
