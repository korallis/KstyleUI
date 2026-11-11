-- test-ornament-rail-border.lua: at Subtle a nameplate's rails lie flush outside the bar's border and cover no row of it, for plain, elite, selected and boss plates at two plate scales on nine screens in both typesets; the bottom hairline always draws, and the top one is omitted only where the plate's name reaches into the row above the border.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local UNITS = {
	{ name = "Shadowgale Poacher", level = 38, reaction = 2, canAttack = true },
	{ name = "Bloodtalon Matriarch", level = 40, classification = "elite", reaction = 2, canAttack = true },
	{ name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true },
	{ name = "Onyxia", level = -1, classification = "worldboss", reaction = 2, canAttack = true },
}
local rails, plates, omitted = 0, 0, 0
for _, typeset in ipairs({ "Folio", "Lumen" }) do
	for _, screen in ipairs(SCREENS) do
		local env, K, ns = N.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "default" })
		env._textWidth = function(text, fontPath, size) return Scene.TextWidth(Scene.PlainText(text), size, fontPath) end
		K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
		K.Store.Module("Widgets").ornaments = "Subtle"
		if typeset ~= "Folio" then
			K.Options.Write("Appearance", "typeSet", typeset)
			assert(K.Appearance.Get("typeSet") == typeset, "the typeset is " .. typeset)
		end
		env.WorldFrame:SetPoint("TOPLEFT")
		env.WorldFrame:SetPoint("BOTTOMRIGHT")
		for s, scale in ipairs({ 1, 0.58 }) do
			for k, unit in ipairs(UNITS) do
				local base = N.Base(env, { scale = scale })
				base:ClearAllPoints()
				base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", screen[1] * 0.75 * (k - 0.5) / #UNITS, screen[2] * 0.6 * s / 2)
				N.Add(env, "nameplate" .. ((s - 1) * #UNITS + k), unit, { base = base, scale = scale })
			end
		end
		N.Target(env, "nameplate1")
		env.RunTimers()
		for _ = 1, 10 do N.Tick(env, 0.05) end
		Scene.Build(env)
		K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
		local solver = Scene.RectSolver(env)
		local pixel = 1080 / screen[2]
		local function snap(v) return math.floor(v / pixel + 0.5) * pixel end
		for i = 1, 2 * #UNITS do
			local plate = ns.Plates.Get("nameplate" .. i)
			local handle = plate.ornament
			local label = string.format("Subtle %s %dx%d %s", typeset, screen[1], screen[2], tostring(plate.name:GetText()))
			local _, ty, tw, th = Scene.RectIn(solver, handle.target)
			local rim = (handle.target.rimOutset or 0) * tw / handle.target:GetWidth()
			local top, bottom = snap(ty - rim), snap(ty + th + rim)
			local above, below = 0, 0
			for j = 1, handle.used do
				local texture = handle.textures[j]
				local name = texture:IsShown() and (texture:GetTexture() or ""):match("(Rail%d+)%.png$")
				if name then
					local _, y, _, h = Scene.RectIn(solver, texture)
					assert(y + h <= top + 1e-3 or y >= bottom - 1e-3, string.format("%s: %s at %.2f..%.2f covers the bar's border %.2f..%.2f", label, name, y, y + h, top, bottom))
					assert(math.abs(y + h - top) < 1e-3 or math.abs(y - bottom) < 1e-3, string.format("%s: %s at %.2f..%.2f does not lie flush on the border %.2f..%.2f", label, name, y, y + h, top, bottom))
					if y < top then above = above + 1 else below = below + 1 end
					rails = rails + 1
				end
			end
			assert(below >= 1, label .. ": the bottom hairline is drawn")
			if above == 0 then
				local _, ny, _, nh = Scene.RectIn(solver, plate.name)
				assert(ny + nh > top - pixel + 1e-3, string.format("%s: the top hairline is omitted though the name (bottom %.2f) leaves the row above the border (%.2f..%.2f) free", label, ny + nh, top - pixel, top))
				omitted = omitted + 1
			end
			plates = plates + 1
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
assert(rails > 0, "no rail was drawn")
print(string.format("ok at Subtle %d rails on %d plates lie flush outside the bar's border on nine screens, two plate scales and both typesets; the top hairline is omitted on %d plates, only where the name reaches into the row above the border", rails, plates, omitted))
