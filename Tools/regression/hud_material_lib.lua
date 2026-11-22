-- hud_material_lib.lua: the card material audit of the raw reference HUD (LEE-122). Build(preset) draws the reference
-- scene (Tools/render/scenes/_reference.lua); Audit(scene, roles) reads what the scene actually draws, never IsVisible alone.
--
-- A drawn card is a Chrome of a card shape (panel, card, window, rail) with a CardShape fill item in scene.items. Its
-- role is "story" (the RestedXP guide card), "databars.wing" (the data strip's wing), "minimap.plaque1" or "2" (the
-- round face's plaques) or the Layout element its centre stands in. Audit fails when
--   - a CardShape item is drawn by no captured Chrome, or an expected role draws no card;
--   - a drawn card's Chrome:Material() is not the Medallions steel, unless OPT_OUTS names its role with a reason;
--   - the card fills with another colour than its steel fill, draws no steel bevel, or draws gilt ticks under the steel.
-- OPT_OUTS is empty: no drawn reference card opts out of the material. A new entry is one role with its consumer's
-- reason, never a blanket allowance for radius or grain = false.
rawset(_G, "RENDER_SCENE_LIB", true)
local Reference = dofile("Tools/render/scenes/_reference.lua")

local Lib = {}

Lib.OPT_OUTS = {}

-- The party stands bare on the world since KSTY-57, so no preset draws a party card.
Lib.ROLES = {
	DPS = { "story", "databars.strip", "databars.wing", "minimap.plaque1", "minimap.plaque2", "skins.quests", "meters.damage", "chat.main", "qol.lootfeed" },
	Tank = { "story", "databars.strip", "databars.wing", "minimap.plaque1", "minimap.plaque2", "skins.quests", "meters.damage", "meters.threat", "chat.main", "qol.lootfeed" },
	Healer = { "story", "databars.strip", "databars.wing", "minimap.plaque1", "minimap.plaque2", "skins.quests", "meters.damage", "chat.main", "qol.lootfeed" },
}

local CARD_FILE = "CardShape.png"

function Lib.Build(preset)
	local scene = Reference.Build({ layout = preset })
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
	for _, name in ipairs({ "fill", "shadow", "rim", "line", "gilt", "bevel" }) do
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
	local addons = owner._env._addons or {}
	local data, map = addons.KstyleUI_DataBars, addons.KstyleUI_Minimap
	local view = data and data.Strip.view
	if view and view.card == owner then return "databars.strip" end
	if view and view.wingCard == owner then return "databars.wing" end
	local plaques = map and map.Map.face and map.Map.face.plaques or {}
	for i, plaque in ipairs(plaques) do
		if plaque == owner then return "minimap.plaque" .. i end
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

-- AuditCard(card) checks one drawn card from Cards(scene) against the Medallions steel.
function Lib.AuditCard(card)
	local K = card.chrome.owner._env.KstyleUI
	local chrome, label = card.chrome, "the " .. card.role .. " card"
	local optOut = Lib.OPT_OUTS[card.role]
	if optOut then
		assert(type(optOut) == "string" and #optOut >= 40, label .. ": an opt-out needs its consumer's reason")
		assert(chrome:Material() == nil, label .. " lists an opt-out but takes the material")
		return
	end
	local spec = K.Widgets.SteelMaterial()
	assert(chrome:Material() == spec, label .. " does not take the steel: " .. why(chrome))
	local r, g, b = K.Widgets.Rgba(chrome.steelFill or spec.fill)
	for _, item in ipairs(card.drawn.fill) do
		local v = item.vertex
		assert(near(v[1], r, 1e-4) and near(v[2], g, 1e-4) and near(v[3], b, 1e-4), label .. " fills with another colour than its steel fill")
	end
	assert(card.drawn.bevel, label .. " draws no steel bevel")
	assert(not card.drawn.gilt, label .. " draws gilt ticks under the steel")
end

-- Audit(scene, roles) -> the cards. roles are the roles the preset must draw; a drawn card of any other role is
-- audited as well.
function Lib.Audit(scene, roles)
	local cards = Lib.Cards(scene)
	assert(#cards.unowned == 0, "a CardShape fill is drawn by no captured Chrome: " .. #cards.unowned .. " items")
	local seen = {}
	for _, card in ipairs(cards) do
		assert(card.role ~= "unplaced", "a drawn card stands in no Layout element and is not the story card")
		assert(not seen[card.role], "two drawn cards share the role " .. card.role)
		seen[card.role] = card
		Lib.AuditCard(card)
	end
	for _, name in ipairs(roles) do
		assert(seen[name], "the reference HUD draws no " .. name .. " card")
	end
	return cards
end

return Lib
