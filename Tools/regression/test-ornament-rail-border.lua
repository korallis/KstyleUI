-- test-ornament-rail-border.lua: at Subtle a nameplate's rails lie flush outside the bar's border and cover no row of it; at Full a plate's rail may replace its own bar's border (the named exemption) but covers no fill row and stays inside the ends' frame line; at both levels every rail keeps 1 px from the name's ink, the health and level text, the level badge and the markers, for plain, elite, selected and boss plates at two plate scales on nine screens in both typesets; the bottom rail always draws, the top one is split around the name's ink with 1 px clear, and it is omitted only where the name's ink comes within 1 px of its row.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local UNITS = {
	{ name = "Shadowgale Poacher", level = 38, reaction = 2, canAttack = true },
	{ name = "Bloodtalon Matriarch", level = 40, classification = "elite", reaction = 2, canAttack = true },
	{ name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true, raid = 8 },
	{ name = "Onyxia", level = -1, classification = "worldboss", reaction = 2, canAttack = true },
	{ name = "Zo\195\171 Thornbrook", level = 39, reaction = 2, canAttack = true },
	{ name = "Jaina Proudmoore", level = 60, reaction = 2, canAttack = true },
}
local rails, plates, omitted = 0, 0, 0

do
	local _, K = N.New({ width = 1920, height = 1080 })
	local cinzel = K.Widgets.OrnamentInk.fonts["CinzelUnit-SemiBold"]
	assert(cinzel and math.abs(cinzel.ascent - 0.976) < 1e-4 and math.abs(cinzel.descent - 0.372) < 1e-4, "CinzelUnit-SemiBold has ascent 0.976 and descent 0.372 em")
	assert(math.abs(cinzel.deep[81] - 0.271) < 1e-3 and math.abs(cinzel.deep[74] - 0.203) < 1e-3 and (cinzel.deep[65] or 0) == 0, "Cinzel's Q and J reach 0.271 and 0.203 em below the baseline and A none")
	assert((cinzel.deep[0xEB] or 0) < 0.02, "Cinzel's e with diaeresis sits on the baseline")
