-- test-chat-parity.lua: the chat's EllesmereUI parity options keep today's defaults, apply when switched on, restore when switched off and refresh on the events that change them.
local C = dofile("Tools/regression/chat_env.lua")
local W = C.W

local function saved(settings)
	return { version = 42, profiles = { Default = { Chat = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function boot(settings)
	local env, K, ns = C.New({ saved = saved(settings or { enabled = true }) })
	env.RunTimers()
	assert(K.Modules.IsRunning("Chat"), tostring(env._errors[1]))
	return env, K, ns
end

local function write(env, K, key, value)
	assert(K.Options.Write("Chat", key, value) ~= false, key .. " must write")
	env.RunTimers()
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- A v0.2.8-shaped profile loads with every new option at its default.
do
	local env, K = boot({ enabled = true, fontSize = 16, buttons = false })
	local s = K.Store.Module("Chat")
	assert(s.fontSize == 16, "the player's own setting is kept")
	for key, value in pairs({ lockSize = false, editHeight = 22, idleFade = false, idleDelay = 15, idleStrength = 0.4, tabFont = "", tabHeight = 34,
		tabSpacing = 13.5, tabPadding = 6, tabOpacity = 1, tabEdge = "accent", classMentions = false, linkTooltips = false, sideHover = false,
		sideRight = false, sideWidth = 35 }) do
		assert(s[key] == value, key .. " defaults to " .. tostring(value) .. ", got " .. tostring(s[key]))
	end
	for _, group in ipairs({ "emotes", "skills", "reputation", "loot", "system", "achievements", "npc" }) do
		assert(s.idleWake[group] == false, "idleWake." .. group .. " is off by default")
	end
	for _, icon in ipairs({ "menu", "channels", "voice", "friends" }) do
		assert(s.sideIcons[icon] == true, "sideIcons." .. icon .. " is on by default")
	end
	clean(env, K)
end

-- Tab row height, spacing and font: on moves the row and the tabs, off puts them back.
do
	local env, K, ns = boot()
	local chat, tab, dock = env.ChatFrame1, env.ChatFrame1Tab, env.GENERAL_CHAT_DOCK
	tab.Text.GetUnboundedStringWidth = function() return 40 end
	ns.Frames.FitTabs(dock)
	local before, width = ns.Panel.Geometry(chat), tab:GetWidth()
	assert(width > 40, "the stand-in name is measured")
	write(env, K, "tabHeight", 46)
	local tall = ns.Panel.Geometry(chat)
	assert(tall.divider > before.divider + 10 and tall.top > before.top + 10, "a taller tab row pushes the rule and the messages down")
	write(env, K, "tabHeight", 34)
	assert(near(ns.Panel.Geometry(chat).top, before.top), "the default row comes back")
	write(env, K, "tabSpacing", 24)
	assert(tab:GetWidth() > width + 9, "wider spacing widens each tab: " .. tab:GetWidth() .. " vs " .. width)
	write(env, K, "tabSpacing", 13.5)
	assert(near(tab:GetWidth(), width), "the default spacing comes back")
	local caps = select(1, tab.Text:GetFont())
	local body = K.Tokens.Font("body")
	write(env, K, "tabFont", body)
	assert(select(1, tab.Text:GetFont()) == body, "the tab font applies to the tab names")
	assert(select(1, chat:GetFont()) ~= nil, "the messages keep their font")
	write(env, K, "tabFont", "")
	assert(select(1, tab.Text:GetFont()) == caps, "the caps face comes back")
	clean(env, K)
end

-- The filled tile: padding, opacity and edge apply only to it, and restore.
do
	local env, K, ns = boot()
	write(env, K, "tabStyle", "filled")
	local parts = K.Skin.Parts(env.ChatFrame1Tab)
	local fill = parts.backdrop
	assert(fill and fill:IsShown(), "the filled style shows its tile")
	local left = fill.inset.left
	write(env, K, "tabPadding", 2)
	assert(near(fill.inset.left, left + 4), "less padding draws the tile closer to the name")
	write(env, K, "tabSpacing", 4)
	write(env, K, "tabPadding", 12)
	assert(near(fill.inset.right, 2), "the tile never reaches past half the tab spacing, so it cannot touch the next tab")
	write(env, K, "tabSpacing", 13.5)
	write(env, K, "tabPadding", 6)
	assert(near(fill.inset.left, left), "the default padding comes back")
	assert(not fill.chrome.ownFill, "the token fill by default")
	write(env, K, "tabOpacity", 0.5)
	local _, _, _, a = K.Widgets.Rgba("buttonFill", 0.5)
	assert(fill.chrome.ownFill and near(fill.chrome.fillColor[4], a), "the tile takes the chosen opacity")
	write(env, K, "tabOpacity", 1)
	assert(not fill.chrome.ownFill, "full opacity gives the token fill back")
	assert(fill.chrome.ownEdge, "the accent edge by default")
	write(env, K, "tabEdge", "panel")
	assert(not fill.chrome.ownEdge, "the card's own edge")
	env.FireEvent("UPDATE_CHAT_WINDOWS")
	env.RunTimers()
	assert(not fill.chrome.ownEdge, "and it stays after the game updates its windows")
	write(env, K, "tabEdge", "accent")
	assert(fill.chrome.ownEdge, "the accent edge comes back")
	assert(ns.Frames.TilePad(K.Store.Module("Chat")) == 6, "the default tile padding")
	clean(env, K)
end

-- Edit box height: the tile and the room the card keeps for it follow, and restore.
do
	local env, K, ns = boot({ enabled = true, editBox = "always" })
	local chat = env.ChatFrame1
	local insets, bottom = ns.Panel.EditInsets(chat), ns.Panel.Geometry(chat).bottom
	write(env, K, "editHeight", 30)
	assert(ns.Panel.EditInsets(chat).top < insets.top - 2, "a taller box tile")
	assert(ns.Panel.Geometry(chat).bottom > bottom + 3, "the card keeps more room under the messages")
	local backdrop = K.Skin.Parts(chat.editBox).backdrop
	assert(near(backdrop.inset.top, ns.Panel.EditInsets(chat).top), "the box's tile takes the new insets")
	write(env, K, "editHeight", 22)
	assert(near(ns.Panel.EditInsets(chat).top, insets.top) and near(ns.Panel.Geometry(chat).bottom, bottom), "the default box comes back")
	clean(env, K)
end

-- Lock chat size: the docked windows' size grips hide, an undocked window keeps its own, and every grip returns.
do
	local env, K = boot()
	local docked, grip = env.ChatFrame2, env.ChatFrame2.ResizeButton
	assert(docked.isDocked and not K.Safe.IsHidden(grip), "the grip shows by default")
	env.SetCombat(true)
	write(env, K, "lockSize", true)
	env.SetCombat(false)
	env.RunTimers()
	assert(K.Safe.IsHidden(grip), "locking hides a docked window's grip, after combat")
	docked.isDocked = nil
	env.FCF_UnDockFrame(docked)
	env.RunTimers()
	assert(not K.Safe.IsHidden(grip), "an undocked window keeps its own grip")
	docked.isDocked = 1
	env.FCF_DockFrame(docked)
	env.RunTimers()
	assert(K.Safe.IsHidden(grip), "docking it again hides the grip")
	write(env, K, "lockSize", false)
	assert(not K.Safe.IsHidden(grip), "unlocking gives the grip back")
	write(env, K, "lockSize", true)
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(not K.Safe.IsHidden(grip), "turning the chat off gives the grip back")
	clean(env, K)
end

-- Idle fade: the whole card fades after the delay, wakes on hover, typing, player chat and the chosen lines, and off restores it.
do
	local env, K, ns = boot()
	local chat, glass, holder = env.ChatFrame1, ns.Panel.Glass(), ns.Panel.Holder()
	local alpha = chat:GetAlpha()
	assert(glass:GetAlpha() == 1, "the card is solid")
	write(env, K, "idleFade", true)
	assert(near(chat:GetAlpha(), alpha * 0.6) and near(glass:GetAlpha(), 0.6), "the quiet card fades to 60%: " .. chat:GetAlpha())
	assert(near(env.GENERAL_CHAT_DOCK:GetAlpha(), alpha * 0.6), "the tabs fade with it")
	env.FireEvent("CHAT_MSG_GUILD", "hi", "Thargor")
	assert(near(chat:GetAlpha(), alpha) and glass:GetAlpha() == 1, "a guild line wakes it")
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha * 0.6), "and it fades again after the delay")
	env.FireEvent("CHAT_MSG_LOOT", "You receive loot")
	assert(near(chat:GetAlpha(), alpha * 0.6), "a loot line does not wake it by default")
	write(env, K, "idleWake.loot", true)
	env.FireEvent("CHAT_MSG_LOOT", "You receive loot")
	assert(near(chat:GetAlpha(), alpha), "the chosen loot lines wake it")
	env.RunTimers()
	holder:GetScript("OnEnter")(holder)
	assert(near(chat:GetAlpha(), alpha), "the pointer wakes it")
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha), "and keeps it awake while it stays")
	holder:GetScript("OnLeave")(holder)
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha * 0.6), "leaving lets it fade")
	local box = chat.editBox
	box:GetScript("OnEditFocusGained")(box)
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha), "typing keeps it awake")
	box:GetScript("OnEditFocusLost")(box)
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha * 0.6), "and it fades after typing ends")
	write(env, K, "framing", "bare")
	assert(near(chat:GetAlpha(), alpha * 0.6), "the bare chat fades too, without depending on the card")
	write(env, K, "idleStrength", 1)
	assert(chat:GetAlpha() == 0 and glass:GetAlpha() == 0, "full strength hides it until it wakes")
	write(env, K, "framing", "auto")
	write(env, K, "idleFade", false)
	assert(near(chat:GetAlpha(), alpha) and glass:GetAlpha() == 1, "turning it off restores the card")
	env.FireEvent("CHAT_MSG_SAY", "hi", "Thargor")
	env.RunTimers()
	assert(near(chat:GetAlpha(), alpha) and glass:GetAlpha() == 1, "and nothing fades it again")
	write(env, K, "idleFade", true)
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(chat:GetAlpha() == 1, "turning the chat off gives the window full alpha")
	clean(env, K)
