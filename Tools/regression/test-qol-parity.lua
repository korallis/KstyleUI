-- test-qol-parity.lua: the EllesmereUI parity round 1 QoL options: defaults change nothing, each option works switched on, follows the events that change it, and turning it off puts everything back.
local Q = dofile("Tools/regression/qol_env.lua")

local function boot(settings, setup)
	local saved = { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = setup })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function settle(env)
	env.Release()
	Q.W.Settle(env)
end

local function shown(frame)
	return frame ~= nil and frame:IsShown()
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- Defaults: a v0.2.8-shaped profile keeps every new switch off, draws nothing and changes nothing.
do
	local env, K, ns = boot({ enabled = true, fastLoot = true, lootFeed = true, quietErrors = false })
	for key, value in pairs({ combatAlert = false, talentAlert = false, deathAlert = false, durabilityAlert = false, crosshair = "none",
		cursorRing = false, hideScreenshot = false, announceReset = false, autoLog = false, skipMode = "cinematics" }) do
		assert(ns.Get(key) == value, key .. " keeps today's behaviour by default")
	end
	env._unspent, env._durability[1] = true, { 1, 100 }
	env.SetCombat(true)
	env.SetCombat(false)
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	env.FireEvent("PLAY_MOVIE", 1)
	env.RunTimers()
	assert(not ns.noticeLines.flash and not ns.noticeLines.talents and not ns.noticeLines.durability, "no alert line is built")
	local cross, ring = ns.AidFrames()
	assert(not cross and not ring, "no crosshair or ring is built")
	assert(env.ActionStatus:IsEventRegistered("SCREENSHOT_SUCCEEDED"), "the screenshot notice stays")
	assert(#Q.Calls(env, "SendChatMessage") == 0 and #Q.Calls(env, "LoggingCombat") == 0 and #Q.Calls(env, "FinishMovie") == 0)
	K.Store.Module("QoL").alertSize, K.Store.Module("QoL").crosshair, K.Store.Module("QoL").combatEnterColor = 0 / 0, "huge", { r = "red" }
	assert(ns.Get("alertSize") == 28 and ns.Get("crosshair") == "none" and ns.Get("combatEnterColor").r == ns.defaults.combatEnterColor.r, "bad saved values read as defaults")
	clean(env, K)
end

-- Combat alert, on: enter and leave text, colours, class colour, Show on, and the line leaves after its hold.
do
	local env, K, ns = boot()
	Q.Write(env, K, "combatAlert", true)
	env.SetCombat(true)
	local line = ns.noticeLines.flash
	assert(shown(line) and line.text:GetText() == "+Combat", tostring(line and line.text:GetText()))
	local r, g, b = line.text:GetTextColor()
	local hr, hg, hb = K.Tokens.Color("hostile")
	assert(near(r, hr) and near(g, hg) and near(b, hb), "entering uses its colour")
	local _, _, _, _, y = line:GetPoint(1)
	assert(y > 0, "the line sits above the screen centre")
	assert(line:GetParent():GetFrameStrata() == "BACKGROUND", "alerts sit under every window, as the loot feed does")
	settle(env)
	assert(not line:IsShown(), "the alert leaves after its hold")
	env.SetCombat(false)
	assert(shown(line) and line.text:GetText() == "-Combat")
	Q.Write(env, K, "combatAlertOn", "enter")
	env.Release()
	env.SetCombat(true)
	env.SetCombat(false)
	assert(line.text:GetText() == "+Combat", "leaving shows nothing when Show on is entering")
	Q.Write(env, K, "combatLeaveText", "Safe")
	Q.Write(env, K, "combatAlertOn", "both")
	Q.Write(env, K, "combatLeaveClass", true)
	local before = select(2, line.text:GetFont())
	Q.Write(env, K, "alertSize", 40)
	env.SetCombat(true)
	env.SetCombat(false)
	assert(line.text:GetText() == "Safe", "custom leaving text")
	local cr, cg, cb = K.Theme.ClassColor(select(2, env.UnitClass("player")))
	r, g, b = line.text:GetTextColor()
	assert(near(r, cr) and near(g, cg) and near(b, cb), "class colour")
	assert(select(2, line.text:GetFont()) > before, "Alert text size grows the line")
	Q.Write(env, K, "combatAlert", false)
	settle(env)
assert(not line:IsShown(), "turning it off clears the line")
	settle(env)
	env.SetCombat(true)
	assert(not line:IsShown(), "and no alert follows")
	clean(env, K)
end

-- Unspent talents, on: out of combat only, gone once spent, back after a level-up; text and colour repaint.
do
	local env, K, ns = boot()
	env._unspent = true
	Q.Write(env, K, "talentAlert", true)
	local line = ns.noticeLines.talents
	assert(shown(line) and line.text:GetText() == "Unspent talent points")
	env.SetCombat(true)
	settle(env)
	assert(not line:IsShown(), "hidden in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(shown(line), "back after combat")
	env._unspent = false
	env.FireEvent("TRAIT_CONFIG_UPDATED", 1)
	settle(env)
	assert(not line:IsShown(), "gone once spent")
	env._unspent = true
	env.FireEvent("PLAYER_LEVEL_UP", 11)
	env.RunTimers()
	assert(shown(line), "back after a level-up")
	Q.Write(env, K, "talentText", "Talents!")
	Q.Write(env, K, "talentColor", { r = 0.1, g = 0.2, b = 0.3 })
	local r, g, b = line.text:GetTextColor()
	assert(line.text:GetText() == "Talents!" and near(r, 0.1) and near(g, 0.2) and near(b, 0.3), "text and colour repaint")
	Q.Write(env, K, "combatAlert", true)
	env.SetCombat(true)
	assert(ns.noticeLines.flash:GetBottom() > line:GetTop(), "the combat and talent lines do not overlap")
	env.SetCombat(false)
	Q.Write(env, K, "talentAlert", false)
	settle(env)
	assert(not line:IsShown(), "turning it off hides it")
	clean(env, K)
end

-- Group deaths, on: one alert per death with its sound, none for the player, a feign or a repeat; a raid ignores party units.
do
	local env, K, ns = boot()
	Q.Write(env, K, "deathAlert", true)
	env._group, env._names.party1 = true, "Valerin"
	env._dead.party1 = true
	env.FireEvent("UNIT_HEALTH", "party1")
	local line = ns.noticeLines.flash
	assert(shown(line) and line.text:GetText() == "Valerin died", tostring(line and line.text:GetText()))
	assert(#Q.Calls(env, "PlaySound") == 1 and Q.Calls(env, "PlaySound")[1][1] == 8959, "the raid warning sound plays")
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(#Q.Calls(env, "PlaySound") == 1, "one alert per death")
	env._dead.party1 = false
	env.FireEvent("UNIT_HEALTH", "party1")
	Q.Write(env, K, "deathSound", "none")
	env._dead.party1, env._names.party1 = true, env.Secret("Valerin")
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(line.text:GetText() == "A group member died", "a secret name is not read")
	assert(#Q.Calls(env, "PlaySound") == 1, "no sound when None")
	env._raid, env._dead.party2, env._dead.raid1 = true, true, true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.FireEvent("UNIT_HEALTH", "raid1")
	assert(line.text:GetText() == "A group member died", "a member dead before the roster changed raises nothing")
	env._dead.raid2, env._names.raid2 = true, "Odo"
	env.FireEvent("UNIT_HEALTH", "party2")
	env.FireEvent("UNIT_HEALTH", "player")
	env.FireEvent("UNIT_HEALTH", "raid2")
	assert(line.text:GetText() == "Odo died", "raid units in a raid")
	Q.Write(env, K, "deathAlert", false)
	env._dead.raid3 = true
	env.FireEvent("UNIT_HEALTH", "raid3")
	assert(line.text:GetText() == "Odo died", "off: no alert")
	clean(env, K)
end

-- Low durability, on: the lowest worn item under the threshold, out of combat, thrown weapons left out unless asked.
do
	local env, K, ns = boot()
	env._durability[5], env._durability[18], env._equipped[18], env._items[900] = { 60, 100 }, { 1, 100 }, 900, { icon = 1, equipLoc = "INVTYPE_THROWN" }
	Q.Write(env, K, "durabilityAlert", true)
	assert(not ns.noticeLines.durability, "a thrown weapon alone raises nothing")
	env._durability[5] = { 30, 100 }
	env.FireEvent("UPDATE_INVENTORY_DURABILITY")
	local line = ns.noticeLines.durability
	assert(shown(line) and line.text:GetText() == "Low durability: 30%", tostring(line and line.text:GetText()))
	local _, _, _, _, y = line:GetPoint(1)
	Q.Write(env, K, "durabilityY", 100)
	local _, _, _, _, y2 = line:GetPoint(1)
	assert(y2 < y, "Warning height moves the line")
	Q.Write(env, K, "durabilityThrown", false)
	assert(line.text:GetText() == "Low durability: 1%", "thrown weapons count when asked")
	env.SetCombat(true)
	settle(env)
	assert(not line:IsShown(), "hidden in combat")
	env.SetCombat(false)
	env.RunTimers()
	Q.Write(env, K, "durabilityPercent", 5)
	Q.Write(env, K, "durabilityThrown", true)
	settle(env)
	assert(not line:IsShown(), "above the threshold: gone")
	Q.Write(env, K, "durabilityPercent", 40)
	env.RunTimers()
	assert(shown(line))
	Q.Disable(env, K)
	settle(env)
	assert(not line:IsShown(), "turning the module off hides it")
	clean(env, K)
end

-- Crosshair, on: style, lengths, thickness, outline, offsets, and its show rule follows combat and instances.
do
	local env, K, ns = boot()
	Q.Write(env, K, "crosshair", "thick")
	local cross = ns.AidFrames()
	assert(shown(cross), "the crosshair shows")
	assert(near(cross.h:GetHeight(), K.Scale.Pixel(4)) and near(cross.h:GetWidth(), 40) and not cross.hb:IsShown())
	Q.Write(env, K, "crosshairHWidth", 6)
	Q.Write(env, K, "crosshairVLength", 90)
	Q.Write(env, K, "crosshairBorder", 2)
	assert(near(cross.h:GetHeight(), K.Scale.Pixel(6)) and near(cross.v:GetHeight(), 90) and near(cross.v:GetWidth(), K.Scale.Pixel(4)))
	assert(cross.hb:IsShown() and near(cross.hb:GetHeight(), K.Scale.Pixel(10)), "the outline wraps the line")
	Q.Write(env, K, "crosshairX", 30)
	Q.Write(env, K, "crosshairY", -20)
	local _, _, _, x, y = cross:GetPoint(1)
	assert(near(x, 30) and near(y, -20), x .. "," .. y)
	Q.Write(env, K, "crosshairShow", "combat")
	assert(not cross:IsShown(), "combat only: hidden out of combat")
	env.SetCombat(true)
	assert(cross:IsShown(), "shown in combat")
	Q.Write(env, K, "crosshairShow", "instancesCombat")
	assert(not cross:IsShown(), "instance combat: hidden in the open world")
	env._instance = { true, "party" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(cross:IsShown(), "shown in instance combat")
	env.SetCombat(false)
	assert(not cross:IsShown())
	Q.Write(env, K, "crosshair", "none")
	assert(not cross:IsShown(), "None hides it")
	clean(env, K)
end

-- Cursor ring, on: it follows the pointer, takes its colour, size and opacity, and its show rule.
do
	local env, K, ns = boot()
	Q.Write(env, K, "cursorRing", true)
	local _, ring = ns.AidFrames()
	assert(shown(ring) and ring:GetFrameStrata() == "TOOLTIP")
	env._cursor = { 300, 200 }
	ring:GetScript("OnUpdate")(ring, 0)
	local _, relative, _, x, y = ring:GetPoint(1)
	local scale = ring:GetEffectiveScale()
	assert(relative == env.UIParent and near(x, 300 / scale) and near(y, 200 / scale), "the ring sits on the pointer")
	local calls = #Q.W.Calls(ring, "SetPoint")
	ring:GetScript("OnUpdate")(ring, 0)
	assert(#Q.W.Calls(ring, "SetPoint") == calls, "a still pointer moves nothing")
	Q.Write(env, K, "cursorScale", 150)
	Q.Write(env, K, "cursorOpacity", 50)
	Q.Write(env, K, "cursorColor", { r = 0.2, g = 0.4, b = 0.6 })
	local r, g, b, a = ring.texture:GetVertexColor()
	assert(near(ring.texture:GetWidth(), 48) and near(r, 0.2) and near(g, 0.4) and near(b, 0.6) and near(a, 0.5))
	Q.Write(env, K, "cursorClass", true)
	local cr = K.Theme.ClassColor(select(2, env.UnitClass("player")))
	assert(near((ring.texture:GetVertexColor()), cr), "class colour")
	Q.Write(env, K, "cursorShow", "instances")
	assert(not ring:IsShown(), "instances only: hidden outside")
	Q.Write(env, K, "cursorRing", false)
	assert(not ring:IsShown())
	clean(env, K)
end

-- Screenshot notice, reset announcement, combat log and movie skipping, each on and then off.
do
	local env, K = boot()
	Q.Write(env, K, "hideScreenshot", true)
	assert(not env.ActionStatus:IsEventRegistered("SCREENSHOT_SUCCEEDED"), "the screenshot notice is muted")
	Q.Write(env, K, "hideScreenshot", false)
	assert(env.ActionStatus:IsEventRegistered("SCREENSHOT_SUCCEEDED"), "and given back")
	env.ActionStatus:UnregisterEvent("SCREENSHOT_SUCCEEDED")
	Q.Write(env, K, "hideScreenshot", true)
	Q.Write(env, K, "hideScreenshot", false)
	assert(not env.ActionStatus:IsEventRegistered("SCREENSHOT_SUCCEEDED"), "a notice another addon muted stays muted")

	Q.Write(env, K, "announceReset", true)
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	assert(#Q.Calls(env, "SendChatMessage") == 0, "solo: nobody to tell")
	env._group = true
	env.FireEvent("CHAT_MSG_SYSTEM", "You are now away.")
	env.FireEvent("CHAT_MSG_SYSTEM", env.Secret("Deadmines has been reset."))
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	local sent = Q.Calls(env, "SendChatMessage")
	assert(#sent == 1 and sent[1][1] == "Deadmines has been reset." and sent[1][2] == "PARTY", "only the reset line, to the party")
	env._raid = true
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	assert(Q.Calls(env, "SendChatMessage")[2][2] == "RAID")
	Q.Write(env, K, "announceReset", false)
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	assert(#Q.Calls(env, "SendChatMessage") == 2, "off: silent")

	Q.Write(env, K, "autoLog", true)
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(not env._logging, "Raids only by default")
	Q.Write(env, K, "autoLogWhere", "party")
	assert(env._logging == true, "a dungeon starts the log")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == false, "leaving stops it")
	env._logging = true
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == true, "a log the player started stays theirs")
	env._logging, env._instance = false, { true, "raid" }
	Q.Write(env, K, "autoLogWhere", "all")
	assert(env._logging == true)
	Q.Write(env, K, "autoLog", false)
	assert(env._logging == false, "turning it off inside stops the log it started")

	Q.Write(env, K, "skipCinematics", true)
	env.MovieFrame:Show()
	env.FireEvent("PLAY_MOVIE", 1)
	env.RunTimers()
	assert(#Q.Calls(env, "FinishMovie") == 0, "Cinematics leaves movies alone")
	Q.Write(env, K, "skipMode", "movies")
	env.StopCinematic = function() error("cinematics are left alone in Movies mode") end
	env.FireEvent("CINEMATIC_START", true)
	env._modifiers.shift = true
	env.FireEvent("PLAY_MOVIE", 1)
	env.RunTimers()
	assert(#Q.Calls(env, "FinishMovie") == 0, "Shift keeps the movie")
	env._modifiers.shift = false
	env.FireEvent("PLAY_MOVIE", 1)
	env.RunTimers()
	assert(#Q.Calls(env, "FinishMovie") == 1 and not env.MovieFrame:IsShown(), "the movie is skipped")
	Q.Write(env, K, "skipDelay", 5)
	env.MovieFrame:Show()
	env.FireEvent("PLAY_MOVIE", 1)
	env.RunTimers()
	assert(#Q.Calls(env, "FinishMovie") == 1, "Skip after waits")
	Q.Write(env, K, "skipMode", "both")
	env.Release()
	assert(#Q.Calls(env, "FinishMovie") == 1, "a setting change cancels a waiting skip")
	clean(env, K)
end

-- The page: every new row writes, and the live preview repaints from the settings.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(preview.lines[1]:GetText() == "+Combat" and preview.lines[1]:GetAlpha() < 1, "an off alert is dimmed")
	for key, value in pairs({ combatAlert = true, combatEnterText = "Go", talentAlert = true, crosshair = "thin", crosshairHLength = 70, cursorRing = true }) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
		Q.Write(env, K, key, value)
	end
	preview:Refresh()
	assert(preview.lines[1]:GetText() == "Go" and preview.lines[1]:GetAlpha() == 1 and preview.lines[5]:GetAlpha() == 1, "the talent sample lights")
	assert(near(preview.cross.h:GetWidth(), 70) and near(preview.cross.h:GetHeight(), K.Scale.Pixel(1)))
	assert(near(select(4, preview.ring:GetVertexColor()), 0.7), "the ring sample takes the ring's opacity")
	clean(env, K)
end

-- The PR #598 review's probes follow, one block per finding.

-- A restricted or missing self comparison never announces the player's own death.
do
	local env, K, ns = boot()
	Q.Write(env, K, "deathAlert", true)
	env._raid = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	env.UnitIsUnit = function() return env.Secret(true) end
	env._names.raid2, env._dead.raid2 = "PlayerAlias", true
	env.FireEvent("UNIT_HEALTH", "raid2")
	assert(not ns.noticeLines.flash and #Q.Calls(env, "PlaySound") == 0, "a secret UnitIsUnit raises nothing")
	env.UnitIsUnit, env._dead.raid3 = nil, true
	env.FireEvent("UNIT_HEALTH", "raid3")
	assert(not ns.noticeLines.flash and #Q.Calls(env, "PlaySound") == 0, "nor does a missing one")
	clean(env, K)
end

-- At the largest alert size, at every screen size, no two alert lines overlap, and a global text size change restyles a visible line at once.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = Q.New({ width = screen[1], height = screen[2], size = "auto", uiScale = 768 / 1080 })
	Q.Enable(env, K)
	env._unspent, env._durability[5] = true, { 1, 100 }
	for _, key in ipairs({ "talentAlert", "combatAlert", "durabilityAlert" }) do Q.Write(env, K, key, true) end
	Q.Write(env, K, "alertSize", 64)
	env.SetCombat(true)
	env.SetCombat(false)
	Q.W.Settle(env)
	local flash, talents, durability = ns.noticeLines.flash, ns.noticeLines.talents, ns.noticeLines.durability
	local function apart(when)
		assert(flash:GetBottom() > talents:GetTop() and durability:GetBottom() > flash:GetTop(), screen[1] .. "x" .. screen[2] .. ": no alert lines overlap " .. when)
	end
	apart("at size 64")
	assert(K.Theme.SetFontScale(1.3))
	env.RunTimers()
	Q.W.Settle(env)
	assert(select(2, talents.text:GetFont()) > 80 and select(2, flash.text:GetFont()) > 80, "a visible line follows the global text size")
	apart("after a larger global text size")
	clean(env, K)
end

-- A quick combat round trip leaves the warning up, and turning one flash source off clears only its own flash.
do
	local env, K, ns = boot()
	env._durability[5] = { 20, 100 }
	Q.Write(env, K, "durabilityAlert", true)
	Q.W.Settle(env)
	local line = ns.noticeLines.durability
	env.SetCombat(true)
	env.SetCombat(false)
	Q.W.Settle(env)
	assert(line:IsShown() and line:GetAlpha() == 1, "the warning is up out of combat after a quick round trip")
	Q.Write(env, K, "combatAlert", true)
	Q.Write(env, K, "deathAlert", true)
	env.SetCombat(true)
	env.SetCombat(false)
	local flash = ns.noticeLines.flash
	Q.Write(env, K, "combatAlert", false)
	Q.W.Settle(env)
	assert(not flash:IsShown(), "turning Combat alert off clears -Combat while Group death alert stays on")
	env._group, env._names.party1, env._dead.party1 = true, "Valerin", true
	env.FireEvent("UNIT_HEALTH", "party1")
	Q.Write(env, K, "combatAlert", true)
	Q.W.Settle(env)
	assert(flash:IsShown() and flash.text:GetText() == "Valerin died", "a death flash stays when Combat alert changes")
	clean(env, K)
end

-- A log the player stopped and started again stays theirs when they leave.
do
	local env, K = boot()
	Q.Write(env, K, "autoLog", true)
	env._instance = { true, "raid" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(env._logging == true)
	env.LoggingCombat(false)
	env.LoggingCombat(true)
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == true, "a log the player restarted keeps running")
	clean(env, K)
end

-- Shift held as a movie starts keeps it, and an unrelated setting leaves a waiting skip alone.
do
	local env, K = boot()
	Q.Write(env, K, "skipCinematics", true)
	Q.Write(env, K, "skipDelay", 5)
	Q.Write(env, K, "skipMode", "both")
	env._modifiers.shift = true
	env.MovieFrame:Show()
	env.FireEvent("PLAY_MOVIE", 1)
	env._modifiers.shift = false
	env.Release()
	assert(#Q.Calls(env, "FinishMovie") == 0, "Shift at the start keeps the movie")
	env.FireEvent("PLAY_MOVIE", 1)
	Q.Write(env, K, "announceReset", true)
	env.Release()
	assert(#Q.Calls(env, "FinishMovie") == 1 and not env.MovieFrame:IsShown(), "Announce instance resets leaves the waiting skip alone")
	env.IsShiftKeyDown = nil
	env.MovieFrame:Show()
	env.FireEvent("PLAY_MOVIE", 1)
	env.Release()
	assert(#Q.Calls(env, "FinishMovie") == 1, "a missing Shift answer keeps the movie")
	clean(env, K)
end

-- A missing or unreadable game answer takes the safe path.
do
	local env, K, ns = boot()
	env._durability[18], env._equipped[18] = { 1, 100 }, 900
	env.C_Item.GetItemInfoInstant = nil
	Q.Write(env, K, "durabilityAlert", true)
	clean(env, K)
	local reads, read, fight = 0, env.GetInventoryItemDurability, env.InCombatLockdown
	env.GetInventoryItemDurability = function(slot) reads = reads + 1; return read(slot) end
	env.InCombatLockdown = function() return env.Secret(true) end
	Q.Write(env, K, "alertSize", 30)
	assert(reads == 0, "an unreadable combat state reads no gear")
	env.InCombatLockdown = fight
	env.IsInRaid, env.IsInGroup, env.IsInInstance = nil, nil, nil
	Q.Write(env, K, "deathAlert", true)
	Q.Write(env, K, "crosshair", "normal")
	assert(ns.AidFrames():IsShown(), "a missing instance answer still shows an Always crosshair")
	Q.Write(env, K, "crosshairShow", "instances")
	assert(not ns.AidFrames():IsShown(), "and counts as outside")
	Q.Write(env, K, "announceReset", true)
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	assert(#Q.Calls(env, "SendChatMessage") == 0, "a missing group answer announces nothing")
	env.IsInGroup = function() return true end
	env.InCombatLockdown = function() return env.Secret(false) end
	env.FireEvent("CHAT_MSG_SYSTEM", "Deadmines has been reset.")
	assert(#Q.Calls(env, "SendChatMessage") == 0, "an unreadable combat state announces nothing")
	env.InCombatLockdown = fight
	clean(env, K)
end

-- The ring's OnUpdate, the reviewed exception to the no-per-frame rule, exists only while the ring is on and shown.
do
	local env, K, ns = boot()
	Q.Write(env, K, "cursorRing", true)
	local _, ring = ns.AidFrames()
	assert(ring:IsShown() and ring:GetScript("OnUpdate"), "a shown ring follows the pointer")
	Q.Write(env, K, "cursorShow", "combat")
	assert(not ring:IsShown() and not ring:GetScript("OnUpdate"), "a hidden ring has no OnUpdate")
	env.SetCombat(true)
	assert(ring:GetScript("OnUpdate"))
	env.SetCombat(false)
	assert(not ring:GetScript("OnUpdate"), "leaving combat clears it")
	Q.Write(env, K, "cursorShow", "always")
	Q.Write(env, K, "cursorRing", false)
	assert(not ring:GetScript("OnUpdate"), "turning the ring off clears it")
	Q.Write(env, K, "cursorRing", true)
	Q.Disable(env, K)
	assert(not ring:GetScript("OnUpdate"), "so does turning the module off")
	clean(env, K)
end

-- The preview puts the crosshair, the warning and the group death alert where the screen does, and every colour swatch is disabled under its class colour.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	local function find(text)
		for _, line in ipairs(preview.lines) do
			if line:GetText() == text then return line end
		end
	end
	local function offset(a, b)
		local _, _, _, ax, ay = a:GetPoint(1)
		local _, _, _, bx, by = b:GetPoint(1)
		return ax - bx, ay - by
	end
	local function close(a, b)
		return math.abs(a - b) < 1
	end
	local death, talents, durability = find("A group member died"), find("Unspent talent points"), find("Low durability: 39%")
	assert(death and death:GetAlpha() < 1, "the group death sample shows, dimmed while off")
	local cx, cy = offset(preview.cross, talents)
	local dx, dy = offset(durability, talents)
	Q.Write(env, K, "crosshairX", 125)
	Q.Write(env, K, "crosshairY", -100)
	Q.Write(env, K, "durabilityY", 400)
	Q.Write(env, K, "deathAlert", true)
	preview:Refresh()
	local cx2, cy2 = offset(preview.cross, talents)
	local dx2, dy2 = offset(durability, talents)
	assert(close(cx2 - cx, 125) and close(cy2 - cy, -100), "the crosshair sample moves with its offsets")
	assert(close(dx2, dx) and close(dy2 - dy, 150), "the warning sample moves with Warning height")
	assert(death:GetAlpha() == 1, "the group death sample lights up")
	for colour, class in pairs({ combatEnterColor = "combatEnterClass", combatLeaveColor = "combatLeaveClass", talentColor = "talentClass", cursorColor = "cursorClass" }) do
		local row = K.Options.Row("QoL", colour)
		local settings = { enabled = true, combatAlert = true, talentAlert = true, cursorRing = true }
		assert(not row.disableWhen(settings), colour .. " is editable")
		settings[class] = true
		assert(row.disableWhen(settings), colour .. " is disabled under class colour")
	end
	clean(env, K)
end

-- Every new option switched on at once: each has a row and reads back, a feign raises nothing, and the class colours and thicknesses show.
do
	local env, K, ns = boot()
	env._unspent, env._durability[5], env._group = true, { 10, 100 }, true
	local ON = {
		skipMode = "both", alertSize = 40, combatAlert = true, combatAlertOn = "enter", combatEnterText = "In", combatEnterColor = { r = 0.1, g = 0.2, b = 0.3 },
		combatEnterClass = true, combatLeaveText = "Out", combatLeaveColor = { r = 0.3, g = 0.2, b = 0.1 }, combatLeaveClass = true,
		talentAlert = true, talentText = "Spend", talentColor = { r = 0.4, g = 0.5, b = 0.6 }, talentClass = true, deathAlert = true, deathSound = "ready",
		durabilityAlert = true, durabilityPercent = 50, durabilityY = 300, durabilityThrown = false,
		crosshair = "thin", crosshairShow = "combat", crosshairHLength = 60, crosshairHWidth = 3, crosshairVLength = 70, crosshairVWidth = 5,
		crosshairBorder = 1, crosshairX = 10, crosshairY = -10,
		cursorRing = true, cursorShow = "combat", cursorScale = 150, cursorOpacity = 50, cursorClass = true, cursorColor = { r = 0.7, g = 0.8, b = 0.9 },
		hideScreenshot = true, announceReset = true, autoLog = true, autoLogWhere = "all", autoLogNotice = false,
	}
	for key, value in pairs(ON) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
		Q.Write(env, K, key, value)
		local got = ns.Get(key)
		assert(got == value or type(value) == "table" and near(got.r, value.r), key .. " reads back")
	end
	local cr, cg, cb = K.Theme.ClassColor(select(2, env.UnitClass("player")))
	local function classed(text)
		local r, g, b = text:GetTextColor()
		return near(r, cr) and near(g, cg) and near(b, cb)
	end
	env.UnitIsFeignDeath = function(unit) return unit == "party1" end
	env._dead.party1 = true
	env.FireEvent("UNIT_HEALTH", "party1")
	assert(not ns.noticeLines.flash and #Q.Calls(env, "PlaySound") == 0, "a feign raises nothing")
	env.SetCombat(true)
	local flash = ns.noticeLines.flash
	assert(flash.text:GetText() == "In" and classed(flash.text), "Entering in class colour")
	local cross, ring = ns.AidFrames()
	assert(cross:IsShown() and ring:IsShown(), "combat shows the crosshair and the ring")
	assert(near(cross.v:GetWidth(), K.Scale.Pixel(5)) and near(cross.h:GetHeight(), K.Scale.Pixel(3)), "Vertical and Horizontal thickness")
	env.SetCombat(false)
	local talents, durability = ns.noticeLines.talents, ns.noticeLines.durability
	assert(talents:IsShown() and talents.text:GetText() == "Spend" and classed(talents.text), "Talent alert in class colour")
	assert(durability:IsShown() and durability.text:GetText() == "Low durability: 10%")
	assert(not env.ActionStatus:IsEventRegistered("SCREENSHOT_SUCCEEDED"))
	clean(env, K)
end

print("qol parity ok")
