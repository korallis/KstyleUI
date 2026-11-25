-- test-qol-parity-r2.lua: the EllesmereUI parity round 2 QoL options: a v0.2.8 profile keeps today's behaviour, each option works switched on and follows the events that change it, nothing depends on another switch it does not name, and turning an option off puts back exactly what it changed.
local Q = dofile("Tools/regression/qol_env.lua")

local LOOT_TOASTS = { "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE", "LOOT_ITEM_ROLL_WON" }
local ACHIEVEMENT_TOASTS = { "ACHIEVEMENT_EARNED", "CRITERIA_EARNED" }

local function record(env, name, result)
	return function(...)
		env._calls[name] = env._calls[name] or {}
		table.insert(env._calls[name], { ... })
		return result
	end
end

local function stand(env)
	local frame = function(name, parent)
		local f = env.CreateFrame("Frame", name, parent or env.UIParent)
		f._blizzard = true
		if name then env[name] = f end
		return f
	end
	env._crit, env._cast, env._channel = 12.5, nil, nil
	env.UnitStat = function(_, i) return 100, 100 + i, 0, 0 end
	env.GetCritChance = function() return env._crit end
	env.GetSpellCritChance = function() return 8.25 end
	env.GetMeleeHaste = function() return 5 end
	env.GetSpellBonusDamage = function() return 321 end
	env.GetSpellBonusHealing = function() return 400 end
	env.GetDodgeChance = function() return 4 end
	env.GetParryChance = function() return 3 end
	env.UnitArmor = function() return 900, 1000 end
	env.GetCombatRating = function(i) return i * 10 end
	env.CR_CRIT_MELEE, env.CR_CRIT_SPELL, env.CR_HASTE_MELEE, env.CR_DODGE, env.CR_PARRY, env.CR_BLOCK = 9, 11, 18, 3, 4, 5
	env.UnitCastingInfo = function() if env._cast then return "Bolt", "Bolt", 1, env._cast[1], env._cast[2] end end
	env.UnitChannelInfo = function() if env._channel then return "Drain", "Drain", 1, env._channel[1], env._channel[2] end end
	local alerts = frame("AlertFrame")
	for _, event in ipairs(LOOT_TOASTS) do alerts:RegisterEvent(event) end
	for _, event in ipairs(ACHIEVEMENT_TOASTS) do alerts:RegisterEvent(event) end
	frame("GroupLootHistoryFrame"):Hide()
	local cinematic = frame("CinematicFrame")
	cinematic.closeDialog = frame(nil, cinematic)
	cinematic.closeDialog:Hide()
	env.CinematicFrame_CancelCinematic = record(env, "CancelCinematic")
	env.StopCinematic = record(env, "StopCinematic")
	env.InCinematic = function() return true end
	env.MovieFrame.CloseDialog = frame(nil, env.MovieFrame)
	env.MovieFrame.CloseDialog:Hide()
	-- As Blizzard_FrameXML/MovieFrame.lua: Escape (the game menu binding), Space and Enter all open the movie's prompt.
	env.GetBindingFromClick = function(key) return key == "ESCAPE" and "TOGGLEGAMEMENU" or nil end
	env.MovieFrame:SetScript("OnKeyUp", function(self, key)
		if key == "SPACE" or key == "ENTER" or env.GetBindingFromClick(key) == "TOGGLEGAMEMENU" then self.CloseDialog:Show() end
	end)
	-- Blizzard_TrainerUI.xml: a 338 by 424 ButtonFrameTemplate whose 80-wide Train button sits at its bottom right.
	frame("ClassTrainerFrame"):SetSize(338, 424)
	env.ClassTrainerFrame:SetPoint("CENTER")
	frame("ClassTrainerTrainButton", env.ClassTrainerFrame):SetSize(80, 22)
	env.ClassTrainerTrainButton:SetPoint("BOTTOMRIGHT")
	env.BuyTrainerService = record(env, "BuyTrainerService")
	env.NUM_BAG_SLOTS = 4
	env._bags = { [0] = { { itemID = 5, hasLoot = false, stackCount = 1, isLocked = false }, { itemID = 7, hasLoot = true, stackCount = 2, isLocked = false } },
		[1] = { { itemID = 9, hasLoot = true, stackCount = 1, isLocked = false } } }
	env.C_Item.IsItemBindToAccount = function() return false end
	env.C_Container = {
		GetContainerNumSlots = function() return 4 end,
		GetContainerItemInfo = function(bag, slot) return env._bags[bag] and env._bags[bag][slot] end,
		UseContainerItem = record(env, "UseContainerItem"),
	}
	frame("MerchantFrame"):Hide()
	env.C_MountJournal = { ClearFanfare = record(env, "MountFanfare") }
	env.C_ToyBoxInfo = { ClearFanfare = record(env, "ToyFanfare") }
	env.C_GossipInfo.GetOptions = function() return env._options or {} end
	local gossip = frame("GossipFrame")
	gossip.SelectGossipOption = record(env, "SelectGossipOption")
	gossip:Hide()
	local popup = frame("StaticPopup1")
	popup.button = env.CreateFrame("Button", nil, popup)
	popup.GetButton1 = function() return popup.button end
	popup.button.Click = record(env, "PopupClick")
	popup:Hide()
	env.StaticPopup_Show = function() popup:Show() end
	env.StaticPopup_OnHide = function() end
