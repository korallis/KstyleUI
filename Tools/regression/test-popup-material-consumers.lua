-- test-popup-material-consumers.lua: the existing tooltip, Blizzard popup and RestedXP overlays opt into opaque materials at runtime, and the meter's hover split, rows of its card with no chrome of its own, keeps its rows across material changes.
local W = dofile("Tools/regression/widget_env.lua")
local materials = { "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }

local function Painted(K, chromes, material)
	local spec = K.Tokens.Material(material)
	local r, g, b = K.Tokens.Color(spec.fill)
	for _, chrome in ipairs(chromes) do
		assert(chrome:Material() == spec, "the existing popup consumer resolves " .. material)
		for _, piece in ipairs(chrome.fill) do
			assert(W.SameColor(piece, r, g, b, 1), "the existing popup consumer has an opaque " .. material .. " fill")
		end
		assert((chrome.grain ~= nil and chrome.grain:IsShown()) == (spec.texture ~= nil))
		assert((chrome.materialFrame ~= nil and chrome.materialFrame[1]:IsShown()) == (spec.frame == true), "card popups keep their material frame")
	end
end

local function Cycle(K, chromes, refresh)
	for _, material in ipairs(materials) do
		K.Options.Write("Widgets", "cardMaterial", material)
		for _, opacity in ipairs({ 0.5, 0.75, 1 }) do
			K.Options.Write("Widgets", "panelOpacity", opacity)
			if refresh then refresh() end
			Painted(K, chromes, material)
		end
	end
	K.Options.Write("Widgets", "panelOpacity", 0.75)
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	if refresh then refresh() end
	local r, g, b = K.Tokens.Color("surface")
	for _, chrome in ipairs(chromes) do
		assert(W.SameColor(chrome.fill[5], r, g, b, 0.75), "Glass consumers retain the original translucent fill")
		assert(not chrome.grain or not chrome.grain:IsShown())
		assert(not chrome.materialFrame or not chrome.materialFrame[1]:IsShown())
	end
end

do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local env, K, ns = T.New()
	for name in pairs(T.TOOLTIPS) do env[name]:SetSize(260, 180) end
	assert(K.Modules.Enable("Tooltips"))
	local chromes = {}
	for name in pairs(T.TOOLTIPS) do
		chromes[#chromes + 1] = assert(ns.Style.Glass(env[name])).chrome
	end
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(420, 600)
	local preview = K.Options.Preview("Tooltips")(parent)
	chromes[#chromes + 1], chromes[#chromes + 2] = preview.item.chrome, preview.unit.chrome
	local tip = env.GameTooltip
	tip:SetOwner(env.UIParent, "ANCHOR_NONE")
	tip:AddLine("Popup material item")
	tip:AddLine("The item description stays intact")
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 19019 })
	local width, height = preview.item:GetSize()
	Cycle(K, chromes, function()
		preview:Refresh()
		assert(W.Near(preview.item:GetWidth(), width) and W.Near(preview.item:GetHeight(), height), "the tooltip preview does not resize with its material")
		assert(preview.title:GetText() == "Ranger's Long Bow")
		assert(tip:GetLeftLine(1):GetText() == "Popup material item" and tip:GetLeftLine(2):GetText() == "The item description stays intact")
	end)
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local S = dofile("Tools/regression/skins_env.lua")
	local popups, menu, button = {}, nil, nil
	local env, K, ns = S.New({ before = function(e)
		local B = S.Blizzard(e)
		for i = 1, 4 do
			local popup = B.frame("Frame", nil, "StaticPopup" .. i)
			popup:SetSize(360, 180)
			popup.Text = B.text(popup)
			popup.Text:SetText("Confirmation " .. i)
			popup:Hide()
			popups[i] = popup
		end
		menu = B.frame("Frame", nil, "GameMenuFrame")
		menu:SetSize(280, 360)
		button = B.frame("Button", menu)
		button:SetSize(220, 28)
		menu.buttonPool = { EnumerateActive = function()
			local done = false
			return function()
				if not done then done = true; return button end
			end
		end }
		menu:Hide()
	end })
	assert(K.Modules.Enable("Skins"))
	S.LoadAddOn(env, "Blizzard_GameMenu")
	S.Show(popups[1])
	S.Show(menu)
	assert(ns.Skins.IsApplied("popups") and ns.Skins.IsApplied("gameMenu"), "the real skins apply on show")
	local chromes = { assert(K.Skin.Parts(menu).backdrop).chrome }
	for _, popup in ipairs(popups) do
		chromes[#chromes + 1] = assert(K.Skin.Parts(popup).backdrop).chrome
	end
	for _, kit in ipairs({ ns.PartBKit, ns.PartC }) do
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(320, 180)
		chromes[#chromes + 1] = kit.Window(frame, { popup = true }).chrome
	end
	Cycle(K, chromes, function()
		assert(menu:GetWidth() == 280 and menu:GetHeight() == 360)
		for i, popup in ipairs(popups) do
			assert(popup:GetWidth() == 360 and popup:GetHeight() == 180 and popup.Text:GetText() == "Confirmation " .. i)
		end
		local chrome = K.Skin.Parts(button).backdrop.chrome
		assert(chrome:Material() == nil and W.SameColor(chrome.fill[5], K.Tokens.Color("buttonFill")), "the game menu button remains an embedded tile")
	end)
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local S = dofile("Tools/regression/skins_env.lua")
	local popups, B, snapshot = {}, nil, nil
	local friends, professions, ready, bnet
	local env, K, ns = S.New({
		loaded = { Blizzard_FriendsFrame = true, Blizzard_Professions = true },
		before = function(e)
			B = S.Blizzard(e)
			local function Frame(parent, name, width, height)
				local frame = B.frame("Frame", parent, name)
				frame:SetSize(width, height)
				frame:SetPoint("CENTER", parent or e.UIParent, "CENTER")
				return frame
			end
			local function Popup(parent, name, label)
				local frame = Frame(parent, name, 300, 180)
				local art = B.texture(frame, "BACKGROUND")
				local text = B.text(frame)
				text:SetText(label)
				popups[#popups + 1] = { frame = frame, art = art, text = text, label = label }
				return frame
			end
			friends = Frame(nil, "FriendsFrame", 550, 430)
			friends.FriendsTabHeader = Frame(friends, "FriendsTabHeader", 500, 40)
			bnet = Frame(friends.FriendsTabHeader, nil, 400, 28)
			friends.FriendsTabHeader.BattlenetFrame = bnet
			bnet.BroadcastFrame = Popup(bnet, nil, "Broadcast message")
			bnet.UnavailableInfoFrame = Popup(bnet, nil, "Battle.net unavailable")
			friends.IgnoreListWindow = Popup(friends, nil, "Ignored players")
			Popup(nil, "RaidInfoFrame", "Raid lockouts")
			Frame(friends, "FriendsListFrame", 500, 300)
			professions = Frame(nil, "ProfessionsFrame", 620, 480)
			local page = Frame(professions, nil, 600, 400)
			professions.CraftingPage = page
			page.RecipeList = Frame(page, nil, 180, 360)
			page.MinimizedSearchResults = Popup(page, nil, "Crafting search results")
			ready = Frame(nil, "ReadyCheckFrame", 300, 180)
			local listener = Popup(ready, "ReadyCheckListenerFrame", "Are you ready?")
			listener.Text = popups[#popups].text
			listener.YesButton = B.frame("Button", listener)
			listener.NoButton = B.frame("Button", listener)
			friends:Hide()
			professions:Hide()
			ready:Hide()
			snapshot = B.snapshot()
		end,
	})
	assert(K.Modules.Enable("Skins"))
	for _, key in ipairs({ "friends", "professions", "readyCheck" }) do
		assert(not ns.Skins.IsApplied(key), key .. " waits for its actual window to show")
	end
	S.Show(friends)
	S.Show(professions)
	S.Show(ready)
	for _, key in ipairs({ "friends", "professions", "readyCheck" }) do
		assert(ns.Skins.IsApplied(key), key .. " applies through the module's real show path")
	end
	local chromes = {}
	for _, popup in ipairs(popups) do
		S.Show(popup.frame)
		assert(popup.art:GetAlpha() == 0, popup.label .. ": the real skin strips the original art")
		chromes[#chromes + 1] = assert(K.Skin.Parts(popup.frame).backdrop).chrome
	end
	assert(#chromes == 6, "all four Friends popups, minimized profession results and the ready check are covered")
	Cycle(K, chromes, function()
		for _, popup in ipairs(popups) do
			assert(popup.frame:IsVisible(), popup.label .. ": the popup remains visible")
			assert(popup.frame:GetWidth() == 300 and popup.frame:GetHeight() == 180, popup.label .. ": the popup keeps its dimensions")
			assert(popup.text:GetText() == popup.label, popup.label .. ": the popup retains its content")
		end
		local tile = K.Skin.Parts(bnet).backdrop.chrome
		assert(tile:Material() == nil and W.SameColor(tile.fill[5], K.Widgets.Rgba("surface", K.Widgets.Setting("panelOpacity") / 0.75)), "the embedded Battle.net strip remains an ordinary glass tile")
		local spec = K.Tokens.Material(K.Widgets.Setting("cardMaterial"))
		if spec.fill then
			local r, g, b, a = K.Tokens.Color(spec.fill)
			for _, frame in ipairs({ friends, professions }) do
				assert(W.SameColor(K.Skin.Parts(frame).backdrop.chrome.fill[5], r, g, b, math.min(1, a * K.Widgets.Setting("panelOpacity") / 0.75)), "the containing window still honors panel opacity")
			end
		end
	end)
	B.check(snapshot)
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local S = dofile("Tools/regression/skins_env.lua")
	local Fake = dofile("Tools/regression/restedxp_fake.lua")
	local rxp
	local env, K, ns = S.New({ setup = function(e) rxp = Fake.Install(e) end })
	assert(K.Modules.Enable("Skins"))
	env.RunTimers()
	rxp.fake.menuRows({ "Choose a guide", "Export guide" })
	rxp.fake.trust(function() rxp.menuLists[2]:SetSize(220, 78) end)()
	rxp:ShowMenu()
	rxp.fake.open(rxp.menuLists[2])
	rxp.comms.OpenBrandedExport("Popup material export", "Copy this text", "Export content", 480, 240, function() end)
	local dialog = env.RESTEDXP_BRANDED_EXPORT
	local menu = assert(ns.RestedXP.Chrome.MenuPanel(rxp.menuLists[1]))
	local submenu = assert(ns.RestedXP.Chrome.MenuPanel(rxp.menuLists[2]))
	local panel = assert(ns.RestedXP.Chrome.DressPanel(dialog))
	assert(menu:IsShown() and submenu:IsShown() and panel:IsShown())
	Cycle(K, { menu.chrome, submenu.chrome, panel.chrome }, function()
		assert(dialog.obj.titletext:GetText() == "RestedXP: Popup material export", "the leased dialog retains RestedXP's text")
		local guide = K.Skin.Parts(rxp.RXPFrame).backdrop.chrome
		local material = K.Tokens.Material(K.Widgets.Setting("cardMaterial"))
		if material.fill then
			local r, g, b, a = K.Tokens.Color(material.fill)
			assert(W.SameColor(guide.fill[5], r, g, b, math.min(1, a * K.Widgets.Setting("panelOpacity") / 0.75)), "the docked story card remains an ordinary opacity-controlled card")
		end
	end)
	rxp.fake.close(rxp.menuLists[1])
	rxp.fake.close(rxp.menuLists[2])
	assert(not menu:IsShown() and not submenu:IsShown(), "closing the leased menus hides their popup chrome")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local M = dofile("Tools/regression/meters_env.lua")
	local Geometry = dofile("Tools/regression/geometry.lua")
	local env, K, ns = M.New({ game = function(e)
		e._group = { raid = false, size = 2 }
		e._spells[100] = { name = "Mortal Strike", icon = "Interface\\Icons\\ability_warrior_savageblow" }
	end })
	local sources = {}
	for i = 1, 6 do
		sources[i] = { name = "Source " .. i, classFilename = "WARRIOR", totalAmount = 3000 - i * 100, amountPerSecond = 30 - i, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0, sourceGUID = "Player-" .. i }
	end
	env._session = { combatSources = sources, maxAmount = 2900, totalAmount = 15900, durationSeconds = 30 }
	env._sources["Player-1"] = { combatSpells = {
		{ spellID = 100, totalAmount = 1800, amountPerSecond = 18, creatureName = "", overkillAmount = 0, isAvoidable = false, isDeadly = false,
			combatSpellDetails = { unitName = "", unitClassFilename = "", classification = "", isPet = false, isMob = false, amount = 0, specIconID = 0 } },
	}, maxAmount = 1800, totalAmount = 1800 }
	M.Enable(env, K)
	local list = ns.Damage.list
	list.holder:ClearAllPoints()
	list.holder:SetSize(318, 190)
	list.holder:SetPoint("CENTER", K.Scale.Root(), "CENTER")
	list.panel:ClearAllPoints()
	list.panel:SetSize(318, 190)
	list.panel:SetPoint("CENTER", K.Scale.Root(), "CENTER")
	env.RunTimers()
	local row = list.rows[1].frame
	row:GetScript("OnEnter")(row)
	env.RunTimers()
	local split = assert(list.split)
	assert(split.frame:IsShown(), "the real source row hover opens the detail overlay")
	split.frame.GetWidth = function(self)
		local rect, why = Geometry.Rect(self, K.Scale.Root())
		assert(rect, tostring(why))
		return rect.right - rect.left
	end
	-- The split is rows of the card (KSTY-60 item 24), with no popup chrome of its own: the card's material shows
	-- behind it, so cycling the card's material keeps the split open, its size and its spells.
	assert(split.chrome == nil, "the split carries no popup chrome")
	local width, height = split.frame:GetSize()
	assert(type(width) == "number" and type(height) == "number", "the hovered split has measured dimensions")
	local text = split.lines[1].name:GetText()
	assert(text:find("Mortal Strike", 1, true))
	Cycle(K, {}, function()
		assert(split.frame:IsShown(), "the detail overlay remains open")
		assert(W.Near(split.frame:GetWidth(), width) and W.Near(split.frame:GetHeight(), height), "the split size changed from " .. width .. "x" .. height .. " to " .. split.frame:GetWidth() .. "x" .. split.frame:GetHeight())
		assert(split.lines[1].name:GetText() == text, "the split keeps its spell content")
	end)
	row:GetScript("OnLeave")(row)
	env.RunTimers()
	assert(not split.frame:IsShown(), "the detail overlay still closes on leave")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

print("popup consumers: tooltips, StaticPopup/GameMenu, Friends popups, profession results, ready check, RestedXP menus/dialog and meter detail overlay passed")
