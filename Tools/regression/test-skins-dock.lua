-- test-skins-dock.lua: one docked-tab treatment for every skinned window: the window's glass grows to wrap the tabs Blizzard hangs past its edge (bottom tabs, side columns, the world map's quest log), a hairline marks the seam unless the tabs straddle the edge, the title re-centres over the glass, and a window title never wraps.
local S = dofile("Tools/regression/skins_env.lua")
local Windows = dofile("Tools/regression/skins_windows.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")
local W = S.W

local EPS = 0.01

-- Open(key) -> env, K, ns, parts: the stand-in window built as the gallery builds it, shown, its skins applied.
local function Open(key)
	local spec = Windows.Spec(key)
	local B, parts
	local env, K, ns = S.New({
		setup = function(env)
			env._textWidth = Measure.TextWidth
		end,
		before = function(env)
			B = S.Blizzard(env)
			parts = select(2, Windows.Build(key, env, B))
		end,
	})
	K.Modules.Enable("Skins")
	if spec.addon then
		S.LoadAddOn(env, spec.addon)
	end
	for _, shown in ipairs(parts.show) do
		S.Show(shown)
	end
	env.RunTimers()
	W.Settle(env)
	for _, skin in ipairs(spec.skins) do
		assert(ns.Skins.IsApplied(skin), key .. ": the " .. skin .. " skin applies")
	end
	return env, K, ns, parts
end

local function Rect(region, root)
	local rect, why = Geometry.Rect(region, root)
	assert(rect, tostring(why))
	return rect
end

local function Inside(inner, outer, what)
	assert(inner.left >= outer.left - EPS and inner.right <= outer.right + EPS, what .. ": left " .. inner.left .. " right " .. inner.right .. " in " .. outer.left .. ".." .. outer.right)
	assert(inner.bottom >= outer.bottom - EPS and inner.top <= outer.top + EPS, what .. ": bottom " .. inner.bottom .. " top " .. inner.top .. " in " .. outer.bottom .. ".." .. outer.top)
end

local function Same(a, b, what)
	assert(math.abs(a - b) <= EPS, what .. ": " .. a .. " vs " .. b)
end

-- Shifted(title, container, window, glass, root): the title's centre sits half the grown reach over from the
-- container's centre, where Blizzard put it, so it keeps its place over the glass.
local function Shifted(title, container, window, glass, root)
	if title:GetHeight() == nil then
		local _, size = title:GetFont()
		title:SetHeight(size)
	end
	if title:GetWidth() == nil then
		title:SetWidth(title:GetUnboundedStringWidth() or 100)
	end
	local t, c = Rect(title, root), Rect(container, root)
	local shift = ((glass.right - window.right) - (window.left - glass.left)) / 2
	Same((t.left + t.right) / 2 - (c.left + c.right) / 2, shift, "the title moves over by half the gutter")
end

local function Glass(K, window)
	local parts = K.Skin.Parts(window)
	assert(parts and parts.backdrop, "the window has a glass backdrop")
	return parts.backdrop
end

local function Run(frame, script)
	local fn = frame:GetScript(script)
	assert(fn, script .. " is hooked")
	fn(frame)
end

-- Mail: the bottom tabs stand inside the window's glass, on a seam hairline --------------------------------

do
	local env, K, ns = Open("mail")
	local root = env.UIParent
	local mail = env.MailFrame
	local dock = ns.Parts.DockOf(mail)
	assert(dock, "the mail window docks its bottom tabs")
	local window, glass = Rect(mail, root), Rect(Glass(K, mail), root)
	assert(glass.bottom < window.bottom - 1, "the glass grows below the window to wrap the tabs: " .. glass.bottom .. " vs " .. window.bottom)
	Same(glass.left, window.left, "the glass keeps the window's left edge")
	Same(glass.right, window.right, "and its right edge")
	Same(glass.top, window.top, "and its top edge")
	for i = 1, 2 do
		local tab = env["MailFrameTab" .. i]
		Inside(Rect(tab, root), glass, "mail tab " .. i .. " stands inside the glass")
	end
	local strip = K.Skin.Parts(mail).strip
	Inside(Rect(strip, root), glass, "the tabs' pill strip stands inside the glass")
	-- The selected tab (Inbox, disabled by PanelTemplates) reads at a glance: an accent wash fills its segment
	-- of the pill and the underline shows; the other tab shows neither.
	local inbox, send = K.Skin.Parts(env.MailFrameTab1), K.Skin.Parts(env.MailFrameTab2)
	assert(inbox.selected == true and send.selected == false, "Inbox is the selected tab")
	assert(inbox.wash and inbox.wash:IsShown(), "the selected tab wears an accent wash")
	assert(inbox.underline:IsShown(), "and its underline")
	assert(not send.wash:IsShown() and not send.underline:IsShown(), "the other tab wears neither")
	local wr, wg, wb, wa = inbox.wash:GetVertexColor()
	local ar, ag, ab = ns.Style.Accent()
	assert(W.Near(wr, ar) and W.Near(wg, ag) and W.Near(wb, ab), "the wash is the accent")
	assert(wa > 0.08 and wa < 0.4, "at a wash alpha: " .. tostring(wa))
	Same(Rect(inbox.wash, root).left, Rect(env.MailFrameTab1, root).left, "the wash fills the tab's segment")
	Same(Rect(inbox.wash, root).right, Rect(env.MailFrameTab1, root).right, "to its right edge")
	local seam = dock.seams.BOTTOM
	assert(seam and seam:IsShown(), "a hairline marks the seam between the window and its tab band")
	local seamRect = Rect(seam, root)
	Same(seamRect.top, window.bottom, "the seam runs along the window's bottom edge")
	assert(seamRect.left > glass.left and seamRect.right < glass.right, "inset from the glass corners")
	local er, eg, eb = K.Widgets.Rgba("edgeInner")
	local r, g, b = seam:GetVertexColor()
	assert(W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb), "in the inner edge tone")
	-- The open letter beside the inbox has no tabs; its glass is its frame.
	local letter = env.OpenMailFrame
	assert(ns.Parts.DockOf(letter) == nil, "a window without tabs has no dock")
	local letterRect, letterGlass = Rect(letter, root), Rect(Glass(K, letter), root)
	Same(letterGlass.bottom, letterRect.bottom, "and keeps its glass on its frame")
	-- A window title is one line, never wrapped onto a second.
	local title = mail.TitleContainer.TitleText
	assert(W.LastCall(title, "SetWordWrap") and W.LastCall(title, "SetWordWrap")[1] == false, "the window title never wraps")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Character: the mode tabs stand in a gutter inside the window's glass ----------------------------------

