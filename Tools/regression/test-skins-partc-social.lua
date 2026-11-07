-- test-skins-partc-social.lua: the friends and the guild and communities skins restyle Forever's FriendsFrame and CommunitiesFrame, their tabs, lists and controls, without touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local HOOKED = { Show = true, Hide = true, SetShown = true, AddTab = true, SetTabSelected = true }

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

local function Button(B, parent, key, name)
	local button = B.frame("Button", parent, name)
	button.Art = B.texture(button)
	if key then
		parent[key] = button
	end
	return button
end

local function Dropdown(B, parent, key)
	local drop = B.frame("Button", parent)
	drop.Background, drop.Arrow, drop.Text = B.texture(drop, "BACKGROUND"), B.texture(drop), B.text(drop)
	parent[key] = drop
	return drop
end

-- Window(B, name, parent) -> a stand-in ButtonFrameTemplate window: NineSlice, Bg, portrait, title and close button.
local function Window(B, name, parent)
	local f = B.frame("Frame", parent, name)
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	f.NineSliceArt = B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	f.PortraitContainer = B.frame("Frame", f)
	f.PortraitContainer.portrait = B.texture(f.PortraitContainer)
	Button(B, f, "CloseButton")
	return f
end

-- TabSystem(B, parent) -> a stand-in TabSystemTemplate with two tabs and AddTab.
local function TabSystem(B, parent)
	local system = B.frame("Frame", parent)
	system.tabs = {}
	local function NewTab()
		local tab = B.frame("Button", system)
		B.texture(tab)
		tab.Text = B.text(tab)
		function tab.SetTabSelected(self, selected)
			self.isSelected = selected
		end
		return tab
	end
	system.tabs[1], system.tabs[2] = NewTab(), NewTab()
	system.spare = NewTab()
	function system.AddTab(self)
		self.tabs[#self.tabs + 1] = self.spare
	end
	return system
end

-- Friends(env, B) -> the stand-in Camelot FriendsFrame with its list, ignore window and raid tab.
local function Friends(env, B)
	local p = {}
	local f = Window(B, "FriendsFrame")
	p.icon = B.texture(f, "OVERLAY")
	env.FriendsFrameTitleText = B.text(f)
	f.Tabs = {}
	for i, n in ipairs({ 1, 3, 4 }) do
		local tab = Button(B, f, nil, "FriendsFrameTab" .. n)
		tab.Text = B.text(tab)
		f.Tabs[i] = tab
	end
	f.numTabs = 3
	local header = B.frame("Frame", f, "FriendsTabHeader")
	f.FriendsTabHeader = header
	header.TabSystem = TabSystem(B, header)
	Dropdown(B, header, "StatusDropdown")
	local bnet = B.frame("Frame", header)
	header.BattlenetFrame = bnet
	p.bnetArt = B.texture(bnet, "BACKGROUND")
	bnet.Tag = B.text(bnet)
	local broadcast = B.frame("Frame", bnet)
	bnet.BroadcastFrame = broadcast
	p.broadcastTitle = B.text(broadcast)
	broadcast.Border = B.frame("Frame", broadcast)
	p.broadcastBorder = B.texture(broadcast.Border)
	broadcast.EditBox = B.frame("EditBox", broadcast)
	p.broadcastEdit = B.texture(broadcast.EditBox)
	Button(B, broadcast, "UpdateButton")
	Button(B, broadcast, "CancelButton")

	local list = B.frame("Frame", f, "FriendsListFrame")
	list.ScrollBar = B.frame("Frame", list)
	local box = S.ScrollBox(B, list)
	list.ScrollBox = box
	local friend = B.frame("Button", box.ScrollTarget)
	friend.background = B.texture(friend, "BACKGROUND")
	friend.status = B.texture(friend)
	friend.gameIcon = B.texture(friend)
	friend.name, friend.info = B.text(friend), B.text(friend)
	friend:SetHighlightTexture(B.texture(friend, "HIGHLIGHT"))
	box.AddRow(friend, {})
	local divider = B.frame("Frame", box.ScrollTarget)
	p.dividerArt = B.texture(divider)
	box.AddRow(divider, {})
	local invite = B.frame("Frame", box.ScrollTarget)
	invite.Background = B.texture(invite, "BACKGROUND")
	invite.Name = B.text(invite)
	Button(B, invite, "AcceptButton")
	local decline = Button(B, invite, "DeclineButton")
	decline.Icon = B.texture(decline)
	box.AddRow(invite, {})
	local inviteHeader = B.frame("Button", box.ScrollTarget)
	inviteHeader.BG = B.texture(inviteHeader, "BACKGROUND")
	inviteHeader.RightArrow, inviteHeader.DownArrow = B.texture(inviteHeader), B.texture(inviteHeader)
	box.AddRow(inviteHeader, {})
	Button(B, list, nil, "FriendsFrameAddFriendButton")
	Button(B, list, nil, "FriendsFrameSendMessageButton")

	local ignore = Window(B, nil, f)
	f.IgnoreListWindow = ignore
	Button(B, ignore, "UnignorePlayerButton")
	ignore.ScrollBar = B.frame("Frame", ignore)
	ignore.ScrollBox = S.ScrollBox(B, ignore)
	local ignored = B.frame("Button", ignore.ScrollBox.ScrollTarget)
	ignored.name = B.text(ignored)
	ignored:SetHighlightTexture(B.texture(ignored, "HIGHLIGHT"))
	ignore.ScrollBox.AddRow(ignored, {})
	local heading = B.frame("Frame", ignore.ScrollBox.ScrollTarget)
	heading.Title = B.text(heading)
	ignore.ScrollBox.AddRow(heading, {})

	local raid = B.frame("Frame", f, "RaidFrame")
	local assist = B.frame("CheckButton", raid, "RaidFrameAllAssistCheckButton")
	B.texture(assist)
	p.assistLabel = B.text(assist)
	Button(B, raid, nil, "RaidFrameConvertToRaidButton")
	Button(B, raid, nil, "RaidFrameRaidInfoButton")
	p.frame, p.friend, p.divider, p.invite, p.inviteHeader, p.ignored, p.heading = f, friend, divider, invite, inviteHeader, ignored, heading
	return p
end

-- The friends window ------------------------------------------------------------------------------------

do
	local B, p, snap
	local env, K, ns = S.New({
		setup = S.UseScrollUtil,
		loaded = { Blizzard_FriendsFrame = true },
		before = function(env)
			B = S.Blizzard(env)
			p = Friends(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	assert(K.Options.Row("Skins", "friends.enabled"), "the friends list has a switch")
	K.Modules.Enable("Skins")
	assert(not ns.Skins.IsApplied("friends"))
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("friends") and S.Logged(env, "friends: applied"), "the first show skins the window")
	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(f.Bg) == 0 and Alpha(p.icon) == 0, "a glass panel replaces the window art and the portrait icon")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading") and FontPath(env.FriendsFrameTitleText) == Style.Font("heading"), "both titles wear the heading font")
	for _, tab in ipairs(f.Tabs) do
		assert(K.Skin.IsSkinned(tab, "Tab"), "the bottom tabs get the accent underline")
	end
	local system = f.FriendsTabHeader.TabSystem
	assert(K.Skin.IsSkinned(system.tabs[1], "Tab") and K.Skin.IsSkinned(system.tabs[2], "Tab"), "the friends and recent allies tabs too")
	system:AddTab()
	assert(K.Skin.IsSkinned(system.spare, "Tab"), "a tab added later is skinned")
	assert(K.Skin.IsSkinned(f.FriendsTabHeader.StatusDropdown, "Backdrop"), "the status dropdown wears a raised tile")
	local bnet = f.FriendsTabHeader.BattlenetFrame
	assert(Alpha(p.bnetArt) == 0 and K.Skin.IsSkinned(bnet, "Backdrop"), "the battle tag bar wears a raised tile")
	assert(FontPath(bnet.Tag) == Style.Font("body"))
	local broadcast = bnet.BroadcastFrame
	assert(Alpha(p.broadcastBorder) == 0 and K.Skin.IsSkinned(broadcast, "Backdrop"), "the broadcast box sits on glass")
	assert(K.Skin.IsSkinned(broadcast.EditBox, "EditBox") and Alpha(p.broadcastEdit) == 0)
	assert(K.Skin.IsSkinned(broadcast.UpdateButton, "Button") and K.Skin.IsSkinned(broadcast.CancelButton, "Button"))
	assert(FontPath(p.broadcastTitle) == Style.Font("heading"))
	assert(K.Skin.IsSkinned(env.FriendsListFrame.ScrollBar, "ScrollBar"), "the list's scroll bar is restyled")
	assert(K.Skin.IsSkinned(env.FriendsFrameAddFriendButton, "Button") and K.Skin.IsSkinned(env.FriendsFrameSendMessageButton, "Button"))

	local friend = p.friend
	assert(Alpha(friend.background) == 1 and Alpha(friend.status) == 1 and Alpha(friend.gameIcon) == 1, "a friend row keeps its tint, status and game icons")
	assert(FontPath(friend.name) == Style.Font("body") and FontPath(friend.info) == Style.Font("body"))
	local highlight = friend:GetHighlightTexture()
	assert(W.SameRGB(highlight, Style.Accent()), "the friend row highlight is an accent wash")
	assert(Alpha(p.dividerArt) == 0, "the online divider art goes for an accent line")
	assert(K.Skin.IsSkinned(p.invite.AcceptButton, "Button") and K.Skin.IsSkinned(p.invite.DeclineButton, "Button"), "invite buttons are restyled")
	assert(Alpha(p.invite.DeclineButton.Icon) == 1 and Alpha(p.invite.DeclineButton.Art) == 0, "the decline button keeps its cross")
	assert(Alpha(p.inviteHeader.BG) == 0 and Alpha(p.inviteHeader.RightArrow) == 1 and K.Skin.IsSkinned(p.inviteHeader, "Backdrop"), "an invite header becomes a tile and keeps its arrows")

	local ignore = f.IgnoreListWindow
	assert(K.Skin.IsSkinned(ignore, "Window") and K.Skin.IsSkinned(ignore.UnignorePlayerButton, "Button"), "the ignore list window sits on glass")
	assert(FontPath(p.ignored.name) == Style.Font("body") and FontPath(p.heading.Title) == Style.Font("caption"), "ignored names and headers wear the skin fonts")

	assert(K.Skin.IsSkinned(env.RaidFrameAllAssistCheckButton, "CheckBox") and FontPath(p.assistLabel) == Style.Font("body"), "the raid tab's check box is restyled")
	assert(K.Skin.IsSkinned(env.RaidFrameConvertToRaidButton, "Button") and K.Skin.IsSkinned(env.RaidFrameRaidInfoButton, "Button"))
	K.Options.Write("Skins", "accent.source", "custom")
	K.Options.Write("Skins", "accent.color", { r = 0.2, g = 0.4, b = 0.6 })
	assert(W.SameRGB(K.Skin.Parts(system.tabs[1]).underline, 0.2, 0.4, 0.6), "tab underlines follow the module's accent")
	assert(W.SameRGB(K.Skin.Parts(f.Tabs[1]).underline, 0.2, 0.4, 0.6), "the bottom tabs too")
	assert(W.SameRGB(K.Skin.Parts(env.RaidFrameAllAssistCheckButton).mark, 0.2, 0.4, 0.6), "and check marks")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Communities(env, B) -> the stand-in CommunitiesFrame Blizzard_Communities builds.
local function Communities(env, B)
	local p = {}
	local f = Window(B, "CommunitiesFrame")
	f.PortraitOverlay = B.frame("Frame", f)
	p.tabard = B.texture(f.PortraitOverlay, "BACKGROUND")
	f.MaximizeMinimizeFrame = B.frame("Frame", f)
	Button(B, f.MaximizeMinimizeFrame, "MaximizeButton")
	Button(B, f.MaximizeMinimizeFrame, "MinimizeButton")
	for _, key in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
		local tab = B.frame("CheckButton", f)
		tab.Icon = B.texture(tab)
		tab.Art = B.texture(tab, "BORDER")
		f[key] = tab
	end
	for _, key in ipairs({ "StreamDropdown", "GuildMemberListDropdown", "CommunityMemberListDropdown", "CommunitiesListDropdown" }) do
		Dropdown(B, f, key)
	end
	local list = B.frame("Frame", f)
	f.CommunitiesList = list
	list.Bg = B.texture(list, "BACKGROUND")
	list.FilligreeOverlay = B.frame("Frame", list)
	p.filigree = B.texture(list.FilligreeOverlay)
	list.InsetFrame = B.frame("Frame", list)
	p.listInset = B.texture(list.InsetFrame)
	list.ScrollBar = B.frame("Frame", list)
	list.ScrollBox = S.ScrollBox(B, list)
	local entry = B.frame("Button", list.ScrollBox.ScrollTarget)
	entry.Background = B.texture(entry, "BACKGROUND")
	entry.Selection = B.texture(entry, "BACKGROUND")
	entry.Selection:Hide()
	entry.Icon = B.texture(entry)
	entry.IconRing = B.texture(entry, "OVERLAY")
	entry.Name = B.text(entry)
	list.ScrollBox.AddRow(entry, {})
	local members = B.frame("Frame", f)
	f.MemberList = members
	members.ScrollBar = B.frame("Frame", members)
	members.ScrollBox = S.ScrollBox(B, members)
	members.MemberCount = B.text(members)
	members.ColumnDisplay = B.frame("Frame", members)
	p.columnArt = B.texture(members.ColumnDisplay)
	local offline = B.frame("CheckButton", members)
	members.ShowOfflineButton = offline
	B.texture(offline)
	local member = B.frame("Button", members.ScrollBox.ScrollTarget)
	member.NameFrame = B.frame("Frame", member)
	member.NameFrame.Name = B.text(member.NameFrame)
	member.Level, member.Zone = B.text(member), B.text(member)
	member.Class = B.texture(member)
	member:SetHighlightTexture(B.texture(member, "HIGHLIGHT"))
	members.ScrollBox.AddRow(member, {})
	f.Chat = B.frame("Frame", f)
	f.Chat.ScrollBar = B.frame("Frame", f.Chat)
	local box = B.frame("EditBox", f)
	f.ChatEditBox = box
	box.Left, box.Right, box.Mid = B.texture(box), B.texture(box), B.texture(box)
	Button(B, f, "InviteButton")
	Button(B, f, "GuildLogButton")
	f.CommunitiesControlFrame = B.frame("Frame", f)
	Button(B, f.CommunitiesControlFrame, "GuildControlButton")
	f.GuildBenefitsFrame = B.frame("Frame", f)
	p.benefitsArt = B.texture(f.GuildBenefitsFrame)
	p.frame, p.entry, p.member = f, entry, member
	return p
end

-- The guild and communities window ---------------------------------------------------------------------

do
	local env, K, ns = S.New({ setup = S.UseScrollUtil })
	local Style, Kit = ns.Style, ns.PartC
	assert(K.Options.Row("Skins", "communities.enabled"), "the guild window has a switch")
	K.Modules.Enable("Skins")
	assert(S.Logged(env, "communities: waits for Blizzard_Communities to load"), "nothing loads the guild window for KstyleUI")
	local B = S.Blizzard(env)
	local p = Communities(env, B)
	local snap = B.snapshot()
	S.LoadAddOn(env, "Blizzard_Communities")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("communities"), "the first show skins the window")
	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(f.Bg) == 0 and Alpha(p.tabard) == 0, "a glass panel replaces the window art and the tabard")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"))
	assert(Alpha(f.MaximizeMinimizeFrame.MaximizeButton.Art) == 0, "the size buttons become chevrons")
	assert(ns.Parts.RimOf(f.RosterTab) and Alpha(f.RosterTab.Icon) == 1 and Alpha(f.RosterTab.Art) == 0, "the side tabs keep their icons on a rim")
	assert(S.Logged(env, "GuildPreferredPlaySettingsTab is missing"), "a tab this client lacks is logged")
	assert(K.Skin.IsSkinned(f.StreamDropdown, "Backdrop") and K.Skin.IsSkinned(f.CommunitiesListDropdown, "Backdrop"), "the dropdowns wear raised tiles")
	local list = f.CommunitiesList
	assert(Alpha(list.Bg) == 0 and Alpha(p.filigree) == 0 and Alpha(p.listInset) == 0, "the list's blue menu art and filigree go")
	assert(K.Skin.IsSkinned(list.ScrollBar, "ScrollBar"))
	local entry = p.entry
	assert(Alpha(entry.Background) == 0 and Alpha(entry.IconRing) == 0 and Alpha(entry.Icon) == 1, "a community keeps its icon and loses its card and ring")
	assert(FontPath(entry.Name) == Style.Font("body"))
	assert(Alpha(entry.Selection) == 0, "Blizzard's selection art goes")
	local wash = Kit.Wash(entry.Selection)
	assert(not wash:IsShown(), "the selection wash hides while nothing is selected")
	entry.Selection:Show()
	assert(wash:IsShown(), "and shows on the selected community")
	local members = f.MemberList
	assert(K.Skin.IsSkinned(members.ScrollBar, "ScrollBar") and K.Skin.IsSkinned(members.ShowOfflineButton, "CheckBox"))
	assert(Alpha(p.columnArt) == 0 and FontPath(members.MemberCount) == Style.Font("caption"))
	local member = p.member
	assert(FontPath(member.NameFrame.Name) == Style.Font("body") and FontPath(member.Zone) == Style.Font("body") and Alpha(member.Class) == 1, "member rows keep their class icons and wear the body font")
	assert(W.SameRGB(member:GetHighlightTexture(), Style.Accent()), "the member highlight is an accent wash")
	assert(K.Skin.IsSkinned(f.Chat.ScrollBar, "ScrollBar") and K.Skin.IsSkinned(f.ChatEditBox, "EditBox") and Alpha(f.ChatEditBox.Mid) == 0, "the chat and its edit box are restyled")
	assert(K.Skin.IsSkinned(f.InviteButton, "Button") and K.Skin.IsSkinned(f.CommunitiesControlFrame.GuildControlButton, "Button"))
	assert(Alpha(p.benefitsArt) == 0, "the benefits page's inset art goes")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part C social ok")
