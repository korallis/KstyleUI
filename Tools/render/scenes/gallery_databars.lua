-- gallery_databars.lua: every frame KstyleUI_DataBars draws that the HUD scene does not already show, each cropped as
-- one frame of the gallery: the experience bar with rested experience on its track, the reputation bar for a
-- watched faction with its ticks and text, the honour bar, the micro menu and the bag bar on their glass, and the
-- settings window's live preview. The data strip is the HUD scene's, so it is not listed here, though it draws
-- at its default position.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local SCREEN_H = 1080
local PREVIEW_W, PREVIEW_H = 256, 240
local BAG_ICONS = { [31] = 133634, [32] = 133635, [33] = 133636 }
local BACKPACK, KEYRING = 133633, 134237

local function at(frame, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
	if w then
		frame:SetSize(w, h)
	end
end

-- Layout-registered frames move through Layout: a BOTTOMLEFT anchor whose y is measured up from the bottom.
local function layout(K, key, x, top, width, height)
	local values = { anchor = "BOTTOMLEFT", x = x, y = SCREEN_H - top - height }
	if width then
		values.width, values.height = width, height
	end
	assert(K.Layout.Update(key, values))
end

return Common.Run(function()
	local D = dofile("Tools/regression/databars_env.lua")
	local portraitNote
	local env, K, ns = D.New({
		saved = Gallery.Saved({ "DataBars" }),
		-- Level 38 at 32% with rested experience, Stormwind watched at Friendly, and PvP rank 3.
		game = { xp = 16000, xpMax = 50000, rested = 9000, level = 38 },
		setup = function(env)
			Gallery.Setup(env)
			D.Menus(env, {
				bags = BAG_ICONS, backpack = BACKPACK, keyring = KEYRING,
				portrait = function(texture)
					local file = Common.StandIn("portrait-player.png")
					if file then
						texture:SetTexture(file)
						portraitNote = "the character button's portrait is a crop of the mockup (" .. file .. "); the game draws it itself"
					else
						texture:SetColorTexture(0.35, 0.3, 0.25, 1)
						portraitNote = "the character button's portrait is a flat stand-in; run Tools/render/standins.py for the mockup's crop"
					end
				end,
			})
		end,
	})
	K.Options.Write("DataBars", "honor.show", "always")
	K.Options.Write("DataBars", "rep.textHover", false)
	K.Options.Write("DataBars", "rep.segments", 6)
	K.Options.Write("DataBars", "honor.textHover", false)
	K.Options.Write("DataBars", "honor.segments", 4)
	env.RunTimers()

	local frames = Gallery.Frames()
	local xp, rep, honor = ns.Bars.views.xp, ns.Bars.views.rep, ns.Bars.views.honor
	assert(xp and rep and honor, "the three bars are built")
	assert(rep.content:IsShown(), "the reputation bar shows for the watched faction")
	assert(honor.content:IsShown(), "the honour bar shows when set to always")

	layout(K, "databars.xp", 60, 80, 440, 4)
	frames:Add(env, xp.holder, {
		name = "databars_xp_rested", title = "Experience bar, rested", grade = "bar", reference = "xp",
		caption = "Bars.lua's experience bar at 32% with rested experience: a Widgets.StatusBar track on the bar grade (surface fill, edgeBar line, tile chamfer, no shadow), the rested share as the track's second fill in the rare colour at half alpha, the class-colour fill over it and the percent in the number font.",
		match = "Track, faint line and chamfer as the mockup's experience bar; the mockup's state has no rested share, so its second fill is this bar's own.",
	})
	layout(K, "databars.rep", 60, 130, 440, 5)
	frames:Add(env, rep.holder, {
		name = "databars_rep", title = "Reputation bar", grade = "bar", reference = "xp",
		caption = "The reputation bar for the watched faction, Stormwind at Friendly: the same bar-grade track, the fill in the reaction colour, six segments split by one-border ticks in the edgeOuter tone, and the label and percent shown.",
		match = "Track, line and chamfer as the mockup's experience bar; the ticks are lines, not chrome, and the mockup shows no reputation bar.",
	})
	layout(K, "databars.honor", 60, 180, 440, 5)
	frames:Add(env, honor.holder, {
		name = "databars_honor", title = "Honour bar", grade = "bar", reference = "xp",
		caption = "The honour bar set to show always, at PvP rank 3: the bar-grade track, the fill in the epic colour, four segments and the rank label.",
		match = "Track, line and chamfer as the mockup's experience bar; the mockup shows no honour bar.",
	})

	-- The readout and menu card: the strip's line of values and units over the micro menu and the bag bar, docked in
	-- the same card as round crystal buttons. Both rows are hidden by default, when the card is the readout line the
	-- HUD scenes show; this frame turns them on, as a player does from the settings.
	K.Options.Write("DataBars", "micro.shown", true)
	K.Options.Write("DataBars", "bags.shown", true)
	local micro, bags = ns.Menus.Content("micro"), ns.Menus.Content("bags")
	assert(micro and bags, "the micro menu and the bag bar are built")
	layout(K, "databars.strip", 60, 240, 318, 94)
	env.RunTimers()
	frames:Add(env, ns.Strip.view.card, {
		name = "databars_micro", title = "Readout and menu card", grade = "panel", reference = "datastrip",
		caption = "The readout card (Strip.lua and Menus.lua) with Show the micro menu and Show the bag bar turned on (both are off by default, when the card is the line alone): one line of value plus muted unit (144 fps, 34 ms, 143g 82s 17c, 96% armour, 14:32) over the micro menu at the left and the bag bar at the right, docked in the same panel-grade card as round crystal discs (Widgets.CrystalDisc) with Blizzard's own glyph atlases masked round.",
		match = "The mockup's readout card: values first, units muted, a row of small round buttons under them; the card is the panel grade where the mockup's is the rounded frost card the material slice brings.",
	})
	local mh, bh = 94, 0

	-- The settings window's live preview, on a pane the width of the options window's preview holder.
	local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
	at(pane, 60, 240 + mh + 30 + bh + 40, PREVIEW_W, PREVIEW_H)
	local preview = ns.Preview(pane)
	K.Call(preview.Refresh, preview)
	frames:Add(env, pane, {
		name = "databars_preview", title = "Data bars preview", grade = "bar", reference = "xp",
		caption = "Settings.lua's ns.Preview, the options window's live preview: captioned sample experience, reputation and honour bars on the bar grade, and the data strip scaled to the pane on its panel-grade glass.",
		match = "Bars as the mockup's experience bar; the strip as the HUD's data strip. The pane itself has no chrome: in the options window it sits on the preview panel's buttonFill tile.",
	})

	D.W.Settle(env)
	env.RunTimers()
	local scene = Gallery.Build(env)
	scene.log[#scene.log + 1] = portraitNote or "the character button got no portrait"
	scene.log[#scene.log + 1] = "micro glyphs are Blizzard's atlases from the atlas cache; bag icons are bag file IDs from the icon set"
	return frames:Finish(scene, env, K, "gallery databars")
end)
