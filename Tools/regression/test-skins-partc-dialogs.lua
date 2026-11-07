-- test-skins-partc-dialogs.lua: the popup, ready check and addon list skins restyle StaticPopup1 to 4, ReadyCheckListenerFrame and AddonList without touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local HOOKED = { Show = true, Hide = true, SetShown = true, SetDesaturated = true, SetTextColor = true }

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

local function RimColor(ns, frame)
	local rim = ns.Parts.RimOf(frame)
	assert(rim, "the frame has a KstyleUI rim")
	if not rim.rim[1]:IsShown() then
		return nil
	end
	return rim.rim[1]:GetVertexColor()
end

local function Button(B, parent, key)
	local button = B.frame("Button", parent)
	button.Art = B.texture(button)
	if key then
		parent[key] = button
	end
	return button
end

local function EditBox(B, parent, key)
	local box = B.frame("EditBox", parent)
	box.Left, box.Right = B.texture(box), B.texture(box)
	parent[key] = box
	return box
end

local function Dropdown(B, parent)
	local drop = B.frame("Button", parent)
	drop.Background, drop.Arrow, drop.Text = B.texture(drop, "BACKGROUND"), B.texture(drop), B.text(drop)
	return drop
end

-- Popup(B, i) -> the stand-in StaticPopup<i> from StaticPopupTemplate.
local function Popup(B, i)
	local f = B.frame("Frame", nil, "StaticPopup" .. i)
	f:Hide()
	f.BG = B.frame("Frame", f)
	f.BG.Top, f.BG.Bottom = B.texture(f.BG, "BACKGROUND"), B.texture(f.BG, "BACKGROUND")
	f.Text = B.text(f)
	f.AlertIcon = B.texture(f)
	f.CloseButton = Button(B, f)
	f.ButtonContainer = B.frame("Frame", f)
	for n = 1, 4 do
		Button(B, f.ButtonContainer, "Button" .. n)
	end
	Button(B, f, "ExtraButton")
	local box = EditBox(B, f, "EditBox")
	box.NineSlice = B.frame("Frame", box)
	box.NineSliceArt = B.texture(box.NineSlice)
	box.Instructions = B.text(box)
	f.Dropdown = Dropdown(B, f)
	f.MoneyInputFrame = B.frame("Frame", f)
	for _, key in ipairs({ "gold", "silver", "copper" }) do
		local coin = EditBox(B, f.MoneyInputFrame, key)
		coin.texture = B.texture(coin)
	end
	local item = B.frame("Frame", f)
	f.ItemFrame = item
	item.NameFrame = B.texture(item)
	item.Text = B.text(item)
	item.Item = B.frame("Button", item)
	item.Item.icon = B.texture(item.Item, "BORDER")
	item.Item.IconBorder = B.texture(item.Item, "OVERLAY")
	function item.DisplayInfo(self, _, _, color)
		self.Text:SetTextColor(unpack(color or { 1, 1, 1, 1 }))
	end
	return f
end

-- Popups ----------------------------------------------------------------------------------------------

