-- test-meters-plate-style.lua: damage and threat use the nameplates' bar texture, height and type at every owner screen size.
local M = dofile("Tools/regression/meters_env.lua")
local N = dofile("Tools/regression/nameplates_env.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local saved = { version = 38, profiles = { Default = { HudStyle = { style = style } } } }
		local ne, _, plates = N.New({ width = screen[1], height = screen[2], saved = saved })
		N.Add(ne, "nameplate1", { name = "Warrior", class = "WARRIOR", isPlayer = true })
		local plate = assert(plates.Plates.Get("nameplate1"))
		local env, K, ns = M.New({ width = screen[1], height = screen[2], saved = { version = 38, profiles = { Default = { HudStyle = { style = style } } } } })
		local lists = {}
		for _, section in ipairs({ "damage", "threat" }) do
			local list = ns.BarList.New(K.Scale.Root(), section, { width = 269, height = 158, columns = function() return { value = true, percent = true } end })
			list:SetRow(1, "Warrior", "WARRIOR", "friendly", 50, 100, "50", "50%")
			local row = list.rows[1]
			assert(math.abs(row.bar:GetHeight() - K.Widgets.Snap(row.bar, K.Tokens.Size("barHeight"))) < 0.01, style .. ": meter bars use the shared barHeight token without changing the nameplates")
			assert(row.bar.texturePath == plate.health.texturePath, "use the same bar texture")
			assert(row.bar.barEdge ~= nil and row.bar.backgroundName == "barTrack", "use the shared edge and track")
			assert(select(1, row.name:GetPoint(1)) == "TOPLEFT" and select(1, row.bar:GetPoint(1)) == "BOTTOMLEFT", "names sit above the bar")
			local wash = M.Last(row.wash, "SetColorTexture")
			assert(wash and wash[4] == 0.05, "the shared row hover wash uses rowHover")
			if section == "threat" then
				assert(not row.frame:IsMouseEnabled(), "threat rows must keep passing clicks to the world")
			end
			for _, pair in ipairs({ { row.name, plate.name }, { row.value, plate.healthText }, { row.percent, plate.healthText } }) do
				local font, size = pair[1]:GetFont()
				local plateFont, plateSize = pair[2]:GetFont()
				assert(font == plateFont and math.abs(size - (pair[1] == row.name and plateSize or K.Widgets.FontSize(pair[1], K.Tokens.Size("number")))) < 0.01, style .. ": meter name and number faces/sizes must match the nameplates")
			end
			lists[#lists + 1] = list
		end
		assert(lists[1].rowHeight == lists[2].rowHeight and lists[1].spacing == lists[2].spacing and lists[1].pad == lists[2].pad, "both cards share their row and card geometry")
		assert(#env._errors == 0 and #ne._errors == 0)
	end
end
print("meter/nameplate style ok: 3 HUD styles, 4 screens")
