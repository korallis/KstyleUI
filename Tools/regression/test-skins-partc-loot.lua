-- test-skins-partc-loot.lua: the loot window and group loot roll skins restyle Forever's LootFrame and GroupLootFrame1 to 4, with quality rims, without touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local QUALITY_COMMON, QUALITY_EPIC = 1, 4

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

local function SameQuality(K, r, g, b, quality)
	local qr, qg, qb = K.Theme.QualityColor(quality)
	return W.Near(r, qr) and W.Near(g, qg) and W.Near(b, qb)
end

-- ItemButton(B, parent) -> a stand-in ItemButton: icon, quality border, normal texture and count.
local function ItemButton(B, parent)
	local button = B.frame("Button", parent)
	button.icon = B.texture(button, "BORDER")
	button.IconBorder = B.texture(button, "OVERLAY")
	button.NormalTexture = B.texture(button)
	button.Count = B.text(button)
	return button
end

-- LootRow(B, box, data, money) -> a stand-in LootFrameItemElementTemplate row, or a money row.
local function LootRow(B, box, data, money)
	local row = B.frame("Frame", box.ScrollTarget)
	row.NameFrame = B.texture(row, "BACKGROUND")
	row.BorderFrame = B.texture(row, "BORDER")
	row.IconQuestTexture = B.texture(row, "OVERLAY")
	row.HighlightNameFrame = B.texture(row, "OVERLAY")
	row.HighlightNameFrame:Hide()
	row.PushedNameFrame = B.texture(row, "OVERLAY")
	row.Text = B.text(row)
	if not money then
		row.QualityStripe = B.texture(row, "BACKGROUND")
		row.QualityText = B.text(row)
	end
	row.Item = ItemButton(B, row)
	row.Item:SetFrameLevel(row:GetFrameLevel())
	local current = data
	function row.GetElementData()
		return current
	end
	function row.SetData(_, value)
		current = value
	end
	return row
end

-- Loot(env, B) -> the stand-in LootFrame Blizzard_UIPanels_Game builds, with an item row, a money row and an empty row.
local function Loot(env, B)
	local p = {}
	local f = B.frame("Frame", nil, "LootFrame")
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	p.border = B.texture(f.NineSlice)
	f.Bg = B.frame("Frame", f)
	p.bg = B.texture(f.Bg, "BACKGROUND")
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	f.ClosePanelButton = B.frame("Button", f)
	p.closeArt = B.texture(f.ClosePanelButton)
	local box = S.ScrollBox(B, f)
	f.ScrollBox = box
	p.upper, p.lower = B.texture(box, "OVERLAY"), B.texture(box, "OVERLAY")
	function box.GetUpperShadowTexture()
		return p.upper
	end
	function box.GetLowerShadowTexture()
		return p.lower
	end
	f.ScrollBar = B.frame("Frame", f)
	p.epic = box.AddRow(LootRow(B, box, { slotIndex = 1, quality = QUALITY_EPIC }), { slotIndex = 1, quality = QUALITY_EPIC })
	p.money = box.AddRow(LootRow(B, box, { slotIndex = 2, quality = QUALITY_COMMON }, true), { slotIndex = 2, quality = QUALITY_COMMON })
	p.empty = box.AddRow(B.frame("Frame", box.ScrollTarget), { slotIndex = 3 })
	p.late = LootRow(B, box, { slotIndex = 4, quality = QUALITY_COMMON })
	p.frame, p.box = f, box
	return p
end

