-- actionbars_parity.lua: public per-bar settings at every text anchor, with real cooldown events and item quality.
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local AB = dofile("Tools/regression/actionbars_env.lua")
return Common.Run(function()
	local env, K, ns = AB.New({ width = Common.SCREEN.width, height = Common.SCREEN.height,
		saved = Gallery.Saved({ ActionBars = { slab = false, useTray = false, bar3 = { enabled = true, finished = false }, bar4 = { enabled = true }, bar5 = { enabled = false }, pet = { enabled = false }, stance = { enabled = false }, consumables = { enabled = false } } }),
		setup = function(e)
			Gallery.Setup(e)
			e._time = 10
			e._game.slots[1] = { type = "spell", id = 100, texture = 136048 }
			e._game.slots[61] = { type = "item", id = 100, texture = 135637, count = "20" }
			e._game.slots[49] = { type = "macro", subType = "item", id = 200, texture = 134400, text = "USE" }
			e._game.slots[25] = { type = "spell", id = 200, texture = 136026, cooldown = { start = 2, finish = 22 } }
			e._game.bindings.ACTIONBUTTON1 = { "Q" }
			e.C_Item = e.C_Item or {}
			e.C_Item.GetItemQualityByID = function(id) return id == 100 and 3 or 4 end
			e.C_Item.GetItemQualityColor = function(q) return q == 3 and 0 or 0.64, q == 3 and 0.44 or 0.21, q == 3 and 0.87 or 0.93 end
		end })
	AB.Enable(env, K)
	local function Write(key, value) K.Options.Write("ActionBars", key, value) end
	local after = os.getenv("RENDER_PARITY") ~= "before"
	local kinds = { "hotkey", "count", "macro", "cooldown" }
	for i, kind in ipairs(kinds) do
		local key = "bar" .. i
		Write(key .. ".buttons", 1)
		Write(key .. ".size", 38)
		Write(key .. ".rows", 1)
		Write(key .. ".desaturateCooldown", after)
		Write(key .. ".rarityBorder", after)
		Write(key .. ".swipeOpacity", after and 0.5 or 0.65)
		for _, field in ipairs(kinds) do Write(key .. "." .. field, field == kind) end
	end
	local label = K.Widgets.Text(K.Scale.Root(), "body", "textEmphasis")
	local headers = {}
	for i, title in ipairs({ "KEYBIND", "COUNT", "MACRO", "COOLDOWN" }) do
		local fs = K.Widgets.Text(K.Scale.Root(), "body", "textEmphasis")
		fs:SetText(title)
		fs:SetPoint("TOP", K.Scale.Root(), "TOP", -330 + (i - 1) * 220, -80)
		headers[i] = fs
	end
	local combined
	for row, anchor in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
		local y = -110 - (row - 1) * 85
		label:SetText(anchor)
		label:ClearAllPoints()
		label:SetPoint("RIGHT", K.Scale.Root(), "TOP", -410, y - 32)
		for i, kind in ipairs(kinds) do
			local key = "bar" .. i
			Write(key .. ".placement." .. kind .. ".anchor", after and anchor or "")
			K.Layout.Update("actionbars." .. key, { anchor = "TOP", x = -330 + (i - 1) * 220, y = y })
		end
		env.FireEvent("SPELL_UPDATE_COOLDOWN")
		local b = ns.bars.bar4.buttons[1]
		b.cooldown:GetScript("OnShow")(b.cooldown)
		env.RunTimers(); AB.W.Settle(env)
		assert(not Common.Errors(env, K), tostring(Common.Errors(env, K)))
		local scene = Gallery.Build(env, { time = 10 })
		if not combined then combined = scene else
			for _, item in ipairs(scene.items) do combined.items[#combined.items + 1] = item end
		end
		for _, fs in ipairs(headers) do fs:Hide() end
	end
	combined.log[#combined.log + 1] = after and "Nine anchors through per-bar Options writes; rare and epic items; desaturated real cooldowns." or "Previous choices: style anchors, ordinary item rims and coloured cooldown icons."
	return combined
end)