do
	local B, popups, snap
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			popups = {}
			for i = 1, 4 do
				popups[i] = Popup(B, i)
			end
			popups[1].ItemFrame:DisplayInfo("link", "Bracers", { 0.64, 0.21, 0.93, 1 })
			snap = B.snapshot()
		end,
	})
	assert(K.Options.Row("Skins", "popups.enabled"), "popups have a switch")
	K.Modules.Enable("Skins")
	assert(not ns.Skins.IsApplied("popups"), "nothing happens before a popup shows")
	S.Show(popups[1])
	assert(ns.Skins.IsApplied("popups"), "the first popup skins every popup frame")
	for _, f in ipairs(popups) do
		assert(K.Skin.IsSkinned(f, "Backdrop") and Alpha(f.BG.Top) == 0 and Alpha(f.BG.Bottom) == 0, "a glass panel replaces the dialog art")
		assert(K.Skin.IsSkinned(f.CloseButton, "CloseButton"), "the close button becomes the close glyph")
		for n = 1, 4 do
			assert(K.Skin.IsSkinned(f.ButtonContainer["Button" .. n], "Button"), "every dialog button is restyled")
		end
		assert(K.Skin.IsSkinned(f.ExtraButton, "Button"))
		assert(K.Skin.IsSkinned(f.EditBox, "EditBox") and Alpha(f.EditBox.NineSliceArt) == 0 and Alpha(f.EditBox.Left) == 0, "the edit box wears a raised tile")
		assert(K.Skin.IsSkinned(f.Dropdown, "Backdrop") and Alpha(f.Dropdown.Arrow) == 1, "the dropdown wears a raised tile and keeps its arrow")
		local gold = f.MoneyInputFrame.gold
		assert(K.Skin.IsSkinned(gold, "EditBox") and Alpha(gold.Left) == 0 and Alpha(gold.texture) == 1, "the money boxes keep their coin icons")
		assert(Alpha(f.ItemFrame.NameFrame) == 0 and Alpha(f.ItemFrame.Item.icon) == 1 and Alpha(f.ItemFrame.Item.IconBorder) == 0, "the item frame's art goes, its icon stays")
		assert(Alpha(f.AlertIcon) == 1, "the alert icon stays")
		assert(#W.Calls(f.Text, "SetFont") == 0, "popup text keeps the game's scaled font")
	end
	local er, eg, eb = K.Theme.Brighten(0.64, 0.21, 0.93)
	local r, g, b = RimColor(ns, popups[1].ItemFrame.Item)
	assert(W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb), "an item Blizzard showed before the skin applied is rimmed at once")
	local item = popups[2].ItemFrame
	item:DisplayInfo("link", "Bracers", { 0.64, 0.21, 0.93, 1 })
	r, g, b = RimColor(ns, item.Item)
	assert(W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb), "Blizzard's colour array for the item rims its icon")
	item:DisplayInfo("link", "Linen", { 1, 1, 1, 1 })
	assert(RimColor(ns, item.Item) == nil, "a white or grey item stays plain")
	item:DisplayInfo("link", "Gold", nil)
	assert(RimColor(ns, item.Item) == nil, "no colour leaves the rim plain")
	item.Text:SetTextColor(0, 0.44, 0.87)
	assert(RimColor(ns, item.Item) ~= nil, "any colour Blizzard gives the item name, as the standard callback does, rims the icon")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Ready check ---------------------------------------------------------------------------------------------

do
	local B, f, listener, snap
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			f = B.frame("Frame", nil, "ReadyCheckFrame")
			f:Hide()
			listener = B.frame("Frame", f, "ReadyCheckListenerFrame")
			listener.Bg = B.texture(listener, "BACKGROUND")
			listener.Text = B.text(listener)
			listener.NineSlice = B.frame("Frame", listener)
			listener.NineSliceArt = B.texture(listener.NineSlice)
			listener.TitleContainer = B.frame("Frame", listener)
			listener.TitleContainer.TitleText = B.text(listener.TitleContainer)
			listener.PortraitContainer = B.frame("Frame", listener)
			listener.PortraitContainer.Portrait = B.texture(listener.PortraitContainer, "BACKGROUND")
			Button(B, listener, "YesButton")
			Button(B, listener, "NoButton")
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	assert(K.Options.Row("Skins", "readyCheck.enabled"), "the ready check has a switch")
	K.Modules.Enable("Skins")
	S.Show(f)
	assert(ns.Skins.IsApplied("readyCheck"), "the first ready check skins the dialog")
	assert(K.Skin.IsSkinned(listener, "Window") and Alpha(listener.Bg) == 0 and Alpha(listener.NineSliceArt) == 0, "a glass panel replaces the dialog art")
	assert(Alpha(listener.PortraitContainer.Portrait) == 0, "the portrait and its ring go with the rest of the window art")
	assert(FontPath(listener.TitleContainer.TitleText) == Style.Font("heading"), "the title wears the heading font")
	assert(FontPath(listener.Text) == Style.Font("body"), "the question wears the body font")
	assert(K.Skin.IsSkinned(listener.YesButton, "Button") and K.Skin.IsSkinned(listener.NoButton, "Button"), "ready and not ready are restyled")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The addon list ------------------------------------------------------------------------------------------

-- AddonList(env, B) -> the stand-in AddonList Blizzard_AddOnList builds, with an entry and a category row.
local function AddonList(env, B)
	local p = {}
	local f = B.frame("Frame", nil, "AddonList")
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.Inset = B.frame("Frame", f)
	p.inset = B.texture(f.Inset)
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	Button(B, f, "CloseButton")
	f.Dropdown = Dropdown(B, f)
	local force = B.frame("CheckButton", f)
	f.ForceLoad = force
	B.texture(force)
	p.forceLabel = B.text(force)
	local search = EditBox(B, f, "SearchBox")
	search.searchIcon = B.texture(search, "OVERLAY")
	local perf = B.frame("Frame", f)
	f.Performance = perf
	perf.Header, perf.Current = B.text(perf), B.text(perf)
	perf.Divider = B.texture(perf)
	for _, key in ipairs({ "CancelButton", "OkayButton", "EnableAllButton", "DisableAllButton" }) do
		Button(B, f, key)
	end
	p.okayLabel = B.text(f.OkayButton)
	f.OkayButton:SetFontString(p.okayLabel)
	f.ScrollBar = B.frame("Frame", f)
	f.ScrollBox = S.ScrollBox(B, f)
	local entry = B.frame("Button", f.ScrollBox.ScrollTarget)
	entry.Title, entry.Status, entry.Reload = B.text(entry), B.text(entry), B.text(entry)
	entry:SetHighlightTexture(B.texture(entry, "HIGHLIGHT"))
	local check = B.frame("CheckButton", entry)
	entry.Enabled = check
	check.CheckedTexture = B.texture(check, "ARTWORK")
	B.texture(check, "BACKGROUND")
	Button(B, entry, "LoadAddonButton")
	f.ScrollBox.AddRow(entry, {})
	local category = B.frame("Button", f.ScrollBox.ScrollTarget)
	category.Title = B.text(category)
	category.CollapseExpand = Button(B, category)
	category:SetHighlightTexture(B.texture(category, "HIGHLIGHT"))
	f.ScrollBox.AddRow(category, {})
	p.frame, p.entry, p.category = f, entry, category
	return p