end

-- Names inside messages: group members' names take their class colour, outside links and colour codes, and follow the roster.
do
	local env, K = boot()
	local members = { player = { "Tester", "WARRIOR" }, party1 = { "Lunara", "MAGE" } }
	env.UnitName = function(unit) return members[unit] and members[unit][1] end
	env.UnitClass = function(unit) return members[unit] and members[unit][2], members[unit] and members[unit][2] end
	env.GetNumGroupMembers = function() local n = 0 for _ in pairs(members) do n = n + 1 end return n end
	env.IsInRaid = function() return false end
	local chat = env.ChatFrame1
	local hex = env._addons.KstyleUI_Chat.Format.Hex(K.Theme.Brighten(K.Theme.ClassColor("MAGE")))
	C.Say(env, chat, "CHAT_MSG_PARTY", "Lunara pull now")
	assert(C.Last(chat):find(": Lunara pull", 1, true), "off by default")
	write(env, K, "classMentions", true)
	C.Say(env, chat, "CHAT_MSG_PARTY", "Lunara pull now")
	assert(C.Last(chat):find("|c" .. hex .. "Lunara|r pull", 1, true), "a member's name is class-coloured: " .. C.Last(chat))
	C.Say(env, chat, "CHAT_MSG_PARTY", "|Hitem:1|h[Lunara Ring]|h and |cffff0000Lunara|r")
	assert(not C.Last(chat):find("|c" .. hex, 1, true), "names inside links and coloured text are left alone")
	C.Say(env, chat, "CHAT_MSG_GUILD", "Lunara pull now")
	assert(not C.Last(chat):find("|c" .. hex, 1, true), "guild chat is not a group message")
	members.party2 = { "Valerin", "PRIEST" }
	env.FireEvent("GROUP_ROSTER_UPDATE")
	C.Say(env, chat, "CHAT_MSG_SAY", "Valerin here")
	assert(C.Last(chat):find("|c" .. env._addons.KstyleUI_Chat.Format.Hex(K.Theme.Brighten(K.Theme.ClassColor("PRIEST"))) .. "Valerin|r", 1, true), "a member who joins is coloured after the roster changes")
	members.party1 = nil
	env.FireEvent("GROUP_ROSTER_UPDATE")
	C.Say(env, chat, "CHAT_MSG_SAY", "Lunara left")
	assert(not C.Last(chat):find("|c" .. hex, 1, true), "a member who left is plain again")
	assert(C.Say(env, chat, "CHAT_MSG_SAY", env.Secret("Valerin secret")), "a secret line passes untouched")
	write(env, K, "classMentions", false)
	C.Say(env, chat, "CHAT_MSG_SAY", "Valerin here")
	assert(C.Last(chat):find(": Valerin here", 1, true), "off restores plain names")
	clean(env, K)
