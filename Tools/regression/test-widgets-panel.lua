-- test-widgets-panel.lua: the glass panel: chamfered chrome, title bar, close button, open and close motion, Escape, dragging and Layout.
local W = dofile("Tools/regression/widget_env.lua")

local function panelWith(opts, envOpts)
	local env, K = W.New(envOpts)
	return env, K, K.Widgets.Panel(K.Scale.Root(), opts)
end

-- A plain panel: snapped size, panel chrome with a shadow, a content frame inside the padding.
do
	local env, K, panel = panelWith({ width = 300.3, height = 180 })
	local Scale, Tokens = K.Scale, K.Tokens
	assert(panel:GetObjectType() == "Frame" and panel:GetParent() == Scale.Root())
	assert(W.Near(panel:GetWidth(), Scale.Snap(300.3)) and W.Near(panel:GetHeight(), Scale.Snap(180)), "the size is snapped to whole pixels")
	assert(panel.chrome and #panel.chrome.fill == 9 and panel.chrome.shadow[1]:IsShown(), "panel chrome with a shadow")
	assert(W.Near(panel.chrome.fill[1]:GetWidth(), Scale.Snap(Tokens.Size("chamferPanel"))), "8-unit chamfers")
	assert(panel.chrome.shapeName == "panel", "a plain panel is the small-panel grade")
	local content = panel.content
	assert(content and content:GetParent() == panel, "a content frame")
	local p = content._points[1]
	local pad = K.Widgets.WindowInset(panel)
	assert(p[1] == "TOPLEFT" and W.Near(p[4], pad) and W.Near(p[5], -pad), "content starts one rule inset in")
	assert(panel.titleText == nil and panel.closeButton == nil, "no title bar unless asked")
	assert(#env._errors == 0)
end

-- The title bar: an upper-case heading and a close button, with no line under the title, as the kit's panel.
do
	local closed = 0
	local env, K, panel = panelWith({
		width = 320, height = 200, title = "Panel title", close = true,
		onClose = function(p)
			closed = closed + 1
			assert(p ~= nil)
		end,
	})
	local Tokens = K.Tokens
	assert(panel.titleText:GetText() == "PANEL TITLE", "the title is upper case")
	assert(W.LastCall(panel.titleText, "SetFont")[2] == Tokens.Size("body"), "the title is body text, as the design's PANEL TITLE")
	assert(panel.chrome.shapeName == "window", "a titled panel is a window: the design's window-grade edge")
	assert(W.Near(panel.chrome.fill[1]:GetWidth(), K.Scale.Snap(Tokens.Size("chamferWindow"))), "10-unit chamfers")
	assert(panel.divider == nil, "no line under the title, as the kit's glass panel")
	for _, region in ipairs(W.Regions(panel, "Texture")) do
		assert(region:GetTexture() ~= Tokens.Texture("divider"), "no divider texture on the panel")
	end
	local top = panel.content._points[1]
	assert(top[5] < -K.Widgets.WindowInset(panel) - Tokens.Size("heading"), "content starts below the title bar")
	panel:SetTitle("Other")
	assert(panel.titleText:GetText() == "OTHER")
	local secret = env.Secret("Name")
	panel:SetTitle(secret)
	assert(panel.titleText:GetText() == secret, "a secret title passes through")
	local close = panel.closeButton
	assert(close and close:GetObjectType() == "Button", "a close button")
	panel:Open()
	W.Settle(env)
	assert(panel:IsShown() and panel:GetAlpha() == 1)
	W.Click(close)
	assert(closed == 1, "the close button closes the panel and runs onClose")
	W.Settle(env)
	assert(panel:IsShown() == false, "the panel fades out and hides")
	assert(panel:GetAlpha() == 1, "a later Show shows it at full alpha")
end

-- Opening fades in and plays the rise; reduced motion skips both.
do
	local env, K, panel = panelWith({ width = 200, height = 120, hidden = true })
	assert(panel:IsShown() == false, "hidden makes the panel start hidden")
	panel:Open()
	assert(panel:IsShown() and panel:GetAlpha() == 0, "Open shows the panel at alpha 0")
	assert(#W.Calls(panel.rise, "Play") == 1, "the rise plays")
	local translations = 0
	for _, anim in ipairs(panel.riseParts) do
		local offset = W.LastCall(anim, "SetOffset")
		translations = translations + offset[2]
	end
	assert(W.Near(translations, 0), "the rise ends where the panel rests, so nothing jumps")
	W.Settle(env)
	assert(panel:GetAlpha() == 1, "and fades to full alpha")
	panel:Close()
	W.Settle(env)
	K.Motion.SetReducedMotion(true)
	panel:Open()
	assert(panel:IsShown() and panel:GetAlpha() == 1, "reduced motion opens at once")
	assert(#W.Calls(panel.rise, "Play") == 1, "and does not play the rise")
	panel:Toggle()
	assert(panel:IsShown() == false, "Toggle closes an open panel")
	panel:Toggle()
	assert(panel:IsShown() == true, "and opens a closed one")
end

-- Escape closes a panel that asks for it.
do
	local env, _, panel = panelWith({ width = 200, height = 120, escape = true })
	panel:Open()
	W.Settle(env)
	W.Key(panel, "ESCAPE")
	W.Settle(env)
	assert(panel:IsShown() == false, "Escape closes the panel")
end

-- A movable panel drags by its title bar and reports the move.
do
	local moved = 0
	local _, _, panel = panelWith({
		width = 200, height = 120, title = "Drag me", movable = true,
		onMoved = function()
			moved = moved + 1
		end,
	})
	local bar = panel.titleBar
	assert(W.LastCall(panel, "SetMovable")[1] == true and W.LastCall(panel, "SetClampedToScreen")[1] == true)
	bar:GetScript("OnDragStart")(bar, "LeftButton")
	assert(#W.Calls(panel, "StartMoving") == 1, "dragging the title moves the panel")
	bar:GetScript("OnDragStop")(bar)
	assert(#W.Calls(panel, "StopMovingOrSizing") == 1 and moved == 1, "and stops and reports the move")
end

-- A panel with a layout key registers with Layout at its default position.
do
	local env, K, panel = panelWith({
		width = 200, height = 120,
		layout = { key = "Test.Panel", position = { anchor = "LEFT", x = 40, y = 0 }, options = { resizable = true, minWidth = 120, label = "Test" } },
	}, { layout = true })
	local reg = env._layout[1]
	assert(reg and reg.frame == panel and reg.key == "Test.Panel" and reg.opts.resizable and reg.position.anchor == "LEFT", "registered with Layout")
	assert(panel._points[1][1] == "LEFT" and panel._points[1][2] == K.Scale.Root())
end

-- Review Focus 1: a class change restyles an open panel, which still has no title line.
do
	local _, K, panel = panelWith({ width = 200, height = 120, title = "Accent" })
	assert(K.Theme.SetCustomAccent(0.2, 0.4, 0.9) and K.Theme.SetAccentSource("custom"))
	assert(panel.divider == nil and panel.titleText:GetText() == "ACCENT", "the title stays, with no line under it")
end

print("widgets panel ok")