-- Roll(B, i) -> the stand-in GroupLootFrame<i> from MKBGroupLootFrameTemplate.
local function Roll(B, i)
	local f = B.frame("Frame", nil, "GroupLootFrame" .. i)
	f:Hide()
	f:SetFrameLevel(1)
	f.Background = B.texture(f, "BACKGROUND")
	f.Border = B.texture(f, "BORDER")
	f.Name = B.text(f)
	local icon = B.frame("Button", f)
	f.IconFrame = icon
	icon.Icon = B.texture(icon)
	icon.Count = B.text(icon)
	icon.Border = B.texture(icon, "OVERLAY")
	local timer = B.frame("StatusBar", f)
	f.Timer = timer
	timer.Background = B.texture(timer, "BACKGROUND")
	timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
	B.add(timer:GetStatusBarTexture())
	timer:SetStatusBarColor(1, 1, 0)
	timer:SetMinMaxValues(0, 60000)
	timer:SetValue(60000)
	f.LootButtonContainer = B.frame("Frame", f)
	for _, key in ipairs({ "NeedButton", "PassButton", "GreedButton" }) do
		local button = B.frame("Button", f.LootButtonContainer)
		button.Art = B.texture(button)
		f.LootButtonContainer[key] = button
	end
	return f
end

-- The loot window, as Forever builds it ----------------------------------------------------------------

do
	local B, p, snap
	local env, K, ns = S.New({
		setup = S.UseScrollUtil,
		before = function(env)
			B = S.Blizzard(env)
			p = Loot(env, B)
			snap = B.snapshot()
		end,
	})
	local Style, Kit = ns.Style, ns.PartC
	assert(K.Options.Row("Skins", "loot.enabled"), "the loot window has a switch")
	assert(K.Options.Row("Skins", "loot.qualityBorders") and K.Options.Row("Skins", "loot.qualityFrom"), "and its quality border settings")
	K.Modules.Enable("Skins")
	assert(not ns.Skins.IsApplied("loot"), "nothing happens before the window opens")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("loot") and S.Logged(env, "loot: applied"), "the first show skins the window")

	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(p.bg) == 0 and Alpha(p.border) == 0, "a glass panel replaces Blizzard's flat panel")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"), "the title wears the heading font")
	assert(K.Skin.IsSkinned(f.ClosePanelButton, "CloseButton") and Alpha(p.closeArt) == 0, "the close button becomes the close glyph")
	assert(K.Skin.IsSkinned(f.ScrollBar, "ScrollBar"), "the scroll bar is restyled")
	assert(Alpha(p.upper) == 0 and Alpha(p.lower) == 0, "the list's shadows go")

	local row = p.epic
	assert(Alpha(row.NameFrame) == 0 and Alpha(row.BorderFrame) == 0 and Alpha(row.QualityStripe) == 0, "the item card art goes")
	assert(Alpha(row.PushedNameFrame) == 0, "the pressed card art goes")
	assert(K.Skin.IsSkinned(row, "Backdrop"), "a tile sits behind the row")
	assert(K.Skin.Parts(row).backdrop.chrome.fillName == "surface", "a row is the glass surface, as every list row")
	assert(K.Skin.Parts(row).backdrop:GetFrameLevel() < ns.Parts.RimOf(row.Item):GetFrameLevel(), "the row's tile sits under the icon's rim")
	assert(Alpha(row.IconQuestTexture) == 1, "the quest marker stays")
	local item = row.Item
	assert(Alpha(item.icon) == 1 and Alpha(item.IconBorder) == 0 and Alpha(item.NormalTexture) == 0, "the item keeps its icon and loses Blizzard's slot art")
	local crop = W.LastCall(item.icon, "SetTexCoord")
	assert(crop and W.Near(crop[1], 0.07), "the icon is cropped")
	local r, g, b = RimColor(ns, item)
	assert(SameQuality(K, r, g, b, QUALITY_EPIC), "an epic item gets the epic rim")
	assert(FontPath(row.Text) == Style.Font("body") and FontPath(row.QualityText) == Style.Font("caption"), "the name and quality label wear the skin fonts")
	assert(W.SameRGB({ GetVertexColor = function() return row.QualityText:GetTextColor() end }, K.Theme.QualityColor(QUALITY_EPIC)), "the quality label takes the quality colour")
	assert(FontPath(item.Count) == Style.Font("number"), "the stack count uses the number font")

	B.check(snap, { Show = true, Hide = true, SetShown = true })
	assert(Alpha(row.HighlightNameFrame) == 0, "Blizzard's highlight art goes")
	local wash = Kit.Wash(row.HighlightNameFrame)
	assert(not wash:IsShown(), "the accent wash hides while Blizzard's highlight hides")
	row.HighlightNameFrame:Show()
	assert(wash:IsShown(), "and shows while Blizzard shows it")
	local ar, ag, ab = Style.Accent()
	assert(W.SameRGB(wash, ar, ag, ab), "in the module's accent")
	row.HighlightNameFrame:Hide()
	assert(not wash:IsShown())
	snap = B.snapshot()

	assert(RimColor(ns, p.money.Item) == nil, "common coin stays plain by default")
	K.Options.Write("Skins", "loot.qualityFrom", QUALITY_COMMON)
	assert(RimColor(ns, p.money.Item) ~= nil, "lowering the threshold rims common loot at once")
	K.Options.Write("Skins", "loot.qualityBorders", false)
	assert(RimColor(ns, item) == nil, "switching quality borders off clears every rim")
	K.Options.Write("Skins", "loot.qualityBorders", true)
	K.Options.Write("Skins", "loot.qualityFrom", 2)

	p.box.Init(p.late, { slotIndex = 4, quality = QUALITY_COMMON })
	assert(Alpha(p.late.NameFrame) == 0 and K.Skin.IsSkinned(p.late, "Backdrop"), "a row the list shows later is skinned too")
	row:SetData({ slotIndex = 1, quality = QUALITY_COMMON })
	p.box.Init(row, { slotIndex = 1, quality = QUALITY_COMMON })
	assert(RimColor(ns, item) == nil, "a recycled row repaints for its new item")

	B.check(snap, { SetData = true, Show = true, Hide = true, SetShown = true })
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Group loot rolls ----------------------------------------------------------------------------------------