end

-- Link tooltips: off by default; on shows the game's tooltip for item, spell and quest links, never for a secret link.
do
	local env, K = boot()
	local calls = {}
	env.GameTooltip = {
		SetOwner = function(_, owner) calls[#calls + 1] = "owner" end,
		SetHyperlink = function(_, link) calls[#calls + 1] = link end,
		Show = function() calls[#calls + 1] = "show" end,
		Hide = function() calls[#calls + 1] = "hide" end,
		IsOwned = function(_, frame) return frame == env.ChatFrame1 end,
	}
	local registry, chat = env.EventRegistry, env.ChatFrame1
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, "item:4232")
	assert(#calls == 0, "no tooltip by default")
	write(env, K, "linkTooltips", true)
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, "item:4232")
	assert(calls[2] == "item:4232" and calls[3] == "show", "an item link shows its tooltip")
	registry:TriggerEvent("ChatFrame.OnHyperlinkLeave", chat)
	assert(calls[4] == "hide", "leaving hides it")
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, "player:Thargor")
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, env.Secret("item:1"))
	registry:TriggerEvent("ChatFrame.OnHyperlinkLeave", chat)
	assert(#calls == 4, "player and secret links show nothing")
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, "spell:133")
	write(env, K, "linkTooltips", false)
	assert(calls[#calls] == "hide", "turning it off hides an open tooltip")
	local n = #calls
	registry:TriggerEvent("ChatFrame.OnHyperlinkEnter", chat, "item:4232")
	assert(#calls == n, "and shows no more")
	clean(env, K)
end

-- Chat buttons: on the right, a wider room, only on hover and button by button, each restored.
do
	local env, K, ns = boot({ enabled = true, buttons = true })
	local chat, column = env.ChatFrame1, env.ChatFrame1.buttonFrame
	local g = ns.Panel.Geometry(chat)
	assert(select(1, column:GetPoint(1)) == "TOPLEFT", "the buttons sit on the left by default")
	write(env, K, "sideRight", true)
	local r = ns.Panel.Geometry(chat)
	assert(select(1, column:GetPoint(1)) == "TOPRIGHT", "on the right")
	assert(near(r.left + r.right, g.left + g.right + 8 * r.k) and r.left < g.left, "the room moves to the right and leaves the scroll bar clear")
	write(env, K, "sideWidth", 50)
	assert(ns.Panel.Geometry(chat).right > r.right + 14 * r.k, "a wider room")
	write(env, K, "sideRight", false)
	write(env, K, "sideWidth", 35)
	assert(near(ns.Panel.Geometry(chat).left, g.left) and select(1, column:GetPoint(1)) == "TOPLEFT", "the default room comes back")
	local friends = env.QuickJoinToastButton
	write(env, K, "sideHover", true)
	assert(column:GetAlpha() == 0 and friends:GetAlpha() == 0, "the buttons wait out of sight")
	local holder = ns.Panel.Holder()
	holder:GetScript("OnEnter")(holder)
	assert(column:GetAlpha() == 1 and friends:GetAlpha() == 1, "the pointer on the chat brings them")
	holder:GetScript("OnLeave")(holder)
	W.Enter(env.ChatFrameMenuButton)
	env.RunTimers()
	assert(column:GetAlpha() == 1, "moving onto a button keeps them")
	W.Leave(env.ChatFrameMenuButton)
	env.RunTimers()
	assert(column:GetAlpha() == 0, "and they go when it leaves")
	write(env, K, "sideHover", false)
	assert(column:GetAlpha() == 1 and friends:GetAlpha() == 1, "always shown again")
	write(env, K, "sideIcons.menu", false)
	write(env, K, "sideIcons.friends", false)
	assert(K.Safe.IsHidden(env.ChatFrameMenuButton) and K.Safe.IsHidden(friends), "chosen buttons hide")
	assert(not K.Safe.IsHidden(env.ChatFrameChannelButton) and not K.Safe.IsHidden(column), "the others stay")
	write(env, K, "sideIcons.voice", false)
	assert(K.Safe.IsHidden(env.ChatFrameToggleVoiceDeafenButton) and K.Safe.IsHidden(env.ChatFrameToggleVoiceMuteButton), "both voice buttons hide")
	write(env, K, "sideIcons.menu", true)
	write(env, K, "sideIcons.voice", true)
	assert(not K.Safe.IsHidden(env.ChatFrameMenuButton) and not K.Safe.IsHidden(env.ChatFrameToggleVoiceMuteButton), "and come back")
	write(env, K, "sideHover", true)
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(not K.Safe.IsHidden(friends) and friends:GetAlpha() == 1 and column:GetAlpha() == 1, "turning the chat off gives every button back")
	clean(env, K)
end

-- The settings window's preview follows the new options.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(320, 240)
	local preview = K.Options.Preview("Chat")(parent)
	local function ruleY()
		return select(5, preview.divider:GetPoint(1))
	end
	local y = ruleY()
	write(env, K, "tabHeight", 46)
	preview:Refresh()
	assert(ruleY() < y - 10, "the preview's rule moves with the tab row")
	write(env, K, "tabStyle", "filled")
	write(env, K, "tabOpacity", 0.5)
	write(env, K, "tabEdge", "panel")
	preview:Refresh()
	assert(preview.fill.chrome.ownFill and not preview.fill.chrome.ownEdge, "the preview tile takes the opacity and edge")
	write(env, K, "classMentions", true)
	preview:Refresh()
	assert(preview.lines[3]:GetText():find("Thargor|r", 1, true), "the preview colours a group member's name")
	write(env, K, "idleFade", true)
	preview:Refresh()
	assert(near(preview.glass:GetAlpha(), 0.6), "the preview shows the idle look")
	write(env, K, "idleFade", false)
	preview:Refresh()
	assert(preview.glass:GetAlpha() == 1, "and the solid one again")
	clean(env, K)
end

print("chat parity ok: tabs, tiles, edit box, lock, idle fade, names in messages, link tooltips and chat buttons apply and restore")
