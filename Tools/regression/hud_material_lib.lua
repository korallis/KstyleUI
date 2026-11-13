-- hud_material_lib.lua: the card material audit of the raw reference HUD (LEE-122). Build(preset, material) draws the
-- reference scene (Tools/render/scenes/_reference.lua) with the card material selected through the public
-- RENDER_CARD_MATERIAL flag; Audit(scene, material, roles) reads what the scene actually draws, never IsVisible alone.
--
-- A drawn card is a Chrome of a card shape (panel, card, window, rail) with a CardShape fill item in scene.items. Its
-- role is "story" (the RestedXP guide card) or the Layout element its centre stands in. Audit fails when
--   - a CardShape item is drawn by no captured Chrome, or an expected role draws no card;
--   - a drawn card's Chrome:Material() is not the selected material, unless OPT_OUTS names its role with a reason;
--   - the selected material's grain, forged frame or brackets are missing from the items or sit off the card, a
--     material without them still draws them, or the fill is not the material's fill.
-- OPT_OUTS is empty: no drawn reference card opts out of the material. A new entry is one role with its consumer's
-- reason, never a blanket allowance for radius or grain = false.
rawset(_G, "RENDER_SCENE_LIB", true)
local Reference = dofile("Tools/render/scenes/_reference.lua")

local Lib = {}

Lib.OPT_OUTS = {}

Lib.ACCENTS = {
	["meters.threat"] = "the threat warning edge (KstyleUI_Meters/README.md, Warnings): a warning turns the panel's hairline neutral and danger turns it hostile; Chrome:SyncMaterialFrame swaps the rounded rim for a square edge inside the forged frame and its brackets so the state stays visible",
}

-- The party stands bare on the world since KSTY-57, so no preset draws a party card.
Lib.ROLES = {
	DPS = { "story", "actionbars.tray", "skins.quests", "meters.damage", "chat.main", "qol.lootfeed" },
	Tank = { "story", "actionbars.tray", "skins.quests", "meters.damage", "meters.threat", "chat.main", "qol.lootfeed" },
	Healer = { "story", "actionbars.tray", "skins.quests", "meters.damage", "chat.main", "qol.lootfeed" },
}

local CARD_FILE = "CardShape.png"
local TOLERANCE = 1.25
local RIM = 3.5

function Lib.Build(preset, material)
	local getenv = os.getenv
	rawset(os, "getenv", function(key)
		if key == "RENDER_CARD_MATERIAL" then
			return material
		end
		return getenv(key)
	end)
	local ok, scene = pcall(Reference.Build, { layout = preset })
	rawset(os, "getenv", getenv)
	assert(ok, scene)
	for _, line in ipairs(scene.log) do
		assert(not line:find("error:", 1, true), preset .. ": " .. line)
	end
	return scene
end

local function basename(path)
	return tostring(path):match("[^/\\]+$")
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end

