-- test-render-scenes-focused.lua: every focused render scene (components, tooltip, tracker, buttons, cooldowns,
-- nameplate, data bars, chat, the design-file unit frames, RestedXP) returns its builder and builds what it shows.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local check = L.check
local Components = dofile("Tools/render/scenes/components.lua")
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")
local RestedXP = dofile("Tools/render/scenes/restedxp.lua")

-- The scene scripts themselves return their builders when loaded as libraries.
for _, script in ipairs({ "hud_dps_mac", "hud_dps_threat", "components_mac", "tooltip_design", "smoke", "buttons_mac", "buttons_toned", "nameplate", "databars", "tracker", "chat", "unitframes_design", "auras_tracker" }) do
	local build = dofile("Tools/render/scenes/" .. script .. ".lua")
	assert(type(build) == "function", script .. ".lua returns its builder")
end

do
	local scene = check("hud_dps_threat", dofile("Tools/render/scenes/hud_dps_threat.lua")())
	local shown = {}
	for _, item in ipairs(scene.items) do
		if item.kind == "text" then shown[item.text] = true end
	end
	assert(shown.THREAT and shown.DAMAGE, "the DPS scene draws both meter cards")
	assert(shown["86%"] and shown["72%"] and shown["58%"], "all three compact threat rows draw")
end