end

do
	local B, p, snap
	local env, K, ns = S.New({
		setup = S.UseScrollUtil,
		loaded = { Blizzard_AddOnList = true },
		before = function(env)
			B = S.Blizzard(env)
			p = AddonList(env, B)
			snap = B.snapshot()
		end,
	})
	local Style, W2 = ns.Style, K.Widgets
	assert(K.Options.Row("Skins", "addonList.enabled"), "the addon list has a switch")
	K.Modules.Enable("Skins")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("addonList"), "the first show skins the list")
	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(f.Bg) == 0 and Alpha(p.inset) == 0, "a glass panel replaces the window art")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"))
	assert(K.Skin.IsSkinned(f.Dropdown, "Backdrop"), "the character dropdown wears a raised tile")
	assert(K.Skin.IsSkinned(f.ForceLoad, "CheckBox") and FontPath(p.forceLabel) == Style.Font("body"), "load out of date is a KstyleUI check box")
	assert(K.Skin.IsSkinned(f.SearchBox, "EditBox") and Alpha(f.SearchBox.searchIcon) == 1, "the search box keeps its icon")
	assert(Alpha(f.Performance.Divider) == 0 and FontPath(f.Performance.Header) == Style.Font("caption"), "the performance header reads as a caption over an accent line")
	for _, key in ipairs({ "CancelButton", "OkayButton", "EnableAllButton", "DisableAllButton" }) do
		assert(K.Skin.IsSkinned(f[key], "Button"), key .. " is restyled")
	end
	assert(FontPath(p.okayLabel) == Style.Font("body"), "button labels wear the body font")
	assert(K.Skin.IsSkinned(f.ScrollBar, "ScrollBar"))

	local entry = p.entry
	assert(K.Skin.IsSkinned(entry.Enabled, "CheckBox") and K.Skin.IsSkinned(entry.LoadAddonButton, "Button"), "an entry's check box and load button are restyled")
	assert(FontPath(entry.Title) == Style.Font("body") and FontPath(entry.Status) == Style.Font("caption"), "entry text wears the skin fonts")
	local highlight = entry:GetHighlightTexture()
	assert(W.LastCall(highlight, "SetColorTexture"), "the row highlight becomes a flat wash")
	local ar, ag, ab = Style.Accent()
	assert(W.SameRGB(highlight, ar, ag, ab), "in the module's accent")
	local mark = K.Skin.Parts(entry.Enabled).mark
	entry.Enabled:SetChecked(true)
	entry.Enabled.CheckedTexture:SetDesaturated(false)
	assert(W.SameRGB(mark, K.Theme.Accent()), "an addon on for every character gets the accent mark")
	entry.Enabled.CheckedTexture:SetDesaturated(true)
	assert(W.SameRGB(mark, W2.Rgba("text")), "an addon on for some characters gets a grey mark, as Blizzard's grey check")
	entry.Enabled.CheckedTexture:SetDesaturated(false)
	assert(W.SameRGB(mark, K.Theme.Accent()))
	K.Options.Write("Skins", "accent.source", "custom")
	K.Options.Write("Skins", "accent.color", { r = 0.2, g = 0.4, b = 0.6 })
	assert(W.SameRGB(mark, 0.2, 0.4, 0.6), "check marks follow the module's accent setting")
	entry.Enabled.CheckedTexture:SetDesaturated(true)
	assert(W.SameRGB(mark, W2.Rgba("text")), "and the grey mark survives the accent painter")
	assert(W.SameRGB(highlight, 0.2, 0.4, 0.6), "row highlights follow it too")
	assert(FontPath(p.category.Title) == Style.Font("caption"), "a category reads as a caption")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part C dialogs ok")
