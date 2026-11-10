-- test-actionbars-reference.lua: the reference action bars have square dark tiles, a physical-pixel border, bright bold keys and full-strength empty slots.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W

local function check(env, K, b)
	assert(W.LastCall(b.mask, "SetTexture")[1] == K.Tokens.Texture("iconMask"), "the action tile uses the shared kit's icon mask")
	assert(W.LastCall(b.cooldown, "SetSwipeTexture")[1] == K.Tokens.Texture("iconMask"), "the cooldown uses the shared kit's mask")
	local kit = K.Widgets.IconButton(K.Scale.Root(), { size = b.opts.size })
	assert(b.chrome:Radius() == kit.chrome:Radius(), "the action tile keeps the shared kit's corner geometry")
	local p = b.icon._points[1]
	local kp = kit.icon._points[1]
	assert(p[1] == "TOPLEFT" and W.Near(p[4], kp[4]) and W.Near(p[5], kp[5]), "the action tile keeps the shared kit's icon inset")
	local border = K.Widgets.Border(b)
	assert(W.Near(b.chrome:Radius(), 3 * border), "socket corners span three border lines")
	assert(W.Near(p[4], 2 * border) and W.Near(p[5], -2 * border), "icons sit two border lines inside the socket")
	local r, g, bl, a = K.Tokens.Color("white")
	local kr, kg, kb, ka = b.hotkey:GetTextColor()
	assert(W.Near(kr, r) and W.Near(kg, g) and W.Near(kb, bl) and W.Near(ka, a), "keys are full-strength white")
	local font = b.hotkey:GetFont()
	assert(font == K.Tokens.Font("number"), "keys use the kit's bold number font")
	assert(b.hotkey._points[1][1] == "TOPLEFT", "keys stay at the top left")
	assert(#env._errors == 0, AB.Errors(env))
end

do
	local env, K, ns = AB.New({ setup = function(e)
		e._game.bindings.ACTIONBUTTON8 = { "8" }
	end })
	AB.Enable(env, K)
	local schema = K.Options.Get("ActionBars")
	for _, row in ipairs(schema) do
		if row.key == "bar1.size" or row.key == "bar1.spacing" or row.key == "bar2.size" or row.key == "bar2.spacing" then
			assert(row.step == 0.1, "the size and gap sliders can represent the fractional reference defaults")
		end
	end
	for _, key in ipairs({ "bar1", "bar2" }) do
		local cfg = ns.Config(key)
		assert(W.Near(cfg.size, 36.7) and W.Near(cfg.spacing, 4.6), key .. " uses the measured 36.7-unit tiles and 41.3-unit pitch")
		local bar = ns.bars[key]
		local x = select(4, bar.buttons[12]:GetPoint())
		assert(W.Near(x, K.Widgets.Snap(bar.header, 11 * 41.3)), "the twelfth tile does not accumulate individually rounded gaps")
		assert(W.Near(bar.holder:GetWidth(), x + bar.buttons[12]:GetWidth()), "the holder encloses the final snapped tile")
	end
	for _, key in ipairs({ "bar3", "bar4", "bar5", "bar6" }) do
		local grid = K.Setup.Layouts.Grid("actionbars." .. key)
		assert(ns.Config(key).size == grid.size and ns.Config(key).spacing == (grid.spacing or K.Tokens.Size("actionGap")), key .. " keeps its layout grid")
	end
	local b = AB.Button(ns, "bar1", 8)
	assert(b:GetAlpha() == 1 and b.hotkey:GetText() == "8", "an empty slot keeps its tile and its bright key")
	check(env, K, b)
	env.SetCombat(true)
	assert(b:GetAlpha() == 1, "empty tiles do not disappear in combat")
	assert(#env._blocked == 0, table.concat(env._blocked, ", "))
	env.SetCombat(false)
	AB.Slot(env, 8, { texture = 1, type = "spell", id = 1 })
	b:Restyle()
	check(env, K, b)
	K.Options.Write("ActionBars", "bar1.size", 44)
	check(env, K, b)
	K.Options.Write("ActionBars", "bar1.showEmpty", false)
	AB.Slot(env, 8, nil)
	assert(b:GetAlpha() == 0, "the explicit hide-empty setting still works")
	env.FireEvent("ACTIONBAR_SHOWGRID")
	assert(b:GetAlpha() == 1, "dragging an action still reveals a hidden empty slot")
	K.Options.Write("ActionBars", "bar1.size", 36.7)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(491, 80)
	local preview = K.Options.Preview("ActionBars")(parent)
	local last = preview.buttons[12]
	assert(last:IsShown(), "the measured twelve-tile row fits in the preview's 491 units")
	assert(W.Near(select(4, last:GetPoint()), K.Widgets.Snap(preview, 11 * 41.3)), "the preview uses the same cumulative-safe pitch as the live bar")
	check(env, K, preview.buttons[8])
end

do
	local env, K, ns = AB.New()
	AB.Enable(env, K)
	for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5" }) do
		K.Options.Write("ActionBars", key .. ".enabled", true)
		local empty = 0
		for _, button in ipairs(ns.bars[key].buttons) do
			if not button.hasAction then
				empty = empty + 1
				assert(button:GetAlpha() == 1, key .. " keeps empty sockets at full opacity")
				assert(W.SameColor(button.chrome.fill[5], K.Tokens.Color("buttonFill")), key .. " uses the kit's dark empty fill without further dimming")
				assert(W.SameColor(button.chrome.line[1], K.Tokens.Color("socketEdge")), key .. " keeps the visible black socket edge")
				check(env, K, button)
			end
		end
		assert(empty > 0, key .. " exercises empty sockets")
	end
end

-- The rail's bars stand on whole pixels from one cumulative pitch, as bars 1 and 2 do, so a column of twelve tiles at a
-- fractional scale is as tall as the 491 units the layout reserves for it, within a pixel.
do
	local env, K, ns = AB.New({ width = 1920, height = 1080 })
	AB.Enable(env, K)
	assert(K.Scale.SetUserScale(0.777), "the interface size takes 0.777")
	for _, key in ipairs({ "bar4", "bar5", "bar6" }) do
		K.Options.Write("ActionBars", key .. ".enabled", true)
		local bar = ns.bars[key]
		bar:Layout()
		local reserved = 491
		local height = bar.holder:GetHeight()
		assert(math.abs(height - reserved) <= K.Scale.Pixel(1) + 0.01, key .. " is as tall as its reserved column, got " .. height .. " for " .. reserved)
	end
end

for _, height in ipairs({ 1080, 1440, 2160, 2234 }) do
	local env, K, ns = AB.New({ width = height * 16 / 9, height = height })
	AB.Enable(env, K)
	check(env, K, AB.Button(ns, "bar1", 1))
end

print("reference action tiles ok")