do
	local env, K, ns = Open("character")
	local root = env.UIParent
	local f = env.CharacterFrame
	local dock = ns.Parts.DockOf(f)
	assert(dock, "the character window docks its mode tabs")
	assert(ns.CharacterRail == nil, "the separate tab rail of #177 is gone; the window's own glass holds the tabs")
	local window, glass = Rect(f, root), Rect(Glass(K, f), root)
	assert(glass.right > window.right + 1, "the glass grows past the window's right edge: " .. glass.right .. " vs " .. window.right)
	Same(glass.left, window.left, "the glass keeps the window's left edge")
	Same(glass.top, window.top, "its top")
	Same(glass.bottom, window.bottom, "and its bottom")
	for i, tab in ipairs(f.ModeTabs.Tabs) do
		Inside(Rect(tab, root), glass, "mode tab " .. i .. " stands inside the glass")
		local rim = ns.Parts.RimOf(tab)
		Inside(Rect(rim, root), glass, "and so does its rim")
	end
	local seam = Rect(dock.seams.RIGHT, root)
	Same(seam.left, window.right, "the seam runs along the window's right edge")
	assert(seam.top < glass.top and seam.bottom > glass.bottom, "inset from the glass corners")
	assert(dock.seams.BOTTOM == nil or not dock.seams.BOTTOM:IsShown(), "no seam on an edge without tabs")
	-- The paper doll's sidebar tabs (stats, titles, equipment sets) wear one rim size whatever Blizzard sizes
	-- their icons, stand inside the right pane with a gap from the mode column, and the column's seam starts
	-- at the first mode tab, below the header band, instead of running up between the title and the close glyph.
	local gap = K.Widgets.Snap(f, K.Tokens.Size("gapMedium"))
	local pane = Rect(f.RightPaneHost, root)
	local first
	for i = 1, 3 do
		local tab = env["PaperDollSidebarTab" .. i]
		local rim = ns.Parts.RimOf(tab)
		assert(rim, "sidebar tab " .. i .. " wears a rim")
		local r = Rect(rim, root)
		first = first or r
		Same(r.right - r.left, first.right - first.left, "sidebar tab " .. i .. " rim width")
		Same(r.top - r.bottom, first.top - first.bottom, "sidebar tab " .. i .. " rim height")
		Inside(r, pane, "sidebar tab " .. i .. " stands inside the right pane")
		assert(r.right <= window.right - gap + EPS, "sidebar tab " .. i .. " keeps a gap from the mode column: " .. r.right .. " vs " .. window.right)
	end
	local modeTop = Rect(f.ModeTabs.Tabs[1], root).top
	assert(seam.top <= modeTop + gap + EPS, "the seam starts at the tab column, below the header band: " .. seam.top .. " vs " .. modeTop)
	assert(seam.top < Rect(f.TitleContainer, root).bottom, "and under the title band: " .. seam.top)
	-- The title moves over by half the gutter, so it keeps its place over the grown glass.
	Shifted(f.TitleContainer.TitleText, f.TitleContainer, window, glass, root)
	-- With every tab hidden the glass returns to the window.
	for _, tab in ipairs(f.ModeTabs.Tabs) do
		tab:Hide()
	end
	f.UpdateTabLayout()
	Same(Rect(Glass(K, f), root).right, window.right, "no shown tab, no gutter")
	assert(not dock.seams.RIGHT:IsShown(), "and no seam")
	Shifted(f.TitleContainer.TitleText, f.TitleContainer, window, Rect(Glass(K, f), root), root)
	for _, tab in ipairs(f.ModeTabs.Tabs) do
		tab:Show()
	end
	f.UpdateTabLayout()
	Same(Rect(Glass(K, f), root).right, glass.right, "the gutter comes back with the tabs")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Group finder: bottom tabs below and page tabs at the left, both inside the shown page's glass ------------