do
	local B, rolls, snap
	local qualities = {}
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			rolls = { Roll(B, 1), Roll(B, 2) }
			env.GetLootRollItemInfo = function(rollID)
				return 134400, "Bracers", 1, qualities[rollID]
			end
			env.GroupLootFrame_SetupItemDisplay = function(frame)
				frame.Timer:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
				return true
			end
			snap = B.snapshot()
		end,
	})
	local Style, Kit = ns.Style, ns.PartC
	assert(K.Options.Row("Skins", "lootRolls.enabled") and K.Options.Row("Skins", "lootRolls.qualityBorders"), "the rolls have a switch and quality borders")
	K.Modules.Enable("Skins")
	local first, second = rolls[1], rolls[2]
	first.rollID = 7
	qualities[7] = QUALITY_EPIC
	S.Show(first)
	env.GroupLootFrame_SetupItemDisplay(first)
	assert(ns.Skins.IsApplied("lootRolls"), "the first roll skins every roll frame")
	assert(S.Logged(env, "GroupLootFrame3 is missing"), "a roll frame this client lacks is logged")
	for _, frame in ipairs(rolls) do
		assert(Alpha(frame.Background) == 0 and Alpha(frame.Border) == 0, "the toast art goes")
		assert(K.Skin.IsSkinned(frame, "Backdrop"), "a glass panel sits behind each roll")
		assert(K.Skin.Parts(frame).backdrop.chrome.shapeName == "panel", "a 67-unit toast takes the panel grade's 8-unit chamfer, as the unit frames")
		assert(Alpha(frame.IconFrame.Icon) == 1 and Alpha(frame.IconFrame.Border) == 0, "the icon stays and its border goes")
		assert(FontPath(frame.Name) == Style.Font("body"), "the item name wears the body font")
		assert(Alpha(frame.LootButtonContainer.NeedButton.Art) == 1, "the need, greed and pass buttons keep their icons")
	end
	local r, g, b = RimColor(ns, first.IconFrame)
	assert(SameQuality(K, r, g, b, QUALITY_EPIC), "the roll's item quality colours the icon rim")
	local timer = first.Timer
	assert(Alpha(timer.Background) == 0 and Alpha(timer:GetStatusBarTexture()) == 0, "Blizzard's timer art is hidden")
	local mirror = Kit.MirrorBar(timer, first)
	assert(mirror and mirror:GetFrameLevel() > first:GetFrameLevel(), "a KstyleUI timer bar sits above the roll's glass panel, even at frame level 1")
	assert(K.Skin.Parts(first).backdrop:GetFrameLevel() < mirror:GetFrameLevel())
	assert(W.LastCall(mirror, "SetStatusBarTexture")[1] == Style.BarTexture(), "it uses the bar texture")
	local tr, tg, tb = K.Theme.Brighten(1, 1, 0)
	local last = W.LastCall(mirror, "SetStatusBarColor")
	assert(W.Near(last[1], tr) and W.Near(last[2], tg) and W.Near(last[3], tb), "Blizzard's timer colour, lifted for the glass")
	assert(W.LastCall(mirror, "SetMinMaxValues")[2] == 60000 and W.LastCall(mirror, "SetValue")[1] == 60000, "it starts from Blizzard's timer")
	timer:SetMinMaxValues(0, 30000)
	timer:SetValue(12000)
	assert(W.LastCall(mirror, "SetMinMaxValues")[2] == 30000 and W.LastCall(mirror, "SetValue")[1] == 12000, "and follows each value Blizzard sets")
	K.Options.Write("Skins", "bars.fill", "right")
	assert(W.LastCall(mirror, "SetReverseFill")[1] == true, "the fill direction setting reaches it")

	second.rollID = env.Secret(8)
	S.Show(second)
	env.GroupLootFrame_SetupItemDisplay(second)
	assert(RimColor(ns, second.IconFrame) == nil, "a secret roll ID leaves the rim plain")
	K.Options.Write("Skins", "lootRolls.qualityBorders", false)
	assert(RimColor(ns, first.IconFrame) == nil, "switching quality borders off clears the rims")

	B.check(snap, { rollID = true, SetValue = true, SetMinMaxValues = true })
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without GetLootRollItemInfo still skins the rolls -----------------------------------------------

