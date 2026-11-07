-- GroupFinder.lua: the skin for Forever's group finder, the vanilla-style LFGParentFrame with its listing, browse and who-list pages.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit
local Skin = K.Skin

local function Each(fn, ...)
	for i = 1, select("#", ...) do
		local item = select(i, ...)
		if item ~= nil then
			fn(item)
		end
	end
end

local function BrowseRow(row)
	Kit.Hush(row, row.ResultBG, row.Selected, row.Highlight)
	Kit.Select(row, row.Selected)
end

local function WhoRow(row)
	Kit.Hush(row, row.Background, row.Selected)
	Kit.Select(row, row.Selected)
end

local function Listing(frame)
	if not Kit.Have(frame, "LFGListingFrame") then
		return
	end
	Kit.Window(frame, { tabs = false })
	if frame.RolesSection then
		Skin.Strip(frame.RolesSection)
	end
	if frame.DividerFrame then
		Skin.Strip(frame.DividerFrame)
	end
	Each(Kit.Button, frame.BackButton, frame.PostButton)
	local group = frame.GroupRoleButtons
	if type(group) == "table" then
		Kit.Button(group.RolePollButton)
		Kit.Dropdown(group.RoleDropdown)
	end
	local friendly = frame.NewPlayerFriendlyButton
	if type(friendly) == "table" then
		Kit.CheckBox(friendly.CheckButton)
	end
	local view = frame.ActivityView
	if type(view) ~= "table" then
		return
	end
	Skin.Strip(view)
	Each(Kit.Dropdown, view.PlayStyleDropdown, view.VoiceChatDropdown)
	if type(view.LevelRangesCheckbox) == "table" then
		Kit.CheckBox(view.LevelRangesCheckbox.Checkbox)
	end
	Kit.ScrollBar(view.ScrollBar)
	Kit.InputScroll(view.Comment)
end

local function Browse(frame)
	if not Kit.Have(frame, "LFGBrowseFrame") then
		return
	end
	Kit.Window(frame, { tabs = false })
	Each(Kit.Dropdown, frame.CategoryDropdown, frame.ActivityDropdown)
	Kit.Square(frame.RefreshButton)
	Kit.ScrollBar(frame.ScrollBar)
	Each(Kit.Button, frame.SendMessageButton, frame.GroupInviteButton)
	if frame.ScrollBox then
		Kit.Rows(frame.ScrollBox, BrowseRow)
	end
end

local function Who(frame)
	if not Kit.Have(frame, "LFGWhoListFrame") then
		return
	end
	Kit.Window(frame, { tabs = false })
	Kit.EditBox(frame.EditBox)
	Kit.Square(frame.WhoSearch)
	Kit.Dropdown(frame.FilterDropdown)
	Kit.ScrollBar(frame.ScrollBar)
	if frame.ScrollBox then
		Kit.Rows(frame.ScrollBox, WhoRow)
	end
end

local function Apply()
	local parent = LFGParentFrame
	if not Kit.Have(parent, "LFGParentFrame") then
		return false
	end
	Skin.CloseButton(LFGParentFrameCloseButton)
	Each(Kit.Tab, parent.Tab1, parent.Tab2, parent.Tab3)
	Each(Kit.SideTab, parent.ListingTab, parent.BrowsingTab, parent.WhoListingTab)
	Listing(LFGListingFrame)
	Browse(LFGBrowseFrame)
	Who(LFGWhoListFrame)
	return true
end

ns.Skins.Add({
	key = "groupFinder",
	label = L["Group finder"],
	help = L["Restyles the Looking for Group window: listing, browsing and the who list."],
	addon = "Blizzard_GroupFinder_VanillaStyle",
	frame = "LFGParentFrame",
	Apply = Apply,
})
