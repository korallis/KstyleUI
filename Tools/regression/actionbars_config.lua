-- actionbars_config.lua: every free bar's controls, slab controls and combat deferral on the four owner screens.
local AB = dofile("Tools/regression/actionbars_env.lua")
local screens = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local function Near(a, b, message)
	assert(math.abs(a - b) < 1e-5, message .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function XY(button)
	local _, _, _, x, y = button:GetPoint(1)
	return x, y
end
return function(style)
for _, screen in ipairs(screens) do
	do
		local env, K, ns = AB.New({ width = screen[1], height = screen[2] })
		env._game.petExists = true
		for i = 1, 10 do env._game.forms[i] = { texture = 132355, spellID = 2457 + i } end
		AB.Enable(env, K)
		K.Options.Write("HudStyle", "style", style)
		local function Write(key, value) K.Options.Write("ActionBars", key, value) end
		assert(ns.Config("slab") == true and ns.Config("tray") == true, "slab and tray keep the shipped look by default")
		Write("slab", false)
		Write("tray", false)
		assert(not ns.Tray.Column(ns.BAR.bar1), "Use the tray off must release the Frames size override")
		if ns.Slab.frame then assert(not ns.Slab.frame:IsShown(), "Use the slab off hides its connected plate") end
		for _, def in ipairs(ns.BARS) do
			local key, element = def.key, def.element
			Write(key .. ".enabled", true)
			local bar = ns.bars[key]
			Write(key .. ".buttons", 6)
			Write(key .. ".rows", 2)
			Write(key .. ".size", 40)
			Write(key .. ".spacing", 4)
			if def.kind == "action" then Write(key .. ".split", "off") end
			Write(key .. ".growth", "RIGHTDOWN")
			Write(key .. ".orientation", "HORIZONTAL")
			assert(bar.count == 6 and bar.buttons[6]:IsShown() and not bar.buttons[7]:IsShown(), key .. " buttons apply")
			local size = K.Widgets.Snap(bar.header, 40)
			local pitch = def.kind == "action" and K.Widgets.Snap(bar.header, 44) or size + K.Widgets.Snap(bar.header, 4)
			Near(bar.buttons[1]:GetWidth(), size, style .. " " .. key .. " size")
			local x1, y1 = XY(bar.buttons[1])
			local x2, y2 = XY(bar.buttons[2])
			Near(x2 - x1, pitch, key .. " spacing")
			Near(y2, y1, key .. " horizontal fill")
			Near(select(2, XY(bar.buttons[4])) - y1, -pitch, key .. " rows")
			Write(key .. ".orientation", "VERTICAL")
			Near(select(2, XY(bar.buttons[2])) - select(2, XY(bar.buttons[1])), -pitch, key .. " vertical fill")
			Write(key .. ".growth", "LEFTUP")
			x1, y1 = XY(bar.buttons[1])
			assert(x1 > 0 and y1 < 0, key .. " growth reverses both axes")
			Write(key .. ".rows", 1)
			Near(bar.holder:GetHeight(), size, key .. " one row")
			Write(key .. ".rows", 2)
			Write(key .. ".backing", true)
			assert(bar.backing:IsShown(), key .. " backing on")
			local plate = ns.Slab.sides and ns.Slab.sides[key]
			if plate then assert(not plate:IsShown(), key .. " the optional backing must stay visible over the style's plate") end
			Write(key .. ".backing", false)
			assert(not bar.backing:IsShown(), key .. " backing off")
			Write(key .. ".fadeAlpha", 0.25)
			Write(key .. ".fade", true)
			Near(bar.target, 0.25, key .. " fade")
			bar:SetHovered(true)
			Near(bar.target, 1, key .. " hover restores opacity")
			bar:SetHovered(false)
			Write(key .. ".fade", false)
			Write(key .. ".hotkey", false)
			assert(not bar.buttons[1].hotkey:IsShown(), key .. " keybind text")
			Write(key .. ".hotkey", true)
			Write(key .. ".cooldown", false)
			if def.kind ~= "stance" then
				Write(key .. ".showEmpty", false)
				assert(bar.buttons[6]:GetAlpha() == 0, key .. " hides empty slots")
				Write(key .. ".showEmpty", true)
				assert(bar.buttons[6]:GetAlpha() > 0, key .. " shows empty slots (quiet Medallions sockets may be dim)")
			end
			if def.kind == "action" then
				Write(key .. ".count", false)
				assert(not bar.buttons[1].count:IsShown(), key .. " count text")
				Write(key .. ".macro", true)
				assert(bar.buttons[1].macroText:IsShown(), key .. " macro text")
			end
			local width, height = K.Setup.Layouts.Footprint("DPS", element, style)
			local scale = style == "orbs" and key == "bar2" and bar.holder:GetScale() or 1
			assert(math.abs(width - bar.holder:GetWidth() * scale) <= 2 * K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar.header), key .. " setup width follows live bar")
			assert(math.abs(height - bar.holder:GetHeight() * scale) <= 2 * K.Scale.Pixel(1) / K.Widgets.ScaleFactor(bar.header), key .. " setup height follows live bar")
			local before = bar.holder:GetWidth()
			env.SetCombat(true)
			Write(key .. ".buttons", 4)
			Write(key .. ".size", 32)
			Write(key .. ".spacing", 8)
			Write(key .. ".rows", 1)
			Near(bar.holder:GetWidth(), before, key .. " combat retains live layout")
			env.SetCombat(false)
			assert(bar.count == 4 and bar.holder:GetWidth() ~= before, key .. " combat queue applies latest layout")
		end
		if style == "medallions" then
			Write("slab", true)
			Write("bar1.buttons", 6)
			Write("bar2.buttons", 9)
			Write("bar1.size", 40)
			Near(ns.bars.bar1.buttons[1]:GetWidth(), ns.bars.bar2.buttons[1]:GetWidth(), "slab size scales both sides")
			assert(ns.Slab.frame:IsShown(), "slab stays connected with different button counts")
			env.SetCombat(true)
			Write("slab", false)
			assert(ns.Slab.frame:IsShown(), "combat keeps the slab until the queued change applies")
			env.SetCombat(false)
			assert(not ns.Slab.frame:IsShown(), "combat end applies the queued slab toggle")
			Write("slab", true)
			local cfg = K.Store.Module("ActionBars")
			cfg.editBar = "bar1"
			for _, option in ipairs({ "rows", "orientation", "growth", "spacing", "split", "showEmpty", "backing" }) do
				assert(not K.Options.Row("ActionBars", "bar1." .. option).showWhen(cfg), "slab hides unsupported " .. option)
			end
			Write("slab", false)
			assert(K.Options.Row("ActionBars", "bar1.rows").showWhen(cfg), "free bars show all controls")
		end
		assert(#env._blocked == 0, table.concat(env._blocked, ", "))
		assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
	end
	collectgarbage("collect")
end
print("ok actionbars configurable: " .. style .. ", all bars, four screens and combat")
end
