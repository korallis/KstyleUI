-- test-render-scenes-hud.lua: the HUD scene's modules build and merge, show the mockup's state with set B's
-- icons, and the icon rule, the text widths and the tooltip title's layout hold.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Common, Hud, check, collect = L.Common, L.Hud, L.check, L.collect
local SET_B, setB = L.SET_B, L.setB
local Tooltip = dofile("Tools/render/scenes/tooltip.lua")

-- Each HUD module in its own environment, then the merge.
local scenes = {}
for _, name in ipairs(Hud.Order()) do
	scenes[#scenes + 1] = check("hud." .. name, (Hud.Module(name)))
end
local hud = check("hud", Common.Scene.Merge(scenes))
local total = 0
for _, scene in ipairs(scenes) do
	total = total + #scene.items
end
assert(#hud.items == total, "the merge keeps every module's drawables")

-- The HUD shows the mockup's state: the vitals line's name, value and cast line (Slam), the target's sigil with its
-- level line, and warrior icons from set B, which
-- the renderer draws for every file ID the pack covers, as the client does with the pack installed (docs/icons.md).
local texts, files = collect(hud)
for _, want in ipairs({ "VALERIN", "Slam", "Casting", "RIVERGLADE CROCOLISK", "Level 38 \194\183 Beast", "2750", "/ 3350", "Battle Shout", "Enrage" }) do
	assert(texts[want], "the HUD shows " .. want)
end
assert(files[SET_B .. Hud.Classes.WARRIOR.cast[2] .. ".png"], "Slam's icon comes from set B")
local swipes = 0
for _, item in ipairs(hud.items) do
	if item.kind == "swipe" then
		swipes = swipes + 1
	end
end
assert(swipes >= 1, "a cooldown swipe is drawn")

-- The chat tabs are laid out as Blizzard's dock lays them, skinned upper case by KstyleUI_Chat.
for _, want in ipairs({ "GENERAL", "COMBAT", "LOOT", "TRADE" }) do
	assert(texts[want], "the chat shows the " .. want .. " tab")
end

-- The centre cluster: six essential and four utility cooldown icons, each with its own warrior icon.
for _, group in ipairs({ "essential", "utility" }) do
	for _, entry in ipairs(Hud.Classes.WARRIOR[group]) do
		assert(files[SET_B .. entry[2] .. ".png"], "the cooldown rows show " .. entry[1])
	end
end

-- The centre cluster's countdowns read with their unit, as the mockup's "4s" and "2m".
assert(texts["4s"] and texts["2m"], "the cooldown rows show 4s and 2m")

-- The quest tracker is the shared stand-in with the skin's one caption header and numbered discs.
assert(texts["QUESTS"] and texts["1"] and texts["2"] and not texts["Quests"], "the HUD's tracker shows the QUESTS caption and the numbered discs")

-- The chat's tabs sit on Blizzard's dock as FCFDock_UpdateTabs lays them, with the plus glyph at the right end.
local hudPlus = 0
for _, item in ipairs(hud.items) do
	if item.kind == "texture" and item.file and item.file:find("GlyphClose", 1, true) and item.rotation and math.abs(item.rotation - math.pi / 4) < 1e-3 then
		hudPlus = hudPlus + 1
	end
end
assert(hudPlus == 1, "the HUD's chat draws the plus glyph once, got " .. hudPlus)

-- The minimap's terrain stand-in draws through the chamfered mask the module set on the Minimap frame
-- (Minimap:SetMaskTexture), so the render shows the clip the game makes at the frame's cut corners.
local masked = false
for _, item in ipairs(scenes[3].items) do
	if item.kind == "texture" and item.masks then
		for _, mask in ipairs(item.masks) do
			if mask.file and mask.file:find("MinimapMask", 1, true) then
				masked = true
			end
		end
	end
end
assert(Hud.Order()[3] == "minimap" and masked, "the minimap's terrain draws through the module's chamfered mask")

-- The buff row beside the minimap: five icons with their time left, from the Auras module. The aura engine
-- paints each tile's icon itself as a secret; the client then loads the pack's loose file for that file ID,
-- so the row shows set B's repaint, as every other icon does.
assert(texts["24s"] and texts["8m"], "the buff row shows its timers")
local buffFiles = {}
for _, item in ipairs(scenes[4].items) do
	if item.kind == "texture" and item.fileID then
		buffFiles[tostring(item.fileID)] = item.file
	end
end
assert(Hud.Order()[4] == "auras", "the fourth HUD module is the buff row")
assert(buffFiles[tostring(Hud.Classes.WARRIOR.buffRow[1][2])] == SET_B .. Hud.Classes.WARRIOR.buffRow[1][2] .. ".png", "the buff row shows Battle Shout from set B, as the installed pack does")

-- Combat text: the crit on the crocolisk and the heal on the player.
assert(texts["142"] and texts["+168"], "the combat numbers 142 and +168 are drawn")

-- One rule for every icon: a file ID resolves to set B's art when the pack has it, else to Blizzard's icon
-- folder, whatever the scene; there is no icon set option any more.
assert(Common.IconDirs()[1] == "Tools/icons/setB/Icons", "set B is searched first")
assert(#Common.IconDirs() == 2 and Common.IconDirs()[2]:find("/icons/blizzard$"), "then Blizzard's icons")
assert(Common.IconSet == nil and Common.IconsSection == nil and Common.InstallAddOns == nil, "the icon set switches are gone")
assert(Common.Scene.ResolvePath(Hud.Classes.WARRIOR.cast[2]) == setB(Hud.Classes.WARRIOR.cast[2]), "Scene.ResolvePath uses the same rule by default")

-- Text widths: a kit font measures by its real glyph advances (gen_glyphs.py), another face by the
-- class averages, and a Blizzard face the page draws as Source Sans measures as Source Sans.
local Scene = Common.Scene
local sample = "[14:32] [1. General] [Riverglades]: Anyone for"
local semibold = Scene.TextWidth(sample, 100, "Media\\Fonts\\SourceSans3-Semibold.ttf")
assert(math.abs(semibold - 1914.4) < 10, "the kit font's advances give " .. semibold .. " for 100 em of the sample")
assert(math.abs(Scene.TextWidth(sample, 100, "Fonts\\FRIZQT__.TTF") - semibold) < 0.01, "Friz Quadrata measures as the semibold it draws as")
assert(math.abs(Scene.TextWidth(sample, 100) - semibold) > 20, "an unknown face falls back to the class averages")

-- The tooltip's title keeps a blank second line for the rarity caption, so the caption sits under the name
-- and the next line under both, as the game lays GameTooltip's lines out.
local function textItem(scene, prefix)
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and (item.text:gsub("\226\128\137", "")):sub(1, #prefix) == prefix then
			return item
		end
	end
	error("no text " .. prefix)
end
for _, triple in ipairs({ { scenes[#scenes], "VANQUISHER", "Item Level" }, { Tooltip.Build(), "RANGER", "Level 38" } }) do
	local scene, name = triple[1], triple[2]
	local title, caption, second = textItem(scene, name), textItem(scene, "UNCOMMON"), textItem(scene, triple[3])
	local line = title.font.size * 1.2
	assert(math.abs(second.rect[2] - (title.rect[2] + title.rect[4] + 0.5)) < 0.01, name .. ": the next line follows the title at the skin's half-unit spacing")
	assert(title.rect[4] >= 2 * line - 0.01, name .. ": the title is two lines tall")
	assert(caption.rect[2] >= title.rect[2] + line - 0.01, name .. ": the caption sits on the title's second line")
	assert(second.rect[2] >= title.rect[2] + title.rect[4] - 0.01, name .. ": the next line sits under the title's second line")
end

print("ok")
