-- test-ornament-rail-border.lua: at Subtle a nameplate's rails lie flush outside the bar's border and cover no row of it, for plain, elite, selected and boss plates at two plate scales on nine screens in both typesets; the bottom hairline always draws, the top one is split around the name's ink with 1 px clear, and it is omitted only where the name's ink comes within 1 px of its row.
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
			local px = K.Scale.Pixel(1)
			local function box(region)
				local f = K.Widgets.ScaleFactor(region)
				return region:GetLeft() * f / px, region:GetRight() * f / px, region:GetTop() * f / px, region:GetBottom() * f / px, f
			end
			local nl, nr, nt, nb, nf = box(plate.name)
			local fontFile, fontSize = plate.name:GetFont()
			local metrics = K.Widgets.OrnamentInk.fonts[fontFile:match("([^/\\]+)%.[tT][tT][fF]$")]
			assert(metrics, label .. ": the name's font has metrics in OrnamentInk")
			local deep = 0
			for k = 1, #plate.name:GetText() do
				local code = plate.name:GetText():byte(k)
				deep = math.max(deep, code < 0x80 and (metrics.deep[code] or 0) or metrics.descent)
			end
			local height = (nt - nb) * px / nf
			local inkBottom = nb + math.max(0, metrics.descent - deep) * math.min(fontSize, height / (metrics.ascent + metrics.descent)) * nf / px
			local inkWidth = plate.name:GetStringWidth() * nf / px
			if inkWidth < nr - nl then
				local justify = plate.name:GetJustifyH()
				if justify == "LEFT" then nr = nl + inkWidth elseif justify == "RIGHT" then nl = nr - inkWidth else nl, nr = (nl + nr - inkWidth) / 2, (nl + nr + inkWidth) / 2 end
			end
			local width = 0
			for j = 1, handle.used do
				local texture = handle.textures[j]
				if texture:IsShown() and (texture:GetTexture() or ""):match("End%a+%d+%.png$") then local l, r = box(texture) width = math.max(width, r - l) end
			end
			local above, below = 0, 0
			for j = 1, handle.used do
				local texture = handle.textures[j]
				local name = texture:IsShown() and (texture:GetTexture() or ""):match("(Rail%d+)%.png$")
				if name then
					local _, y, _, h = Scene.RectIn(solver, texture)
					assert(y + h <= top + 1e-3 or y >= bottom - 1e-3, string.format("%s: %s at %.2f..%.2f covers the bar's border %.2f..%.2f", label, name, y, y + h, top, bottom))
					assert(math.abs(y + h - top) < 1e-3 or math.abs(y - bottom) < 1e-3, string.format("%s: %s at %.2f..%.2f does not lie flush on the border %.2f..%.2f", label, name, y, y + h, top, bottom))
					if y < top then
						above = above + 1
						local rl, rr, rt = box(texture)
						local gapX = math.max(nl - rr, rl - nr)
						assert(inkBottom - rt >= 1 - 1e-3 or gapX >= 1 - 1e-3, string.format("%s: the top %s [%.2f..%.2f] comes within 1 px of the name's ink [%.2f..%.2f], %.2f px above", label, name, rl, rr, nl, nr, inkBottom - rt))
						assert(rr - rl >= width - 1e-3 or inkBottom - rt >= 1 - 1e-3, string.format("%s: a top %s piece %.2f px wide is shorter than an end (%.2f)", label, name, rr - rl, width))
					else
						below = below + 1
					end
					rails = rails + 1
				end
			end
			assert(below >= 1, label .. ": the bottom hairline is drawn")
			if above == 0 then
				local _, _, ht = box(handle.target)
				local rimPx = math.floor((handle.target.rimOutset or 0) * K.Widgets.ScaleFactor(handle.target) / px + 0.5)
				assert(inkBottom - (math.floor(ht + 0.5) + rimPx + 1) < 1 - 1e-3, string.format("%s: the top hairline is omitted though the name's ink (bottom %.2f px) keeps 1 px from its row (top %.2f px)", label, inkBottom, math.floor(ht + 0.5) + rimPx + 1))
				omitted = omitted + 1
			end
			plates = plates + 1
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
assert(rails > 0, "no rail was drawn")
print(string.format("ok at Subtle %d rails on %d plates lie flush outside the bar's border on nine screens, two plate scales and both typesets; the top hairline keeps 1 px from the name's ink and is omitted on %d plates, only where that ink comes within 1 px of its row", rails, plates, omitted))