-- Lumen Rails: the aura rows stand beside the minimap's left edge, and Layout > Apply's Edit Mode layout puts the
-- objective tracker in the left rail's story slot, so at the full two rows of eight buffs and three debuffs every
-- tile sits left of the map and clear of the tracker, on the far side of the screen.
do
	local Hud = L.Hud
	local Lumen = dofile("Tools/render/scenes/_lumen.lua")
	local _, slot = Lumen.Preset("DPS")
	local scene = check("auras_tracker", Hud.Build({ layout = "DPS", modules = { "minimap", "auras", "tracker" }, buffs = 16, debuffs = 3 }))
	local tiles, quests, zone = {}, nil, nil
	for _, item in ipairs(scene.items) do
		local text = item.kind == "text" and item.text and (item.text:gsub("\226\128\137", ""))
		if text == "QUESTS" then
			quests = item.rect
		end
		if text == "RIVERGLADES" then
			zone = item.rect
		end
		if item.kind == "texture" and item.fileID and item.rect[3] < 40 then
			tiles[#tiles + 1] = item.rect
		end
	end
	assert(quests and zone, "the scene shows the tracker's caption and the minimap's zone")
	assert(#tiles == 19, "sixteen buff tiles and three debuff tiles draw, got " .. #tiles)
	assert(quests[1] >= slot.left and quests[1] + quests[3] <= slot.left + slot.width and quests[2] >= slot.top, "the tracker's caption sits in the story slot")
	for _, rect in ipairs(tiles) do
		assert(rect[1] + rect[3] <= zone[1], "every aura tile sits left of the map's zone line")
		assert(rect[2] + rect[4] <= slot.top + 0.5, "every aura tile stays above the story slot, which hangs under the rows, got " .. (rect[2] + rect[4]) .. " for " .. slot.top)
	end
end

-- The tracker scene builds Blizzard's tracker the way Forever does and shows the skin's one caption header,
-- its numbered discs and the quest titles, with no Blizzard header text left visible.
do
	local tracker = check("tracker", dofile("Tools/render/scenes/tracker.lua")())
	local shown = {}
	for _, item in ipairs(tracker.items) do
		if item.kind == "text" then
			shown[(item.text:gsub("\226\128\137", ""))] = true
		end
	end
	for _, want in ipairs({ "QUESTS", "1", "2", "Riverglade Crocolisks", "The Lost Patrol", "RIVERGLADES" }) do
		assert(shown[want], "the tracker scene shows " .. want)
	end
	assert(not shown["All Objectives"] and not shown["Quests"], "Blizzard's two header shown are hushed")
end
check("components", Components.Build())
check("tooltip", Tooltip.Build())

-- The button scene: the six states twice, bag slots, aura tiles, and the micro menu and bag bar; a toned
-- rim changes only the secondary buttons' hairlines.
local Buttons = dofile("Tools/render/scenes/buttons.lua")
local full = check("buttons", Buttons.Build({ rim = 1 }))
local toned = check("buttons toned", Buttons.Build({ rim = 0.5 }))
assert(#full.items == #toned.items, "the toned scene draws the same drawables")
local fullTexts, buttonSwipes = {}, 0
for _, item in ipairs(full.items) do
	if item.kind == "text" then
		fullTexts[item.text] = true
	elseif item.kind == "swipe" then
		buttonSwipes = buttonSwipes + 1
	end
end
for _, want in ipairs({ "NORMAL", "HOVER", "PRESSED", "COOLDOWN", "PROC", "DISABLED", "3" }) do
	assert(fullTexts[want], "the button scene shows " .. want)
end
assert(buttonSwipes >= 2, "both cooldown buttons draw their swipe")
-- The cooldowns scene: the mirror's buff bars draw their countdowns right-aligned through the Cooldown's
-- own font string, and Blizzard's restyled viewer items draw with the dark button body.
local cooldowns = check("cooldowns", dofile("Tools/render/scenes/cooldowns.lua")())
local rightAligned, fills = {}, 0
for _, item in ipairs(cooldowns.items) do
	if item.kind == "text" and item.justifyH == "RIGHT" then
		rightAligned[item.text] = true
	elseif item.kind == "texture" and item.bar then
		fills = fills + 1
	end
end
assert(rightAligned["24s"] and rightAligned["12s"], "the buff bars' countdowns draw right-aligned, with their unit")
assert(fills >= 2, "the buff bars draw their fills")

-- The focused scenes. The nameplate scene puts the plate on a base the game scaled to 0.58, as the owner's Mac
-- does, and the plate still draws the KSTY-44 bible's 156.75 by 11.875 fill in root units: at the shipped
-- Interface size (16 / 19) that is 16 / 19 of it in screen units.
local plate = check("nameplate", dofile("Tools/render/scenes/nameplate.lua")())
local fill
for _, item in ipairs(plate.items) do
	if item.kind == "texture" and item.fraction and math.abs(item.fraction - 864 / 1540) < 0.001 then
		fill = item
	end
end
assert(fill, "the plate's health fill is drawn")
local SIZE = 16 / 19
assert(math.abs(fill.rect[3] - 156.75 * SIZE * 864 / 1540) < 1 and math.abs(fill.rect[4] - 11.875 * SIZE) < 1, "the bar is the bible's fill on a 0.58 base, got " .. fill.rect[3] .. " x " .. fill.rect[4])
local databars = check("databars", dofile("Tools/render/scenes/databars.lua")())
local seen = {}
for _, item in ipairs(databars.items) do
	if item.kind == "text" then
		seen[item.text] = true
	end
end
for _, want in ipairs({ "Level 38 \194\183 32%", "fps", "144", "34", "ms", "143g 82s 17c", "armour", "96%" }) do
	assert(seen[want], "the data bars scene shows " .. want)
end
assert(not seen["32%"], "the XP caption includes the level under LEE-20; this fixture has no rested XP")
assert(not seen["14:32"], "the readout leaves the clock to the minimap card, as the Lumen mockup does (round 4, Fable #5)")

-- The chat scene shows the mockup's four tabs on Blizzard's dock, the plus glyph and five lines.
local chat = check("chat", (dofile("Tools/render/scenes/chat.lua"))())
local chatTexts, plus, lines = {}, 0, 0
for _, item in ipairs(chat.items) do
	if item.kind == "text" then
		chatTexts[item.text] = true
		if item.text:find("[14:3", 1, true) then
			lines = lines + 1
		end
	elseif item.kind == "texture" and item.file and item.file:find("GlyphClose", 1, true) and item.rotation and math.abs(item.rotation - math.pi / 4) < 1e-3 then
		plus = plus + 1
	end
end
-- The dock ends before the panel's copy and plus glyphs. On the 372-unit card (owner pass 1, "the chat box is too
-- thin") Blizzard's tab sizing fits all four tabs; on the old 318 rail it folded the fourth into its overflow button.
for _, want in ipairs({ "GENERAL", "COMBAT", "LOOT", "TRADE" }) do
	assert(chatTexts[want], "the chat scene shows the " .. want .. " tab")
end
assert(plus == 0, "the plus glyph waits at rest, as the picture draws no buttons, got " .. plus)
-- At the shipped Interface size the card holds the scene's five lines. Timestamps are off by default (LEE-20), so
-- the lines are the messages themselves.
local bodies = 0
for _, phrase in ipairs({ "Crocolisk Hide", "168 experience", "Rugged Hide", "croc hunt", "Razorfen" }) do
	for text in pairs(chatTexts) do
		if text:find(phrase, 1, true) then
			bodies = bodies + 1
			break
		end
	end
end
assert(bodies == 5, "five lines, with no timestamps by default, got " .. bodies)

-- The unit frames with the design file's octagon portraits, at the design's sections.
local design = check("unitframes_design", dofile("Tools/render/scenes/unitframes_design.lua")())
local designTexts = {}
for _, item in ipairs(design.items) do
	if item.kind == "text" then
		designTexts[(item.text:gsub("\226\128\137", ""))] = true
	end
end
for _, want in ipairs({ "VALERIN", "FROST HOWLER", "78%", "56%", "FROST BITE", "42", "40" }) do
	assert(designTexts[want], "the design scene shows " .. want)
end

-- The RestedXP windows the fake builds, skinned, laid out as RestedXP lays them out in the game: the guide as
-- one card (the Lumen cap reading the guide's name with the current step as its trail, the steps as rows, the
-- route as a caption row, the list and the footer) and the v2 window on glass.
local rested = check("restedxp", RestedXP())
local restedTexts = {}
for _, item in ipairs(rested.items) do
	if item.kind == "text" then
		restedTexts[(item.text:gsub("\226\128\137", ""))] = true
	end
end
for _, want in ipairs({ "Step 34", "6-10 DUROTAR", "0/1 Raider's Bow", "Move toward the second floor of the keep" }) do
	assert(restedTexts[want], "the RestedXP scene shows " .. want)
end
-- One fact, one place (owner, 2026-11-09): the cap names the guide, so RestedXP's appended guide group and its
-- version footer are hushed.
for _, gone in ipairs({ "Speedrun Guide 1-22", "RestedXP Guides v4.11.35" }) do
	assert(not restedTexts[gone], "the RestedXP scene hushes " .. gone)
end
assert(not restedTexts["Step 35"], "the Step plates are hushed: the cap's trail carries the first shown step")
assert(not restedTexts["6-10 Durotar\nSpeedrun Guide 1-22"], "RestedXP's own two-line title is hushed, not drawn")
-- RestedXP's own layout is the fake's (its UpdateText), and the skin then reads the steps as the owner's picture
-- draws them: each line starts under the cap's title, and its check sits in the gem's column. The rest of
-- RestedXP's geometry is kept: the list's scroll bar 20 before the list's right edge.
do
	local Common = L.Common
	local Lib = dofile("Tools/render/scenes/_restedxp.lua")
	local R = Lib.Build()
	local f = R.rxp.RXPFrame
	local step = f.CurrentStepFrame.framePool[1]
	local cap = R.ns.RestedXP.Chrome.Path(f).cap
	-- TextLeft(text) -> where a text's first anchor puts its left edge, in screen units (a text has no rect of its
	-- own until the page measures it).
	local function TextLeft(text)
		local _, relative, relativePoint, x = text:GetPoint(1)
		local rx, _, rw = Common.Scene.Rect(R.env, relative)
		return rx and (relativePoint:find("RIGHT", 1, true) and rx + rw or rx) + x * rw / (relative:GetRight() - relative:GetLeft())
	end
	local tx = TextLeft(cap.title)
	local gx, _, gw = Common.Scene.Rect(R.env, cap.gem)
	for e, element in ipairs(step.elements) do
		local ex = TextLeft(element.text)
		local bx, _, bw = Common.Scene.Rect(R.env, element.button)
		assert(tx and ex and math.abs(ex - tx) < 0.01, "line " .. e .. " of the step starts under the cap's title, got " .. tostring(ex) .. " for " .. tostring(tx))
		assert(gx and bx and math.abs((bx + bw / 2) - (gx + gw / 2)) < 0.01, "its check sits in the gem's column, got " .. tostring(bx))
	end
	local lx, _, lw = Common.Scene.Rect(R.env, f.BottomFrame)
	local barX, _, barW = Common.Scene.Rect(R.env, f.ScrollFrame.ScrollBar)
	assert(math.abs((lx + lw) - (barX + barW) - 4) < 0.25, "the scroll bar ends 4 before the list's right edge, to the screen pixel the skin snaps the list's inset to, got " .. tostring((lx + lw) - (barX + barW)))
	local _, sy, _, sh = Common.Scene.Rect(R.env, step)
	local _, ny = Common.Scene.Rect(R.env, step.number)
	assert(math.abs((sy - ny) - 5) < 0.01, "the Step plate rises 5 above the step frame")
	assert(sh > 60, "the first step holds its four elements, got " .. tostring(sh))
end

print("ok")