end

local function boot(settings, size)
	local saved = { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = stand, width = size and size[1], height = size and size[2] })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function last(frame, method)
	for i = #frame._calls, 1, -1 do
		if frame._calls[i].method == method then return frame._calls[i].args end
	end
end

local function keyboard(frame)
	local args = last(frame, "EnableKeyboard")
	return args ~= nil and args[1] == true
end

local function press(env, ns, key)
	local catcher = ns.KeyCatcher()
	catcher:GetScript("OnKeyDown")(catcher, key)
	env.RunTimers()
	return catcher:GetPropagateKeyboardInput()
end

-- What a font string shows, as the game formats SetFormattedText; a secret argument reads "<secret>".
local function shows(fs)
	for i = #fs._calls, 1, -1 do
		local call = fs._calls[i]
		if call.method == "SetText" then return call.args[1] end
		if call.method == "SetFormattedText" then
			local ok, text = pcall(string.format, unpack(call.args, 1, call.args.n))
			return ok and text or "<secret>"
		end
	end
end

local function texts(frame)
	local out = {}
	for i = 1, frame.count do out[i] = shows(frame.lines[i]) end
	return out
end

-- Defaults: a v0.2.8-shaped profile keeps every new switch at today's behaviour, builds nothing and changes nothing.
do
	local env, K, ns = boot({ enabled = true, fastLoot = true, lootFeed = true, skipCinematics = true, cursorRing = true })
	for key, value in pairs({ rollsClose = 0, autoLogDelay = false, openSkipWarbound = true, skipAuto = true, cursorTexture = "ring", cursorDot = false, cursorHidden = false, cursorTrail = false, castRing = false,
		stats = false, dialogKeys = false, numberKeys = false, confirmPopups = false, hideToasts = "none", autoOpen = false, autoUnwrap = false }) do
		assert(ns.Get(key) == value, key .. " keeps today's behaviour by default")
	end
	assert(not ns.StatsFrame() and not ns.KeyCatcher() and not select(3, ns.AidFrames()), "no stats, key catcher or cast circle is built")
	local _, ring = ns.AidFrames()
	assert(ring.texture:IsShown() and not ring.dot:IsShown(), "the ring shows as before, without a dot")
	assert(ring.texture:GetTexture():find("Ring.png", 1, true) and not ring.texture:GetTexture():find("Bevel", 1, true), "the plain ring")
	env.FireEvent("BAG_UPDATE_DELAYED")
	env.FireEvent("NEW_MOUNT_ADDED", 55)
	env.FireEvent("CINEMATIC_START", true)
	env.GroupLootHistoryFrame:Show()
	env.Release()
	assert(env.GroupLootHistoryFrame:IsShown(), "the loot rolls window stays open")
	assert(#Q.Calls(env, "StopCinematic") == 1, "cinematics still skip at once")
	assert(#Q.Calls(env, "UseContainerItem") == 0 and #Q.Calls(env, "MountFanfare") == 0, "no container or fanfare is touched")
	for _, event in ipairs(LOOT_TOASTS) do assert(env.AlertFrame:IsEventRegistered(event), event .. " toasts stay") end
	clean(env, K)
end

-- Character stats, on: the default stats in order, percentages, short labels, ratings, colour and size; events refresh the values only.
do
	local env, K, ns = boot()
	Q.Write(env, K, "stats", true)
	local frame = ns.StatsFrame()
	assert(frame:IsShown() and frame.count == 5, tostring(frame.count))
	local lines = texts(frame)
	assert(lines[1]:find("Critical strike", 1, true) and lines[1]:find("12.50%", 1, true), lines[1])
	assert(lines[3]:find("Haste", 1, true) and lines[4]:find("321", 1, true) and lines[5]:find("Armour", 1, true) and lines[5]:find("1000", 1, true), table.concat(lines, " / "))
	local x, y = frame:GetLeft(), frame:GetTop()
	assert(x >= 0 and y <= K.Scale.Root():GetTop(), "the stats sit on the screen")
	env._crit = 20
	env.FireEvent("COMBAT_RATING_UPDATE")
	env.RunTimers()
	assert(shows(frame.lines[1]):find("20.00%", 1, true), "a rating change refreshes the value on the next frame")
	env._crit = 21
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	assert(shows(frame.lines[1]):find("21.00%", 1, true), "an aura change refreshes the value")
	env._crit = env.Secret(30)
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	assert(shows(frame.lines[1]) == "<secret>" and env.issecretvalue(frame.lines[1]:IsShown()) == false, "a secret value still draws")
	env._crit = 12.5
	Q.Write(env, K, "statsShort", true)
	assert(shows(frame.lines[1]):find("Crit|r", 1, true) and not shows(frame.lines[1]):find("Critical", 1, true), "short labels")
	Q.Write(env, K, "statsValue", "rating")
	assert(shows(frame.lines[1]):find("90|r", 1, true), shows(frame.lines[1]))
	assert(shows(frame.lines[4]):find("321", 1, true), "a stat with no rating keeps its value")
	Q.Write(env, K, "statsValue", "both")
	assert(shows(frame.lines[1]):find("12.50% (90)", 1, true), shows(frame.lines[1]))
	local plain = shows(frame.lines[1])
	Q.Write(env, K, "statsColored", true)
	local r, g, b = K.Tokens.Color("accent")
	local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	assert(shows(frame.lines[1]) ~= plain and shows(frame.lines[1]):find(hex, 1, true), "coloured values use the accent")
	local size, width = select(2, frame.lines[1]:GetFont()), frame:GetWidth()
	local height = frame:GetHeight()
	assert(K.Theme.SetFontScale(1.3))
	env.RunTimers()
	assert(select(2, frame.lines[1]:GetFont()) > size and frame:GetHeight() > height and frame:GetWidth() > width, "global text size grows the stat rows and their block")
	assert(K.Theme.SetFontScale(1))
	env.RunTimers()
	Q.Write(env, K, "statsScale", 150)
	assert(select(2, frame.lines[1]:GetFont()) > size and frame:GetWidth() > width, "Stats size grows the text and the block")
	local list = {}
	for _, entry in ipairs(K.Options.Read("QoL", "statsList")) do list[#list + 1] = { id = entry.id, shown = entry.id == "block" or entry.id == "dodge" or entry.id == "haste", zone = "left" } end
	list[1], list[8] = list[8], list[1]
	Q.Write(env, K, "statsList", list)
	lines = texts(frame)
	assert(frame.count == 2 and lines[1]:find("Haste", 1, true) and lines[2]:find("Dodge", 1, true), "the chosen stats in the chosen order; block's missing call draws no line")
	assert(not frame.lines[3]:IsShown(), "lines past the list hide")
	Q.Write(env, K, "stats", false)
	assert(not frame:IsShown(), "turning it off hides the stats")
	env._crit = 40
	env.FireEvent("COMBAT_RATING_UPDATE")
	Q.Write(env, K, "stats", true)
	assert(frame:IsShown())
	Q.Disable(env, K)
	assert(not frame:IsShown(), "the module off hides them")
	clean(env, K)
end

-- Cursor ring parts, on: the bevelled style, the centre dot, the trail that settles, and showing only while looking around.
do
	local env, K, ns = boot({ enabled = true, cursorRing = true })
	local _, ring = ns.AidFrames()
	Q.Write(env, K, "cursorTexture", "ringBevel")
	assert(ring.texture:GetTexture():find("RingBevel.png", 1, true), "the bevelled ring")
	Q.Write(env, K, "cursorDot", true)
	assert(ring.dot:IsShown() and ring.dot:GetTexture():find("Dot.png", 1, true), "the centre dot")
	Q.Write(env, K, "cursorTrail", true)
	local follow = ring:GetScript("OnUpdate")
	env._cursor = { 100, 100 }
	follow(ring, 0)
	env._cursor = { 160, 130 }
	follow(ring, 0)
	assert(ring.trail[1]:IsShown(), "moving draws the trail")
	for _ = 1, 8 do follow(ring, 0) end
	for _, dot in ipairs(ring.trail) do assert(not dot:IsShown(), "standing still settles the trail") end
	Q.Write(env, K, "cursorHidden", true)
	assert(not ring:IsShown() and not ring:GetScript("OnUpdate"), "only while looking: hidden at rest, with no OnUpdate")
	env.FireEvent("PLAYER_STARTED_LOOKING")
	assert(ring:IsShown() and ring.texture:IsShown() and ring:GetScript("OnUpdate"), "shown while the camera turns")
	env.FireEvent("PLAYER_STARTED_TURNING")
	env.FireEvent("PLAYER_STOPPED_LOOKING")
	assert(ring:IsShown(), "still turning")
	env.FireEvent("PLAYER_STOPPED_TURNING")
	assert(not ring:IsShown(), "hidden once both stop")
	Q.Write(env, K, "cursorHidden", false)
	assert(ring:IsShown(), "off shows the ring again")
	Q.Write(env, K, "cursorDot", false)
	Q.Write(env, K, "cursorTexture", "ring")
	assert(not ring.dot:IsShown() and not ring.texture:GetTexture():find("Bevel", 1, true), "off puts the plain ring back")
	clean(env, K)
end

-- Cast circle, on with the ring off: it follows the pointer while casting, fills for casts and empties for channels, sits at the centre when not on the pointer, and refuses a secret cast.
do
	local env, K, ns = boot()
	Q.Write(env, K, "castRing", true)
	local _, ring, cast = ns.AidFrames()
	assert(cast and not cast:IsShown() and not ring:IsShown(), "nothing shows until a cast")
	env._cast = { 100000, 102500 }
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	assert(cast:IsShown() and ring:IsShown() and not ring.texture:IsShown() and ring:GetScript("OnUpdate"), "the circle follows the pointer without the ring")
	local args = last(cast, "SetCooldown")
	assert(args[1] == 100 and args[2] == 2.5 and last(cast, "SetReverse")[1] == true, "a cast fills over its cast time")
	assert(select(2, cast:GetPoint(1)) == ring, "on the pointer")
	assert(last(cast, "SetDrawEdge")[1] == true, "the spark is on by default")
	Q.Write(env, K, "castSpark", false)
	assert(last(cast, "SetDrawEdge")[1] == false, "the spark turns off")
	Q.Write(env, K, "cursorClass", true)
	local cr = K.Theme.ClassColor(select(2, env.UnitClass("player")))
	assert(math.abs(last(cast, "SetSwipeColor")[1] - cr) < 1e-6, "the class colour paints the circle with the ring off")
	env._cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "player")
	assert(not cast:IsShown() and not ring:IsShown() and not ring:GetScript("OnUpdate"), "the circle and its OnUpdate leave with the cast")
	env._channel = { 200000, 203000 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	assert(cast:IsShown() and last(cast, "SetReverse")[1] == false, "a channel empties")
	Q.Write(env, K, "castAttach", false)
	assert(select(2, cast:GetPoint(1)) == K.Scale.Root() and not ring:IsShown(), "off the pointer: the screen centre, no pointer frame")
	env._channel = { env.Secret(1), 2 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	assert(not cast:IsShown(), "a secret cast time is refused")
	env._channel = { 200000, 203000 }
	env.FireEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	Q.Write(env, K, "castRing", false)
	assert(not cast:IsShown(), "turning it off hides it")
	env.FireEvent("UNIT_SPELLCAST_START", "player")
	assert(not cast:IsShown(), "and no cast brings it back")
	clean(env, K)
end

-- Dialog keys, on: Space and number keys act only in their windows and out of combat; every other key passes through.
do
	local env, K, ns = boot()
	Q.Write(env, K, "dialogKeys", true)
	local catcher = ns.KeyCatcher()
	assert(not keyboard(catcher), "no window, no keyboard")
	env._quest.gossipAvailable = { { questID = 11 } }
	env._quest.gossipActive = { { questID = 12 } }
	env.GossipFrame.gossipOptions = { {}, {} }
	env.FireEvent("GOSSIP_SHOW")
	assert(keyboard(catcher) and catcher:GetPropagateKeyboardInput() == true, "a gossip window takes the keyboard, passing keys on")
	assert(press(env, ns, "W") == true and #Q.Calls(env, "C_GossipInfo.SelectAvailableQuest") == 0, "other keys pass through")
	assert(press(env, ns, "2") == true and #Q.Calls(env, "C_GossipInfo.SelectActiveQuest") == 0, "number keys stay off")
	assert(press(env, ns, "SPACE") == false and Q.Calls(env, "C_GossipInfo.SelectAvailableQuest")[1][1] == 11, "Space picks the first choice and is used up")
	Q.Write(env, K, "numberKeys", true)
	assert(press(env, ns, "2") == false and Q.Calls(env, "C_GossipInfo.SelectActiveQuest")[1][1] == 12, "2 picks the second entry")
	assert(press(env, ns, "4") == false and Q.Calls(env, "SelectGossipOption")[1][2] == 2, "4 picks the second option")
	assert(press(env, ns, "7") == true, "no seventh choice: the key passes")
	env.SetCombat(true)
	assert(not keyboard(catcher) and catcher:GetPropagateKeyboardInput() == true, "combat gives the keyboard back")
	env.FireEvent("GOSSIP_SHOW")
	assert(not keyboard(catcher), "and a window in combat takes nothing")
	env.SetCombat(false)
	assert(keyboard(catcher), "back after combat")
	env.FireEvent("GOSSIP_CLOSED")
	assert(not keyboard(catcher), "closing the window gives it back")
	env._quest.choices = 3
	env.FireEvent("QUEST_COMPLETE")
	assert(press(env, ns, "SPACE") == true and #Q.Calls(env, "GetQuestReward") == 0, "Space never picks one of several rewards")
	assert(press(env, ns, "2") == false and Q.Calls(env, "GetQuestReward")[1][1] == 2, "2 picks the second reward")
	env.FireEvent("QUEST_DETAIL")
	assert(press(env, ns, "SPACE") == false and #Q.Calls(env, "AcceptQuest") == 1, "Space accepts a quest")
	env.FireEvent("QUEST_FINISHED")
	assert(not keyboard(catcher))
	Q.Write(env, K, "confirmPopups", true)
	env.StaticPopup_Show("CONFIRM")
	env.RunTimers()
	assert(keyboard(catcher), "a shown popup takes the keyboard")
	env.StaticPopup1.button:Disable()
	assert(press(env, ns, "SPACE") == true and #Q.Calls(env, "PopupClick") == 0, "a disabled first button is not clicked")
	env.StaticPopup1.button:Enable()
	env.StaticPopup_Show("CONFIRM")
	assert(press(env, ns, "SPACE") == false and #Q.Calls(env, "PopupClick") == 1, "Space clicks the first button")
	env.FireEvent("GOSSIP_SHOW")
	for _, key in ipairs({ "dialogKeys", "numberKeys", "confirmPopups" }) do Q.Write(env, K, key, false) end
	assert(not keyboard(catcher) and catcher:GetPropagateKeyboardInput() == true, "all three off give the keyboard back")
	clean(env, K)
end

-- Toasts, loot rolls, Escape skipping, containers and new mounts and toys: each works on and puts back exactly what it changed.
do
	local env, K = boot()
	Q.Write(env, K, "hideToasts", "loot")
	for _, event in ipairs(LOOT_TOASTS) do assert(not env.AlertFrame:IsEventRegistered(event), event .. " hidden") end
	assert(env.AlertFrame:IsEventRegistered("ACHIEVEMENT_EARNED"), "achievements stay")
	Q.Write(env, K, "hideToasts", "both")
	assert(not env.AlertFrame:IsEventRegistered("ACHIEVEMENT_EARNED"))
	Q.Write(env, K, "hideToasts", "none")
	for _, event in ipairs(LOOT_TOASTS) do assert(env.AlertFrame:IsEventRegistered(event), event .. " back") end
	assert(not env.AlertFrame:IsEventRegistered("SHOW_LOOT_TOAST_LEGENDARY_LOOTED"), "an event the game never registered stays off")

	Q.Write(env, K, "rollsClose", 5)
	env.GroupLootHistoryFrame:Show()
	assert(env.GroupLootHistoryFrame:IsShown())
	env.Release()
	assert(not env.GroupLootHistoryFrame:IsShown(), "the loot rolls window closes after the delay")
	env.GroupLootHistoryFrame:Show()
	Q.Write(env, K, "rollsClose", 0)
	env.Release()
	assert(env.GroupLootHistoryFrame:IsShown(), "zero cancels a waiting close")

	Q.Write(env, K, "skipCinematics", true)
	Q.Write(env, K, "skipAuto", false)
	env.FireEvent("CINEMATIC_START", true)
	assert(#Q.Calls(env, "StopCinematic") == 0, "Skip at once off waits for Escape")
	env.CinematicFrame.closeDialog:Show()
	assert(#Q.Calls(env, "CancelCinematic") == 1, "Escape's prompt is answered")
	env.FireEvent("PLAY_MOVIE", 1)
	env.Release()
	assert(#Q.Calls(env, "FinishMovie") == 0, "movies follow Skip which")
	Q.Write(env, K, "skipMode", "both")
	env.MovieFrame:Show()
	local key = env.MovieFrame:GetScript("OnKeyUp")
	key(env.MovieFrame, "SPACE")
	assert(env.MovieFrame.CloseDialog:IsShown() and #Q.Calls(env, "FinishMovie") == 0, "Space and Enter leave the movie's prompt to the player")
	env.MovieFrame.CloseDialog:Hide()
	key(env.MovieFrame, "ESCAPE")
	assert(#Q.Calls(env, "FinishMovie") == 1, "Escape's movie prompt is answered")
	Q.Write(env, K, "skipAuto", true)
	env.CinematicFrame.closeDialog:Hide()
	env.CinematicFrame.closeDialog:Show()
	assert(#Q.Calls(env, "CancelCinematic") == 1, "Skip at once on leaves the prompt to the player")

	Q.Write(env, K, "autoOpen", true)
	local used = Q.Calls(env, "UseContainerItem")
	assert(#used == 1 and used[1][1] == 0 and used[1][2] == 2, "the first container opens")
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 2 and Q.Calls(env, "UseContainerItem")[2][1] == 1, "one that will not open is passed over")
	env._bags[1][1] = nil
	env.MerchantFrame:Show()
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 2, "nothing opens at a merchant")
	env.MerchantFrame:Hide()
	env._bags[0][2] = { itemID = 8, hasLoot = true, stackCount = 1, isLocked = false }
	env.SetCombat(true)
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 2, "nothing opens in combat")
	env.SetCombat(false)
	assert(#Q.Calls(env, "UseContainerItem") == 3, "leaving combat opens it")
	env.C_Item.IsItemBindToAccount = function(id) return id == 11 end
	env._bags[0][2] = { itemID = 11, hasLoot = true, stackCount = 1, isLocked = false }
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 3, "a warbound container is left for alts")
	Q.Write(env, K, "openSkipWarbound", false)
	assert(#Q.Calls(env, "UseContainerItem") == 4, "off opens it too")
	Q.Write(env, K, "autoOpen", false)
	env._bags[0][3] = { itemID = 10, hasLoot = true, stackCount = 1, isLocked = false }
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 4, "off opens nothing")

	Q.Write(env, K, "autoLog", true)
	Q.Write(env, K, "autoLogWhere", "party")
	Q.Write(env, K, "autoLogDelay", true)
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(env._logging == true, "a dungeon starts the log")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == true, "leaving keeps the log 30 seconds")
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env.Release()
	assert(env._logging == true, "coming back within the grace cancels the stop")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	env.Release()
	assert(env._logging == false, "the grace ends the log")
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	Q.Write(env, K, "autoLogDelay", false)
	assert(env._logging == false, "turning the grace off stops a waiting log at once")
	env.Release()
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	Q.Write(env, K, "autoLogDelay", true)
	Q.Write(env, K, "autoLog", false)
	assert(env._logging == false, "turning logging off never waits")

	Q.Write(env, K, "autoUnwrap", true)
	env.FireEvent("NEW_MOUNT_ADDED", 55)
	env.FireEvent("NEW_TOY_ADDED", env.Secret(77))
	env.FireEvent("NEW_TOY_ADDED", 78)
	assert(Q.Calls(env, "MountFanfare")[1][1] == 55 and #Q.Calls(env, "ToyFanfare") == 1 and Q.Calls(env, "ToyFanfare")[1][1] == 78, "new mounts and toys unwrap; a secret id is skipped")
	Q.Write(env, K, "autoUnwrap", false)
	env.FireEvent("NEW_MOUNT_ADDED", 56)
	assert(#Q.Calls(env, "MountFanfare") == 1, "off leaves the wrap on")
	clean(env, K)
end

-- The page: every new row writes, and the live preview draws the dot, trail, cast circle and stats, dimmed while off.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(preview.stats:GetAlpha() < 1 and preview.cast:GetAlpha() == 1 and preview.stats.count == 5, "the stats sample is dimmed while off")
	assert(select(4, preview.dot:GetVertexColor()) < 0.7 * 0.5, "the dot is dimmed while off")
	for key, value in pairs({ rollsClose = 3, skipAuto = false, cursorTexture = "ringBevel", cursorDot = true, cursorHidden = true, cursorTrail = true, castRing = true, castSpark = false,
		castAttach = false, autoLogDelay = true, stats = true, statsValue = "both", statsColored = true, statsShort = true, statsScale = 120, dialogKeys = true, numberKeys = true,
		confirmPopups = true, hideToasts = "both", autoOpen = true, openSkipWarbound = false, autoUnwrap = true, crosshairX = 120, crosshairY = 90 }) do
		assert(K.Options.Row("QoL", key), key .. " has a row")
		Q.Write(env, K, key, value)
	end
	assert(K.Options.Row("QoL", "statsList"), "the stats list has a row")
	preview:Refresh()
	assert(preview.stats:GetAlpha() == 1 and shows(preview.stats.lines[1]):find("Crit|r", 1, true), "the preview follows the stats settings")
	assert(preview.ring:GetTexture():find("RingBevel", 1, true) and last(preview.cast, "SetSwipeTexture")[1]:find("RingBevel", 1, true), "both rings take the style")
	assert(last(preview.cast, "SetDrawEdge")[1] == false and preview.trail[1]:IsShown(), "spark and trail follow")
	local dx, dy = select(4, preview.cast:GetPoint(1)) - select(4, preview.cross:GetPoint(1)), select(5, preview.cast:GetPoint(1)) - select(5, preview.cross:GetPoint(1))
	assert(math.abs(dx + 120) < 1 and math.abs(dy + 90) < 1, "off the pointer, the cast circle sits at the screen centre, not on a moved crosshair: " .. dx .. ", " .. dy)
	Q.Write(env, K, "castAttach", true)
	preview:Refresh()
	assert(select(4, preview.cast:GetPoint(1)) == select(4, preview.ring:GetPoint(1)), "on the pointer, it rings the ring")
	local function span(region)
		local x = select(4, region:GetPoint(1))
		return x - region:GetWidth() / 2, x + region:GetWidth() / 2
	end
	local _, right = span(preview.stats)
	for _, region in ipairs({ preview.cross, preview.ring, preview.cast }) do
		assert(right <= (span(region)) + 1e-6, "the stats sample sits left of the cursor aids")
	end
	clean(env, K)
end

-- Review of 8a31bbed: the game's own confirmations and combat rules stay, unknown answers refuse, keys and timers follow their windows, and stats read as the character sheet does.
do
	local env, K, ns = boot()
	Q.Write(env, K, "dialogKeys", true)
	Q.Write(env, K, "numberKeys", true)
	env._quest.money = 10000
	env.FireEvent("QUEST_COMPLETE")
	assert(press(env, ns, "SPACE") == true and press(env, ns, "1") == true and #Q.Calls(env, "GetQuestReward") == 0, "a quest that takes money is left to the game's confirmation")
	clean(env, K)
end

-- The game refuses BuyTrainerService from addon code (ADDON_ACTION_FORBIDDEN), so KstyleUI offers no Train all: a profile saved with that option on has nothing to turn on, adds nothing to the trainer window and buys nothing.
do
	local env, K, ns = boot({ enabled = true, trainAll = true })
	env.FireEvent("TRAINER_SHOW")
	env.RunTimers()
	assert(ns.Get("trainAll") == nil and not K.Options.Row("QoL", "trainAll"), "no Train all setting or row is left")
	assert(select("#", env.ClassTrainerFrame:GetChildren()) == 1, "the trainer window keeps only the game's own Train button")
	assert(#Q.Calls(env, "BuyTrainerService") == 0, "nothing buys from addon code")
	clean(env, K)
end

do
	local env, K, ns = boot()
	env.SetCombat(true)
	Q.Write(env, K, "dialogKeys", true)
	assert(last(ns.KeyCatcher(), "EnableKeyboard") == nil, "a catcher made in combat makes no protected call")
	env.SetCombat(false)
	clean(env, K)
end

do
	local env, K, ns = boot()
	Q.Write(env, K, "confirmPopups", true)
	local catcher, popup = ns.KeyCatcher(), env.StaticPopup1
	env.StaticPopup_Show("CONFIRM")
	popup:Hide()
	env.StaticPopup_OnHide(popup)
	assert(not keyboard(catcher), "a popup closed with the mouse gives the keyboard back")
	popup.button:Disable()
	env.StaticPopup_Show("CONFIRM")
	popup.button:Enable()
	assert(keyboard(catcher) and press(env, ns, "SPACE") == false and #Q.Calls(env, "PopupClick") == 1, "a popup whose button enables later still takes Space")
	popup.button.Click = function() popup:Hide(); env.StaticPopup_OnHide(popup) end
	env.StaticPopup_Show("CONFIRM")
	assert(press(env, ns, "SPACE") == false and not keyboard(catcher), "the Space that closes a popup is used up")
	Q.Write(env, K, "confirmPopups", false)
	env.QuestFrameDetailPanel = env.CreateFrame("Frame", "QuestFrameDetailPanel", env.UIParent)
	env.FireEvent("QUEST_DETAIL")
	Q.Write(env, K, "dialogKeys", true)
	assert(keyboard(catcher) and press(env, ns, "SPACE") == false and #Q.Calls(env, "AcceptQuest") == 1, "a quest window open before the switch turns on takes Space")
	clean(env, K)
end

do
	local env, K = boot()
	env.C_Item.IsItemBindToAccount = nil
	Q.Write(env, K, "autoOpen", true)
	assert(#Q.Calls(env, "UseContainerItem") == 0, "with no way to tell warbound containers, Leave warbound containers opens nothing")
	env.C_Item.IsItemBindToAccount = function() return env.Secret(false) end
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(#Q.Calls(env, "UseContainerItem") == 0, "nor with a secret answer")
	env.C_Item.IsItemBindToAccount = function() return false end
	env._bags[0][2].isLocked = env.Secret(false)
	env.FireEvent("BAG_UPDATE_DELAYED")
	local used = Q.Calls(env, "UseContainerItem")
	assert(#used == 1 and used[1][1] == 1, "a container whose lock is unknown is passed over")
	clean(env, K)
end

do
	local env, K = boot()
	env.GuildBankFrame = env.CreateFrame("Frame", nil, env.UIParent)
	Q.Write(env, K, "autoOpen", true)
	assert(#Q.Calls(env, "UseContainerItem") == 0, "nothing opens at the guild bank")
	env.GuildBankFrame:Hide()
	env.FireEvent("GUILDBANKFRAME_CLOSED")
	assert(#Q.Calls(env, "UseContainerItem") == 1, "closing the guild bank opens the next container")
	clean(env, K)
end

do
	local env, K = boot()
	Q.Write(env, K, "autoLog", true)
	Q.Write(env, K, "autoLogWhere", "party")
	Q.Write(env, K, "autoLogDelay", true)
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	env._instance = { false, "none" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	local deadline = env._held[#env._held]
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	Q.Write(env, K, "autoUnwrap", true)
	deadline()
	assert(env._logging == false, "another zone change or setting keeps the first 30-second deadline")
	Q.Write(env, K, "rollsClose", 5)
	env.GroupLootHistoryFrame:Show()
	Q.Write(env, K, "rollsClose", 10)
	env.Release()
	assert(not env.GroupLootHistoryFrame:IsShown(), "a new delay restarts the wait for an open loot rolls window")
	env.C_MountJournal = nil
	env.FireEvent("NEW_MOUNT_ADDED", 55)
	assert(#Q.Calls(env, "ToyFanfare") == 0, "a mount id never reaches the toy box")
	clean(env, K)
end

do
	local env, K, ns = boot()
	env.GetSpellBonusDamage = function(school) return school == 2 and 500 or 125 end
	local reads = 0
	env.GetCombatRating = function(i) reads = reads + 1; return i * 10 end
	Q.Write(env, K, "stats", true)
	local line = ns.StatsFrame().lines[4]
	assert(shows(line):find("125|r", 1, true), "spell power is the lowest school, as the character sheet shows it: " .. shows(line))
	reads = 0
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	assert(reads == 0, "percent mode reads no ratings")
	env.GetSpellBonusDamage = function(school) return school == 3 and env.Secret(1) or 125 end
	env.FireEvent("UNIT_AURA", "player")
	env.RunTimers()
	assert(shows(line) == "", "a restricted school leaves spell power blank rather than wrong")
	clean(env, K)
end

do
	local env, K, ns = boot({ enabled = true, cursorRing = true, castRing = true })
	local _, ring = ns.AidFrames()
	local dot = ring.trail[1]
	local function visibility(from)
		local n = 0
		for i = from + 1, #dot._calls do
			local method = dot._calls[i].method
			if method == "Hide" or method == "Show" or method == "SetShown" then n = n + 1 end
		end
		return n
	end
	local before = #dot._calls
	env.FireEvent("UNIT_SPELLCAST_DELAYED", "player")
	env.FireEvent("UNIT_SPELLCAST_DELAYED", "player")
	assert(visibility(before) == 0, "a cast event leaves the hidden trail alone")
	Q.Write(env, K, "cursorTrail", true)
	local follow = ring:GetScript("OnUpdate")
	env._cursor = { 100, 100 }
	follow(ring, 0)
	env._cursor = { 160, 130 }
	follow(ring, 0)
	before = #dot._calls
	env._cursor = { 220, 160 }
	follow(ring, 0)
	assert(dot:IsShown() and visibility(before) == 0, "a shown trail dot is not shown again on each move")
	env.FireEvent("UNIT_SPELLCAST_DELAYED", "player")
	assert(dot:IsShown(), "a cast event keeps the trail")
	clean(env, K)
end

print("qol parity round 2 ok")
