-- test-databars-parity-2.lua: round 2 of the data bar's EllesmereUI parity keeps today's defaults, and each option applies when on, restores when off, follows its events and reaches the preview.
local D = dofile("Tools/regression/databars_env.lua")
local Fixture = dofile("Tools/regression/databars_readouts_fixture.lua")
local Scene = dofile("Tools/render/scene.lua")

local function eq(a, b, why) assert(a == b, (why or "value") .. ": " .. tostring(a) .. " differs from " .. tostring(b)) end
local function near(a, b, why) assert(math.abs(a - b) < 0.01, (why or "value") .. ": " .. tostring(a) .. " differs from " .. tostring(b)) end

local OLD = { "gold", "latency", "fps", "durability", "time", "spec", "guild", "friends", "bags", "currencies", "xp", "location", "itemLevel" }
local old = {}
for i, id in ipairs(OLD) do old[i] = { id = id, shown = i <= 10, zone = id == "time" and "centre" or "right" } end

local x, game = {}, nil
local env, K, ns = D.New({
	saved = { version = 42, profiles = { Default = { DataBars = { enabled = true, strip = { modules = old }, micro = { rows = 1 } } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
	setup = function(e)
		D.Menus(e)
		game = Fixture(e)
		x = { reads = 0, cool = "ready", quests = { { questID = 11, isHeader = false, ready = true, xp = 4000 }, { questID = 12, isHeader = false, ready = false, xp = 900 } },
			bags = { [0] = { { 6265, 12, 15, 1, "Soul Shard" }, { 2589, 20, 7, 0, "Linen Cloth" } }, [1] = { { 17020, 5, 5, 0, "Arcane Powder" }, { 180653, 1, 5, 1, "Keystone" } } },
			members = { { isSelf = true, name = "Me", presence = 1 }, { name = "Zed", presence = 1, zone = "Orgrimmar", memberNote = "raid lead" }, { name = "Amy", presence = 4, zone = "Durotar" },
				{ name = "Off", presence = 3 }, { name = "Phone", presence = 2 }, { name = "Bea", presence = 5, zone = "Barrens", memberNote = "" } },
			friends = { { connected = true, name = "Kim", area = "Ashenvale", notes = "tank" }, { connected = false, name = "Gone" } },
			bnet = { { accountName = "Lou", note = "healer", gameAccountInfo = { isOnline = true, characterName = "Lulu" } } } }
		e.C_Container = { CalculateTotalNumberOfFreeBagSlots = function() return 15 end,
			GetContainerNumSlots = function(bag) return x.bags[bag] and #x.bags[bag] or 0 end,
			GetContainerItemInfo = function(bag, slot)
				x.reads = x.reads + 1
				local item = x.bags[bag] and x.bags[bag][slot]
				if item == "secret" then return e.Secret({}) end
				return item and { itemID = item[1], stackCount = item[2], itemName = item[5], iconFileID = 1000 + item[1] % 100 }
			end }
		local items = { [6265] = { 15, 1 }, [2589] = { 7, 0 }, [17020] = { 5, 0 }, [180653] = { 5, 1 } }
		e.C_Item.GetItemInfoInstant = function(id) local c = items[id] or {}; return id, "", "", "", 0, c[1], c[2] end
		e.C_Item.GetItemNameByID = function(id) return id == 2512 and "Rough Arrow" or nil end
		e.C_PaperDollInfo = { GetInventorySlotInfo = function(name) return name == "AmmoSlot" and 0 or nil end }
		e.UnitUsesAmmo = function() return x.ammo ~= nil end
		e.GetInventoryItemID = function(_, slot) return slot == 0 and x.ammo or nil end
		e.GetInventoryItemTexture = function(_, slot) return slot == 0 and x.ammo and 132382 or nil end
		e.GetInventoryItemCount = function(_, slot) return slot == 0 and x.ammoCount or 0 end
		e.C_QuestLog = { GetNumQuestLogEntries = function() return #x.quests, #x.quests end, GetInfo = function(i) return x.quests[i] end,
			ReadyForTurnIn = function(id) for _, q in ipairs(x.quests) do if q.questID == id then return q.ready end end end }
		e.GetQuestLogRewardXP = function(id) for _, q in ipairs(x.quests) do if q.questID == id then return q.xp end end end
		e.C_Club = { GetGuildClubId = function() return x.club end, GetClubMembers = function() return x.secretMembers and e.Secret({}) or { 1, 2, 3, 4, 5, 6 } end,
			GetMemberInfo = function(_, id) return x.members[id] end }
		e.C_FriendList.GetNumFriends = function() return #x.friends end
		e.C_FriendList.GetFriendInfoByIndex = function(i) return x.friends[i] end
		e.BNGetNumFriends = function() return #x.bnet, 1 end
		e.C_BattleNet = { GetFriendAccountInfo = function(i) return x.bnet[i] end }
		e.C_Spell = { GetSpellInfo = function(id) return ({ [556] = { name = "Astral Recall" }, [3561] = { name = "Teleport: Stormwind" } })[id] end }
	end,
})
x.club = 1
K.Safe.Side(K).travelData = {
	Hearth = function() return "Stormwind", x.cool end,
	Read = function() return { { { kind = "item", id = 6948, name = "Hearthstone" }, { kind = "spell", id = 556, name = "Astral Recall" } }, { { kind = "spell", id = 3561, name = "Teleport: Stormwind" } }, {} } end,
}

local function write(key, value) assert(K.Options.Write("DataBars", key, value) ~= false, key); env.RunTimers() end
local function item(id) return ns.Strip.view.items[id] end
local function text(id) return item(id).value:GetText() end
local function disabled(key) local row = K.Options.Row("DataBars", key); return row.disableWhen ~= nil and row.disableWhen(K.Store.Module("DataBars")) == true end
local function rgb(r, g, b) return string.format("%.3f %.3f %.3f", r, g, b) end
local function color(region) return rgb(region:GetTextColor()) end
local function tint(texture) return rgb(texture:GetVertexColor()) end
local function rect(region) return Scene.Rect(env, region) end
local function show(ids, key)
	local s, want = K.Store.Module("DataBars").strip, {}
	key = key or "modules"
	for i, id in ipairs(ids) do want[id] = i end
	table.sort(s[key], function(a, b) return (want[a.id] or 99) < (want[b.id] or 99) end)
	for _, entry in ipairs(s[key]) do entry.shown = want[entry.id] ~= nil end
	write("strip." .. key, s[key])
end
local function tooltip(id)
	ns.Strip.ShowTooltip(item(id))
	local lines = {}
	for _, row in ipairs(K.Widgets.Tooltip().used) do
		if row.left:IsShown() then lines[#lines + 1] = (row.left:GetText() or "") .. "=" .. (row.right:IsShown() and row.right:GetText() or "") end
	end
	ns.Strip.HideTooltip(item(id))
	return table.concat(lines, "|"):gsub("\226\128\137", "")
end

-- Defaults keep today's look: every new option is off or today's value, and a v0.2.8 profile gains Class resources switched off.
local s = K.Store.Module("DataBars").strip
for key, value in pairs({ icons = "off", iconColor = "label", fill = "none", currencyIcons = false, reagentsShown = "all", reagentsLabel = false, socialList = 0,
	guildNotes = false, friendNotes = false, hearthText = "both", hearthLeft = "", hearthRight = "", hearthMiddle = "" }) do
	eq(s[key], value, key)
end
eq(K.Store.Module("DataBars").micro.align, "LEFT", "micro align")
eq(K.Store.Module("DataBars").bags.align, "LEFT", "bag align")
eq(K.Store.Module("DataBars").xp.questXP, false, "quest experience")
eq(s.modules[1].id, "gold", "the saved order survives")
for _, entry in ipairs(s.modules) do if entry.id == "reagents" then eq(entry.shown, false, "Class resources joins switched off") end end
assert(K.Options.Get("DataBars"), "the schema builds with every new row")

-- Icons: on one line each readout's own glyph sits before its value, tinted like its label; icons only hides the value; off restores the widths.
show({ "fps", "latency", "gold", "coords", "spacer", "time" })
local widths = {}
for _, id in ipairs({ "fps", "latency", "gold", "coords" }) do widths[id] = item(id).button:GetWidth() end
write("strip.icons", "beside")
for _, id in ipairs({ "fps", "latency", "gold", "coords" }) do
	local icon = item(id).icon
	assert(icon and icon:IsShown(), id .. " shows its glyph")
	assert(item(id).button:GetWidth() > widths[id], id .. " widens for its glyph")
	local point, to, at, gap = icon:GetPoint()
	local run = select(4, item(id).value:GetPoint())
	assert(point == "RIGHT" and to == item(id).value and at == "LEFT" and gap < 0, id .. ": the glyph sits before the value")
	near(run, icon:GetWidth() - gap, id .. ": the glyph starts at the readout's left edge")
end
assert(not (item("spacer").icon and item("spacer").icon:IsShown()), "the spacer draws no glyph")
local order = ns.Strip.view.order
for i = 1, #order do
	for j = i + 1, #order do
		local ax, _, aw = rect(item(order[i]).button)
		local bx, _, bw = rect(item(order[j]).button)
		assert(ax + aw <= bx + 0.01 or bx + bw <= ax + 0.01, order[i] .. " overlaps " .. order[j])
	end
end
eq(tint(item("fps").icon), color(item("fps").label), "glyphs follow the label colour")
item("fps").button.hoverT = 1
item("fps").button.Paint()
eq(tint(item("fps").icon), color(item("fps").label), "a hovered glyph brightens with its label")
item("fps").button.hoverT = 0
item("fps").button.Paint()
write("strip.iconColor", "accent")
eq(tint(item("latency").icon), rgb(ns.Accent()), "accent glyphs")
write("strip.iconColor", "custom")
write("strip.iconCustom", { r = 1, g = 0, b = 0, a = 1 })
eq(tint(item("latency").icon), "1.000 0.000 0.000", "custom glyphs")
write("strip.iconColor", "label")
eq(tint(item("latency").icon), color(item("latency").label), "label colour restores")
write("strip.icons", "only")
for _, id in ipairs({ "fps", "latency", "gold", "coords" }) do
	assert(item(id).icon:IsShown() and not item(id).value:IsShown() and not item(id).label:IsShown(), id .. " shows its glyph alone")
	near(item(id).button:GetWidth(), item(id).icon:GetWidth(), id .. " narrows to its glyph")
end
assert(tooltip("fps"):find("Frame rate=144 fps", 1, true), "the tooltip still gives the value")
write("strip.icons", "off")
for _, id in ipairs({ "fps", "latency", "gold", "coords" }) do
	assert(not item(id).icon:IsShown() and item(id).value:IsShown(), id .. " hides its glyph and shows its value again")
	eq(item(id).button:GetWidth(), widths[id], id .. " width restores")
end
assert(not disabled("strip.icons") and disabled("strip.iconColor"), "icon colour waits for icons, visibly")

-- Fill the rest: in cells one readout takes the room the others leave; off restores the even split.
write("strip.placement", "rail")
write("strip.line", false)
show({ "fps", "latency", "gold" }, "railModules")
assert(disabled("strip.icons") and not disabled("strip.fill"), "icons are a one-line option; fill is a cells option")
write("strip.icons", "only")
assert(item("fps").value:IsShown(), "cells keep their values even with icons only")
write("strip.icons", "off")
local lefts = {}
for _, id in ipairs({ "fps", "latency", "gold" }) do lefts[id] = select(4, item(id).button:GetPoint()) end
write("strip.fill", "latency")
local em = 4 * s.fontSize
near(item("fps").button:GetWidth(), K.Widgets.Snap(item("fps").button, 0.8 * em), "the others keep their natural width")
assert(item("latency").button:GetWidth() > item("gold").button:GetWidth(), "the filling readout takes the rest")
write("strip.fill", "none")
for _, id in ipairs({ "fps", "latency", "gold" }) do eq(select(4, item(id).button:GetPoint()), lefts[id], id .. " left restores") end
write("strip.line", true)
write("strip.placement", "top")
assert(disabled("strip.fill"), "fill is off on one line")

-- Currency icons replace each name after its amount; off restores the names.
show({ "currencies", "fps" })
eq(#game.currencies, 2, "the fixture tracks two currencies")
game.currencies[1].iconFileID = 463446
eq(text("currencies"), "1250 Honor \194\183 350 Justice")
write("strip.currencyIcons", true)
eq(text("currencies"), "1250 |T463446:0|t \194\183 350 Justice", "an icon replaces the name; a currency with no icon keeps its name")
write("strip.currencyIcons", false)
eq(text("currencies"), "1250 Honor \194\183 350 Justice", "off restores the names")

-- Class resources: class reagents by item class and equipped ammunition, read on bag and equipment events only.
show({ "reagents", "fps" })
eq(text("reagents"), "|T1065:0|t 12 \194\183 |T1020:0|t 5", "Soul Shard and Arcane Powder; cloth and a keystone are not class reagents")
x.ammo, x.ammoCount = 2512, 200
env.FireEvent("PLAYER_EQUIPMENT_CHANGED", 0)
eq(text("reagents"), "|T132382:0|t 200 \194\183 |T1065:0|t 12 \194\183 |T1020:0|t 5", "ammunition leads")
local reads = x.reads
ns.Strip.Tick()
ns.Strip.Refresh()
eq(x.reads, reads, "the bags are read on their events, not on the ticker or a repaint")
x.bags[0][1][2] = 11
env.FireEvent("BAG_UPDATE_DELAYED")
assert(text("reagents"):find(" 11 ", 1, true), "a bag update refreshes the count")
write("strip.reagentsShown", "reagents")
eq(text("reagents"), "|T1065:0|t 11 \194\183 |T1020:0|t 5")
write("strip.reagentsShown", "ammo")
eq(text("reagents"), "|T132382:0|t 200")
write("strip.reagentsLabel", true)
eq(text("reagents"), "|T132382:0|t 200 Rough Arrow", "names follow the counts")
write("strip.reagentsShown", "all")
write("strip.reagentsLabel", false)
assert(tooltip("reagents"):find("Soul Shard=11", 1, true), "the tooltip lists each item")
x.bags[0][1] = "secret"
env.FireEvent("BAG_UPDATE_DELAYED")
eq(text("reagents"), "|T132382:0|t 200 \194\183 |T1020:0|t 5", "a secret slot is skipped")
local container = env.C_Container
env.C_Container, x.ammo = nil, nil
env.FireEvent("BAG_UPDATE_DELAYED")
eq(text("reagents"), "--", "no bag API and no ammunition reads as --")
assert(tooltip("reagents"):find("You carry no class reagents or ammunition.", 1, true))
env.C_Container = container
x.bags[0][1] = { 6265, 12, 15, 1, "Soul Shard" }

-- Guild and friends: counts alone by default; names, capped and sorted, then notes when asked.
show({ "guild", "friends", "fps" })
eq(tooltip("guild"), "GUILD=|Online=17", "the default keeps the count alone")
assert(disabled("strip.guildNotes") and disabled("strip.friendNotes"), "notes need names, and say so")
write("strip.guildNotes", true)
eq(tooltip("guild"), "GUILD=|Online=17", "notes alone add nothing")
write("strip.socialList", 2)
assert(not disabled("strip.guildNotes"))
eq(tooltip("guild"), "GUILD=|Online=17|Amy=Durotar|Bea=Barrens|and 1 more=", "online members, sorted and capped, not you, offline or mobile")
write("strip.socialList", 5)
eq(tooltip("guild"), "GUILD=|Online=17|Amy=Durotar|Bea=Barrens|Zed=Orgrimmar|raid lead=", "a member's note under the name")
write("strip.guildNotes", false)
eq(tooltip("guild"), "GUILD=|Online=17|Amy=Durotar|Bea=Barrens|Zed=Orgrimmar", "notes off")
x.secretMembers = true
eq(tooltip("guild"), "GUILD=|Online=17", "a secret roster lists no one")
x.secretMembers = nil
eq(tooltip("friends"), "FRIENDS=|World of Warcraft=4|Battle.net=1|Kim=Ashenvale|Lou=Lulu", "online friends from both lists")
write("strip.friendNotes", true)
eq(tooltip("friends"), "FRIENDS=|World of Warcraft=4|Battle.net=1|Kim=Ashenvale|tank=|Lou=Lulu|healer=", "friend notes")
write("strip.friendNotes", false)
write("strip.socialList", 0)
eq(tooltip("friends"), "FRIENDS=|World of Warcraft=4|Battle.net=1", "0 restores the counts alone")

-- Hearthstone text and travel clicks.
show({ "hearth", "fps" })
eq(text("hearth"), "ready Stormwind", "today's text")
for mode, want in pairs({ location = "Stormwind", cooldown = "ready", smart = "Stormwind" }) do
	write("strip.hearthText", mode)
	eq(text("hearth"), want, mode)
end
x.cool = "12 min"
ns.Strip.Tick()
eq(text("hearth"), "12 min", "smart shows the cooldown while it runs")
write("strip.hearthText", "both")
eq(text("hearth"), "12 min Stormwind")
x.cool = "ready"
local choices = ns.Readouts.TravelChoices("hearthRight")
eq(choices[1].label, "None")
eq(choices[2].value, "item:6948", "the Hearthstone is a choice for other clicks")
eq(choices[4].value, "spell:3561")
eq(ns.Readouts.TravelChoices("hearthLeft")[2].value, "spell:556", "the left click lists the Hearthstone as its default only")
local hearth = item("hearth")
ns.Click.Attach(hearth)
local proxy = ns.Click.proxy
eq(proxy:GetAttribute("type1"), "item")
eq(proxy:GetAttribute("item1"), "item:6948")
eq(proxy:GetAttribute("type2"), nil, "no right-click action by default")
write("strip.hearthLeft", "spell:3561")
write("strip.hearthRight", "spell:556")
write("strip.hearthMiddle", "item:6948")
ns.Click.Attach(hearth)
eq(proxy:GetAttribute("type1"), "spell")
eq(proxy:GetAttribute("spell1"), 3561)
eq(proxy:GetAttribute("type2"), "spell")
eq(proxy:GetAttribute("spell2"), 556)
eq(proxy:GetAttribute("type3"), "item")
eq(proxy:GetAttribute("item3"), "item:6948")
local tip = tooltip("hearth")
assert(tip:find("Click: Teleport: Stormwind.", 1, true) and tip:find("Right-click: Astral Recall.", 1, true) and tip:find("Middle-click: Hearthstone", 1, true) == nil, tip)
show({ "gold", "hearth" })
ns.Click.Attach(item("gold"))
eq(proxy:GetAttribute("type1"), "click")
eq(proxy:GetAttribute("type2"), nil, "another readout clears the travel clicks")
eq(proxy:GetAttribute("type3"), nil)
ns.Click.Detach()
env.SetCombat(true)
eq(ns.Click.Attach(item("hearth")), false, "travel clicks wait for combat to end")
env.SetCombat(false)
for _, key in ipairs({ "hearthLeft", "hearthRight", "hearthMiddle" }) do write("strip." .. key, "") end
ns.Click.Attach(item("hearth"))
eq(proxy:GetAttribute("type1"), "item")
eq(proxy:GetAttribute("type2"), nil, "off restores the Hearthstone alone")
ns.Click.Detach()

-- Micro menu and bag bar alignment moves a shorter last row only.
show({ "micro", "fps" })
write("strip.menus", false)
write("micro.shown", true)
write("micro.rows", 3)
local buttons = ns.Menus.Shown("micro")
local last, firstX = buttons[#buttons], select(4, buttons[1]:GetPoint())
local leftX = select(4, last:GetPoint())
write("micro.align", "RIGHT")
assert(select(4, last:GetPoint()) > leftX, "right moves the short row")
eq(select(4, buttons[1]:GetPoint()), firstX, "full rows stay put")
write("micro.align", "CENTER")
local centre = select(4, last:GetPoint())
assert(centre > leftX and centre < leftX + 2 * buttons[1]:GetWidth(), "centre sits between")
write("micro.align", "LEFT")
eq(select(4, last:GetPoint()), leftX, "left restores")
write("micro.rows", 1)
write("strip.menus", true)

-- Quest experience marks finished quests' experience past the fill and follows the quest log.
local bar = ns.Bars.views.xp
assert(not (bar.quest and bar.quest:IsShown()), "no quest mark by default")
local events = 0
local register = K.Events.Register
K.Events.Register = function(owner, ...) if owner == "DataBars.QuestXP" then events = events + 1 end return register(owner, ...) end
write("xp.questXP", true)
assert(bar.quest:IsShown(), "on, the mark shows")
local w = bar.fill:GetWidth()
near(bar.quest:GetWidth(), K.Widgets.Snap(bar.quest, w * 4000 / 50000), "the mark's width is the finished quests' experience")
eq(select(2, bar.quest:GetPoint()), bar.fill:GetStatusBarTexture(), "it starts where the fill ends")
local sets, setWidth = 0, bar.quest.SetWidth
bar.quest.SetWidth = function(...) sets = sets + 1; return setWidth(...) end
env.FireEvent("PLAYER_XP_UPDATE")
eq(sets, 0, "an unchanged mark is not placed again")
bar.quest.SetWidth = setWidth
D.W.Enter(bar.holder)
local lines = {}
for _, row in ipairs(K.Widgets.Tooltip().used) do if row.left:IsShown() then lines[#lines + 1] = (row.left:GetText() or "") .. "=" .. (row.right:IsShown() and row.right:GetText() or "") end end
D.W.Leave(bar.holder)
assert(table.concat(lines, "|"):gsub("\226\128\137", ""):find("Completed quests=4,000", 1, true), "the tooltip gives the quest experience")
x.quests[2].ready = true
env.FireEvent("QUEST_LOG_UPDATE")
near(bar.quest:GetWidth(), K.Widgets.Snap(bar.quest, w * 4900 / 50000), "a finished quest grows the mark")
eq(events, 1, "one quest-log owner while on")
write("xp.questColor", { r = 0, g = 1, b = 0, a = 0.5 })
eq(tint(bar.quest), "0.000 1.000 0.000", "quest colour")
x.quests[1].isHeader = env.Secret(false)
env.FireEvent("QUEST_LOG_UPDATE")
near(bar.quest:GetWidth(), K.Widgets.Snap(bar.quest, w * 900 / 50000), "a secret entry is skipped")
x.quests[1].isHeader = false
write("xp.questXP", false)
assert(not bar.quest:IsShown(), "off hides the mark")
x.quests[2].ready = false
env.FireEvent("QUEST_LOG_UPDATE")
assert(not bar.quest:IsShown(), "and stops following the quest log")
K.Events.Register = register

-- The Medallions dock gives round 1's readouts and Class resources their own glyphs, and keeps them with icons off.
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
show({ "coords", "combat", "played", "audio", "prof1", "broker", "reagents", "fps" }, "dockModules")
write("strip.brokerPlugin", "")
local cells, glyphs = {}, 0
assert(ns.Strip.view.deco, "the Medallions dock draws glyph segments")
for _, id in ipairs({ "coords", "combat", "played", "audio", "reagents", "fps" }) do
	if item(id).button:IsShown() then
		local l, r, t, b = item(id).icon:GetTexCoord()
		assert(item(id).icon:IsShown() and r - l == 0.25 and b - t == 0.125 and not cells[l .. t], id .. " shows its own glyph cell")
		cells[l .. t], glyphs = true, glyphs + 1
	end
end
assert(glyphs >= 4, "the dock shows the new glyphs: " .. glyphs)
assert(disabled("strip.icons") and disabled("strip.iconColor"), "the dock always draws its own glyphs")
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()

-- The preview reflects each new option.
show({ "fps", "currencies", "hearth", "reagents" })
write("strip.icons", "beside")
write("strip.currencyIcons", true)
write("strip.hearthText", "location")
write("xp.questXP", true)
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(400, 600)
local preview = K.Options.Preview("DataBars")(parent)
local items = preview.strip.items
assert(items.fps.icon and items.fps.icon:IsShown(), "preview icons")
assert(items.currencies.value:GetText():find("|T", 1, true), "preview currency icons")
eq(items.hearth.value:GetText(), "Stormwind", "preview Hearthstone text")
eq(items.reagents.value:GetText(), "200 \194\183 12", "preview class resources")
assert(preview.bars.xp.quest and preview.bars.xp.quest:IsShown(), "preview quest mark")
write("strip.reagentsLabel", true)
preview:Refresh()
eq(items.reagents.value:GetText(), "200 Ammunition \194\183 12 Reagents", "preview names")
write("strip.icons", "off")
preview:Refresh()
assert(not items.fps.icon:IsShown(), "preview icons off")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databars parity 2 ok: icons, fill, currency icons, class resources, social names, travel clicks, menu align and quest experience keep defaults, apply, restore and follow events")
