-- test-worldmap-search.lua: the map search sits in the nav bar row, off the map art, and its list shows only while the box has focus.
local M = dofile("Tools/regression/worldmap_env.lua")
local env, K, R, _, map = M.New(true)
-- Blizzard_WorldMap.lua:369-384: WorldMapMixin:OnShow puts the map back on the player's zone and refreshes its data.
local function Open() M.S.Show(map); map:SetMapID(1); map:RefreshAllDataProviders() end
Open()
local box, canvas, nav, filter, spacer = R.search, map.ScrollContainer, map.NavBar, map.WorldMapTrackingOptionsButton, map.TitleCanvasSpacerFrame
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
-- Blizzard_Game/Mainline/EventImplementation.lua:117-135: a left mouse-down anywhere clears the focused box unless the
-- mouse is on the box or the box's HasStickyFocus answers true; the click then reaches the frame under the mouse if it still shows.
local function Click(frame)
	rawset(frame, "_mouseOver", true)
	if box.focused and not (box.HasStickyFocus and box:HasStickyFocus()) then box:ClearFocus() end
	local click = frame:GetScript("OnClick")
	if click and frame:IsVisible() then click(frame) end
	rawset(frame, "_mouseOver", nil)
end
local function Near(a, b) return a and b and math.abs(a - b) < 0.01 end
-- NavigationBar.lua:200-272 fits the breadcrumbs inside the nav bar's own width, so a box right of it never covers them.
local function Placed(view)
	Check(box:IsVisible() and box:GetBottom() >= canvas:GetTop() and box:GetRight() <= spacer:GetRight() and box:GetLeft() >= filter:GetRight() and filter:GetLeft() >= nav:GetRight(),
		view .. ": the search sits in the nav bar row, right of the breadcrumbs and the tracking button, off the map art")
	Check(Near(box:GetTop(), nav:GetTop()) and Near(box:GetBottom(), nav:GetBottom()), view .. ": the box matches the nav bar's height")
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
box:GetScript("OnEscapePressed")(box)
Check(#Rows() == 0, "Escape closes the list")
Focus()
Click(canvas)
Check(#Rows() == 0 and not box.focused, "a click on the map clears the box's focus and closes the list")
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
K.Options.Write("Skins", "worldMap.routes", false)
Check(not box:IsVisible() and Near(nav:GetRight(), spacer:GetRight() - 50), "search off gives Blizzard's nav bar its whole width back")
K.Options.Write("Skins", "worldMap.routes", true)
Placed("search back on")

assert(#failed == 0, table.concat(failed, "\n"))
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("world map search ok")