do
	local B, roll
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			roll = Roll(B, 1)
		end,
	})
	K.Modules.Enable("Skins")
	S.Show(roll)
	assert(ns.Skins.IsApplied("lootRolls") and K.Skin.IsSkinned(roll, "Backdrop"))
	assert(S.Logged(env, "GroupLootFrame_SetupItemDisplay is missing"), "the missing hook is logged")
	assert(RimColor(ns, roll.IconFrame) == nil)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The settings preview shows a loot roll under part A's sample ------------------------------------------

do
	local env, K, ns = S.New()
	local build = K.Options.Preview("Skins")
	local pane = env.CreateFrame("Frame", nil, env.UIParent)
	local frame = build(pane)
	assert(frame and #frame.extras == 1, "part C adds one sample to the preview")
	local roll = frame.extras[1]
	assert(roll.rim and W.SameRGB(roll.rim.rim[1], K.Theme.QualityColor(QUALITY_EPIC)), "the sample roll wears the epic rim")
	assert(FontPath(roll.name) == ns.Style.Font("body"), "its name wears the body font")
	K.Options.Write("Skins", "text.size", 1.2)
	K.Options.Write("Skins", "bars.color", "custom")
	K.Options.Write("Skins", "bars.customColor", { r = 0.3, g = 0.6, b = 0.9 })
	frame:Refresh()
	local _, size = roll.name:GetFont()
	assert(W.Near(size, select(2, K.Tokens.Font("body")) * 1.2), "Refresh applies the text size")
	local color = W.LastCall(roll.bar, "SetStatusBarColor")
	assert(W.Near(color[1], 0.3) and W.Near(color[2], 0.6) and W.Near(color[3], 0.9), "and the bar colour")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part C loot ok")