do
	local env, K, ns, parts = Open("groupfinder")
	local root = env.UIParent
	local parent = env.LFGParentFrame
	local browse = parts.show[2]
	assert(browse == env.LFGBrowseFrame, "the browse page is the shown page")
	local glass = Rect(Glass(K, browse), root)
	local page = Rect(browse, root)
	assert(glass.bottom < page.bottom - 1 and glass.left < page.left - 1, "the page's glass grows below and to the left")
	for i = 1, 3 do
		Inside(Rect(parent["Tab" .. i], root), glass, "bottom tab " .. i .. " stands inside the glass")
	end
	for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
		Inside(Rect(parent[key], root), glass, key .. " stands inside the glass")
	end
	Shifted(browse.TitleContainer.TitleText, browse.TitleContainer, page, glass, root)
	assert(ns.Parts.DockOf(browse) and ns.Parts.DockOf(env.LFGListingFrame), "every page docks the parent's tabs")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- World map: the quest log docks inside the map's glass while it is shown --------------------------------

do
	local env, K, ns = Open("worldmap")
	local root = env.UIParent
	local map, log = env.WorldMapFrame, env.QuestMapFrame
	assert(ns.Parts.DockOf(map), "the map docks its quest log")
	local mapRect, glass = Rect(map, root), Rect(Glass(K, map), root)
	Inside(Rect(log, root), glass, "the quest log stands inside the map's glass")
	Same(glass.left, mapRect.left, "the glass keeps the map's left edge")
	assert(K.Skin.Parts(log) == nil or K.Skin.Parts(log).backdrop == nil, "the quest log has no glass of its own")
	assert(K.Skin.Parts(env.QuestScrollFrame) and K.Skin.Parts(env.QuestScrollFrame).backdrop, "the quest list body sits on a tile, as every list body does")
	log:Hide()
	Run(log, "OnHide")
	Same(Rect(Glass(K, map), root).right, mapRect.right, "with the log hidden the glass is the map's")
	log:Show()
	Run(log, "OnShow")
	Same(Rect(Glass(K, map), root).right, glass.right, "and wraps the log again when it shows")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Game menu: the title sits inside the header band and never wraps -----------------------------------------

do
	local env, K = Open("gamemenu")
	local root = env.UIParent
	local menu = env.GameMenuFrame
	local text = menu.Header.Text
	assert(W.LastCall(text, "SetWordWrap") and W.LastCall(text, "SetWordWrap")[1] == false, "the game menu title never wraps")
	local _, size = text:GetFont()
	text:SetSize(text:GetUnboundedStringWidth() or 100, size)
	local glass, title = Rect(Glass(K, menu), root), Rect(text, root)
	assert(title.top <= glass.top - K.Widgets.Snap(menu, K.Tokens.Size("gapSmall")) + EPS, "the title sits inside the glass's header band: " .. title.top .. " vs " .. glass.top)
	Same((title.left + title.right) / 2, (glass.left + glass.right) / 2, "centred over the glass")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Side columns on communities, spellbook, professions and legacy stand inside their window's glass ----------

local SIDE = {
	communities = function(env)
		local f = env.CommunitiesFrame
		return f, { f.ChatTab, f.RosterTab, f.GuildBenefitsTab, f.GuildInfoTab }, "RIGHT"
	end,
	spellbook = function(env)
		local f = env.PlayerSpellsFrame
		return f, f.SpellBookFrame.CategoryTabSystem.tabs, "RIGHT", true
	end,
	professions = function(env)
		local f = env.ProfessionsFrame
		local tabs = { f.ProfessionsOverviewTab }
		for _, tab in ipairs(f.rightProfessionTabs or {}) do
			tabs[#tabs + 1] = tab
		end
		return f, tabs, "LEFT"
	end,
	legacy = function(env)
		local f = env.LegacySystemFrame
		return f, f.Tabs, "LEFT"
	end,
}

for _, key in ipairs({ "communities", "spellbook", "professions", "legacy" }) do
	local env, K, ns = Open(key)
	local root = env.UIParent
	local f, tabs, edge, straddles = SIDE[key](env)
	local dock = ns.Parts.DockOf(f)
	assert(dock, key .. " docks its side tabs")
	local glass = Rect(Glass(K, f), root)
	local seam = dock.seams[edge]
	if straddles then
		assert(seam == nil or not seam:IsShown(), key .. ": tabs that straddle the window's edge get no seam through them")
	else
		assert(seam and seam:IsShown(), key .. ": a seam marks the gutter on the " .. edge)
	end
	assert(#tabs > 0, key .. " has side tabs")
	for i, tab in ipairs(tabs) do
		if tab:IsShown() then
			Inside(Rect(tab, root), glass, key .. " side tab " .. i .. " stands inside the glass")
		end
	end
	assert(#env._errors == 0, key .. ": " .. tostring(env._errors[1]))
end

print("skins dock ok")
