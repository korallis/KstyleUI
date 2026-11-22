-- test-actionbars-parity.lua: per-bar text placement, cooldown finish, item quality and mover settings journeys.
local AB = dofile("Tools/regression/actionbars_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local W = AB.W
local quality, reads = { [100] = 3, [200] = 4 }, {}
local env, K, ns = AB.New({ setup = function(e)
	for i = 1, 10 do e._game.forms[i] = { texture = 132355, spellID = 2457 + i } end
	e._game.petExists = true
	e.C_Item = e.C_Item or {}
	e.C_Item.IsEquippableItem = function() error("quality borders include non-equippable items") end
	e.C_Item.GetItemQualityByID = function(id) reads[id] = (reads[id] or 0) + 1; return quality[id] end
	e.C_Item.GetItemQualityColor = function(q) return q / 5, 0.4, 0.8 end
	e.C_AddOns.LoadAddOn = function(name)
		if name == "KstyleUI_Options" and not e._addons[name] then Load(O.Files(), e) end
		return true
	end
end })
AB.Enable(env, K)
K.Options.Write("ActionBars", "slab", false)
K.Options.Write("ActionBars", "consumables.hideEmpty", false)
local function Write(key, value) K.Options.Write("ActionBars", key, value) end
local function Near(a, b) return math.abs(a - b) < 0.001 end
local function Last(region, method) return assert(W.LastCall(region, method), method) end
local choices = {}
for _, def in ipairs(ns.BARS) do choices[#choices + 1] = def end
choices[#choices + 1] = ns.Consumables.def
for _, def in ipairs(choices) do
	local key = def.key
	if key == "consumables" then Write("consumables.size", 38); Write("consumables.hotkey", true) end
	Write(key .. ".enabled", true)
	local cfg = K.Store.Module("ActionBars")[key]
	local live = def.kind == "consumable" and ns.Consumables or ns.bars[key]
	local b = live.buttons[1]
	assert(not cfg.desaturateCooldown and cfg.swipeOpacity == 0.65 and cfg.rarityBorder, "retain cooldown defaults; quality borders default on")
	assert(b.hotkey._points[1][1] == "TOPLEFT" and b.count._points[1][1] == "BOTTOMRIGHT", "default text corners stay unchanged")
	local before = K.Options.Copy(K.Store.Module("ActionBars"))
	for _, spec in ipairs(ns.TEXTS) do
		local field = spec.key
		if field == "hotkey" or field == "cooldown" or field == "count" and (def.kind == "action" or def.kind == "consumable") or field == "macro" and def.kind == "action" then
			local region = field == "macro" and b.macroText or field == "cooldown" and b.countdown or b[field]
			Write(key .. ".placement." .. field .. ".anchor", "LEFT")
			Write(key .. ".placement." .. field .. ".x", 1)
			Write(key .. ".placement." .. field .. ".y", -1)
			assert(region._points[1][1] == "LEFT" and region._points[1][4] > 0 and region._points[1][5] < 0, key .. ": text placement applies")
		end
	end
	Write(key .. ".desaturateCooldown", true)
	Write(key .. ".swipeOpacity", 0.25)
	b:SetUsable(true)
	b:SetCooldown(10, 20, false)
	b.cooldown:GetScript("OnShow")(b.cooldown)
	assert(Last(b.icon, "SetDesaturated")[1] == true, key .. ": desaturate a real cooldown")
	assert(Near(Last(b.cooldown, "SetSwipeColor")[4], 0.25), key .. ": swipe opacity applies")
	b:SetCooldown(10, 1.5, true)
	assert(Last(b.icon, "SetDesaturated")[1] == false, key .. ": keep the GCD in colour")
	assert(Near(Last(b.cooldown, "SetSwipeColor")[4], 0.25 * 0.4 / 0.65), "quiet GCD keeps its proportional opacity")
	Write(key .. ".swipeOpacity", 0.65)
	assert(Near(Last(b.cooldown, "SetSwipeColor")[4], 0.4), "reset opacity restores the usual GCD")
	for _, other in ipairs(choices) do
		if other.key ~= key then assert(K.Options.Equal(before[other.key], K.Store.Module("ActionBars")[other.key]), "only " .. key .. " changes") end
	end
end
Write("consumables.size", 26)
for _, field in ipairs({ "hotkey", "count", "cooldown" }) do Write("consumables.placement." .. field .. ".anchor", "CENTER") end
local compact = ns.Consumables.buttons[1]
assert(compact.count._points[1][1] == "BOTTOMRIGHT" and compact.countdown._points[1][1] == "CENTER", "compact count wins over placement choices")
assert(not compact.hotkey:IsShown(), "compact count wins over an enabled keybind")
Write("consumables.count", false)
assert(compact.hotkey:IsShown(), "without a count the compact keybind can show")
compact:SetCooldown(10, 20)
compact.cooldown:GetScript("OnShow")(compact.cooldown)
assert(compact.count:GetAlpha() == 0 and compact.hotkey:GetAlpha() == 0, "compact countdown temporarily replaces the keybind")
Write("consumables.cooldown", false)
assert(compact.hotkey:GetAlpha() > 0, "hiding countdown numbers restores the compact keybind")
local b = ns.bars.bar1.buttons[1]
for _, anchor in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
	for _, spec in ipairs(ns.TEXTS) do
		Write("bar1.placement." .. spec.key .. ".anchor", anchor)
		local region = spec.key == "macro" and b.macroText or spec.key == "cooldown" and b.countdown or b[spec.key]
		assert(region._points[1][1] == anchor, "all four texts support " .. anchor)
	end
end
for _, spec in ipairs(ns.TEXTS) do
	Write("bar1.placement." .. spec.key .. ".anchor", "")
	Write("bar1.placement." .. spec.key .. ".x", 0)
	Write("bar1.placement." .. spec.key .. ".y", 0)
end
assert(b.hotkey._points[1][1] == "TOPLEFT" and b.count._points[1][1] == "BOTTOMRIGHT" and b.countdown._points[1][1] == "CENTER", "reset restores the original text positions")
assert(#b.macroText._points == 2, "reset restores the original macro width")
AB.Slot(env, 1, { type = "item", id = 100, texture = 132355 })
assert(b.itemQuality == 3, "rare items get their quality border")
for _, q in ipairs({ 0, 1, 2, 3, 4 }) do
	quality[100] = q
	env.FireEvent("GET_ITEM_INFO_RECEIVED", 100, true)
	assert(b.itemQuality == (q >= 2 and q or nil), "only uncommon and better items have quality borders")
end
quality[100] = nil
env.FireEvent("GET_ITEM_INFO_RECEIVED", 100, true)
assert(b.itemQuality == nil, "unavailable data clears the old border")
AB.Slot(env, 1, { type = "item", id = 200, texture = 132355 })
assert(b.itemQuality == 4, "swapping the action updates its quality")
Write("bar1.rarityBorder", false)
assert(b.itemQuality == nil, "rarity toggle clears its border")
Write("bar1.rarityBorder", true)
assert(b.itemQuality == 4, "rarity toggle restores its border")
quality[200] = nil
env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
assert(b.itemQuality == nil, "uncached item starts with the regular border")
quality[200] = 4
AB.Slot(env, 2, { type = "macro", subType = "item", id = 200, texture = 132355 })
AB.Slot(env, 3, { type = "item", id = 100, texture = 132355 })
reads = {}
env.FireEvent("GET_ITEM_INFO_RECEIVED", 999, true)
assert(next(reads) == nil, "unrelated item data does no action-button work")
env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
assert(reads[200] == 2 and reads[100] == nil, "refresh only buttons and resolved macros holding the received item")
assert(b.itemQuality == 4, "item data arrival restores quality")
AB.Slot(env, 2, { type = "spell", id = 200, texture = 132355 })
reads = {}
env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
assert(reads[200] == 1, "swapping an item for a spell removes its old map entry")
env.FireEvent("GET_ITEM_INFO_RECEIVED", env.Secret(200), true)
local qualityColor = env.C_Item.GetItemQualityColor
env.C_Item.GetItemQualityColor = function() error("paint must use the cached item colour") end
b:Paint()
env.C_Item.GetItemQualityColor = qualityColor
quality[200] = env.Secret(4)
env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
assert(b.itemQuality == nil, "secret quality is never compared or used as a key")
quality[200] = 4
for _, style in ipairs({ "frames", "medallions" }) do
	Write("bar1.placement.hotkey.anchor", "RIGHT")
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	assert(b.hotkey._points[1][1] == "RIGHT", "restyling preserves chosen position in " .. style)
	assert(b.itemQuality == 4, "restyling restores quality")
	if style == "medallions" then assert(Near(Last(b.medFrame, "SetVertexColor")[1], 0.8), "Medallions socket carries the quality colour") end
end
assert(K.Options.Open("ActionBars"))
env.RunTimers(); W.Settle(env)
local options = env._addons.KstyleUI_Options
local picker = options.Window.Parts().picker
assert(picker:IsShown() and picker.controls.segmented, "picker is outside the scroller")
local top = picker:GetTop()
options.Window.Parts().content:SetOffset(800)
assert(picker:IsShown() and picker:GetTop() == top, "picker stays still while the settings scroll")
W.Click(picker.controls.segmented.buttons[picker.controls.segmented:IndexOf("bar2")])
env.RunTimers(); W.Settle(env)
assert(K.Store.Module("ActionBars").editBar == "bar2", "pinned picker selects another bar after scrolling")
for _, def in ipairs(choices) do
	assert(K.Layout.Enter())
	local plate = assert(K.Layout.Mode.Plate(def.element))
	plate:GetScript("OnMouseDown")(plate, "LeftButton")
	assert(K.Layout.Mode.Selected() == def.element, "click still selects the mover")
	plate:GetScript("OnDoubleClick")(plate, "LeftButton")
	assert(not K.Layout.IsActive() and K.Store.Module("ActionBars").editBar == def.key, "double-click opens " .. def.key)
	env.RunTimers(); W.Settle(env)
	assert(options.Window.State().page == "ActionBars" and options.Window.Frame():IsShown(), "open the actual Options page")
end
local itemAPI = env.C_Item
for _, method in ipairs({ "GetItemQualityByID", "GetItemQualityColor" }) do
	local saved = itemAPI[method]
	itemAPI[method] = nil
	env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
	assert(b.itemQuality == nil, "missing " .. method .. " keeps the regular border")
	itemAPI[method] = saved
end
env.FireEvent("GET_ITEM_INFO_RECEIVED", 200, true)
Write("bar1.moverOptions", false)
assert(K.Layout.Enter())
local plate = K.Layout.Mode.Plate("actionbars.bar1")
plate:GetScript("OnDoubleClick")(plate, "LeftButton")
assert(K.Layout.IsActive(), "mover shortcut can be switched off")
K.Layout.Exit()
env._combat = true
local old = b.hotkey._points[1][1]
Write("bar1.placement.hotkey.anchor", "BOTTOM")
Write("bar1.desaturateCooldown", false)
assert(b.hotkey._points[1][1] == old, "protected settings wait until combat ends")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(b.hotkey._points[1][1] == "BOTTOM", "combat end applies placement")
assert(#env._blocked == 0 and #env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
print("actionbars parity ok: independent placement and cooldowns, event-driven rarity, pinned picker and mover shortcuts")
