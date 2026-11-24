-- test-worldmap-search.lua: the map search sits in the nav bar row, off the map art, and its list shows only while the box has focus.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, _, map = M.New(true)
local nav = map.NavBar
-- Forever's breadcrumbs (NavigationBar.lua:5-51, 77-131): a home button, then one per map level. The port keeps
-- NavigationBar.lua:200-272's fit: from the current map back, the buttons that fit the nav bar's width less its buffer
-- show, after the overflow button when some do not. The widths stand for long German labels.
local fits = 0
function env.NavBar_CheckLength(self)
	fits = fits + 1
	local list, room, width, first = self.navList, self:GetWidth() - self.widthBuffer, 0, 1
	for i = #list, 1, -1 do
		width = width + list[i]:GetWidth()
		if width + (i > 1 and self.overflowButton:GetWidth() or 0) > room then first = i + 1; break end
	end
	self.overflowButton:SetShown(first > 1)
	local previous = first > 1 and self.overflowButton
	for i, crumb in ipairs(list) do
		crumb:SetShown(i >= first)
		if i >= first then
			crumb:ClearAllPoints()
			crumb:SetPoint("LEFT", previous or self, previous and "RIGHT" or "LEFT")
			previous = crumb
		end
	end
end
local function Crumb(width)
	local crumb = env.CreateFrame("Button", nil, nav)
	crumb:SetSize(width, 30)
	crumb:SetPoint("LEFT", nav, "LEFT")
	return crumb
