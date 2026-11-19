-- test-minimap-crest.lua: the crest choices keep the map area, use the hub layers and class colour, and clear neighbouring defaults on all four screens, including a saved corner position.
local M = dofile("Tools/regression/minimap_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local W = M.W

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = M.New({ enabled = false, settings = {}, width = screen[1], height = screen[2], size = "auto",
		setup = function(e) e.KstyleUIDB.profiles.Default.HudStyle = { style = "medallions" } end })
	local layouts, section = K.Setup.Layouts, K.Store.Module("Minimap")
	local rw, rh = K.Layout.RootSize()
	section.frame = "classic"
	local base = layouts.Positions("DPS", "medallions", K.Scale.Aspect(), K.Scale.Band())
	local story = layouts.Story("DPS", rh, true, "medallions", rw)
	for _, frame in ipairs({ "classic", "ring", "medallion" }) do
		section.frame = frame
		assert(not layouts.MinimapCrest(), "a disabled Minimap must not reserve crest growth")
		local positions = layouts.Positions("DPS", "medallions", K.Scale.Aspect(), K.Scale.Band())
		for _, key in ipairs({ "minimap.main", "auras.buffs", "auras.debuffs" }) do
			for field, value in pairs(base[key]) do
				assert(positions[key][field] == value, "a disabled Minimap must preserve Classic geometry: " .. key .. "." .. field)
			end
		end
		local cards = layouts.Story("DPS", rh, true, "medallions", rw)
		for _, key in ipairs({ "guide", "quests" }) do
			for field, value in pairs(story[key]) do
				assert(cards[key][field] == value, "a disabled Minimap must preserve story geometry: " .. key .. "." .. field)
			end
		end
	end
	assert(#env._errors == 0)
end

for _, name in ipairs({ "Ring256", "Enamel256" }) do
	local file = assert(io.open("Media/Textures/Medallions/" .. name .. ".png", "rb"))
	local header = file:read(24)
	file:close()
	assert(header:sub(17, 24) == "\0\0\2\0\0\0\2\0", "export the original ring and enamel sources at 512 pixels")
end

local function Apart(a, b)
	return a.right <= b.left or b.right <= a.left or a.top <= b.bottom or b.top <= a.bottom
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, owner in ipairs({ false, true }) do
		local env, K, ns = M.New({ enabled = true, width = screen[1], height = screen[2], size = "auto",
			position = { 0.616, 0.579 }, setup = function(e)
				e._fitScale = true
				e.KstyleUIDB.profiles.Default.HudStyle = { style = "medallions" }
				if owner then e.KstyleUIDB.layouts.Default = { ["medallions:minimap.main"] = { anchor = "TOPRIGHT", x = -0.00008, y = -6.4 } } end
			end,
		})
		M.Settle(env)
		local face, layouts = ns.Map.face, K.Setup.Layouts
		local function Rect(region) return assert(G.ScaledRect(region, env.UIParent, K.Scale.Root())) end
		assert(K.Options.Default("Minimap", "frame") == "medallion", "Crest medallion is the default")
		assert(face.gem and face.gem:IsShown(), "the default uses the crest level-plaque gem")
		local width = face.mapArea:GetWidth()
		local rw, rh = K.Layout.RootSize()
		for _, key in ipairs({ "auras.buffs", "auras.debuffs" }) do
			local element = layouts.Element(key)
			local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
			holder:SetSize(element.width, element.height)
			K.Layout.Register(holder, key, layouts.Default(key))
		end
		local story = layouts.Story("DPS", rh, true, nil, rw, true)
		for _, card in ipairs({ story.guide, story.quests }) do
			local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
			holder:SetSize(card.width, card.height)
			K.Layout.Register(holder, card.key, card)
		end
		local enabled = layouts.Enabled("DPS", K.Store.Profile())
		local _, previousFit = layouts.ScaleLimit(screen[1], screen[2], "DPS", enabled, "medallions")
		local previousCrest = true
		for _, frame in ipairs({ "classic", "ring", "medallion" }) do
			env.KstyleUIDB.scaleCache = { oldFrame = true }
			K.Options.Write("Minimap", "frame", frame)
			M.Settle(env)
			assert(math.abs(face.mapArea:GetWidth() - width) <= K.Scale.Pixel(1), "grow the frame outward; preserve the visible map size: " .. frame .. " " .. width .. " / " .. face.mapArea:GetWidth())
			local crest = frame ~= "classic"
			local _, fit = layouts.ScaleLimit(screen[1], screen[2], "DPS", enabled, "medallions")
			assert(previousCrest == crest or fit ~= previousFit, "invalidate layout-fit cache when the minimap footprint changes")
			assert(not env.KstyleUIDB.scaleCache or not env.KstyleUIDB.scaleCache.oldFrame, "invalidate the persisted scale cache when Minimap frame changes")
			previousFit, previousCrest = fit, crest
			assert(face.enamel:IsShown() == crest and face.runes:IsShown() == crest, "Classic restores the previous ring")
			assert(face.gem:IsShown() == (frame == "medallion"), "only the medallion uses the gem")
			local path = W.LastCall(face.ring, "SetTexture")[1]
			assert(path:find(crest and "Ring256.png" or "MinimapRing.png", 1, true), "use native source exports for the crest")
			assert(W.LastCall(face.runes, "SetBlendMode")[1] == "ADD", "the engraved runes are additive")
			assert(W.Near(face.enamel:GetAlpha(), 0.35) and W.Near(face.runes:GetAlpha(), 0.25), "class tint preserves the hub layer opacities")
			assert(face.ring:GetWidth() * (crest and 118 / 150 or 0.9189) >= width - K.Scale.Pixel(1), "the opening preserves today's map")
			local ring, row = Rect(face.ring), Rect(face.plaques[2])
			for _, key in ipairs({ "auras.buffs", "auras.debuffs", "skins.guide", "skins.quests" }) do
				local other = Rect(K.Layout.Element(key).frame)
				assert(not crest or Apart(ring, other) and Apart(row, other), "refresh registered default neighbours when Minimap frame changes")
			end
			rw, rh = K.Layout.RootSize()
			for _, preset in ipairs(layouts.Names()) do
				local positions = layouts.Positions(preset, "medallions", K.Scale.Aspect(), K.Scale.Band())
				for _, key in ipairs({ "auras.buffs", "auras.debuffs" }) do
					local element = layouts.Element(key)
					local l, b, r, t = layouts.Rect(element, positions[key], rw, rh)
					assert(not crest or Apart(ring, { left = l, bottom = b, right = r, top = t }), frame .. ": move the default aura row clear of the wider ring")
				end
				local presetStory = layouts.Story(preset, rh, true, "medallions", rw)
				for _, card in ipairs({ presetStory.guide, presetStory.quests }) do
					local l, b, r, t = layouts.Rect(card, card, rw, rh)
					local box = { left = l, bottom = b, right = r, top = t }
					assert(not crest or Apart(ring, box) and Apart(row, box), frame .. " " .. screen[1] .. " " .. preset .. ": move the default story cards clear of the ring and caption")
				end
			end
		end
		for _, key in ipairs({ "auras.buffs", "skins.quests" }) do
			K.Layout.Update(key, { anchor = "CENTER", x = 70, y = 50 })
		end
		K.Options.Write("Minimap", "frame", "classic")
		K.Options.Write("Minimap", "frame", "medallion")
		M.Settle(env)
		for _, key in ipairs({ "auras.buffs", "skins.quests" }) do
			local saved = K.Layout.Get(key)
			assert(saved.anchor == "CENTER" and saved.x == 70 and saved.y == 50, "preserve saved neighbour positions when changing the frame")
		end
		for _, class in ipairs({ "MAGE", "WARRIOR" }) do
			env.UnitClass = function() return class, class end
			K.Options.Write("Minimap", "accent.source", "custom")
			env.FireEvent("PLAYER_LOGIN")
			M.Settle(env)
			local r, g, b = K.Theme.ClassColor(class)
			local tint = W.LastCall(face.runes, "SetVertexColor")
			assert(W.Near(tint[1], r) and W.Near(tint[2], g) and W.Near(tint[3], b), "the crest follows the player class, independently of a custom accent")
		end
		for _, style in ipairs({ "frames", "orbs" }) do
			K.Options.Write("HudStyle", "style", style)
			M.Settle(env)
			assert(not face.ring:IsShown() and not face.enamel:IsShown() and not face.runes:IsShown() and not face.gem:IsShown(), "only Medallions has a crest minimap")
			assert(face.plate.diamond.black:IsShown(), "Frames and Orbs restore their north diamond")
		end
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("minimap crest ok: three choices, four screens, defaults and saved positions, three presets, class changes and style isolation")
