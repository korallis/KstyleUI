-- test-hud-material-dps.lua: the raw DPS reference HUD draws every card in the selected material, and the audit fails when a card opts out.
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local scene = Lib.Build("DPS", "ForgedBrackets")
local cards = Lib.Audit(scene, "ForgedBrackets", Lib.ROLES.DPS)
assert(#cards == 5, "DPS draws its guide, quest, chat, loot and damage cards, got " .. #cards)

local function fails(mutate, reason, role)
	local card
	for _, c in ipairs(cards) do
		card = card or (c.role == role and c)
	end
	local restore = mutate(card.chrome)
	local ok, message = pcall(Lib.Audit, scene, "ForgedBrackets", Lib.ROLES.DPS)
	restore()
	assert(not ok and tostring(message):find(reason, 1, true), "a card with " .. reason .. " passes the guard: " .. tostring(message))
	assert(Lib.Audit(scene, "ForgedBrackets", Lib.ROLES.DPS), "restoring the card restores the pass")
end

for _, role in ipairs({ "story", "skins.quests", "meters.damage", "chat.main", "qol.lootfeed" }) do
	fails(function(chrome)
		local old = chrome.radius
		chrome.radius = 10.5
		return function()
			chrome.radius = old
		end
	end, "radius = 10.5", role)
	fails(function(chrome)
		local old = chrome.materialOn
		chrome.materialOn = false
		return function()
			chrome.materialOn = old
		end
	end, "grain = false", role)
	fails(function(chrome)
		local fill, color = chrome.ownFill, { unpack(chrome.fillColor) }
		chrome.ownFill, chrome.fillColor = true, { 0.3, 0.1, 0.1, 0.75 }
		return function()
			chrome.ownFill, chrome.fillColor = fill, color
		end
	end, "its own fill colour", role)
end

local chrome = cards[1].chrome
local ok, message = pcall(function()
	Lib.OPT_OUTS[cards[1].role] = "too short"
	return Lib.Audit(scene, "ForgedBrackets", Lib.ROLES.DPS)
end)
Lib.OPT_OUTS[cards[1].role] = nil
assert(not ok and tostring(message):find("needs its consumer's reason", 1, true), "an opt-out without a reason fails: " .. tostring(message))
ok, message = pcall(function()
	Lib.OPT_OUTS[cards[1].role] = string.rep("a card the consumer draws on purpose. ", 2)
	return Lib.Audit(scene, "ForgedBrackets", Lib.ROLES.DPS)
end)
Lib.OPT_OUTS[cards[1].role] = nil
assert(not ok and tostring(message):find("lists an opt-out but takes the material", 1, true), "an opt-out for a card that takes the material fails: " .. tostring(message))
assert(next(Lib.OPT_OUTS) == nil, "no drawn reference card opts out")
assert(chrome:Material(), "the audit leaves the chrome as it found it")

local glass = Lib.Build("DPS", "Glass")
Lib.Audit(glass, "Glass", Lib.ROLES.DPS)
local forged, plain = Lib.Records(scene), Lib.Records(glass)
assert(#forged == #plain, "paint changes no text, bar fill, swipe or element record: " .. #forged .. " against " .. #plain)
for i = 1, #forged do
	assert(forged[i] == plain[i], "paint changed a record:\n" .. forged[i] .. "\n" .. plain[i])
end
print("ok test-hud-material-dps")