end
for _, level in ipairs({ "Subtle", "Full" }) do
for _, typeset in ipairs({ "Folio", "Lumen" }) do
	for _, screen in ipairs(SCREENS) do
		local env, K, ns = N.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "default" })
		env._textWidth = function(text, fontPath, size) return Scene.TextWidth(Scene.PlainText(text), size, fontPath) end
		K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
		K.Store.Module("Widgets").ornaments = level
		if typeset ~= "Folio" then
			K.Options.Write("Appearance", "typeSet", typeset)
			assert(K.Appearance.Get("typeSet") == typeset, "the typeset is " .. typeset)
			K.Options.Write("Nameplates", "level.show", true)
			K.Options.Write("Nameplates", "healthText.show", true)
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
		for token, base in pairs(env._bases) do N.Align(env, base, ns.Plates.Get(token).health) end
		Scene.Build(env)
		K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
		local solver = Scene.RectSolver(env)
		local pixel = 1080 / screen[2]
		local function snap(v) return math.floor(v / pixel + 0.5) * pixel end
		for i = 1, 2 * #UNITS do
			local plate = ns.Plates.Get("nameplate" .. i)
			local handle = plate.ornament
			local label = string.format("%s %s %dx%d %s", level, typeset, screen[1], screen[2], tostring(plate.name:GetText()))
			local _, ty, tw, th = Scene.RectIn(solver, handle.target)
			local rim = (handle.target.rimOutset or 0) * tw / env.Look(handle.target:GetWidth())
			local top, bottom = snap(ty - rim), snap(ty + th + rim)
			local px = K.Scale.Pixel(1)
			local function box(region)
				local x, y, w, h = Scene.RectIn(solver, region)
				return x / pixel, (x + w) / pixel, (1080 - y) / pixel, (1080 - y - h) / pixel, K.Widgets.ScaleFactor(region)
			end
			local nl, nr, nt, nb, nf = box(plate.name)
			local fontFile, fontSize = plate.name:GetFont()
			local metrics = K.Widgets.OrnamentInk.fonts[fontFile:match("([^/\\]+)%.[tT][tT][fF]$")]
			assert(metrics, label .. ": the name's font has metrics in OrnamentInk")
			local deep = 0
			local text = plate.name:GetText()
			local k = 1
			while k <= #text do
				local c = text:byte(k)
				if c < 0x80 then
					deep = math.max(deep, metrics.deep[c] or 0)
					k = k + 1
				else
					deep = math.max(deep, metrics.deep[(c % 32) * 64 + text:byte(k + 1) % 64] or 0)
					k = k + 2
				end
			end
			local height = (nt - nb) * px / nf
			local inkBottom = nb + math.max(0, metrics.descent - deep) * math.min(fontSize, height / (metrics.ascent + metrics.descent)) * nf / px
			local _, drop = plate.name:GetShadowOffset()
			if type(drop) == "number" and drop < 0 then inkBottom = inkBottom + drop * nf / px end
			local inkWidth = env.Look(plate.name:GetStringWidth()) * nf / px
			if inkWidth < nr - nl then
				local justify = plate.name:GetJustifyH()
				if justify == "LEFT" then nr = nl + inkWidth elseif justify == "RIGHT" then nl = nr - inkWidth else nl, nr = (nl + nr - inkWidth) / 2, (nl + nr + inkWidth) / 2 end
			end
			local width, frame = 0, nil
			for j = 1, handle.used do
				local texture = handle.textures[j]
				local size = texture:IsShown() and tonumber((texture:GetTexture() or ""):match("End%a+(%d+)%.png$"))
				if size then
					local l, r = box(texture)
					width = math.max(width, r - l)
					frame = math.min(frame or math.huge, (size - math.floor((bottom - top) / pixel + 0.5)) / 2)
				end
			end
			local lift = math.max(frame or 0, 0)
			local outerTop, outerBottom = top - lift * pixel, bottom + lift * pixel
			local fillTop, fillBottom = snap(ty), snap(ty + th)
			local others = {}
			for _, region in ipairs({ plate.healthText, plate.levelText, plate.level, plate.marker, plate.raid }) do
				if region:IsVisible() and Scene.RectIn(solver, region) then
					local l, r, t, b = box(region)
					if region:GetObjectType() == "FontString" and (region:GetText() or "") ~= "" then
						local ink = env.Look(region:GetStringWidth()) * K.Widgets.ScaleFactor(region) / px
						if ink < r - l then
							local justify = region:GetJustifyH()
							if justify == "LEFT" then r = l + ink elseif justify == "RIGHT" then l = r - ink else l, r = (l + r - ink) / 2, (l + r + ink) / 2 end
						end
					end
					others[#others + 1] = { l, r, t, b, region == plate.level and "level badge" or region == plate.marker and "target marker" or region == plate.raid and "raid icon" or region == plate.healthText and "health text" or "level text" }
				end
			end
			local above, below = 0, 0
			for j = 1, handle.used do
				local texture = handle.textures[j]
				local name = texture:IsShown() and (texture:GetTexture() or ""):match("(Rail%d+)%.png$")
				if name then
					local _, y, _, h = Scene.RectIn(solver, texture)
					if level == "Full" then
						assert(y + h <= fillTop + 1e-3 or y >= fillBottom - 1e-3, string.format("%s: %s at %.2f..%.2f covers the bar's fill %.2f..%.2f", label, name, y, y + h, fillTop, fillBottom))
						assert(y >= outerTop - 1e-3 and y + h <= outerBottom + 1e-3, string.format("%s: %s at %.2f..%.2f steps past the ends' frame line %.2f..%.2f", label, name, y, y + h, outerTop, outerBottom))
					else
						assert(y + h <= top + 1e-3 or y >= bottom - 1e-3, string.format("%s: %s at %.2f..%.2f covers the bar's border %.2f..%.2f", label, name, y, y + h, top, bottom))
						assert(math.abs(y + h - top) < 1e-3 or math.abs(y - bottom) < 1e-3, string.format("%s: %s at %.2f..%.2f does not lie flush on the border %.2f..%.2f", label, name, y, y + h, top, bottom))
					end
					local rl, rr, rt, rb = box(texture)
					for _, other in ipairs(others) do
						assert(math.max(other[1] - rr, rl - other[2], other[4] - rt, rb - other[3]) >= 1 - 1e-3, string.format("%s: %s [%.2f..%.2f, %.2f..%.2f] comes within 1 px of %s", label, name, rl, rr, rb, rt, other[5]))
					end
					if y + h / 2 < (top + bottom) / 2 then
						above = above + 1
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
				local row = math.floor(ht + 0.5) + rimPx + (level == "Full" and lift or 1)
				assert(inkBottom - row < 1 - 1e-3, string.format("%s: the top rail is omitted though the name's ink (bottom %.2f px) keeps 1 px from its row (top %.2f px)", label, inkBottom, row))
				omitted = omitted + 1
			end
			plates = plates + 1
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		collectgarbage("collect")
	end
end
end
assert(rails > 0, "no rail was drawn")
print(string.format("ok %d rails on %d plates on nine screens, two plate scales and both typesets: at Subtle flush outside the bar's border, at Full off the fill and inside the ends' frame line, and 1 px from the name's ink, the text, the level badge and the markers; the top rail is omitted on %d plates, only where that ink comes within 1 px of its row", rails, plates, omitted))
