-- test-widgets-lists.lua: the virtualised scroll list with eased scrolling and end bounce, the dropdown, and the font and texture pickers.
local W = dofile("Tools/regression/widget_env.lua")

local function items(n)
	local out = {}
	for i = 1, n do
		out[i] = { label = "Item " .. i }
	end
	return out
end

local function newList(K, opts)
	local updates = {}
	opts = opts or {}
	opts.width, opts.height, opts.rowHeight = opts.width or 200, opts.height or 120, opts.rowHeight or 24
	opts.updateRow = function(row, item, index)
		updates[#updates + 1] = index
		row.label:SetText(item.label)
	end
	local list = K.Widgets.ScrollList(K.Scale.Root(), opts)
	return list, updates
end

local function shown(list)
	local out = {}
	for _, row in ipairs(list.rows) do
		if row:IsShown() then
			out[#out + 1] = row.index
		end
	end
	table.sort(out)
	return out
end

-- Virtualised rows: only enough rows to fill the view, recycled as the list scrolls.
do
	local env, K = W.New()
	local list, updates = newList(K)
	list:SetData(items(100))
	assert(#list.rows == 6, "120 units of 24-unit rows need 6 rows, one spare; got " .. #list.rows)
	local s = shown(list)
	assert(s[1] == 1 and s[6] == 6, "the first rows show")
	assert(list.rows[1].label:GetText() == "Item 1")
	assert(W.LastCall(list.view, "SetClipsChildren")[1] == true, "the view clips its rows")
	assert(list:GetMaxOffset() == 100 * 24 - 120, "the scroll range")
	local before = #updates
	list:Refresh()
	assert(#updates == before, "a refresh at the same offset updates no row")
	list:Scroll(-1)
	W.Settle(env)
	assert(list:GetOffset() == 72, "one wheel step scrolls three rows, eased to a stop; got " .. list:GetOffset())
	s = shown(list)
	assert(s[1] == 4 and s[#s] == 9, "rows 4 to 9 now show")
	local p = list.rows[1]._points[1]
	assert(p[2] == list.view and p[1] == "TOPLEFT", "rows hang from the view")
	assert(list.bar:IsShown() and list.thumb:IsShown(), "a scroll bar while the content overflows")
	assert(#env._errors == 0)
end

-- A list that grows taller keeps its offset inside the new range.
do
	local env, K = W.New()
	local list = newList(K)
	list:SetData(items(10))
	list:ScrollTo(120, true)
	list:Scroll(-1)
	W.Tick(env, 0.016)
	list:SetSize(200, 240)
	list:GetScript("OnSizeChanged")(list, 200, 240)
	W.Settle(env)
	assert(list:GetOffset() == 0 and list:GetMaxOffset() == 0, "the offset clamps to the new range, got " .. list:GetOffset())
	local s = shown(list)
	assert(s[1] == 1 and #s == 10, "every row shows")
end

-- Dragging the scroll thumb keeps the point the pointer grabbed under the pointer.
do
	local env, K = W.New()
	local list = newList(K)
	list:SetData(items(20))
	list:ScrollTo(list:GetMaxOffset(), true)
	local bar = list.bar
	bar.GetTop = function()
		return 500
	end
	bar.GetHeight = function()
		return 120
	end
	local scale = bar:GetEffectiveScale()
	local thumb = list.thumb:GetHeight()
	local travel = 120 - thumb
	local y = 500 - travel - thumb / 2
	env.GetCursorPosition = function()
		return 0, y * scale
	end
	bar:GetScript("OnMouseDown")(bar, "LeftButton")
	bar:GetScript("OnUpdate")(bar, 0.016)
	assert(list:GetOffset() == list:GetMaxOffset(), "grabbing the thumb does not move the list, got " .. list:GetOffset())
	y = y + travel / 2
	bar:GetScript("OnUpdate")(bar, 0.016)
	assert(W.Near(list:GetOffset(), list:GetMaxOffset() / 2), "half the travel scrolls half the range")
	bar:GetScript("OnMouseUp")(bar, "LeftButton")
	assert(bar:GetScript("OnUpdate") == nil)
end

-- End bounce: scrolling past either end overshoots briefly and settles back on the end.
do
	local env, K = W.New()
	local list = newList(K)
	list:SetData(items(20))
	local maxOffset = list:GetMaxOffset()
	list:ScrollTo(maxOffset, true)
	assert(list:GetOffset() == maxOffset, "ScrollTo with instant jumps")
	local furthest = maxOffset
	local setOffset = list.SetOffset
	list.SetOffset = function(self, value)
		furthest = math.max(furthest, value)
		setOffset(self, value)
	end
	list:Scroll(-1)
	W.Settle(env)
	assert(furthest > maxOffset, "a wheel step past the end overshoots")
	assert(list:GetOffset() == maxOffset, "and settles on the end")
	local nearest = 0
	list.SetOffset = function(self, value)
		nearest = math.min(nearest, value)
		setOffset(self, value)
	end
	list:ScrollTo(0, true)
	list:Scroll(1)
	W.Settle(env)
	assert(nearest < 0 and list:GetOffset() == 0, "the top bounces too")
	list.SetOffset = setOffset
	list:SetData(items(3))
	assert(list:GetMaxOffset() == 0 and list.bar:IsShown() == false, "short content has no scroll bar")
	list:Scroll(-1)
	W.Settle(env)
	assert(list:GetOffset() == 0, "and does not move")
	K.Motion.SetReducedMotion(true)
	list:SetData(items(50))
	list:Scroll(-1)
	assert(list:GetOffset() == 72, "reduced motion scrolls at once")
end

-- Rows of their own height: with heightOf, each row is as tall as its item asks and sits under the rows above it.
do
	local env, K = W.New()
	local heights = { 24, 60, 24, 100, 24, 24, 24, 48 }
	local data, asked = {}, {}
	for i, h in ipairs(heights) do
		data[i] = { label = "Item " .. i, h = h }
	end
	local list = newList(K, {
		heightOf = function(item, index, self, width)
			asked[#asked + 1] = width
			return item.h
		end,
	})
	list:SetData(data)
	assert(asked[1] == list:GetViewWidth() and asked[1] > 0 and asked[1] < 200, "heightOf is told the width the rows get, inside the scroll bar")
	assert(list:GetMaxOffset() == 328 - 120, "the scroll range is the rows' total height less the view, got " .. list:GetMaxOffset())
	local s = shown(list)
	assert(s[1] == 1 and s[#s] == 4 and #s == 4, "the rows that reach into the view show: 1 to 4")
	local function rowFor(index)
		for _, row in ipairs(list.rows) do
			if row.index == index and row:IsShown() then
				return row
			end
		end
	end
	local second = rowFor(2)
	assert(second:GetHeight() == 60, "a row takes its item's height, got " .. tostring(second:GetHeight()))
	assert(second._points[1][5] == -24, "and sits under the rows above it")
	list:ScrollTo(100, true)
	W.Settle(env)
	s = shown(list)
	assert(s[1] == 3 and s[#s] == 5, "scrolled 100 units, rows 3 to 5 reach into the view, got " .. tostring(s[1]) .. " to " .. tostring(s[#s]))
	assert(rowFor(3)._points[1][5] == 16, "row 3 starts 84 units down, 16 above the view's top")
	list:ScrollToIndex(8, true)
	W.Settle(env)
	assert(list:GetOffset() == 208, "scrolling to the last row brings its bottom to the view's bottom, got " .. list:GetOffset())
	list:ScrollToIndex(2, true)
	W.Settle(env)
	assert(list:GetOffset() == 24, "scrolling up to row 2 brings its top to the view's top, got " .. list:GetOffset())
	local before = #asked
	list:SetSize(160, 120)
	list:GetScript("OnSizeChanged")(list, 160, 120)
	assert(#asked > before, "a new width measures the rows again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Rows fade in one after another when new data arrives.
do
	local env, K = W.New()
	local list = newList(K)
	list:SetData(items(10))
	assert(list.rows[1]:GetAlpha() < 1 or list.rows[2]:GetAlpha() < 1, "rows start faded")
	W.Tick(env, 0.06)
	assert(list.rows[1]:GetAlpha() > list.rows[3]:GetAlpha(), "the first row leads the third")
	W.Settle(env)
	for _, row in ipairs(list.rows) do
		assert(row:GetAlpha() == 1, "every row ends fully shown")
	end
end

-- The default row: a button with a label, which runs onClick with the item.
do
	local _, K = W.New()
	local clicked
	local list = K.Widgets.ScrollList(K.Scale.Root(), { width = 200, height = 96, onClick = function(item, index)
		clicked = { item, index }
	end })
	list:SetData({ "Alpha", { label = "Beta" } })
	assert(list.rows[1].label:GetText() == "Alpha" and list.rows[2].label:GetText() == "Beta", "strings and labelled items")
	W.Click(list.rows[2])
	assert(clicked and clicked[2] == 2 and clicked[1].label == "Beta", "a row click reports the item")
end

local OPTIONS = {
	{ value = 1, label = "Option 1" },
	{ value = 2, label = "Option 2" },
	{ value = 3, label = "Option 3" },
	{ value = 4, label = "Option 4" },
}

-- Dropdown: a raised box with the chosen label and a chevron; its menu marks the choice with an accent bar.
do
	local env, K = W.New()
	local Tokens = K.Tokens
	local picked = {}
	local dd = K.Widgets.Dropdown(K.Scale.Root(), { options = OPTIONS, onChange = function(value)
		picked[#picked + 1] = value
	end })
	assert(dd.text:GetText() == "Select Option", "the placeholder before a choice")
	assert(W.Near(dd:GetHeight(), K.Scale.Snap(26)), "the design's 26-unit box")
	assert(W.LastCall(dd.chevron, "SetTexture")[1] == Tokens.Texture("glyphChevron"), "a chevron")
	W.Click(dd)
	assert(dd:IsOpen(), "a click opens the menu")
	local menu = K.Widgets.DropdownMenu()
	assert(menu:IsShown() and menu.owner == dd and menu:GetFrameStrata() == "FULLSCREEN_DIALOG")
	assert(#menu.list.rows >= 4 and menu.list.rows[1].label:GetText() == "Option 1", "the options fill the menu")
	assert(W.LastCall(dd.chevron, "SetTexCoord")[3] == 1, "the chevron points up while open")
	W.Click(menu.list.rows[2])
	assert(dd:GetValue() == 2 and picked[1] == 2 and dd.text:GetText() == "Option 2", "a row click chooses")
	W.Settle(env)
	assert(not dd:IsOpen() and menu:IsShown() == false, "and closes the menu")
	W.Click(dd)
	local row = menu.list.rows[2]
	assert(row.mark:IsShown() and W.SameRGB(row.mark, Tokens.Color("accent")), "the chosen row has an accent bar")
	assert(W.Near(row.mark:GetWidth(), K.Scale.Border()), "one border wide")
	assert(menu.list.rows[1].mark:IsShown() == false)
	W.Click(menu.catcher)
	W.Settle(env)
	assert(not dd:IsOpen(), "a click outside closes it")
	W.Click(dd)
	W.Key(menu, "ESCAPE")
	W.Settle(env)
	assert(not dd:IsOpen(), "Escape closes it")
	W.Click(dd)
	dd:SetOptions({ { value = 1, label = "Renamed 1" }, { value = 2, label = "Renamed 2" } })
	assert(menu.list.rows[1].label:GetText() == "Renamed 1" and menu.list:GetMaxOffset() == 0, "new options refill an open menu")
	dd:SetOptions(OPTIONS)
	dd:Close()
	W.Settle(env)
	assert(dd:SetValue(3, true) == true and #picked == 1 and dd.text:GetText() == "Option 3", "a silent SetValue")
	assert(dd:SetValue(99) == false and dd:GetValue() == 3, "an unknown value is refused")
	dd:SetOptions(function()
		return { { value = "a", label = "Alpha" }, { value = "b", label = "Beta" } }
	end)
	assert(dd.text:GetText() == "Select Option", "new options without the value show the placeholder")
	dd:SetValue("b")
	assert(dd.text:GetText() == "Beta", "options from a function")
	dd:Disable()
	W.Click(dd)
	assert(not dd:IsOpen(), "a disabled dropdown stays shut")
	assert(#env._errors == 0)
end

-- A long option list scrolls inside the menu, and a broken option function shows an empty menu, not an error box.
do
	local env, K = W.New()
	local long = {}
	for i = 1, 30 do
		long[i] = { value = i, label = "Choice " .. i }
	end
	local dd = K.Widgets.Dropdown(K.Scale.Root(), { options = long, value = 30, maxRows = 8 })
	W.Click(dd)
	local menu = K.Widgets.DropdownMenu()
	assert(W.Near(menu.list:GetHeight(), K.Scale.Snap(8 * K.Tokens.Size("rowHeight"))), "eight rows show")
	assert(menu.list:GetOffset() > 0, "the menu scrolls to the chosen option")
	dd:Close()
	W.Settle(env)
	local scaled = K.Widgets.Dropdown(K.Scale.Root(), { options = OPTIONS, width = 200 })
	scaled:SetScale(1.5)
	W.Click(scaled)
	local shownWidth = menu:GetWidth() * menu:GetEffectiveScale()
	local ownerWidth = scaled:GetWidth() * scaled:GetEffectiveScale()
	assert(math.abs(shownWidth - ownerWidth) <= K.Scale.Pixel(1) * menu:GetEffectiveScale() + 1e-6, "the menu matches a scaled dropdown's width on screen")
	scaled:Close()
	local errors = K.ErrorCount()
	local broken = K.Widgets.Dropdown(K.Scale.Root(), { options = function()
		error("no list")
	end })
	W.Click(broken)
	assert(K.ErrorCount() == errors + 1, "the error is reported once")
	assert(menu.list:GetMaxOffset() == 0, "and the menu is empty")
	broken:Close()
	assert(#env._errors >= 1)
end

-- The media options: KstyleUI's own media, then LibSharedMedia's, without repeats.
do
	local lsm = {
		Register = function() end,
		List = function(_, kind)
			if kind == "font" then
				return { "Arial Narrow", "KstyleUI Source Sans 3 Semibold", "Morpheus" }
			end
			return { "Blizzard", "KstyleUI Glass" }
		end,
		Fetch = function(_, kind, name)
			local paths = {
				["Arial Narrow"] = "Fonts\\ARIALN.TTF",
				["KstyleUI Source Sans 3 Semibold"] = "Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Semibold.ttf",
				["Morpheus"] = "Fonts\\MORPHEUS.TTF",
				["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
				["KstyleUI Glass"] = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\BarGlass.png",
			}
			return paths[name]
		end,
	}
	local env, K = W.New({ setup = function(e)
		e.LibStub = function(major, silent)
			assert(major == "LibSharedMedia-3.0" and silent == true)
			return lsm
		end
	end })
	local fonts = K.Widgets.MediaOptions("font")
	assert(fonts[1].label == "Cinzel SemiBold" and fonts[1].value == K.Tokens.FontPath("CinzelSemiBold"), "KstyleUI's faces come first")
	local labels = {}
	for _, option in ipairs(fonts) do
		labels[option.label] = (labels[option.label] or 0) + 1
	end
	assert(labels["Arial Narrow"] == 1 and labels["Morpheus"] == 1, "then LibSharedMedia's fonts")
	assert(labels["KstyleUI Source Sans 3 Semibold"] == nil, "a path already listed is not repeated")
	assert(#fonts == 9, "KstyleUI's seven faces and LibSharedMedia's two")
	local bars = K.Widgets.MediaOptions("statusbar")
	assert(#bars == 4 and bars[4].label == "Blizzard", "status bars too")
	local picker = K.Widgets.FontPicker(K.Scale.Root(), { value = fonts[4].value })
	assert(picker.text:GetText() == fonts[4].label, "the font picker shows the chosen face")
	W.Click(picker)
	local menu = K.Widgets.DropdownMenu()
	assert(W.LastCall(menu.list.rows[4].label, "SetFont")[1] == fonts[4].value, "each row previews its face")
	picker:Close()
	local tex = K.Widgets.TexturePicker(K.Scale.Root(), { value = bars[1].value })
	W.Click(tex)
	assert(menu.list.rows[1].sample:IsShown() and W.LastCall(menu.list.rows[1].sample, "SetTexture")[1] == bars[1].value, "each row previews its texture")
	assert(W.LastCall(menu.list.rows[1].label, "SetFont")[1] == (K.Tokens.Font("body")), "a reused row gets the body font back")
	tex:Close()
	local unknown = K.Widgets.FontPicker(K.Scale.Root(), { value = "Interface\\AddOns\\Gone\\Gone.ttf" })
	assert(unknown.text:GetText() == "Gone.ttf", "a path no list knows shows its file name")
	assert(#env._errors == 0)
end

-- Without LibSharedMedia the pickers list KstyleUI's own media.
do
	local _, K = W.New()
	assert(#K.Widgets.MediaOptions("font") == 7 and #K.Widgets.MediaOptions("statusbar") == 3)
	assert(#K.Widgets.MediaOptions("background") == 0, "a kind KstyleUI has no media for is empty")
end

print("widgets lists ok")