-- The textures a Chrome owns, as { part name, texture }.
local function parts(chrome)
	local out = {}
	for _, name in ipairs({ "fill", "shadow", "rim", "line", "gilt", "grain", "materialFrame", "materialBrackets", "materialEdge" }) do
		local value = chrome[name]
		if type(value) == "table" and value._type == "Texture" then
			out[#out + 1] = { name, value }
		elseif type(value) == "table" then
			for _, texture in ipairs(value) do
				out[#out + 1] = { name, texture }
			end
		end
	end
	return out
end

-- Chromes(scene) -> every Chrome made in every environment the merged scene draws from.
function Lib.Chromes(scene)
	local out, seen = {}, {}
	for _, item in ipairs(scene.items) do
		local env = item.object and item.object._env
		if env and env._materialChromes and not seen[env] then
			seen[env] = true
			for _, chrome in ipairs(env._materialChromes) do
				out[#out + 1] = chrome
			end
		end
	end
	return out
end

local function union(items)
	local rect
	for _, item in ipairs(items) do
		local r = item.rect
		rect = rect or { r[1], r[2], r[1] + r[3], r[2] + r[4] }
		rect[1], rect[2] = math.min(rect[1], r[1]), math.min(rect[2], r[2])
		rect[3], rect[4] = math.max(rect[3], r[1] + r[3]), math.max(rect[4], r[2] + r[4])
	end
	return rect
end

local function role(scene, chrome, card)
	local owner = chrome.owner
	if owner._name == "RXPFrame" or (owner._parent and owner._parent._name == "RXPFrame") then
		return "story"
	end
	local bars = owner._env._addons and owner._env._addons.KstyleUI_ActionBars
	if bars and bars.Tray and bars.Tray.card == owner then
		return "actionbars.tray"
	end
	if not scene.elements then
		return "widget"
	end
	local f = scene.screen.height * owner._env.KstyleUI.Scale.DEFAULT_USER_SCALE / 1080
	local cx, cy = (card[1] + card[3]) / 2, (card[2] + card[4]) / 2
	local best, area
	for key, e in pairs(scene.elements) do
		local x, y = e.left * f, scene.screen.height - (e.bottom + e.height) * f
		local w, h = e.width * f, e.height * f
		if cx >= x and cx <= x + w and cy >= y and cy <= y + h and (not area or w * h < area) then
			best, area = key, w * h
		end
	end
	return best or "unplaced"
end

-- Cards(scene) -> the drawn cards, each { chrome, role, rect, drawn = { part name = items } }, and .unowned, the
-- CardShape items no captured Chrome owns.
function Lib.Cards(scene)
	local owner = {}
	for _, chrome in ipairs(Lib.Chromes(scene)) do
		for _, part in ipairs(parts(chrome)) do
			owner[part[2]] = { chrome, part[1] }
		end
	end
	local cards, byChrome, unowned = {}, {}, {}
	for _, item in ipairs(scene.items) do
		local mine = item.kind == "texture" and owner[item.object]
		if mine then
			local card = byChrome[mine[1]]
			if not card then
				card = { chrome = mine[1], drawn = {} }
				byChrome[mine[1]] = card
				cards[#cards + 1] = card
			end
			card.drawn[mine[2]] = card.drawn[mine[2]] or {}
			table.insert(card.drawn[mine[2]], item)
		elseif item.kind == "texture" and basename(item.file) == CARD_FILE then
			unowned[#unowned + 1] = item
		end
	end
	local out = { unowned = unowned }
	for _, card in ipairs(cards) do
		if card.chrome.shape.card and card.drawn.fill then
			card.unit = scene.screen.height / scene.screen.physical.height
			card.rect = union(card.drawn.fill)
			card.role = role(scene, card.chrome, card.rect)
			out[#out + 1] = card
		end
	end
	return out
end

local function why(chrome)
	local reasons = {}
	for _, field in ipairs({ "radius", "share" }) do
		if chrome[field] then
			reasons[#reasons + 1] = field .. " = " .. tostring(chrome[field])
		end
	end
	if not chrome.materialOn then
		reasons[#reasons + 1] = "grain = false"
	end
	if chrome.fillName ~= "surface" then
		reasons[#reasons + 1] = "fill = " .. tostring(chrome.fillName)
	end
	if chrome.ownFill then
		reasons[#reasons + 1] = "its own fill colour"
	end
	return #reasons > 0 and table.concat(reasons, ", ") or "an unknown cause"
end

-- AuditCard(card, material) checks one drawn card from Cards(scene) against the material's spec.
function Lib.AuditCard(card, material)
	local K = card.chrome.owner._env.KstyleUI
	local chrome, label = card.chrome, "the " .. card.role .. " card"
	local tolerance, rim = TOLERANCE * card.unit, RIM * card.unit
	local spec = K.Tokens.Material(material)
	local optOut = Lib.OPT_OUTS[card.role]
	if optOut then
		assert(type(optOut) == "string" and #optOut >= 40, label .. ": an opt-out needs its consumer's reason")
		assert(chrome:Material() == nil, label .. " lists an opt-out but takes the material")
		return
	end
	assert(chrome:Material() == spec, label .. " does not take " .. material .. ": " .. why(chrome))
	local r, g, b = K.Tokens.Color(spec.fill or "surface")
	for _, item in ipairs(card.drawn.fill) do
		local v = item.vertex
		assert(near(v[1], r, 1e-4) and near(v[2], g, 1e-4) and near(v[3], b, 1e-4), label .. " fills with another colour than " .. material .. "'s")
	end
	local rect, grain = card.rect, card.drawn.grain
	if spec.texture then
		assert(grain and #grain == 1, label .. " draws no " .. material .. " grain (paint never ran against the resolved size)")
		local item = grain[1]
		assert(basename(item.file) == basename(K.Tokens.Texture(spec.texture)), label .. " grain is not the " .. material .. " texture")
		assert(item.rect[3] > 0 and item.rect[4] > 0 and item.vertex[4] > 0 and item.texCoord[2] > 0 and item.texCoord[4] > 0, label .. " grain draws nothing")
		assert(item.rect[1] >= rect[1] - tolerance and item.rect[2] >= rect[2] - tolerance and item.rect[1] + item.rect[3] <= rect[3] + tolerance and item.rect[2] + item.rect[4] <= rect[4] + tolerance, label .. " grain leaves the card")
		assert(item.rect[3] > (rect[3] - rect[1]) * 0.8 and item.rect[4] > (rect[4] - rect[2]) * 0.8, label .. " grain covers a fraction of the card")
	else
		assert(not grain, label .. " draws a grain the " .. material .. " material lacks")
	end
	local frame, span = card.drawn.materialFrame
	if spec.frame then
		assert(frame and #frame == 9 and chrome.frameReady, label .. " draws no " .. material .. " forged frame")
		span = union(frame)
		assert(near(span[1], rect[1], rim) and near(span[2], rect[2], rim) and near(span[3], rect[3], rim) and near(span[4], rect[4], rim) and span[1] <= rect[1] and span[2] <= rect[2] and span[3] >= rect[3] and span[4] >= rect[4], label .. " forged frame does not span the card: frame " .. table.concat(span, " ") .. ", fill " .. table.concat(rect, " "))
		for _, item in ipairs(frame) do
			assert(basename(item.file):find("^ForgedFrame%d%.png$") and item.vertex[4] > 0, label .. " forged frame is the wrong texture")
		end
		assert(not card.drawn.line, label .. " draws its ring line under the forged frame")
		assert(not card.drawn.rim, label .. " draws its rounded rim over the forged frame")
		local edge = card.drawn.materialEdge
		if edge then
			local reason = Lib.ACCENTS[card.role]
			assert(type(reason) == "string" and #reason >= 40, label .. " draws an outline over its forged frame with no recorded reason")
			assert(chrome.ownEdge or chrome.proc, label .. " draws an outline over its forged frame without a state edge")
			assert(#edge == 4, label .. " draws " .. #edge .. " of 4 sides of its state edge")
			local box = union(edge)
			local inset = box[1] - span[1]
			assert(inset > tolerance and near(span[3] - box[3], inset, tolerance) and near(box[2] - span[2], inset, tolerance) and near(span[4] - box[4], inset, tolerance), label .. " state edge does not sit evenly inside the forged frame")
			for _, item in ipairs(edge) do
				local side = item.rect
				local across = side[3] == box[3] - box[1] or side[4] == box[4] - box[2]
				local down = near(side[1], box[1], 1e-3) or near(side[1] + side[3], box[3], 1e-3)
				assert(across or down, label .. " state edge has a side off its square")
			end
		end
	else
		assert(not frame, label .. " draws a forged frame the " .. material .. " material lacks")
		assert(not card.drawn.materialEdge, label .. " draws a forged state edge the " .. material .. " material lacks")
	end
	local brackets = card.drawn.materialBrackets
	if spec.brackets then
		assert(span, label .. " has brackets without a forged frame")
		assert(brackets and #brackets == 4, label .. " draws " .. (brackets and #brackets or 0) .. " of 4 brackets")
		for _, corner in ipairs({ "TL", "TR", "BL", "BR" }) do
			local x, y = corner:find("L") and span[1] or span[3], corner:find("T") and span[2] or span[4]
			local found
			for _, item in ipairs(brackets) do
				local bx = corner:find("L") and item.rect[1] or item.rect[1] + item.rect[3]
				local by = corner:find("T") and item.rect[2] or item.rect[2] + item.rect[4]
				found = found or near(bx, x, tolerance) and near(by, y, tolerance)
			end
			assert(found, label .. " has no bracket at its " .. corner .. " corner")
		end
		assert(not card.drawn.gilt, label .. " draws gilt ticks under its brackets")
	else
		assert(not brackets, label .. " draws brackets the " .. material .. " material lacks")
		if chrome.gilt then
			assert(card.drawn.gilt and #card.drawn.gilt > 0, label .. " draws no gilt ticks under " .. material)
		end
	end
end

-- Audit(scene, material, roles) -> the cards. roles are the roles the preset must draw; a drawn card of any other role
-- is audited as well.
function Lib.Audit(scene, material, roles)
	local cards = Lib.Cards(scene)
	assert(#cards.unowned == 0, "a CardShape fill is drawn by no captured Chrome: " .. #cards.unowned .. " items")
	local seen = {}
	for _, card in ipairs(cards) do
		assert(card.role ~= "unplaced", "a drawn card stands in no Layout element and is not the story card")
		assert(not seen[card.role], "two drawn cards share the role " .. card.role)
		seen[card.role] = card
		assert(card.chrome.owner._env.KstyleUI.Widgets.Setting("cardMaterial") == material, "the " .. card.role .. " card's addon did not load " .. material)
		Lib.AuditCard(card, material)
	end
	for _, name in ipairs(roles) do
		assert(seen[name], "the reference HUD draws no " .. name .. " card")
	end
	return cards
end

local function signature(item)
	local v = item.vertex and string.format("%.4f,%.4f,%.4f", item.vertex[1], item.vertex[2], item.vertex[3]) or ""
	local r = item.rect
	return table.concat({ item.kind, tostring(item.file), tostring(item.text), string.format("%.3f,%.3f,%.3f,%.3f", r[1], r[2], r[3], r[4]), v, tostring(item.alpha) }, "|")
end

-- Records(scene) -> a sorted list of strings, one per text, swipe and status bar fill the scene draws, and per Layout
-- element. A card's own textures, its caption gem and its rules belong to the material, so they are not records here.
function Lib.Records(scene)
	local out = {}
	for _, item in ipairs(scene.items) do
		local bar = item.kind == "texture" and item.object._parent and item.object._parent._type == "StatusBar"
		if item.kind ~= "texture" or bar then
			out[#out + 1] = signature(item)
		end
	end
	for key, e in pairs(scene.elements) do
		out[#out + 1] = string.format("element|%s|%.4f|%.4f|%.4f|%.4f", key, e.left, e.bottom, e.width, e.height)
	end
	table.sort(out)
	return out
end

return Lib
