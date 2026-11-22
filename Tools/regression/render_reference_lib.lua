-- render_reference_lib.lua: strict reference acceptance shared by three budget-sized preset tests.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New({ width = 3456, height = 2234, size = 16 / 19 })
CoreEnv.Boot(env)
K.Store.Module("DataBars").enabled = true
K.Store.Module("DataBars").strip = { placement = "dock" }
K.Store.Module("Minimap").enabled = true
local Layouts = K.Setup.Layouts
local Guard = dofile("Tools/render/guard.lua")

return function(preset, built)
	local ok, why = pcall(Reference.Build, { layout = "unknown" })
	assert(not ok and tostring(why):find("reference layout must be", 1, true), "unknown reference presets fail before building")
	if not built then
		local loader = assert(loadfile("Tools/render/scenes/hud_reference.lua"))
		local picked = setmetatable({ getenv = function(key)
			if key == "RENDER_LAYOUT" then
				return preset
			end
			return os.getenv(key)
		end }, { __index = os })
		setfenv(loader, setmetatable({ os = picked }, { __index = _G }))
		built = loader()()
	end
	assert(built.layout == preset, "the scene names its preset")
	local findings = Guard.Check(built)
	assert(#findings == 0, preset .. " has a strict finding without any allowlist: " .. table.concat(Guard.Lines(findings, {}, {}, "strict"), "\n"))
	local rh = 1080 / K.Scale.DEFAULT_USER_SCALE
	local rw = rh * 3456 / 2234
	local positions = Layouts.PrepareFits(preset, 3456, 2234, Layouts.Enabled(preset)).layout
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.bar4", "actionbars.bar5", "unitframes.player", "unitframes.target", "minimap.main", "meters.damage", "chat.main", "databars.xp" }) do
		assert(positions[key] and built.elements[key], preset .. " compares the declared and applied position of " .. key)
	end
	for key, element in pairs(built.elements) do
		local position = positions[key]
		if position then
			element.key = key
			local left, bottom = Layouts.Rect(element, position, rw, rh)
			if key == "databars.xp" or key == "databars.rep" or key == "databars.honor" then bottom = math.max(bottom, K.Tokens.Size("screenMargin") + select(3, Layouts.DisplayInsets(key, element.height, position.anchor))) end
			assert(math.abs(left - element.left) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " horizontally")
			assert(math.abs(bottom - element.bottom) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " vertically")
		end
	end
	local seen = L.collect(built)
	local questCount, firstObjective = 0, nil
	for _, item in ipairs(built.items) do
		if item.kind == "text" then
			for _, title in ipairs({ "[11] Unnerving Silence", "[9] Crab Season", "[11] Aid For The Refugees", "[12] A Grand Adventure" }) do
				if item.text == title then
					questCount = questCount + 1
				end
			end
			if item.text:find("Find and speak with Elegael", 1, true) then
				firstObjective = item
			end
		end
	end
	assert(questCount == 4, preset .. " draws all four picture quests, got " .. questCount)
	local Scene = dofile("Tools/render/scene.lua")
	assert(firstObjective and Scene.WrappedLines(Scene.PlainText(firstObjective.text), firstObjective.font.size, firstObjective.font.path, firstObjective.rect[3]) == 3, preset .. " draws the first objective on three lines")
	local column
	for _, card in ipairs(built.rail) do
		if card.name == "quests" then column = (card.left + card.width) * 2234 / 1080 end
	end
	assert(column, preset .. " measures the quest card's right edge")
	local inset = K.Widgets.Inset(K.Scale.Root(), K.Tokens.Size("radius")) + K.Widgets.Snap(K.Scale.Root(), 1)
	column = column - inset * 2234 / rh
	local counts = 0
	for _, item in ipairs(built.items) do
		if item.kind == "text" and (item.text == "0/6" or item.text == "0/8" or item.text == "0/1") and item.rect[1] > 1250 then
			local right = (item.rect[1] + item.rect[3]) * 2.0685
			assert(math.abs(right - column) <= 1, preset .. " keeps quest counts inside the shared card inset and trailing pixel, got " .. right)
			counts = counts + 1
		end
	end
	assert(counts == 3, preset .. " checks all three objective counts")
	-- The crest's debuff fixture (hud.lua sigilSockets) times the target's two debuffs at 3s and 6s.
	for _, text in ipairs({ "45s", "7s", "6s", "8s", "14s", "Lightning Bolt", "203 / 237", "Korallis", "Shadowgale Poacher", "[11] Unnerving Silence", "[9] Crab Season", "You receive loot:" }) do
		local found = false
		for drawn in pairs(seen) do
			found = found or drawn:lower():find(text:lower(), 1, true) ~= nil
		end
		assert(found, preset .. " retains fixture content after Apply: " .. text)
	end
	local wrapped, clipped = false, false
	for _, item in ipairs(built.items) do
		if item.kind == "text" and item.text:find("appearance collection", 1, true) then
			assert(item.wordWrap ~= false, "chat messages wrap rather than ellipsize")
			assert(item.clip and item.scroll, "chat messages use the native scrolling viewport")
			wrapped = item.rect[4] > item.font.size * 1.3
		elseif item.kind == "text" and item.clip and item.scroll then
			clipped = true
		end
	end
	assert(clipped, preset .. " models the scrolling chat viewport")
	if preset == "Healer" then
		assert(wrapped, "the linked Healer message wraps at its own width with no smaller font")
	elseif preset == "Tank" then
		assert(built.elements["meters.threat"], "Tank registers its threat card")
		assert(seen.THREAT, "Tank draws the threat card, not an empty hidden reserve")
	end
	if preset ~= "DPS" then
		assert(built.elements["groupframes.party"], preset .. " renders party frames")
		assert(seen.Leduc and seen.Trolly, preset .. " shows its party members")
	end
	L.guard("hud_reference", built)
	L.globs()
	assert(rawget(_G, "RENDER_SCREEN") == nil, "every preset build gives the global screen back")
end