end
nav.widthBuffer, nav.navList, nav.overflowButton = 20, {}, Crumb(30)
for _, width in ipairs({ 90, 140, 190, 100 }) do nav.navList[#nav.navList + 1] = Crumb(width) end
-- Blizzard fits the breadcrumbs when the map loads, at the nav bar's full width.
env.NavBar_CheckLength(nav)
-- Blizzard_WorldMap.lua:369-384: WorldMapMixin:OnShow puts the map back on the player's zone and refreshes its data.
local function Open() M.S.Show(map); map:SetMapID(1); map:RefreshAllDataProviders() end
Open()
local box, canvas, filter, spacer = R.search, map.ScrollContainer, map.WorldMapTrackingOptionsButton, map.TitleCanvasSpacerFrame
local failed = {}
local function Check(ok, message) if not ok then failed[#failed + 1] = message end end
-- The client's box answers "" before anything is typed; the stub answers nil until SetText.
box:SetText("")
-- The client's ClearFocus fires OnEditFocusLost on the box that had the focus; the stub only records the call.
rawset(box, "ClearFocus", function(self) if self.focused then self:GetScript("OnEditFocusLost")(self) end end)
-- Hiding the map fires OnHide on its shown descendants in the client; the stub only flips the flag.
local function Close() map:Hide(); R.panel:GetScript("OnHide")(R.panel) end
local function Rows()
	local rows = {}
	for _, frame in ipairs({ R.panel:GetChildren() }) do
		if frame:GetObjectType() == "Button" and frame:IsVisible() then rows[#rows + 1] = frame end
	end
	return rows
end
local function Focus() box:GetScript("OnEditFocusGained")(box) end
-- Blizzard_Game/Mainline/EventImplementation.lua:117-135: an unmodified left mouse-down anywhere clears the focused box
-- unless the mouse is on the box or its HasStickyFocus answers true. The frame under the mouse then gets OnMouseDown, and
-- OnClick if it still shows; MapCanvas_ScrollContainerMixin.lua:136 goes up a map on a right click.
local function Click(frame, button, modified)
	button = button or "LeftButton"
	rawset(frame, "_mouseOver", true)
	if button == "LeftButton" and not modified and box.focused and not (box.HasStickyFocus and box:HasStickyFocus()) then box:ClearFocus() end
	local down = frame:GetScript("OnMouseDown")
	if down then down(frame, button) end
	local click = frame:GetScript("OnClick")
	if click and frame:IsVisible() then click(frame, button) end
	rawset(frame, "_mouseOver", nil)
end
local function Near(a, b) return a and b and math.abs(a - b) < 0.01 end
-- NavigationBar.lua:200-272 fits the breadcrumbs inside the nav bar's own width, so a box right of it never covers them.
local function Placed(view)
	Check(box:IsVisible() and box:GetBottom() >= canvas:GetTop() and box:GetRight() <= spacer:GetRight() and box:GetLeft() >= filter:GetRight() and filter:GetLeft() >= nav:GetRight(),
		view .. ": the search sits in the nav bar row, right of the breadcrumbs and the tracking button, off the map art")
	Check(Near(box:GetTop(), nav:GetTop()) and Near(box:GetBottom(), nav:GetBottom()), view .. ": the box matches the nav bar's height")
	Check(Near(filter:GetTop(), nav:GetTop()) and Near(filter:GetBottom(), nav:GetBottom()) and Near(filter:GetWidth(), 32),
		view .. ": the tracking button shares the strip's top and bottom edges at its own width")
	local last = nav.navList[#nav.navList]
	Check(last:IsShown() and last:GetRight() <= nav:GetRight() + 0.01, view .. ": the breadcrumbs refit inside the nav bar, clear of the tracking button and the box")
end

Placed("windowed")
Check(#Rows() == 0, "at rest the box shows no list")
Focus()
local rows = Rows()
Check(#rows == 6 and rows[1]:GetTop() <= box:GetBottom() and Near(rows[1]:GetRight(), box:GetRight()) and rows[1]:GetLeft() >= canvas:GetLeft(),
	"focusing opens the nearest list below the box, over the map")
box:GetScript("OnEditFocusLost")(box)
Check(#Rows() == 0, "losing focus closes the list")
Focus()
local updates, setScript = 0, R.panel.SetScript
rawset(R.panel, "SetScript", function(self, name, fn) if name == "OnUpdate" then updates = updates + 1 end return setScript(self, name, fn) end)
box:GetScript("OnEscapePressed")(box)
rawset(R.panel, "SetScript", nil)
Check(#Rows() == 0 and updates == 1, "Escape closes the list with one route refresh: " .. updates)
Focus()
Click(canvas)
Check(#Rows() == 0 and not box.focused, "a click on the map clears the box's focus and closes the list")
for _, how in ipairs({ { "RightButton", false, "a right click on the map, which goes up a map," }, { "LeftButton", true, "a modified left click on the map" } }) do
	Focus()
	Click(canvas, how[1], how[2])
	if how[1] == "RightButton" then map:SetMapID(12) end
	Check(#Rows() == 0 and not box.focused, how[3] .. " closes the list")
	map:SetMapID(1)
end
Focus()
local row = Rows()[1]
Check(row, "the list shows a row to click")
if row then Click(row) end
Check(#Rows() == 0 and R.card:IsShown(), "a click on a row keeps the focus until the row picks, then the list closes")
R.Clear()
for _, how in ipairs({ "after a click on the close button", "with the box still focused" }) do
	Focus()
	if how:find("click") then Click(map.BorderFrame.CloseButton) end
	Close()
	Open()
	-- The clear on close reaches the box as OnTextChanged; the client can deliver it once the box shows again.
	box:GetScript("OnTextChanged")(box, false)
	Check(#Rows() == 0 and R.search:GetText() == "", "closed " .. how .. ", the reopened map shows no list")
	Focus()
	Check(#Rows() == 6, "closed " .. how .. ", focusing the box again opens the list")
	box:GetScript("OnEditFocusLost")(box)
end

-- Blizzard_WorldMap.lua:60-74, 470-484: maximizing widens the map and moves the nav bar 8 in from the spacer's left.
map:SetSize(1600 + 333, 820)
nav:SetPoint("TOPLEFT", spacer, "TOPLEFT", 8, -25)
map:OnFrameSizeChanged()
Placed("maximized")
map:SetSize(702 + 333, 534)
nav:SetPoint("TOPLEFT", spacer, "TOPLEFT", 64, -25)
map:OnFrameSizeChanged()
Placed("windowed again")
K.Options.Write("Skins", "worldMap.routes", false)
local shown = 0
for _, crumb in ipairs(nav.navList) do if crumb:IsShown() then shown = shown + 1 end end
Check(not box:IsVisible() and Near(nav:GetRight(), spacer:GetRight() - 50) and shown == 4 and not nav.overflowButton:IsShown(),
	"search off gives Blizzard's nav bar its whole width back, and the breadcrumbs uncollapse into it")
K.Options.Write("Skins", "worldMap.routes", true)
Placed("search back on")
local before = fits
map:RefreshAllDataProviders()
map:SetMapID(1)
Check(fits == before, "a data refresh that leaves the nav bar's width alone does not refit the breadcrumbs")

-- Without Forever's nav bar constant the box still keeps off the map art.
local bare, K2, R2, _, map2 = M.New(true)
bare.WorldMapConstants = nil
M.S.Show(map2); map2:SetMapID(1); map2:RefreshAllDataProviders()
Check(R2.search:GetBottom() >= map2.ScrollContainer:GetTop(), "without the nav bar constant the box sits off the map art")
assert(#bare._errors == 0 and K2.ErrorCount() == 0, tostring(bare._errors[1]))

assert(#failed == 0, "\n" .. table.concat(failed, "\n"))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map search ok")
