-- test-skins-partb-windows.lua: the game menu, group finder, mail, merchant, trainer and professions skins register, wait for their window and restyle it without touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local KEYS = { "gameMenu", "groupFinder", "mail", "merchant", "trainer", "professions" }
local ADDONS = {
	gameMenu = "Blizzard_GameMenu",
	groupFinder = "Blizzard_GroupFinder_VanillaStyle",
	mail = "Blizzard_MailFrame",
	merchant = "Blizzard_UIPanels_Game",
	trainer = "Blizzard_TrainerUI",
	professions = "Blizzard_Professions",
}
local FRAMES = {
	gameMenu = "GameMenuFrame",
	groupFinder = "LFGParentFrame",
	mail = "MailFrame",
	merchant = "MerchantFrame",
	trainer = "ClassTrainerFrame",
	professions = "ProfessionsFrame",
}

local HOOKED = {
	SetAlpha = true, SetVertexColor = true, Show = true, Hide = true, SetShown = true, SetChecked = true,
	SetNormalTexture = true, SetStatusBarColor = true, SetTabSelected = true, Update = true, InitButtons = true,
}

local function Fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

-- Snapshot(B) records each stand-in's fields and how many calls it has had, so Check looks only at what came after.
local function Snapshot(B)
	local snap = {}
	for _, object in ipairs(B.made) do
		snap[object] = { fields = Fields(object), calls = #object._calls }
	end
	return snap
end

-- Check(B, snap): no field written onto a stand-in Blizzard object but a hooked method, and no SetScript, Hide or SetParent on one.
local function Check(B, snap)
	for _, object in ipairs(B.made) do
		local before = snap[object] or { fields = {}, calls = 0 }
		for k in pairs(Fields(object)) do
			assert(before.fields[k] or HOOKED[k], "a field was written onto a Blizzard object: " .. tostring(k))
		end
		for i = before.calls + 1, #object._calls do
			local call = object._calls[i]
			assert(call.method ~= "SetScript", "SetScript on a Blizzard object")
			assert(call.method ~= "Hide", "Hide on a Blizzard object")
			assert(call.method ~= "SetParent", "SetParent on a Blizzard object")
		end
	end
end

-- Stand-in pieces ------------------------------------------------------------------------------------

local P = {}

function P.Button(B, parent, name)
	local button = B.frame("Button", parent, name)
	B.texture(button, "BACKGROUND")
	local text = B.text(button)
	button.GetFontString = function()
		return text
	end
	return button
end

function P.Item(B, parent, name)
	local button = B.frame("Button", parent, name)
	button.slot = B.texture(button, "BACKGROUND")
	button.icon = B.texture(button)
	button.IconBorder = B.texture(button, "OVERLAY")
	return button
end

function P.Dropdown(B, parent)
	local dropdown = B.frame("DropdownButton", parent)
	dropdown.Background = B.texture(dropdown, "BACKGROUND")
	dropdown.Text = B.text(dropdown)
	return dropdown
end

function P.ScrollBar(B, parent)
	local bar = B.frame("EventFrame", parent)
	bar.Track = B.frame("Frame", bar)
	B.texture(bar.Track)
	bar.Track.Thumb = B.frame("Button", bar.Track)
	bar.Thumb = bar.Track.Thumb
	return bar
end

function P.EditBox(B, parent, name)
	local box = B.frame("EditBox", parent, name)
	B.texture(box)
	return box
end

function P.Check(B, parent, name)
	local check = B.frame("CheckButton", parent, name)
	B.texture(check)
	return check
end

function P.SideTab(B, parent)
	local tab = B.frame("Frame", parent)
	tab.Background = B.texture(tab, "BACKGROUND")
	tab.Icon = B.texture(tab)
	tab.SelectedTexture = B.texture(tab, "OVERLAY")
	function tab:SetChecked(checked)
		self.SelectedTexture:SetShown(checked)
	end
	return tab
end

function P.Inset(B, parent, name)
	local inset = B.frame("Frame", parent, name)
	inset.NineSlice = B.frame("Frame", inset)
	B.texture(inset.NineSlice)
	inset.Bg = B.texture(inset, "BACKGROUND")
	return inset
end

-- Window(B, name, opts) -> a stand-in PortraitFrameTemplate or ButtonFrameTemplate window.
function P.Window(B, name, parent)
	local frame = B.frame("Frame", parent, name)
	frame.NineSlice = B.frame("Frame", frame)
	B.texture(frame.NineSlice)
	frame.Bg = B.texture(frame, "BACKGROUND")
	frame.art = B.texture(frame)
	frame.TitleContainer = B.frame("Frame", frame)
	frame.TitleContainer.TitleText = B.text(frame.TitleContainer)
	frame.CloseButton = B.frame("Button", frame)
	B.texture(frame.CloseButton)
	frame.Inset = P.Inset(B, frame)
	frame:Hide()
	return frame
end

function P.ScrollBox(B, parent, rows)
	local box = B.frame("Frame", parent)
	function box:ForEachFrame(fn)
		for _, row in ipairs(rows) do
			fn(row)
		end
	end
	function box:Update() end
	return box
end

function P.RankBar(B, parent)
	local bar = B.frame("Frame", parent)
	bar.Background = B.texture(bar)
	bar.Fill = B.texture(bar)
	bar.Border = B.texture(bar)
	bar.Rank = B.frame("Frame", bar)
	bar.Rank.Text = B.text(bar.Rank)
	function bar:Update(info)
		self.Rank.Text:SetText(info.skillLevel)
	end
	return bar
end

-- Run(key, build) -> env, K, ns, B, frames: the module running, the stand-ins built, the addon loaded and
-- the window shown, so its skin has applied. build(B, env) returns a table of named stand-ins.
local function Run(key, build)
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	local B = S.Blizzard(env)
	local made = build(B, env)
	local snap = Snapshot(B)
	S.LoadAddOn(env, ADDONS[key])
	S.Show(env[FRAMES[key]])
	assert(ns.Skins.IsApplied(key), key .. " applies on its window's first show")
	assert(S.Logged(env, key .. ": applied"), key .. " logs that it applied")
	Check(B, snap)
	assert(#env._errors == 0, key .. ": " .. tostring(env._errors[1]))
	return env, K, ns, B, made
end

local function Hidden(region)
	return region:GetAlpha() == 0
end

local function Skinned(K, frame, kind)
	return K.Skin.IsSkinned(frame, kind)
end

-- Registration ----------------------------------------------------------------------------------------

do
	local env, K, ns = S.New()
	local keys = {}
	for _, def in ipairs(ns.Skins.List()) do
		keys[#keys + 1] = def.key
	end
	local found = 0
	for _, key in ipairs(keys) do
		if key == KEYS[found + 1] then
			found = found + 1
		end
	end
	assert(found == #KEYS, "part B's skins register in Skins.xml order: " .. table.concat(KEYS, ", "))
	for _, key in ipairs(KEYS) do
		local def = ns.Skins.Get(key)
		assert(def.addon == ADDONS[key] and def.frame == FRAMES[key], key .. " waits for " .. ADDONS[key] .. " and " .. FRAMES[key])
		assert(#def.help < 100, key .. ": help under 100 characters")
		assert(K.Options.Row("Skins", key .. ".enabled"), key .. " has a switch")
	end
	for _, key in ipairs({ "mail", "merchant", "professions" }) do
		local row = K.Options.Row("Skins", key .. ".qualityRims")
		assert(row and row.type == "toggle", key .. " has a quality rims switch")
		assert(K.Store.Defaults("Skins")[key].qualityRims == true, "quality rims are on by default")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A window left untouched until it shows, and a window with no parts still applies -----------------------

do
	local env, K, ns = S.New()
	K.Modules.Enable("Skins")
	for _, key in ipairs(KEYS) do
		local B = S.Blizzard(env)
		local frame = B.frame("Frame", nil, FRAMES[key])
		frame:Hide()
		S.LoadAddOn(env, ADDONS[key])
		assert(not ns.Skins.IsApplied(key), key .. " waits for its window to show")
		S.Show(frame)
		assert(ns.Skins.IsApplied(key), key .. " applies to a bare window")
	end
	assert(S.Logged(env, "is missing on this client"), "missing parts are logged")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Game menu --------------------------------------------------------------------------------------------

do
	local env, K, ns, _, made = Run("gameMenu", function(B)
		local menu = B.frame("Frame", nil, "GameMenuFrame")
		menu.Border = B.frame("Frame", menu)
		local border = B.texture(menu.Border)
		menu.Header = B.frame("Frame", menu)
		local headerArt = B.texture(menu.Header)
		menu.Header.Text = B.text(menu.Header)
		local buttons = { P.Button(B, menu), P.Button(B, menu) }
		menu.buttonPool = {
			EnumerateActive = function()
				local i = 0
				return function()
					i = i + 1
					return buttons[i]
				end
			end,
		}
		function menu.InitButtons()
			for _, button in ipairs(buttons) do
				button._scripts.OnEnter, button._scripts.OnLeave = nil, nil
			end
		end
		menu:Hide()
		return { menu = menu, border = border, headerArt = headerArt, buttons = buttons }
	end)
	assert(Hidden(made.border) and Hidden(made.headerArt), "the dialog border and header art are hidden")
	assert(Skinned(K, made.menu, "Backdrop"), "a glass panel behind the menu")
	assert(made.menu.Header.Text:GetFont() == (ns.Style.Font("heading")), "the title takes the module's heading font")
	for _, button in ipairs(made.buttons) do
		assert(Skinned(K, button, "Button"), "each menu button is a KstyleUI tile")
	end
	local button = made.buttons[1]
	made.menu:InitButtons()
	W.Enter(button)
	W.Settle(env)
	assert((K.Skin.Parts(button).hoverT or 0) == 1, "hover still works after Blizzard rebuilds the menu")
	W.Leave(button)
	W.Settle(env)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Group finder -----------------------------------------------------------------------------------------

do
	local _, K, ns, _, made = Run("groupFinder", function(B, env)
		local parent = B.frame("Frame", nil, "LFGParentFrame")
		parent:Hide()
		P.Button(B, parent, "LFGParentFrameCloseButton")
		parent.Tab1, parent.Tab2, parent.Tab3 = P.Button(B, parent), P.Button(B, parent), P.Button(B, parent)
		parent.ListingTab, parent.BrowsingTab, parent.WhoListingTab = P.SideTab(B, parent), P.SideTab(B, parent), P.SideTab(B, parent)
		local listing = P.Window(B, "LFGListingFrame", parent)
		listing.BackButton, listing.PostButton = P.Button(B, listing), P.Button(B, listing)
		listing.ActivityView = B.frame("Frame", listing)
		local view = listing.ActivityView
		view.BarTop = B.texture(view)
		view.PlayStyleDropdown = P.Dropdown(B, view)
		view.ScrollBar = P.ScrollBar(B, view)
		view.Comment = B.frame("ScrollFrame", view)
		B.texture(view.Comment)
		view.Comment.ScrollBar = P.ScrollBar(B, view.Comment)
		local browse = P.Window(B, "LFGBrowseFrame", parent)
		browse.CategoryDropdown = P.Dropdown(B, browse)
		browse.RefreshButton = B.frame("Button", browse)
		browse.RefreshButton.Icon = B.texture(browse.RefreshButton)
		local row = B.frame("Button", browse)
		row.ResultBG = B.texture(row)
		row.Selected = B.texture(row)
		row.Name = B.text(row)
		browse.ScrollBox = P.ScrollBox(B, browse, { row })
		browse.ScrollBar = P.ScrollBar(B, browse)
		local who = P.Window(B, "LFGWhoListFrame", parent)
		who.EditBox = P.EditBox(B, who)
		who.FilterDropdown = P.Dropdown(B, who)
		env.LFGVanillaTestRow = row
		return { parent = parent, listing = listing, browse = browse, who = who, row = row }
	end)
	assert(Skinned(K, made.listing, "Window") and Skinned(K, made.browse, "Window") and Skinned(K, made.who, "Window"), "each page is a glass window")
	assert(Skinned(K, made.parent.Tab1, "Tab"), "the bottom tabs get the accent underline")
	assert(ns.Parts.RimOf(made.parent.ListingTab) and Hidden(made.parent.ListingTab.Background), "the side tabs get the shared rimmed side tab")
	assert(Skinned(K, made.listing.BackButton, "Button") and Skinned(K, made.listing.ActivityView.ScrollBar, "ScrollBar"))
	assert(Hidden(made.listing.ActivityView.BarTop), "the activity view's art is hidden")
	assert(Skinned(K, made.listing.ActivityView.Comment, "Backdrop"), "the comment box is a raised tile")
	assert(Hidden(made.row.ResultBG) and Hidden(made.row.Selected), "a result row loses Blizzard's bars")
	assert(Skinned(K, made.row, "Backdrop"), "and becomes a tile")
	assert(Skinned(K, made.who.EditBox, "EditBox"), "the who search box is skinned")
	assert(Skinned(K, made.browse.RefreshButton, "Backdrop") and not Hidden(made.browse.RefreshButton.Icon), "the refresh button keeps its icon")
end

-- Mail -------------------------------------------------------------------------------------------------

do
	local env, K, ns, _, made = Run("mail", function(B, env)
		local mail = P.Window(B, "MailFrame")
		mail.numTabs = 2
		P.Button(B, mail, "MailFrameTab1")
		P.Button(B, mail, "MailFrameTab2")
		local inbox = B.frame("Frame", mail, "InboxFrame")
		local inboxBg = B.texture(inbox)
		inbox.PrevPageButton, inbox.NextPageButton = P.Button(B, inbox), P.Button(B, inbox)
		inbox.OpenAllMail = P.Button(B, inbox)
		local mailItem = B.frame("Frame", inbox, "MailItem1")
		B.texture(mailItem)
		mailItem.Button = P.Item(B, mailItem, "MailItem1Button")
		local cod = B.texture(mailItem.Button)
		env.MailItem1ButtonCODBackground = cod
		local send = B.frame("Frame", mail, "SendMailFrame")
		local bar = B.texture(send)
		local coin = B.texture(send)
		env.SendMailErrorCoin = coin
		P.EditBox(B, send, "SendMailNameEditBox")
		local money = B.frame("Frame", send, "SendMailMoney")
		money.gold = P.EditBox(B, money)
		money.gold.texture = B.texture(money.gold)
		P.Check(B, send, "SendMailCODButton")
		P.Button(B, send, "SendMailMailButton")
		P.Inset(B, send, "SendMailMoneyInset")
		local letter = P.Window(B, "OpenMailFrame")
		P.Item(B, letter, "OpenMailAttachmentButton1")
		P.Button(B, letter, "OpenMailReplyButton")
		return { mail = mail, inboxBg = inboxBg, mailItem = mailItem, cod = cod, bar = bar, coin = coin, money = money, letter = letter }
	end)
	assert(Skinned(K, made.mail, "Window") and Skinned(K, made.letter, "Window"), "the mailbox and open letters are glass windows")
	assert(Skinned(K, made.mail, "Tabs"), "the inbox and send tabs are skinned")
	assert(Hidden(made.inboxBg) and Hidden(made.bar), "the inbox paper and the send form's bars are hidden")
	assert(not Hidden(made.coin), "the send form's error coin stays")
	local item = K.Safe.Side(made.mailItem.Button).partBItem
	assert(item and item.window == "mail", "inbox items get rims that follow the mail switch")
	assert(not Hidden(made.cod), "the cash on delivery tint stays on inbox items")
	assert(not Hidden(made.money.gold.texture) and Skinned(K, made.money.gold, "EditBox"), "money boxes keep their coin")
	assert(Skinned(K, env.SendMailCODButton, "CheckBox"), "the cash on delivery switch is a KstyleUI check box")
	assert(Skinned(K, env.SendMailNameEditBox, "EditBox") and Skinned(K, env.SendMailMailButton, "Button"))
	assert(K.Safe.Side(env.OpenMailAttachmentButton1).partBItem, "an open letter's attachments get rims")
	assert(Skinned(K, env.OpenMailReplyButton, "Button"))
	assert(ns.Skins.IsApplied("mail"))
end

-- Merchant ---------------------------------------------------------------------------------------------

do
	local _, K, _, _, made = Run("merchant", function(B)
		local merchant = P.Window(B, "MerchantFrame")
		merchant.FilterDropdown = P.Dropdown(B, merchant)
		local slots = {}
		for i = 1, 3 do
			local slot = B.frame("Frame", merchant, "MerchantItem" .. i)
			slot.SlotTexture = B.texture(slot)
			slot.ItemButton = P.Item(B, slot)
			slots[i] = slot
		end
		local buyback = B.frame("Frame", merchant, "MerchantBuyBackItem")
		buyback.ItemButton = P.Item(B, buyback)
		local repair = B.frame("Button", merchant, "MerchantRepairAllButton")
		repair.slot = B.texture(repair)
		repair.Icon = B.texture(repair)
		local prev = P.Button(B, merchant, "MerchantPrevPageButton")
		P.Inset(B, merchant, "MerchantMoneyInset")
		return { merchant = merchant, slots = slots, buyback = buyback, repair = repair, prev = prev }
	end)
	for _, slot in ipairs(made.slots) do
		assert(Hidden(slot.SlotTexture) and Skinned(K, slot, "Backdrop"), "each item row is a tile")
		assert(W.SameColor(K.Skin.Parts(slot).backdrop.chrome.fill[5], K.Tokens.Color("buttonFill")), "on the near-black button body")
		assert(K.Safe.Side(slot.ItemButton).partBItem, "each item gets a rim")
	end
	assert(K.Safe.Side(made.buyback.ItemButton).partBItem, "the buyback item too")
	assert(Hidden(made.repair.slot) and not Hidden(made.repair.Icon), "the repair button keeps its icon on a tile")
	assert(K.Safe.Side(made.prev).partBArrow, "the page buttons get chevrons")
	assert(Skinned(K, made.merchant.FilterDropdown, "Backdrop"), "the filter is the shared KstyleUI dropdown")
end

-- Trainer ----------------------------------------------------------------------------------------------

do
	local env, K, ns, _, made = Run("trainer", function(B, env)
		local trainer = P.Window(B, "ClassTrainerFrame")
		local bar = B.frame("StatusBar", trainer, "ClassTrainerStatusBar")
		bar:SetStatusBarTexture("Interface\\Blizzard\\Bar")
		B.add(bar:GetStatusBarTexture())
		local barArt = B.texture(bar)
		trainer.FilterDropdown = P.Dropdown(B, trainer)
		trainer.TrainButton = P.Button(B, trainer)
		trainer.ScrollBar = P.ScrollBar(B, trainer)
		local skill = B.frame("Button", trainer)
		skill.icon = B.texture(skill)
		skill.selectedTex = B.texture(skill)
		local category = B.frame("Button", trainer)
		category.LeftPiece = B.texture(category)
		category.Label = B.text(category)
		trainer.ScrollBox = P.ScrollBox(B, trainer, { skill, category })
		local train = P.Button(B, trainer, "ClassTrainerTrainButton")
		trainer.TrainButton = train
		env.ClassTrainerFrame_InitCategoryButton = function(row)
			row._scripts.OnEnter, row._scripts.OnLeave = nil, nil
		end
		env.ClassTrainerFrame_SetTrainButtonEnabled = function()
			train._scripts.OnEnter, train._scripts.OnLeave = nil, nil
		end
		return { trainer = trainer, bar = bar, barArt = barArt, skill = skill, category = category, train = train }
	end)
	assert(Skinned(K, made.trainer, "Window"))
	assert(Hidden(made.barArt) and not Hidden(made.bar:GetStatusBarTexture()), "the skill bar keeps its fill and loses its frame")
	assert(W.LastCall(made.bar:GetStatusBarTexture(), "SetTexture")[1] == ns.Style.BarTexture(), "the skill bar takes the module's bar texture")
	assert(Hidden(made.skill.selectedTex) and not Hidden(made.skill.icon) and K.Safe.Side(made.skill).partBSelect, "skill rows become tiles that light when selected")
	assert(Hidden(made.category.LeftPiece) and made.category.Label:GetFont() == (ns.Style.Font("body")), "category rows lose the header art")
	assert(Skinned(K, made.trainer.TrainButton, "Button"))
	env.ClassTrainerFrame_InitCategoryButton(made.category)
	W.Enter(made.category)
	W.Settle(env)
	assert(K.Safe.Side(made.category).partBSelect.hoverT == 1, "a category row Blizzard reinitialises still lights under the mouse")
	assert(made.category.Label:GetFont() == (ns.Style.Font("body")), "and keeps the module's font after Blizzard's hover font")
	W.Leave(made.category)
	env.ClassTrainerFrame_SetTrainButtonEnabled(true)
	W.Enter(made.train)
	W.Settle(env)
	assert(K.Skin.Parts(made.train).hoverT == 1, "the train button keeps its hover after Blizzard resets its scripts")
	W.Leave(made.train)
	W.Settle(env)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Professions ------------------------------------------------------------------------------------------

do
	local env, K, ns, _, made = Run("professions", function(B)
		local frame = P.Window(B, "ProfessionsFrame")
		frame.ProfessionsOverviewTab = P.SideTab(B, frame)
		frame.rightProfessionTabs = { P.SideTab(B, frame) }
		local page = B.frame("Frame", frame)
		frame.CraftingPage = page
		page.art = B.texture(page)
		local list = B.frame("Frame", page)
		page.RecipeList = list
		list.Background = B.texture(list)
		list.SearchBox = P.EditBox(B, list)
		list.FilterDropdown = P.Dropdown(B, list)
		list.ScrollBar = P.ScrollBar(B, list)
		page.SchematicForm = B.frame("Frame", page)
		page.SchematicForm.Background = B.texture(page.SchematicForm)
		page.RankBar = P.RankBar(B, page)
		page.CreateMultipleInputBox = P.EditBox(B, page)
		page.CreateMultipleInputBox.IncrementButton = P.Button(B, page.CreateMultipleInputBox)
		page.CreateButton, page.CreateAllButton = P.Button(B, page), P.Button(B, page)
		page.Prof0ToolSlot = P.Item(B, page)
		frame.BookPage = B.frame("Frame", frame)
		frame.BookPage.ProfessionsContentFrame = B.frame("Frame", frame.BookPage)
		local card = B.frame("Frame", frame.BookPage.ProfessionsContentFrame)
		frame.BookPage.ProfessionsContentFrame.PrimaryProfession1 = card
		card.StatusBar = P.RankBar(B, card)
		local spell = B.frame("CheckButton", card)
		spell.IconTexture = B.texture(spell)
		spell.IconBorder = B.texture(spell)
		card.spellButtons = { spell }
		return { frame = frame, page = page, list = list, card = card, spell = spell }
	end)
	assert(Skinned(K, made.frame, "Window"))
	assert(ns.Parts.RimOf(made.frame.ProfessionsOverviewTab) and ns.Parts.RimOf(made.frame.rightProfessionTabs[1]), "the side tabs get the shared rimmed side tab")
	assert(Hidden(made.page.art) and Hidden(made.list.Background), "the page and recipe list art is hidden")
	assert(Skinned(K, made.list, "Backdrop") and Skinned(K, made.list.SearchBox, "EditBox"), "the recipe list is a raised tile with a KstyleUI search box")
	assert(Skinned(K, made.page.SchematicForm, "Backdrop"))
	local bar = K.Safe.Side(made.page.RankBar).partBBar
	assert(bar and bar.fill, "the skill bar is a KstyleUI bar")
	made.page.RankBar:Update({ skillLevel = 75, maxSkillLevel = 150 })
	assert(bar.fill:GetValue() == 75, "it follows Blizzard's updates")
	assert(K.Safe.Side(made.card.StatusBar).partBBar, "the overview cards' skill bars too")
	assert(not Hidden(made.spell.IconTexture) and K.Safe.Side(made.spell).partBItem, "profession spell buttons keep their icon on a rim")
	assert(K.Safe.Side(made.page.Prof0ToolSlot).partBItem, "tool slots get rims")
	assert(K.Safe.Side(made.page.CreateMultipleInputBox.IncrementButton).partBArrow, "the craft count spinner gets chevrons")
	assert(made.page.CreateButton:GetFontString():GetFont() == (ns.Style.Font("body")), "button labels take the module's text settings")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part B windows ok")
