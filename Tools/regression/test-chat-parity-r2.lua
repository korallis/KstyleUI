-- test-chat-parity-r2.lua: the chat button column's round-two options (backing, gap, order, size, spacing, free move, scroll button, column width) and tabs above the card keep today's defaults, apply switched on at every screen size, restore switched off and refresh on the events that change them.
local C = dofile("Tools/regression/chat_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local W = C.W

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }

local function saved(settings)
	return { version = 42, profiles = { Default = { Chat = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function boot(settings, setup)
	local env, K, ns = C.New({ saved = saved(settings or { enabled = true, buttons = true }), setup = setup })
	env.RunTimers()
	assert(K.Modules.IsRunning("Chat"), tostring(env._errors[1]))
	return env, K, ns
end

local function write(env, K, key, value)
	assert(K.Options.Write("Chat", key, value) ~= false, key .. " must write")
	env.RunTimers()
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function point(frame, i)
	return frame:GetPoint(i or 1)
end

local function overlap(a, b)
	return math.min(a.right, b.right) - math.max(a.left, b.left) > 0.01 and math.min(a.top, b.top) - math.max(a.bottom, b.bottom) > 0.01
end

-- The game's own column: channels at the top with the voice toggles two units under it, the menu at the foot
-- (FloatingChatFrameVoiceChat.xml, FloatingChatFrame.xml:723).
local function blizzardStack(env, gap, scale)
	local column = env.ChatFrame1.buttonFrame
	local p, rel, relp, x, y = point(env.ChatFrameChannelButton)
	assert(p == "TOP" and rel == column and relp == "TOP" and x == 0 and y == 0, "channels at the column's top")
	p, rel, relp, x, y = point(env.ChatFrameToggleVoiceDeafenButton)
	assert(p == "TOP" and rel == env.ChatFrameChannelButton and relp == "BOTTOM" and x == 0 and near(y, -gap / scale), "deafen under channels, got " .. tostring(y))
	p, rel, relp, x, y = point(env.ChatFrameToggleVoiceMuteButton)
	assert(p == "TOP" and rel == env.ChatFrameToggleVoiceDeafenButton and relp == "BOTTOM" and x == 0 and near(y, -gap / scale), "mute under deafen")
	p, rel, relp, x, y = point(env.ChatFrameMenuButton)
	assert(p == "BOTTOM" and rel == column and relp == "BOTTOM" and x == 0 and y == 0, "the menu at the column's foot")
end

-- A v0.2.8-shaped profile loads with every new option at today's value, and the buttons keep the game's stack.
do
	local env, K, ns = boot({ enabled = true, buttons = true, fontSize = 14 })
	local s = K.Store.Module("Chat")
	for key, value in pairs({ sideStyle = "card", sideGap = 8, sideOrder = "channels,voice,menu", sideScale = 1, sideSpacing = 2, sideFree = false,
		sideScroll = false, tabsAbove = false, sideWidth = 35 }) do
		assert(s[key] == value, key .. " defaults to " .. tostring(value) .. ", got " .. tostring(s[key]))
	end
	assert(next(s.sidePositions) == nil, "no saved spots")
	blizzardStack(env, 2, 1)
	assert(env.ChatFrame1.buttonFrame:GetWidth() == 29, "the column keeps the game's 29 units at the default room")
	local holder, glass = ns.Panel.Holder(), ns.Panel.Glass()
	assert(near(glass:GetLeft(), holder:GetLeft()) and near(glass:GetTop(), holder:GetTop()) and near(glass:GetRight(), holder:GetRight()), "the card fills its element")
	assert(env.ChatFrameMenuButton:GetScale() == 1, "the buttons keep their scale")
	clean(env, K)
end

-- Backing: own glass beside the card and no glass beside it, on both sides and at every screen size; the buttons sit
-- on the strip, clear of the messages and of the card; Card restores the room inside the card.
for _, size in ipairs(SIZES) do
	local env, K, ns = C.New({ width = size[1], height = size[2], saved = saved({ enabled = true, buttons = true }), setup = function(e) e._size, e._fitScale = "auto", true end })
	env.RunTimers()
	local function rect(f) return assert(G.ScaledRect(f, env.UIParent, K.Scale.Root())) end
	local holder, glass, chat = ns.Panel.Holder(), ns.Panel.Glass(), env.ChatFrame1
	local before = rect(chat)
	local buttons = { env.QuickJoinToastButton, env.ChatFrameChannelButton, env.ChatFrameMenuButton }
	for _, right in ipairs({ false, true }) do
		write(env, K, "sideRight", right)
		for _, style in ipairs({ "glass", "bare" }) do
			write(env, K, "sideStyle", style)
			local where = size[1] .. "x" .. size[2] .. " " .. style .. (right and " right" or " left")
			local strip = assert(ns.Panel.strip, "the strip glass is made on first use")
			assert(strip:IsShown() == (style == "glass"), where .. ": the strip shows only for its own glass")
			local card, h, msgs, column = rect(glass), rect(holder), rect(chat), rect(chat.buttonFrame)
			assert(right and card.right < h.right - 8 or not right and card.left > h.left + 8, where .. ": the card leaves room beside it")
			assert(card.top >= h.top - 0.01 and card.bottom <= h.bottom + 0.01, where .. ": the card keeps its height")
			assert(msgs.left >= card.left - 0.01 and msgs.right <= card.right + 0.01, where .. ": the messages stay on the card")
			if style == "glass" then
				local s = rect(strip)
				assert(not overlap(s, card), where .. ": the strip and the card do not touch")
				assert(column.left >= s.left - 0.01 and column.right <= s.right + 0.01, where .. ": the column sits on the strip")
				local gapUnits = right and (s.left - card.right) or (card.left - s.right)
				assert(gapUnits > 0, where .. ": a gap between strip and card")
			end
			for _, b in ipairs(buttons) do
				local r = rect(b)
				assert(not overlap(r, msgs), where .. ": " .. b:GetName() .. " reaches into the messages")
				assert(not overlap(r, card), where .. ": " .. b:GetName() .. " sits on the card")
			end
		end
	end
	write(env, K, "sideGap", 20)
	write(env, K, "sideStyle", "glass")
	write(env, K, "sideRight", false)
	local wide = rect(glass).left - rect(ns.Panel.strip).right
	write(env, K, "sideGap", 0)
	assert(near(rect(glass).left, rect(ns.Panel.strip).right) and wide > 19, "the gap slider moves the card away from the strip")
	write(env, K, "sideStyle", "card")
	assert(not ns.Panel.strip:IsShown(), "Card hides the strip")
	assert(near(rect(glass).left, rect(holder).left) and near(rect(chat).left, before.left), "the card and the messages come back")
	write(env, K, "tabsAbove", true)
	for _, style in ipairs({ "card", "glass" }) do
		write(env, K, "sideStyle", style)
		local edge = rect(style == "glass" and ns.Panel.strip or glass).top
		assert(rect(env.QuickJoinToastButton).top <= edge + 0.01, size[1] .. "x" .. size[2] .. " " .. style .. ": the friends button stays on the glass under the tabs")
	end
	write(env, K, "sideStyle", "card")
	write(env, K, "tabsAbove", false)
	clean(env, K)
end

-- The strip follows the card's look: bare in the Orbs framing, hidden at rest with buttons on hover, faded when idle.
do
	local env, K, ns = boot()
	write(env, K, "sideStyle", "glass")
	local strip = ns.Panel.strip
	write(env, K, "framing", "bare")
	assert(not strip:IsShown(), "bare text keeps no strip glass")
	write(env, K, "framing", "card")
	assert(strip:IsShown(), "the card framing shows it again")
	write(env, K, "sideHover", true)
	assert(strip:GetAlpha() == 0, "the strip waits with the buttons")
	strip:GetScript("OnEnter")(strip)
	assert(strip:GetAlpha() == 1 and env.ChatFrame1.buttonFrame:GetAlpha() == 1, "the pointer on the strip brings the buttons")
	write(env, K, "sideHover", false)
	assert(strip:GetAlpha() == 1, "and the strip stays with them")
	clean(env, K)
end

-- Order, size, spacing and the column width: on stacks the buttons in the chosen order with the last at the foot,
-- off gives back the game's stack exactly. The card is made tall enough for all five buttons at 1.5, as Layout Mode can.
do
	local env, K, ns = boot()
	ns.Panel.Holder():SetHeight(500)
	local column = env.ChatFrame1.buttonFrame
	write(env, K, "sideOrder", "menu,channels,voice")
	local p, rel, relp = point(env.ChatFrameMenuButton)
	assert(p == "TOP" and rel == column and relp == "TOP", "the menu leads")
	p, rel = point(env.ChatFrameChannelButton)
	assert(p == "TOP" and rel == env.ChatFrameMenuButton, "channels under it")
	p, rel, relp = point(env.ChatFrameToggleVoiceMuteButton)
	assert(p == "BOTTOM" and rel == column and relp == "BOTTOM", "the last choice, voice, sits at the foot")
	p, rel, relp = point(env.ChatFrameToggleVoiceDeafenButton)
	assert(p == "BOTTOM" and rel == env.ChatFrameToggleVoiceMuteButton and relp == "TOP", "deafen above mute")
	write(env, K, "sideIcons.menu", false)
	p, rel = point(env.ChatFrameChannelButton)
	assert(p == "TOP" and rel == column, "a hidden button gives up its slot")
	write(env, K, "sideIcons.menu", true)
	write(env, K, "sideScale", 1.5)
	write(env, K, "sideSpacing", 6)
	write(env, K, "sideOrder", "channels,voice,menu")
	for _, b in ipairs({ env.ChatFrameMenuButton, env.ChatFrameChannelButton, env.ChatFrameToggleVoiceDeafenButton, env.QuickJoinToastButton }) do
		assert(near(b:GetScale(), 1.5), b:GetName() .. " scales")
	end
	blizzardStack(env, 6, 1.5)
	write(env, K, "sideWidth", 60)
	assert(column:GetWidth() == 54, "the column widens with the room")
	write(env, K, "sideScale", 1)
	write(env, K, "sideSpacing", 2)
	write(env, K, "sideWidth", 35)
	blizzardStack(env, 2, 1)
	assert(env.ChatFrameMenuButton:GetScale() == 1 and column:GetWidth() == 29, "today's size and column come back")
	clean(env, K)
end

-- Scroll button with the chat buttons: every docked window's button moves to the column's foot under the last
-- button and the scroll bar no longer follows it, even when the game re-anchors it; undocking, off and buttons off
-- each give it back.
do
	local reanchors = 0
	local env, K = boot(nil, function(e)
		function e.FCF_UpdateScrollbarAnchors(frame)
			reanchors = reanchors + 1
			frame.ScrollBar:ClearAllPoints()
			frame.ScrollBar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
			frame.ScrollBar:SetPoint("BOTTOMLEFT", frame.ScrollToBottomButton, "TOPLEFT", 0, 2)
		end
	end)
	local column, one, two = env.ChatFrame1.buttonFrame, env.ChatFrame1, env.ChatFrame2
	local original = { point(one.ScrollToBottomButton) }
	write(env, K, "sideScroll", true)
	for _, frame in ipairs({ one, two }) do
		local p, rel, relp = point(frame.ScrollToBottomButton)
		assert(p == "BOTTOM" and rel == column and relp == "BOTTOM", frame:GetName() .. "'s scroll button sits at the column's foot")
	end
	local p, rel, relp, _, y = point(env.ChatFrameMenuButton)
	assert(p == "BOTTOM" and rel == one.ScrollToBottomButton and relp == "TOP" and near(y, 2), "the menu sits on it")
	local bp, brel, brelp = one.ScrollBar:GetPoint(2)
	assert(bp == "BOTTOMLEFT" and brel == one and brelp == "BOTTOMRIGHT", "the scroll bar keeps to the window")
	env.FCF_UpdateScrollbarAnchors(one)
	brel = select(2, one.ScrollBar:GetPoint(2))
	assert(brel == one, "the game's re-anchor does not stretch the bar to the column")
	env.FCF_UnDockFrame(two)
	env.RunTimers()
	assert(select(2, point(two.ScrollToBottomButton)) == two, "an undocked window keeps its own button")
	env.FCF_DockFrame(two)
	env.RunTimers()
	assert(select(2, point(two.ScrollToBottomButton)) == column, "docking it again moves it to the column")
	write(env, K, "sideScroll", false)
	local back = { point(one.ScrollToBottomButton) }
	for i = 1, 5 do assert(back[i] == original[i], "off gives back the game's corner, field " .. i) end
	assert(select(2, one.ScrollBar:GetPoint(2)) == one.ScrollToBottomButton and reanchors > 0, "and the game anchors its bar again")
	blizzardStack(env, 2, 1)
	write(env, K, "sideScroll", true)
	write(env, K, "buttons", false)
	assert(select(2, point(one.ScrollToBottomButton)) == one, "buttons off gives it back too")
	clean(env, K)
end

-- Free move: shift-drag out of combat saves a spot that follows the column; combat, a missing shift or the switch off
-- refuse; off returns every button to the column and stops taking drags.
do
	local env, K, ns = boot()
	ns.Panel.Holder():SetHeight(500)
	local column, menu = env.ChatFrame1.buttonFrame, env.ChatFrameMenuButton
	assert(W.LastCall(menu, "RegisterForDrag") == nil, "no drag until free move is on")
	write(env, K, "sideFree", true)
	local calls = W.LastCall(menu, "RegisterForDrag")
	assert(calls and calls[1] == "LeftButton", "free move takes drags")
	menu:GetScript("OnDragStart")(menu)
	assert(W.LastCall(menu, "StartMoving") == nil, "no shift, no drag")
	env._modifiers.shift = true
	env._combat = true
	menu:GetScript("OnDragStart")(menu)
	assert(W.LastCall(menu, "StartMoving") == nil, "combat refuses a drag")
	env._combat = false
	menu:GetScript("OnDragStart")(menu)
	assert(W.LastCall(menu, "StartMoving"), "shift-drag moves the button")
	menu:ClearAllPoints()
	menu:SetPoint("CENTER", column, "TOPLEFT", 40, -25)
	menu:GetScript("OnDragStop")(menu)
	env.RunTimers()
	assert(W.LastCall(menu, "SetUserPlaced")[1] == false, "the game does not save the spot in its own layout cache")
	local spot = K.Store.Module("Chat").sidePositions.ChatFrameMenuButton
	assert(spot and spot.x == 40 and spot.y == -25, "the drop saves the spot against the column")
	local p, rel, relp, x, y = point(menu)
	assert(p == "CENTER" and rel == column and relp == "TOPLEFT" and near(x, 40) and near(y, -25), "and the button stays there")
	write(env, K, "sideScale", 2)
	x, y = select(4, point(menu))
	local grown = menu:GetScale()
	assert(grown > 1 and near(x * grown, 40) and near(y * grown, -25), "a bigger button keeps the same spot on screen")
	write(env, K, "sideScale", 1)
	write(env, K, "sideFree", false)
	blizzardStack(env, 2, 1)
	calls = W.LastCall(menu, "RegisterForDrag")
	assert(calls and calls[1] == nil, "off stops taking drags, so a click still clicks")
	write(env, K, "sideFree", true)
	assert(select(2, point(menu)) == column and select(1, point(menu)) == "CENTER", "the saved spot comes back with the switch")
	clean(env, K)
end

-- Tabs above the card: the card starts at the tab row's foot, the rule goes and the glyphs leave the glass; off
-- restores the card, the rule and the glyphs' parent.
do
	local env, K, ns = boot({ enabled = true })
	local holder, glass, plus = ns.Panel.Holder(), ns.Panel.Glass(), ns.Panel.MenuButton()
	local g = ns.Panel.Geometry(env.ChatFrame1)
	local frame3 = env.ChatFrame3
	env.FCF_UnDockFrame(frame3)
	env.RunTimers()
	local undocked = ns.Panel.UndockedInsets(frame3).top
	write(env, K, "tabsAbove", true)
	assert(near(glass:GetTop(), holder:GetTop() - g.divider), "the card starts under the tabs")
	assert(not glass.divider:IsShown(), "the card's edge replaces the rule")
	assert(select(2, plus:GetPoint(1)) == holder and plus:GetBottom() >= glass:GetTop() - 0.01, "the glyphs sit in the tab row, off the card")
	assert(ns.Panel.UndockedInsets(frame3).top > undocked, "an undocked window's glass starts under its tab too")
	write(env, K, "tabsAbove", false)
	assert(near(glass:GetTop(), holder:GetTop()) and glass.divider:IsShown() and select(2, plus:GetPoint(1)) == glass, "off restores the card, the rule and the glyphs")
	clean(env, K)
end

-- Turning the chat off gives every button, the column and the scroll buttons back to the game.
do
	local env, K = boot()
	write(env, K, "sideScale", 1.5)
	write(env, K, "sideWidth", 60)
	write(env, K, "sideScroll", true)
	write(env, K, "sideFree", true)
	K.Modules.Disable("Chat")
	env.RunTimers()
	assert(env.ChatFrameMenuButton:GetScale() == 1 and env.QuickJoinToastButton:GetScale() == 1, "scales come back")
	assert(env.ChatFrame1.buttonFrame:GetWidth() == 29, "the column's width comes back")
	assert(select(2, point(env.ChatFrame1.ScrollToBottomButton)) == env.ChatFrame1, "the scroll button goes home")
	assert(W.LastCall(env.ChatFrameMenuButton, "RegisterForDrag")[1] == nil, "no drag stays registered")
	blizzardStack(env, 2, 1)
	clean(env, K)
end

-- The settings window's preview shows each option: the strip, the gap, the tiles' order, size and spacing, the scroll
-- tile and tabs above the card.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetPoint("CENTER")
	parent:SetSize(320, 480)
	local preview = K.Options.Preview("Chat")(parent)
	local function shown()
		local n = 0
		for _, tile in ipairs(preview.icons) do if tile:IsShown() then n = n + 1 end end
		return n
	end
	assert(shown() == 5, "friends, channels, two voice toggles and the menu, got " .. shown())
	local menuTile
	for _, tile in ipairs(preview.icons) do if tile:IsShown() and tile.glyph:IsShown() then menuTile = tile end end
	local y = select(5, menuTile:GetPoint(1))
	write(env, K, "sideOrder", "menu,channels,voice")
	preview:Refresh()
	assert(preview.icons[2].glyph:IsShown() and select(3, preview.icons[2]:GetPoint(1)):find("^TOP"), "the menu tile leads")
	assert(select(5, preview.icons[2]:GetPoint(1)) < 0 and y > 0, "it moved from the foot to the top")
	write(env, K, "sideScale", 2)
	write(env, K, "sideSpacing", 10)
	write(env, K, "sideScroll", true)
	preview:Refresh()
	assert(shown() == 6 and near(preview.icons[1]:GetWidth(), 40), "a scroll tile joins and the tiles grow")
	local cardLeft = select(4, preview.card:GetPoint(1))
	write(env, K, "sideStyle", "glass")
	preview:Refresh()
	assert(preview.strip:IsShown() and select(4, preview.card:GetPoint(1)) > cardLeft + 30, "the strip takes the side and the card moves over")
	write(env, K, "sideStyle", "bare")
	preview:Refresh()
	assert(not preview.strip:IsShown(), "no glass behind bare buttons")
	write(env, K, "tabsAbove", true)
	preview:Refresh()
	assert(select(5, preview.card:GetPoint(1)) < -20 and not preview.divider:IsShown(), "the card starts under the tabs")
	local tab = preview.tabs[1]
	assert(tab:GetTop() and tab:GetBottom() >= preview.card:GetTop() - 0.01, "the tab names sit above the card and resolve, so the settings pane keeps them in view")
	write(env, K, "buttons", false)
	preview:Refresh()
	assert(shown() == 0, "no buttons, no tiles")
	clean(env, K)
end

-- Review of cdb0019a, finding 1: a bigger size never pushes a button into the messages, the card or another button
-- at either end of the slider, at every screen size and backing: the room beside the messages widens with the
-- buttons, and above 1 they grow only while the stack still fits the column, so they never overlap more than at 1.
local function area(a, b)
	return math.max(0, math.min(a.right, b.right) - math.max(a.left, b.left)) * math.max(0, math.min(a.top, b.top) - math.max(a.bottom, b.bottom))
end
for _, size in ipairs(SIZES) do
	for _, voice in ipairs({ false, true }) do
		local env, K, ns = C.New({ width = size[1], height = size[2], saved = saved({ enabled = true, buttons = true }), setup = function(e) e._size, e._fitScale = "auto", true end })
		env.RunTimers()
		local names = { "QuickJoinToastButton", "ChatFrameChannelButton", "ChatFrameMenuButton" }
		if voice then
			names[#names + 1], names[#names + 2] = "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton"
		else
			for _, name in ipairs({ "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do env[name]:Hide() end
		end
		local function rect(f) return assert(G.ScaledRect(f, env.UIParent, K.Scale.Root())) end
		for _, style in ipairs({ "card", "glass", "bare" }) do
			write(env, K, "sideStyle", style)
			write(env, K, "sideGap", 0)
			local at = {}
			for _, scale in ipairs({ 1, 0.5, 2 }) do
				write(env, K, "sideScale", scale)
				local where = size[1] .. "x" .. size[2] .. " " .. style .. " scale " .. scale .. (voice and " with voice" or "")
				local msgs, card = rect(env.ChatFrame1), rect(ns.Panel.Glass())
				for i, name in ipairs(names) do
					local r = rect(env[name])
					assert(area(r, msgs) == 0, where .. ": " .. name .. " reaches into the messages")
					assert(style == "card" or area(r, card) == 0, where .. ": " .. name .. " reaches onto the card")
					for j = i + 1, #names do
						local both = area(r, rect(env[names[j]]))
						at[i .. "," .. j] = at[i .. "," .. j] or both
						assert(voice and both <= at[i .. "," .. j] + 0.01 or both == 0, where .. ": " .. name .. " overlaps " .. names[j] .. " by " .. both)
					end
				end
			end
			write(env, K, "sideScale", 1)
		end
		clean(env, K)
	end
end

-- Finding 2: a free spot for the friends button survives the alert container putting it back on its corner.
do
	local env, K = boot()
	write(env, K, "sideFree", true)
	write(env, K, "sidePositions", { QuickJoinToastButton = { x = 111, y = -50 } })
	env.ChatAlertFrame:UpdateAnchors()
	env.RunTimers()
	local p, rel, relp, x, y = point(env.QuickJoinToastButton)
	assert(p == "CENTER" and rel == env.ChatFrame1.buttonFrame and relp == "TOPLEFT" and near(x, 111) and near(y, -50), "the friends button keeps its spot, got " .. tostring(relp) .. " " .. tostring(x) .. " " .. tostring(y))
	clean(env, K)
end

-- Finding 3: a restricted scale is left to the game instead of breaking the layout, and a drag without the combat
-- check is refused.
do
	local env, K, ns = boot({ enabled = true })
	ns.Panel.Holder():SetHeight(500)
	local menu = env.ChatFrameMenuButton
	menu.GetScale = function() return env.Secret(1) end
	write(env, K, "buttons", true)
	write(env, K, "sideScale", 1.5)
	assert(W.LastCall(menu, "SetScale") == nil and env.ChatFrameChannelButton:GetScale() > 1, "only the readable scales change")
	clean(env, K)
	write(env, K, "sideFree", true)
	env._modifiers.shift = true
	local lockdown = env.InCombatLockdown
	env.InCombatLockdown = nil
	local channels = env.ChatFrameChannelButton
	local ok, err = pcall(channels:GetScript("OnDragStart"), channels)
	env.InCombatLockdown = lockdown
	assert(ok, tostring(err))
	assert(W.LastCall(channels, "StartMoving") == nil, "no combat check, no drag")
	clean(env, K)
end

-- Finding 4: only the scroll bar's anchor that followed the jump-to-bottom button moves, so the resize grip keeps a
-- secondary window's bar, and off gives back the game's anchors exactly without FCF_UpdateScrollbarAnchors.
do
	local env, K = boot()
	local function anchors(bar)
		local list = {}
		for i = 1, bar:GetNumPoints() do list[i] = { bar:GetPoint(i) } end
		return list
	end
	local function same(a, b, what)
		assert(#a == #b, what .. ": " .. #b .. " anchors, wanted " .. #a)
		for i = 1, #a do for j = 1, 5 do assert(a[i][j] == b[i][j], what .. ", anchor " .. i .. " field " .. j) end end
	end
	local two = env.ChatFrame2
	two.ScrollBar:ClearAllPoints()
	two.ScrollBar:SetPoint("TOPLEFT", two, "TOPRIGHT", 0, 0)
	two.ScrollBar:SetPoint("BOTTOM", two.ResizeButton, "TOP", 0, 0)
	local grip, game = anchors(two.ScrollBar), anchors(env.ChatFrame1.ScrollBar)
	write(env, K, "sideScroll", true)
	same(grip, anchors(two.ScrollBar), "the resize grip keeps the bar")
	for _, a in ipairs(anchors(env.ChatFrame1.ScrollBar)) do assert(a[2] ~= env.ChatFrame1.ScrollToBottomButton, "the bar leaves the moved button") end
	write(env, K, "sideScroll", false)
	same(grip, anchors(two.ScrollBar), "off keeps the grip's anchors")
	same(game, anchors(env.ChatFrame1.ScrollBar), "off gives back the game's anchors")
	clean(env, K)
end

-- Finding 5: the moved jump-to-bottom button follows the hover rule, even when the game fades it in at rest, and
-- gives back the game's alpha when it goes home.
do
	local env, K, ns = boot()
	write(env, K, "sideStyle", "glass")
	write(env, K, "sideScroll", true)
	local scroll = env.ChatFrame1.ScrollToBottomButton
	scroll:SetAlpha(1)
	scroll:Show()
	write(env, K, "sideHover", true)
	assert(ns.Panel.strip:GetAlpha() == 0 and scroll:GetEffectiveAlpha() == 0, "the scroll button waits with the column, got " .. scroll:GetEffectiveAlpha())
	scroll:SetAlpha(0.65)
	assert(scroll:GetAlpha() == 0, "the game's fade-in at rest stays hidden")
	ns.Panel.strip:GetScript("OnEnter")(ns.Panel.strip)
	assert(scroll:GetAlpha() == 0.65, "the pointer brings back the game's alpha")
	ns.Panel.strip:GetScript("OnLeave")(ns.Panel.strip)
	env.RunTimers()
	assert(scroll:GetAlpha() == 0, "and leaving hides it again")
	write(env, K, "sideScroll", false)
	assert(scroll:GetAlpha() == 0.65, "going home gives back the game's alpha")
	clean(env, K)
end

-- Finding 6: the voice toggles the game hides while logged out of voice give up their slots, and take them back when
-- the game shows them (VoiceToggleButton.lua:17-21). The stub's Hide runs no OnHide, so the test runs it as the game does.
do
	local env, K = boot()
	write(env, K, "sideOrder", "voice,channels,menu")
	local column, channels = env.ChatFrame1.buttonFrame, env.ChatFrameChannelButton
	for _, name in ipairs({ "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
		env[name]:Hide()
		local hidden = env[name]:GetScript("OnHide")
		if hidden then hidden(env[name]) end
	end
	env.RunTimers()
	local p, rel, relp = point(channels)
	assert(p == "TOP" and rel == column and relp == "TOP", "logged out of voice, channels lead the column")
	env.ChatFrameToggleVoiceDeafenButton:Show()
	env.ChatFrameToggleVoiceMuteButton:Show()
	env.RunTimers()
	assert(select(2, point(channels)) == env.ChatFrameToggleVoiceMuteButton, "logging in gives the toggles their slots back")
	clean(env, K)
end

-- Finding 7: the preview draws no strip in the bare framing, as the panel does, and puts a freely moved button at
-- its spot against the column.
do
	local env, K, ns = boot()
	write(env, K, "sideStyle", "glass")
	write(env, K, "framing", "bare")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetPoint("CENTER")
	parent:SetSize(320, 480)
	local preview = K.Options.Preview("Chat")(parent)
	assert(not ns.Panel.strip:IsShown() and not preview.strip:IsShown(), "bare framing draws no strip, live or in the preview")
	write(env, K, "framing", "card")
	local function menu()
		preview:Refresh()
		for _, tile in ipairs(preview.icons) do
			if tile:IsShown() and tile.glyph:IsShown() then return tile:GetCenter() end
		end
	end
	local _, y0 = menu()
	write(env, K, "sideFree", true)
	write(env, K, "sidePositions", { ChatFrameMenuButton = { x = 20, y = -40 } })
	local x1, y1 = menu()
	write(env, K, "sidePositions", { ChatFrameMenuButton = { x = 30, y = -50 } })
	local x2, y2 = menu()
	assert(y1 > y0 + 20, "the spot near the column's top moves the menu tile up from the foot")
	assert(math.abs(x2 - x1 - 10) < 0.5 and math.abs(y2 - y1 + 10) < 0.5, "the tile follows the spot")
	clean(env, K)
end

-- Finding 8: with free move switched on and off again, the layout's own triggers neither re-register drags nor
-- rewrite unchanged scales.
do
	local env, K, ns = boot()
	write(env, K, "sideFree", true)
	write(env, K, "sideFree", false)
	local register, scale = 0, 0
	for _, name in ipairs({ "QuickJoinToastButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "ChatFrameMenuButton" }) do
		local b = env[name]
		local r, s = b.RegisterForDrag, b.SetScale
		b.RegisterForDrag = function(...) register = register + 1 return r(...) end
		b.SetScale = function(...) scale = scale + 1 return s(...) end
	end
	local resize = ns.Panel.Holder():GetScript("OnSizeChanged")
	for _ = 1, 5 do
		resize(ns.Panel.Holder())
		env.RunTimers()
	end
	assert(register == 0 and scale == 0, "five layout passes: " .. register .. " drag registrations, " .. scale .. " scale writes")
	clean(env, K)
end

print("chat parity r2 ok: backing, gap, order, size, spacing, column width, free move, scroll button and tabs above apply, restore and follow their events")
