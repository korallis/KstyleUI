-- test-skins-questcard.lua: the quest card shows a set number of tracked quests (4 by default, 1 to 8) in the right rail's story slot, scrolls to the rest with the wheel, never crosses the map, the aura rows, the damage meter or the readout at the owner's screen, stands in its own column beside the RestedXP guide's card, never changes its item buttons in combat, hands the screen back to Blizzard's tracker for scenarios and when switched off, and keeps the combat path cheap.
local S = dofile("Tools/regression/skins_env.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local RestedXP = dofile("Tools/regression/restedxp_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local W = S.W

local OWNER = { width = 2383, height = 1540, uiScale = 768 / 1080 }
local PROTECTED = {
	SetAttribute = true, Show = true, Hide = true, SetShown = true, SetPoint = true, ClearAllPoints = true,
	SetAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetParent = true, EnableMouse = true,
	SetScale = true, RegisterForClicks = true,
}

-- Sized(size) -> saved data at that Interface size. Boot runs at the shipped size (16 / 19), as the game does: the
-- picture's right rail (LEE-20) leaves the story slot about 300 units tall there, and only 98 at size 1.
local function Sized(size)
	return { version = 12, profiles = { Default = { Appearance = { uiScale = size } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

-- Boot(opts) -> env, K, ns, log, tracker: Skins on, Blizzard's tracker loaded, opts.quests tracked (10 by
-- default). opts.rxp installs RestedXP; opts.screen sets the screen; opts.saved the saved data; opts.measure
-- gives the font strings the kit fonts' glyph widths, so a line wraps where the game wraps it.
local function Boot(opts)
	opts = opts or {}
	local log, tracker, rxp
	local screen = opts.screen or {}
	local env, K, ns = S.New({
		width = screen.width,
		height = screen.height,
		uiScale = screen.uiScale,
		saved = opts.saved or Sized(16 / 19),
		setup = function(env)
			log = Quests.Install(env, opts.quests or Quests.List(10))
			log.super = opts.super or 0
			if opts.measure then
				env._textWidth = Measure.TextWidth
			end
			if opts.rxp then
				rxp = RestedXP.Install(env, {})
			end
		end,
		before = function(env)
			tracker = Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	W.Settle(env)
	return env, K, ns, log, tracker, rxp
end

local function Saved(section)
	return {
		version = 2,
		profiles = { Default = { Skins = section } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

-- Shown(ns) -> the ids of the quests the card shows, top to bottom.
local function Shown(ns)
	local out = {}
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() and row.questID then
			out[#out + 1] = row.questID
		end
	end
	return out
end

local function Ids(list)
	local out = {}
	for i, id in ipairs(list) do
		out[i] = tostring(id)
	end
	return table.concat(out, ",")
end

for _, screen in ipairs({ { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }) do
	local env, K, ns = Boot({ quests = Quests.List(4), screen = { width = screen[1], height = screen[2] } })
	local card, parts = ns.Quests.Card(), ns.Quests.Parts()
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(card)
	ns.QuestCard.Place(K.Scale.Root(), 100, 500, 278, 1000)
	ns.QuestCard.Render()
	assert(#Shown(ns) == 4, "four fixture quests fit an unconstrained card")
	for _, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() then
			for _, value in ipairs({ row:GetHeight(), row.disc:GetWidth(), select(4, row:GetPoint(1)), select(5, row:GetPoint(1)) }) do
				assert(math.abs(value / pixel - math.floor(value / pixel + 0.5)) < 1e-6, "quest geometry is snapped at " .. screen[1] .. "x" .. screen[2])
			end
		end
	end
	local natural = card:GetHeight()
	for _, shortage in ipairs({ 0.25, 0.75 }) do
		ns.QuestCard.Place(K.Scale.Root(), 100, 500, 278, natural - shortage * pixel)
		ns.QuestCard.Render()
		assert(#Shown(ns) == 4, "a subpixel shortage never drops a whole quest: " .. shortage)
	end
	ns.QuestCard.Place(K.Scale.Root(), 100, 500, 278, natural - 4 * pixel)
	ns.QuestCard.Render()
	assert(#Shown(ns) < 4 and parts.more:IsShown() and parts.thumb:IsShown(), "a genuinely short card advertises the quests accessible by scrolling")
	ns.QuestCard.Scroll(99)
	assert(Shown(ns)[#Shown(ns)] == 304, "a short card can scroll to its last quest even with only four tracked")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "the short-card path raises nothing")
end

local function Wheel(ns, delta)
	local card = ns.Quests.Card()
	local fn = assert(card:GetScript("OnMouseWheel"), "the card takes the mouse wheel")
	fn(card, delta)
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- RootRect(K, object) -> the object's rect in KstyleUI's root units, whichever frame it hangs from.
local function RootRect(K, object)
	local root = K.Scale.Root()
	return assert(Geometry.ScaledRect(object, root._env.UIParent, root))
end

do
	local env, K, ns = Boot({ quests = Quests.List(7), measure = true })
	local card, parts = ns.Quests.Card(), ns.Quests.Parts()
	local before = {}
	local edge = RootRect(K, parts.view).right - K.Widgets.Snap(card, 1)
	local function CountRight(row, line)
		local point, relative, on, x = line.count:GetPoint(1)
		assert(point == "TOPRIGHT" and relative == row and on == "TOPRIGHT", "counts keep a right anchor on their own row")
		return RootRect(K, row).right + x * K.Widgets.ScaleFactor(row)
	end
	for i, row in ipairs(ns.Quests.Rows()) do
		if row:IsShown() then
			local line = row.lines[1]
			local right = CountRight(row, line)
			assert(math.abs(right - edge) < 1e-6, "a resting count uses the normal content edge, not a hidden scrollbar's gutter")
			before[i] = { row.span, line.text:GetWidth(), line.text:GetHeight(), right }
		end
	end
	card._mouseOver = true
	card:GetScript("OnEnter")(card)
	assert(parts.thumb:GetAlpha() == 1 and parts.track:GetAlpha() == 1, "hover reveals the scrollbar")
	local bar = RootRect(K, parts.track)
	assert(bar.right < RootRect(K, card).right, "the hover scrollbar remains inside the glass")
	assert(parts.track:GetParent() ~= parts.view, "the scrollbar is not clipped by the text viewport")
	for i, values in pairs(before) do
		local row, line = ns.Quests.Rows()[i], ns.Quests.Rows()[i].lines[1]
		local right = CountRight(row, line)
		assert(right < bar.left, "the hover scrollbar never covers a count")
		assert(row.span == values[1] and line.text:GetWidth() == values[2] and line.text:GetHeight() == values[3] and right == values[4], "hover changes neither wrapping, row height nor count position")
	end
	Clean(env, K)
end

-- Four of ten: the card shows four quests (the picture's count, LEE-20), the super-tracked one first and marked, and counts all ten -------------

do
	local env, K, ns, _, tracker = Boot({ super = 305 })
	assert(ns.Skins.IsApplied("quests"), "the quest card applies once Blizzard's tracker loads")
	assert(ns.Quests.Active(), "the card stands in for Blizzard's quest list")
	assert(ns.Quests.Card():IsShown(), "and shows")
	local shown = Shown(ns)
	assert(Ids(shown) == "305,301,302,303", "four of ten, the super-tracked quest first, got " .. Ids(shown))
	local first = ns.Quests.Rows()[1]
	assert(first.ring == nil and first.marked == nil, "the super-tracked quest leads the list and wears no ring: the picture's discs are flat, with nothing around them")
	local factor = K.Widgets.ScaleFactor(ns.Quests.Card())
	assert(math.abs(first.disc:GetWidth() - 16 / factor) <= K.Scale.Pixel(1) / factor and first.disc:GetHeight() == first.disc:GetWidth(), "the disc is 16 root units across, drawing the picture's 28-pixel blue core, got " .. tostring(first.disc:GetWidth()))
	local discLead = select(4, first.disc:GetPoint(1))
	assert(discLead == K.Widgets.Snap(ns.Quests.Card(), ns.Lumen.Size(ns.Quests.Card(), 1)), "the disc's smaller texture stays centred on the same numeral column, got " .. tostring(discLead))
	local dr, dg, db = first.disc:GetVertexColor()
	local tr, tg, tb = K.Tokens.Color("questDisc")
	assert(dr == tr and dg == tg and db == tb, "the disc reads the picture's questDisc blue, not the class accent")
	local nr, ng, nb = first.numeral:GetTextColor()
	local shade = S.W.LastCall(first.numeral, "SetShadowOffset")
	assert(nr == 1 and ng == 1 and nb == 1 and shade[1] == 0 and shade[2] == 0, "its number is white and casts no shadow on the disc")
	assert(math.abs(select(4, first.title:GetPoint(1)) - 25.5 / factor) <= K.Scale.Pixel(1) / factor, "the title starts 25.5 root units in from the disc's left edge, got " .. tostring(select(4, first.title:GetPoint(1))))
	local parts = ns.Quests.Parts()
	assert(parts.cap.titleValue == "Quests" or parts.cap.titleValue == K.L["Quests"], "the cap reads QUESTS")
	assert(parts.cap.trailValue == "10", "the cap counts every tracked quest, got " .. tostring(parts.cap.trailValue))
	local title = first.title:GetText()
	assert(title:find("[10]", 1, true) and title:find("Dark Storms", 1, true), "the title carries the quest's level as Forever shows it, got " .. title)
	assert(parts.more:IsShown() and parts.more:GetText():find("6", 1, true), "the card says how many more there are, got " .. tostring(parts.more:GetText()))
	assert(parts.thumb:IsShown(), "and a slim scroll bar shows")
	assert(parts.thumb:GetAlpha() == 0 and parts.track:GetAlpha() == 0, "at rest the scroll bar is unseen, as the picture draws the card")
	assert(parts.more:GetAlpha() == 1, "but the more line always shows, so the card says when quests wait (the Captain's ruling on KSTY-33)")
	local card = ns.Quests.Card()
	local cardBox, capBox, viewBox = RootRect(K, card), RootRect(K, parts.cap.row), RootRect(K, parts.view)
	assert(math.abs(cardBox.top - capBox.top - 11) <= 0.6, "standing alone, the caption's row starts 11 root units under the glass's top, as the picture's guide caption does, got " .. cardBox.top - capBox.top)
	assert(math.abs(capBox.bottom - viewBox.top - 6.5) <= 0.6, "the first quest starts 6.5 under the caption's row, as the picture spaces them, got " .. capBox.bottom - viewBox.top)
	assert(math.abs(capBox.top - capBox.bottom - 21) <= 0.6, "the caption's row is 21 root units high, got " .. capBox.top - capBox.bottom)
	-- The more line is a row of its own under the last quest, a quest gap below it, and the card keeps its whole
	-- 12.5 foot clear under the line, as the mock-up's card leaves padding under "7 more, scroll down" (KSTY-60 item 16).
	local function Foot()
		local topPoint, topOn, _, _, topY = parts.more:GetPoint(1)
		local footPoint, footOn, _, _, footY = parts.more:GetPoint(2)
		assert(topPoint == "TOP" and topOn == parts.view and footPoint == "BOTTOM" and footOn == card, "the more line hangs from the view's foot to the card's, got " .. tostring(topPoint) .. " " .. tostring(footPoint))
		local view, whole = RootRect(K, parts.view), RootRect(K, card)
		return -topY * factor, footY * factor, view.bottom - whole.bottom + (topY - footY) * factor, select(2, parts.more:GetFont()) * factor
	end
	local above, under, span, size = Foot()
	assert(math.abs(under - 12.5) <= 0.6, "the card keeps its 12.5 foot clear under the more line, got " .. under)
	assert(math.abs(above - 7) <= 0.6, "the more line starts a quest gap under the last quest, got " .. above)
	assert(span >= size - 0.6, "and its row holds its glyphs, got " .. span .. " for " .. size)
	-- A larger text size setting grows the more line and the foot under it by the same factor; at the shipped size
	-- the foot is the picture's 12.5.
	K.Options.Write("Skins", "text.size", 1.5)
	env.RunTimers()
	do
		local _, bigUnder, bigRow, bigSize = Foot()
		assert(math.abs(bigUnder - 18.75) <= 0.6, "at one and a half times the text size the foot under the more line is one and a half times as deep, got " .. bigUnder)
		assert(bigRow >= bigSize - 0.6, "and the larger more line still fits its row, got " .. bigRow .. " for " .. bigSize)
	end
	K.Options.Write("Skins", "text.size", 1)
	env.RunTimers()
	assert(math.abs(select(2, Foot()) - 12.5) <= 0.6, "and 12.5 again at the shipped size")
	card._mouseOver = true
	card:GetScript("OnEnter")(card)
	assert(parts.thumb:GetAlpha() == 1 and parts.track:GetAlpha() == 1 and parts.more:GetAlpha() == 1, "under the pointer they show")
	local row = first
	row:GetScript("OnLeave")(row)
	assert(parts.thumb:GetAlpha() == 1, "moving from a row onto the card keeps them")
	card._mouseOver = false
	card:GetScript("OnLeave")(card)
	assert(parts.thumb:GetAlpha() == 0 and parts.more:GetAlpha() == 1, "and the bar rests again once the pointer leaves the card, the more line still showing")
	assert(not tracker:IsVisible(), "Blizzard's tracker does not show the quests a second time")
	Clean(env, K)
end

-- Scrolling reveals the rest, one quest per wheel step, and stops at either end -------------------------------------

do
	local env, K, ns = Boot()
	assert(Ids(Shown(ns)) == "301,302,303,304", "the first four, got " .. Ids(Shown(ns)))
	Wheel(ns, -1)
	assert(Ids(Shown(ns)) == "302,303,304,305", "one wheel step down shows the next quest, got " .. Ids(Shown(ns)))
	for _ = 1, 20 do
		Wheel(ns, -1)
	end
	assert(Ids(Shown(ns)) == "307,308,309,310", "the wheel reaches the last quest and stops there, got " .. Ids(Shown(ns)))
	local more = ns.Quests.Parts().more
	assert(more:IsShown() and more:GetText() == "6 above, scroll up", "at the end the more line points up, got " .. tostring(more:GetText()))
	Wheel(ns, 1)
	assert(Ids(Shown(ns)) == "306,307,308,309", "and back up, got " .. Ids(Shown(ns)))
	for _ = 1, 20 do
		Wheel(ns, 1)
	end
	assert(Ids(Shown(ns)) == "301,302,303,304", "up to the top and no further, got " .. Ids(Shown(ns)))
	Clean(env, K)
end

-- The setting picks how many quests show, from 1 to 8; fewer quests than that show them all with no scroll bar -----

do
	-- At the smallest Interface size (0.6) the slot has room for more than eight rows, so the cap limits them.
	local env, K, ns, log = Boot({ saved = Sized(0.6) })
	K.Options.Write("Skins", "quests.shown", 5)
	env.RunTimers()
	assert(#Shown(ns) == 5, "five shown, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 1)
	env.RunTimers()
	assert(#Shown(ns) == 1, "one shown, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 12)
	env.RunTimers()
	assert(#Shown(ns) == 8, "never more than eight, got " .. #Shown(ns))
	K.Options.Write("Skins", "quests.shown", 3)
	for _ = 1, 8 do
		log.Untrack(log.quests[#log.quests].id)
	end
	env.RunTimers()
	assert(Ids(Shown(ns)) == "301,302", "two quests show whole, got " .. Ids(Shown(ns)))
	assert(not ns.Quests.Parts().thumb:IsShown(), "with no scroll bar")
	assert(not ns.Quests.Parts().more:IsShown(), "and no more line")
	local whole, last = RootRect(K, ns.Quests.Card()), RootRect(K, ns.Quests.Parts().view)
	assert(math.abs(last.bottom - whole.bottom - 12.5) <= K.Scale.Pixel(1), "the foot is the same 12.5 with nothing more to scroll to, got " .. last.bottom - whole.bottom)
	for _ = 1, 2 do
		log.Untrack(log.quests[#log.quests].id)
	end
	env.RunTimers()
	assert(not ns.Quests.Card():IsShown(), "no tracked quests, no card")
	Clean(env, K)
end

-- KSTY-67 item 1: beside the RestedXP guide the quest card stands under the map, level with the guide's card, as mock-up B
-- draws them, and its column runs down to a rail gap over the threat card, so it shows at least three of ten quests at
-- 1920x1080 and four at 1440-tall screens, at the sizes the game picks there (15/16 and 21/16 pixels a unit), in every
-- preset and both arrangements ----------------------------------------------------------------------------------------

do
	local SCREENS = { { 1920, 1080, 15 / 16, 3 }, { 2560, 1440, 21 / 16, 4 }, { 3440, 1440, 21 / 16, 4 }, { 5120, 1440, 21 / 16, 4 } }
	for _, screen in ipairs(SCREENS) do
		local width, height, perUnit, need = screen[1], screen[2], screen[3], screen[4]
		for _, arrangement in ipairs({ "centred", "spread" }) do
			for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
				local what = string.format("%s %dx%d %s", preset, width, height, arrangement)
				local env, K, ns, _, _, rxp = Boot({ screen = { width = width, height = height, uiScale = 1 }, saved = Sized(perUnit * 1080 / height), rxp = true })
				K.Options.Write("Layout", "arrangement", arrangement)
				K.Options.Write("Layout", "preset", preset)
				env.RunTimers()
				W.Settle(env)
				local Layouts = K.Setup.Layouts
				local rw, rh = K.Layout.RootSize()
				assert(math.abs(rh - height / perUnit) < 1e-6, what .. ": the root is " .. height / perUnit .. " units tall, got " .. rh)
				local story = K.Setup.Story(preset, true)
				local glass = RootRect(K, assert(K.Skin.Parts(rxp.RXPFrame).backdrop, "the guide wears its glass"))
				local card = RootRect(K, ns.Quests.Card())
				local px = K.Scale.Pixel(1) + 0.01
				assert(math.abs(card.top - glass.top) <= px and math.abs(story.tracker.top - story.guide.top) <= px, what .. ": the quest card's top is level with the guide's, got " .. card.top .. " for " .. glass.top)
				local w, h = Layouts.Footprint(preset, "meters.threat")
				local _, _, _, threatTop = Layouts.Rect({ width = w, height = h }, Layouts.Get(preset, rh)["meters.threat"], rw, rh)
				assert(story.tracker.bottom >= threatTop + 16 - px, what .. ": the column ends a rail gap over the threat card's top, got " .. story.tracker.bottom .. " for " .. threatTop)
				assert(#Shown(ns) >= need, what .. ": at least " .. need .. " quests show, got " .. #Shown(ns))
				for _, row in ipairs(ns.Quests.Rows()) do
					if row:IsShown() then
						assert(RootRect(K, row).bottom >= card.bottom - 0.5, what .. ": every quest shown sits whole inside the card")
					end
				end
				Clean(env, K)
			end
		end
	end
end

-- The card fits its own element at the owner's screen (2383 by 1540 at UI scale 768/1080) with fifteen quests of five
-- objectives each, with and without RestedXP, in every preset. Without the guide it takes the story slot on the right
-- rail under the map and the aura rows, over the tooltip anchor, the damage card and the readout. With the guide the
-- guide's card holds the slot and the quests stand in a column of their own a rail gap to its left, at the same top
-- (KSTY-33, the Captain's ruling on the Fable audit: two cards, two Layout elements, each with its own glass); neither
-- card reaches past its element, and the guide's glass never covers the quests ----------------------------------------

for _, preset in ipairs({ "DPS", "Tank", "Healer" }) do
	for _, withGuide in ipairs({ false, true }) do
		local env, K, ns, _, _, rxp = Boot({ screen = OWNER, quests = Quests.List(15, 5), rxp = withGuide })
		if preset ~= "DPS" then
			K.Options.Write("Layout", "preset", preset)
			env.RunTimers()
		end
		local Layouts = K.Setup.Layouts
		local rw, rh = K.Layout.RootSize()
		local function Box(key)
			local w, h = Layouts.Footprint(preset, key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h }, Layouts.Get(preset, rh)[key], rw, rh)
			return { left = l, bottom = b, right = r, top = t }
		end
		local slot = Layouts.Slot(preset, rh)
		local sl, sb, sr, st = Layouts.Rect(slot, slot, rw, rh)
		local story = K.Setup.Story(preset, withGuide)
		local band = story.tracker
		local over = math.min(Box("minimap.main").bottom, Box("auras.debuffs").bottom)
		local under = math.max(Box("actionbars.bar4").top, Box("actionbars.bar5").top, Box("meters.damage").top, Box("databars.strip").top)
		local card = RootRect(K, ns.Quests.Card())
		local holder = RootRect(K, ns.Quests.Holder())
		local what = preset .. (withGuide and " with the guide" or " without the guide")
		local px = K.Scale.Pixel(1) + 0.01
		assert(K.Layout.Get("skins.quests") ~= nil, what .. ": the quest card is a Layout element of its own")
		assert(math.abs(holder.left - band.left) <= px and math.abs(holder.top - band.top) <= px and math.abs(holder.bottom - band.bottom) <= px, what .. ": the element is the card's band")
		assert(card.top <= over - 15 + 0.5, what .. ": the card starts 15 under the map and the aura rows, got " .. card.top .. " for " .. over)
		assert(math.abs(card.top - st) <= px, what .. ": at the story slot's top, level with the guide's card beside it as mock-up B draws them (KSTY-67 item 1), got " .. card.top .. " for " .. st)
		assert(card.bottom >= band.bottom - px and card.top <= band.top + px, what .. ": inside its element")
		assert(math.abs(card.left - band.left) <= px and math.abs(card.right - band.right) <= px, what .. ": on its element's edge and width")
		assert(math.abs(card.right - card.left - 278) <= 0.6, what .. ": the picture's 278 rail column")
		local edge = K.Tokens.Size("screenMargin")
		if withGuide then
			assert(math.abs(card.right - (sl - 16)) <= px, what .. ": a rail gap left of the guide's slot, got " .. card.right .. " for " .. sl)
		else
			local foot = K.Tokens.Size("gapLarge")
			assert(card.bottom >= under + foot - 0.5, what .. ": the card ends a large gap over bars 4 and 5, the damage card and the readout, as the picture leaves 12, got " .. card.bottom .. " for " .. under)
			assert(math.abs(card.right - (rw - edge)) <= 0.6 and math.abs(card.left - sl) <= 0.6, what .. ": alone, it takes the story slot on the screen margin")
		end
		assert(#Shown(ns) >= 1, what .. ": at least one quest shows")
		for _, row in ipairs(ns.Quests.Rows()) do
			if row:IsShown() then
				local r = RootRect(K, row)
				assert(r.bottom >= card.bottom - 0.5, what .. ": every quest shown sits whole inside the card")
			end
		end
		assert(ns.Quests.Parts().glass:IsShown(), what .. ": the card wears its own glass")
		assert(ns.Quests.Parts().glass.chrome.gilt ~= nil, what .. ": with gilt L-ticks: the owner's picture of 2026-11-09 puts them on the story card, reversing #205's thin rim and nothing else")
		if withGuide then
			assert(ns.RestedXP.Rail.Placed(), what .. ": the guide is placed")
			local glass = assert(K.Skin.Parts(rxp.RXPFrame).backdrop, "the guide wears its glass")
			local g = RootRect(K, glass)
			assert(g.top <= over - 15 + 0.5 and g.top >= st - px, what .. ": the guide's card starts at the slot's top, under the map and the aura rows, got " .. g.top)
			assert(g.bottom >= sb - px and g.left >= sl - px and g.right <= sr + px, what .. ": and stays inside the slot, got " .. g.left .. ".." .. g.right .. " by " .. g.bottom)
			assert(g.left >= card.right + 16 - px, what .. ": a rail gap right of the quests, never over them")
		end
		Clean(env, K)
	end
end

-- Item buttons: a quest's item is a secure item button set out of combat; in combat nothing protected changes on
-- it, whatever happens to the quests, and the changes land when combat ends ------------------------------------------

do
	local list = Quests.List(10)
	list[1].item = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	list[4].item = { link = "|cffffffff|Hitem:6145::::::::|h[Clarice's Pendant]|h|r", icon = 133279 }
	local heart, pendant = list[1].item.link, list[4].item.link
	local env, K, ns, log = Boot({ quests = list, saved = Saved({ enabled = true, quests = { shown = 3 } }) })
	local buttons = ns.Quests.Buttons()
	local used
	for _, button in ipairs(buttons) do
		if button:IsShown() then
			assert(not used, "one item button for the one item quest in view")
			used = button
		end
	end
	assert(used, "the item quest in view has its item button")
	assert(used._template and used._template:find("SecureActionButtonTemplate", 1, true), "built on SecureActionButtonTemplate")
	assert(used:GetAttribute("type") == "item", "type item")
	assert(used:GetAttribute("item") == heart, "using the quest's item")
	assert(used:GetParent() == env.UIParent, "parented to UIParent, so no KstyleUI frame turns protected")
	local marks = {}
	for i, button in ipairs(ns.Quests.Buttons()) do
		marks[i] = #button._calls
	end
	env.SetCombat(true)
	Wheel(ns, -1)
	Wheel(ns, -1)
	Wheel(ns, -1)
	list[1].complete = true
	log.Fire("QUEST_LOG_UPDATE")
	log.Untrack(301)
	log.super = 304
	log.Fire("SUPER_TRACKING_CHANGED")
	K.Options.Write("Skins", "quests.shown", 6)
	env.RunTimers()
	W.Settle(env)
	for i, button in ipairs(ns.Quests.Buttons()) do
		for n = (marks[i] or 0) + 1, #button._calls do
			local method = button._calls[n].method
			assert(not PROTECTED[method], "a protected " .. method .. " on an item button in combat")
		end
	end
	assert(#ns.Quests.Buttons() == #marks, "no item button is made in combat")
	env.SetCombat(false)
	env.RunTimers()
	W.Settle(env)
	local now
	for _, button in ipairs(ns.Quests.Buttons()) do
		if button:IsShown() then
			now = button
		end
	end
	assert(now and now:GetAttribute("item") == pendant, "after combat the item button follows the quests: the pendant's quest, now first")
	Clean(env, K)
end

-- Off: Blizzard's tracker comes back exactly as it was, and the card goes; on again, the card returns --------------

do
	local original = {}
	local env, K, ns, log, tracker = Boot()
	assert(ns.Quests.Active() and not tracker:IsVisible(), "the card stands in")
	original.parent = env.UIParent
	K.Options.Write("Skins", "quests.enabled", false)
	env.RunTimers()
	assert(not ns.Quests.Active(), "off, the card stands down")
	assert(not ns.Quests.Card():IsShown(), "and hides")
	assert(tracker:GetParent() == original.parent, "Blizzard's tracker is back on its own parent")
	assert(tracker:IsVisible(), "and shows")
	local point = { tracker:GetPoint(1) }
	assert(point[1] == "TOPRIGHT" and point[2] == env.UIParent and point[4] == -110 and point[5] == -275, "where Edit Mode put it")
	for _, button in ipairs(ns.Quests.Buttons()) do
		assert(not button:IsShown(), "no item button stays")
	end
	K.Widgets.RestyleAll()
	K.Options.Write("Skins", "text.size", 1.2)
	log.Fire("QUEST_LOG_UPDATE")
	env.RunTimers()
	assert(not ns.Quests.Card():IsShown() and tracker:IsVisible(), "a restyle, a text size change or a quest update never brings a switched-off card back")
	K.Options.Write("Skins", "text.size", 1)
	K.Options.Write("Skins", "quests.enabled", true)
	env.RunTimers()
	assert(ns.Quests.Active() and ns.Quests.Card():IsShown() and not tracker:IsVisible(), "on again, the card stands in again")
	assert(#log.calls == 0, "switching calls no quest action")
	Clean(env, K)
end

-- Scenarios, dungeons and delves stay in Blizzard's tracker: while it holds anything the card does not show, the
-- tracker shows instead of the card, and the card comes back when it ends; in combat the swap waits ----------------

do
	local env, K, ns, _, tracker = Boot()
	tracker.scenario.contentsHeight = 60
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible(), "a scenario stage brings Blizzard's tracker back")
	assert(not ns.Quests.Active() and not ns.Quests.Card():IsShown(), "in place of the card, so no quest shows twice")
	tracker.scenario.contentsHeight = 0
	env.SetCombat(true)
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible(), "in combat Blizzard's tracker stays until combat ends")
	env.SetCombat(false)
	env.RunTimers()
	assert(not tracker:IsVisible() and ns.Quests.Active() and ns.Quests.Card():IsShown(), "then the card takes the slot again")
	Clean(env, K)
end

-- An auto-complete quest's "click to complete" pop-up lives in Blizzard's quest module, which the card does not
-- draw: while one is up, Blizzard's tracker shows in place of the card, so the player can still complete the quest.

do
	local env, K, ns, log, tracker = Boot()
	log.popups = 1
	log.Fire("QUEST_AUTOCOMPLETE", 302)
	tracker:Update()
	env.RunTimers()
	assert(tracker:IsVisible() and not ns.Quests.Active(), "a quest pop-up brings Blizzard's tracker back")
	log.popups = 0
	tracker:Update()
	env.RunTimers()
	assert(not tracker:IsVisible() and ns.Quests.Active(), "and the card returns once it is gone")
	Clean(env, K)
end

-- While an item button is frozen in combat the card itself holds still too: a restyle, a layout change or entering
-- the world in combat moves nothing, so the button keeps covering its socket; the move lands after combat.

do
	local list = Quests.List(10)
	list[1].item = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	local env, K, ns = Boot({ quests = list })
	local card = ns.Quests.Card()
	local mark = #card._calls
	env.SetCombat(true)
	K.Widgets.RestyleAll()
	env.FireEvent("PLAYER_ENTERING_WORLD")
	K.Options.Write("Layout", "preset", "Healer")
	env.RunTimers()
	for i = mark + 1, #card._calls do
		local method = card._calls[i].method
		assert(method ~= "SetPoint" and method ~= "ClearAllPoints" and method ~= "SetWidth", "the card does not move while its item button is frozen, got " .. method)
	end
	env.SetCombat(false)
	env.RunTimers()
	local story = K.Setup.Story("Healer", false).tracker
	local top = RootRect(K, card).top
	assert(math.abs(top - story.top) < 1, "after combat it moves to the new layout's slot, got " .. tostring(top) .. " for " .. story.top)
	Clean(env, K)
end

-- Clicks as Blizzard's tracker: a left click opens the quest's details, shift untracks, a right click opens the
-- quest's menu, whose first entry super-tracks it ---------------------------------------------------------------------

do
	local env, K, ns, log = Boot()
	local row = ns.Quests.Rows()[2]
	W.Click(row, "LeftButton")
	local opened = log.Called("OpenToQuestDetails")
	assert(#opened == 1 and opened[1].args[1] == 302, "a left click opens the quest's details")
	log.modified.QUESTWATCHTOGGLE = true
	W.Click(row, "LeftButton")
	log.modified.QUESTWATCHTOGGLE = nil
	env.RunTimers()
	local removed = log.Called("RemoveQuestWatch")
	assert(#removed == 1 and removed[1].args[1] == 302, "shift untracks it")
	assert(Ids(Shown(ns)) == "301,303,304,305", "and the card moves up, got " .. Ids(Shown(ns)))
	W.Click(ns.Quests.Rows()[1], "RightButton")
	assert(#log.Called("CreateContextMenu") == 1 and log.menu, "a right click opens the quest's menu")
	local track
	for _, entry in ipairs(log.menu) do
		if entry.fn and entry.text == env.SUPER_TRACK_QUEST then
			track = entry
		end
	end
	assert(track, "the menu's entries are Blizzard's own words")
	track.fn()
	env.RunTimers()
	assert(log.super == 301 and ns.Quests.Rows()[1].questID == 301, "super-tracking from the menu brings the quest to the top")
	Clean(env, K)
end

-- Ready to turn in, failed and finished objectives read at a glance -------------------------------------------------

do
	local list = Quests.List(3)
	list[1].complete = true
	list[2].failed = true
	list[3].objectives[1].finished = true
	local env, K, ns = Boot({ quests = list })
	local rows = ns.Quests.Rows()
	local function Lines(row)
		local out = {}
		for _, line in ipairs(row.lines) do
			if line.text:IsShown() then
				out[#out + 1] = line
			end
		end
		return out
	end
	local ready = Lines(rows[1])
	assert(#ready == 1 and ready[1].text:GetText() == "Ready for turn-in", "a complete quest reads Ready for turn-in, got " .. tostring(ready[1] and ready[1].text:GetText()))
	local fr, fg, fb = ready[1].text:GetTextColor()
	local gr, gg, gb = K.Tokens.Color("friend")
	assert(W.Near(fr, gr) and W.Near(fg, gg) and W.Near(fb, gb), "in the friendly green")
	local failed = Lines(rows[2])
	assert(#failed == 1 and failed[1].text:GetText() == "Failed", "a failed quest says so")
	local done = Lines(rows[3])
	assert(done[1].count:GetText() == "3/5", "a finished objective keeps its count, got " .. tostring(done[1].count:GetText()))
	local dr, dg, db = done[1].text:GetTextColor()
	local xr, xg, xb = K.Tokens.Color("textDisabled")
	assert(W.Near(dr, xr) and W.Near(dg, xg) and W.Near(db, xb), "and dims")
	assert(not done[1].text:GetText():find("%d+/%d+"), "the count sits in its own column, out of the words")
	Clean(env, K)
end

-- An objective wider than its room wraps onto up to three lines under its quest's title, the count stays on the first
-- line, and the quest is as tall as the lines it really takes: nothing overlaps and the next quest starts below -------

do
	local LONG = "Find and speak with Elegael Thornpaw in the northeastern part of Shadowgale Forest."
	local COUNTED = "Slay the corrupted Thornpaw wolves prowling the northeastern part of Shadowgale Forest: 0/12"
	local HUGE = string.rep("Gather every last scrap of the shattered Thornpaw banner scattered across ", 4)
	local ITEM = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	local function Quest(id, objectives, item)
		return { id = id, title = "Quest " .. id, level = 10, objectives = objectives, item = item }
	end
	local function List()
		return {
			Quest(401, { { text = LONG, finished = false }, { text = "Speak to Ranger Kalanna", finished = false } }),
			Quest(402, { { text = COUNTED, finished = false } }),
			Quest(403, { { text = COUNTED, finished = false } }, ITEM),
			Quest(404, { { text = HUGE, finished = false } }),
			Quest(405, { { text = "Speak to Ranger Kalanna", finished = false } }),
		}
	end
	-- Five wrapped quests need more room than the picture's story slot has, so this block boots at a small
	-- Interface size: the root is taller and the slot with it, whatever the layout's slot is.
	local roomy = { version = 9, profiles = { Default = { Appearance = { uiScale = 0.75 } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Boot({ quests = List(), measure = true, saved = roomy })
	K.Options.Write("Skins", "quests.shown", 5)
	env.RunTimers()
	local rows = ns.Quests.Rows()
	local function Text(row, i)
		return row.lines[i].text
	end
	local _, size = Text(rows[1], 1):GetFont()
	local pitch = size * 1.2
	local function Top(row, i)
		return RootRect(K, Text(row, i)).top
	end
	local function High(row, i)
		local r = RootRect(K, Text(row, i))
		return r.top - r.bottom
	end

	local wrap = W.LastCall(Text(rows[1], 1), "SetWordWrap")
	assert(wrap and wrap[1] == true, "a long objective's font string wraps")
	local one = High(rows[1], 2)
	local first = High(rows[1], 1)
	assert(first > one * 1.9, "the long objective is taller than a one-line objective, got " .. first .. " against " .. one)
	assert(not Text(rows[1], 1):IsTruncated(), "and is not cut")
	do
		-- The picture's wrapped lines stand a row apart, the height a one-line objective takes, not the font's own line
		-- height: the spacing between two lines (SetSpacing, SimpleFontStringAPIDocumentation.lua) makes up the rest.
		local long = Text(rows[1], 1)
		local count = long:GetNumLines()
		local row = K.Widgets.Snap(ns.Quests.Card(), size + 4)
		local spacing = W.LastCall(long, "SetSpacing")
		assert(count >= 2 and spacing and math.abs(spacing[1] - (row - pitch)) < 1e-6, "each wrapped line stands a row under the one above: the spacing is the row less the font's line, got " .. tostring(spacing and spacing[1]) .. " for " .. row - pitch)
		assert(math.abs(long:GetHeight() - K.Widgets.Snap(ns.Quests.Card(), count * row)) < 1e-6, "and the text is its lines times the row high, got " .. long:GetHeight() .. " for " .. count .. " lines of " .. row)
		assert(math.abs(Text(rows[1], 2):GetHeight() - row) < 1e-6, "a one-line objective is one row high")
		assert(long:GetStringHeight() <= long:GetHeight() + 1e-6, "the wrapped words fit the room the card keeps for them, got " .. long:GetStringHeight() .. " in " .. long:GetHeight())
	end
	assert(Text(rows[1], 1):GetText() == LONG, "with its whole words")
	assert(RootRect(K, Text(rows[1], 1)).bottom >= RootRect(K, Text(rows[1], 2)).top - 0.01, "the next objective starts below the wrapped lines")
	local r1, r2 = RootRect(K, rows[1]), RootRect(K, rows[2])
	assert(r1.bottom >= r2.top - 0.01, "the next quest starts below the wrapped quest, got " .. r1.bottom .. " over " .. r2.top)
	local lastBottom = RootRect(K, Text(rows[1], 2)).bottom
	assert(r1.bottom <= lastBottom + 0.01 and r1.bottom >= lastBottom - 6, "the quest ends at its last line, got " .. r1.bottom .. " for " .. lastBottom)
	local title = RootRect(K, rows[1].title)
	assert(Top(rows[1], 1) <= title.bottom + 0.01 and title.bottom >= Top(rows[1], 1), "the objective sits under the title")
	local plain = RootRect(K, rows[5])
	assert(plain.top - plain.bottom < r1.top - r1.bottom, "a quest of one short line is shorter than the wrapped one")

	local function CountRect(row, line)
		local _, _, _, x, y = line.count:GetPoint(1)
		local at = RootRect(K, row)
		local s = (at.top - at.bottom) / row:GetHeight()
		local width = line.count:GetUnboundedStringWidth() * s
		return { right = at.right + x * s, left = at.right + x * s - width, top = at.top + y * s, bottom = at.top + y * s - pitch * s }
	end
	local count = rows[2].lines[1].count
	local words = rows[2].lines[1].text
	assert(count:GetText() == "0/12" and count:IsShown(), "the count shows, got " .. tostring(count:GetText()))
	assert(High(rows[2], 1) > one * 1.9, "a counted long objective wraps too")
	local c, t = CountRect(rows[2], rows[2].lines[1]), RootRect(K, words)
	assert(math.abs(c.top - t.top) <= 0.01, "the count stays on the first line, got " .. c.top .. " for " .. t.top)
	assert(c.top - c.bottom < t.top - t.bottom, "one line high, the words are more")
	assert(t.right <= c.left + 0.01, "the words end before the count column, got " .. t.right .. " for " .. c.left)
	assert(math.abs(c.right - (RootRect(K, ns.Quests.Parts().view).right - K.Widgets.Snap(ns.Quests.Card(), 1))) <= 0.01, "the count stays at the normal content edge")

	local socketed, bare = rows[3], rows[2]
	local s3 = RootRect(K, socketed.socket)
	local w3, w2 = RootRect(K, Text(socketed, 1)), RootRect(K, Text(bare, 1))
	assert(socketed.socket:IsShown(), "the item quest has its socket")
	assert(w3.right <= s3.left + 0.01, "the words stay clear of the item socket, got " .. w3.right .. " for " .. s3.left)
	assert(CountRect(socketed, socketed.lines[1]).right <= s3.left - K.Widgets.Snap(ns.Quests.Card(), 4) + 0.01, "a socketed quest keeps its count left of the item, not on the outer count edge")
	assert(w3.right - w3.left < w2.right - w2.left - 20, "with a count and a socket the words get a narrower room")
	assert(High(socketed, 1) >= High(bare, 1) - 0.01, "so they take at least as many lines")
	assert(CountRect(socketed, socketed.lines[1]).right <= s3.left + 0.01, "and the count sits left of the socket")

	local huge = Text(rows[4], 1)
	local cap = W.LastCall(huge, "SetMaxLines")
	assert(cap and cap[1] == 3, "an objective takes three lines at most")
	assert(math.abs(High(rows[4], 1) - 3 * one) <= 0.05 * 3 * one, "and is three lines high, to the pixels each height snaps to, got " .. High(rows[4], 1) .. " for " .. 3 * one)

	for i = 1, 4 do
		local a, b = RootRect(K, rows[i]), RootRect(K, rows[i + 1])
		assert(a.bottom >= b.top - 0.01, "quest " .. i .. " does not overlap the next")
	end
	local card = RootRect(K, ns.Quests.Card())
	assert(rows[5]:IsShown() and RootRect(K, rows[5]).bottom >= card.bottom - 0.01, "every quest sits inside the card")
	Clean(env, K)
end

-- In combat with an item button shown the rows hold still: words repaint only where the row keeps its height; the
-- quest is laid out again when combat ends ------------------------------------------------------------------------

do
	local LONG = "Find and speak with Elegael Thornpaw in the northeastern part of Shadowgale Forest."
	local ITEM = { link = "|cffffffff|Hitem:5179::::::::|h[Moss-Twined Heart]|h|r", icon = 134339 }
	local list = {
		{ id = 411, title = "First", level = 10, objectives = { { text = "Crocolisk Hide: 0/6", finished = false } }, item = ITEM },
		{ id = 412, title = "Second", level = 10, objectives = { { text = "Speak to Ranger Kalanna", finished = false } } },
	}
	local env, K, ns, log = Boot({ quests = list, measure = true })
	local rows = ns.Quests.Rows()
	local before = { RootRect(K, rows[1]), RootRect(K, rows[2]) }
	env.SetCombat(true)
	list[1].objectives[1].text = "Crocolisk Hide: 3/6"
	log.Fire("QUEST_LOG_UPDATE")
	env.RunTimers()
	assert(rows[1].lines[1].count:GetText() == "3/6", "a count repaints in combat, got " .. tostring(rows[1].lines[1].count:GetText()))
	list[1].objectives[1].text = LONG
	log.Fire("QUEST_LOG_UPDATE")
	env.RunTimers()
	assert(rows[1].lines[1].text:GetText() == "Crocolisk Hide", "words that would change the row's height wait for combat to end, got " .. tostring(rows[1].lines[1].text:GetText()))
	for i = 1, 2 do
		local now = RootRect(K, rows[i])
		assert(math.abs(now.top - before[i].top) <= 0.01 and math.abs(now.bottom - before[i].bottom) <= 0.01, "row " .. i .. " holds still in combat")
	end
	env.SetCombat(false)
	env.RunTimers()
	W.Settle(env)
	assert(rows[1].lines[1].text:GetText() == LONG, "after combat the quest shows its new words")
	local now = RootRect(K, rows[1])
	assert(now.top - now.bottom > before[1].top - before[1].bottom + 5, "taller, with its wrapped lines")
	assert(RootRect(K, rows[2]).top <= now.bottom + 0.01, "and the next quest starts below it")
	Clean(env, K)
end

-- Without the quest API (an older client) the card stays out of the way and Blizzard's tracker keeps its quests ----

do
	local env, K, ns = S.New({
		before = function(env)
			Quests.Tracker(env, S.Blizzard(env))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	env.RunTimers()
	assert(not ns.Quests.Active(), "no quest API, no card")
	assert(env.ObjectiveTrackerFrame:IsVisible(), "Blizzard's tracker keeps the quests")
	assert(S.Logged(env, "quest card"), "and the devlog says why")
	Clean(env, K)
end

-- The setting off from the first load: Blizzard's tracker is never touched ----------------------------------------

do
	local env, K, ns, _, tracker = Boot({ saved = Saved({ enabled = true, quests = { enabled = false } }) })
	assert(not ns.Quests.Active(), "off from the start")
	assert(tracker:GetParent() == env.UIParent and tracker:IsVisible(), "Blizzard's tracker is untouched")
	for _, call in ipairs(tracker._calls) do
		assert(call.method ~= "SetParent", "never reparented")
	end
	Clean(env, K)
end

print("test-skins-questcard: ok")
