-- test-databars-menus.lua: the micro menu and the bag bar restyled in place: art faded with alpha, glass and tiles on KstyleUI's own child frames, nothing hidden, moved or written.
local D = dofile("Tools/regression/databars_env.lua")
local W = D.W

local MICRO = { "CharacterMicroButton", "PlayerSpellsMicroButton", "QuestLogMicroButton", "MainMenuMicroButton" }
local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "KeyRingButton" }

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function noErrors(env, K)
	assert(#env._errors == 0, "errors were raised: " .. tostring(env._errors[1]))
	eq(K.ErrorCount(), 0, "errors caught by KstyleUI.Call")
end

-- Stand-ins for Blizzard's micro menu and bag bar, built as Forever's XML builds them.
local function Button(env, name, parent, regions)
	local button = env._G[name] or env.CreateFrame("Button", name, parent)
	button:SetParent(parent)
	for _, key in ipairs(regions) do
		button[key] = button:CreateTexture(nil, "BACKGROUND")
	end
	for _, kind in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
		local texture = button:CreateTexture(nil, "ARTWORK")
		button["Set" .. kind .. "Texture"](button, texture)
	end
	button.icon = button:CreateTexture(nil, "BORDER")
	return button
end

local function Menus(env)
	local container = env.CreateFrame("Frame", "MicroMenuContainer", env.UIParent)
	local menu = env.CreateFrame("Frame", "MicroMenu", container)
	menu.BorderArt = menu:CreateTexture(nil, "BACKGROUND")
	menu.BackgroundArt = menu:CreateTexture(nil, "BACKGROUND")
	for _, name in ipairs(MICRO) do
		Button(env, name, menu, { "Background", "PushedBackground" })
	end
	local bags = env.CreateFrame("Frame", "BagsBar", env.UIParent)
	bags.BorderArt = bags:CreateTexture(nil, "BACKGROUND")
	local cluster = env.CreateFrame("Frame", "BagSlotCluster", bags)
	for _, name in ipairs(BAGS) do
		Button(env, name, name:match("^CharacterBag") and cluster or bags, {})
	end
end

local function Snapshot(env)
	local names = { "MicroMenuContainer", "MicroMenu", "BagsBar", "BagSlotCluster" }
	for _, name in ipairs(MICRO) do
		names[#names + 1] = name
	end
	for _, name in ipairs(BAGS) do
		names[#names + 1] = name
	end
	local out = {}
	for _, name in ipairs(names) do
		local frame = env[name]
		local keys = {}
		for key in pairs(frame) do
			keys[key] = true
		end
		out[name] = { frame = frame, keys = keys, calls = #frame._calls }
	end
	return out
end

local FORBIDDEN = { Hide = true, SetParent = true, SetScript = true, ClearAllPoints = true, SetPoint = true, SetAllPoints = true, SetShown = true, SetSize = true, SetScale = true }

local function CheckUntouched(env, before)
	for name, entry in pairs(before) do
		local frame = entry.frame
		for i = entry.calls + 1, #frame._calls do
			local call = frame._calls[i]
			assert(not FORBIDDEN[call.method], "DataBars called " .. call.method .. " on " .. name)
			if call.method == "HookScript" then
				assert(call.args[1] ~= "OnShow" or not (name == "BagsBar" or name == "BagSlotCluster" or name:match("Bag") or name == "KeyRingButton" or name == "MainMenuBarBackpackButton"), "an OnShow hook inside the BagsBar tree on " .. name)
			end
		end
		for key in pairs(frame) do
			assert(entry.keys[key], "DataBars wrote the field " .. tostring(key) .. " onto " .. name)
		end
	end
end

local function New(opts)
	opts = opts or {}
	local userSetup = opts.setup
	opts.setup = function(env, game)
		Menus(env)
		if userSetup then
			userSetup(env, game)
		end
	end
	local enable = opts.enable
	opts.enable = false
	local env, K, ns, game = D.New(opts)
	local before = Snapshot(env)
	if enable ~= false then
		K.Modules.Enable("DataBars")
	end
	return env, K, ns, game, before
end

-- Restyled in place: art faded, icons kept, glass and tiles on KstyleUI frames ---------------------------

do
	local env, K, _, _, before = New()
	local Skin = K.Skin
	eq(env.MicroMenu.BorderArt:GetAlpha(), 0, "the micro menu's frame art fades")
	eq(env.MicroMenu.BackgroundArt:GetAlpha(), 0, "and its background")
	for _, name in ipairs(MICRO) do
		local button = env[name]
		eq(button.Background:GetAlpha(), 0, name .. "'s bronze plate fades")
		eq(button.PushedBackground:GetAlpha(), 0, name .. "'s pushed plate fades")
		eq(button:GetNormalTexture():GetAlpha(), 1, name .. "'s icon stays")
	end
	assert(Skin.IsSkinned(env.MicroMenu, "Backdrop"), "the micro menu sits on glass")
	eq(Skin.Parts(env.MicroMenu).backdrop:IsShown(), true, "the glass shows")
	eq(Skin.Parts(env.CharacterMicroButton) and Skin.Parts(env.CharacterMicroButton).backdrop or nil, nil, "micro buttons get no tiles by default")

	eq(env.BagsBar.BorderArt:GetAlpha(), 0, "the bag bar's frame art fades")
	assert(Skin.IsSkinned(env.BagsBar, "Backdrop"), "the bag bar sits on glass")
	for _, name in ipairs(BAGS) do
		local button = env[name]
		eq(button:GetNormalTexture():GetAlpha(), 0, name .. "'s slot frame fades")
		eq(button:GetPushedTexture():GetAlpha(), 0, name .. "'s pushed frame fades")
		eq(button.icon:GetAlpha(), 1, name .. "'s icon stays")
		assert(Skin.IsSkinned(button, "Backdrop"), name .. " sits on a raised tile")
	end
	CheckUntouched(env, before)

	local tile = K.Skin.Parts(env.CharacterBag0Slot).backdrop
	W.Enter(env.CharacterBag0Slot)
	W.Settle(env)
	local r, g, b = K.Theme.Accent()
	local er, eg, eb = tile.chrome.inner[1]:GetVertexColor()
	assert(near(er, r) and near(eg, g) and near(eb, b), "a hovered bag lights its tile's edge in the accent")
	W.Leave(env.CharacterBag0Slot)
	noErrors(env, K)
end

-- Settings: glass, tiles and icon tint -----------------------------------------------------------------

do
	local env, K, _, _, before = New()
	local Skin = K.Skin
	K.Options.Write("DataBars", "micro.backdrop", false)
	eq(Skin.Parts(env.MicroMenu).backdrop:IsShown(), false, "the micro menu's glass can be turned off")
	K.Options.Write("DataBars", "micro.tiles", true)
	for _, name in ipairs(MICRO) do
		assert(Skin.IsSkinned(env[name], "Backdrop"), name .. " gets a tile")
		eq(Skin.Parts(env[name]).backdrop:IsShown(), true, name .. "'s tile shows")
	end
	K.Options.Write("DataBars", "micro.tiles", false)
	eq(Skin.Parts(env.CharacterMicroButton).backdrop:IsShown(), false, "tiles can be turned off again")

	local quest = env.QuestLogMicroButton
	quest:GetDisabledTexture():SetDesaturation(1)
	quest:GetNormalTexture():SetDesaturation(0.3)
	K.Options.Write("DataBars", "micro.tint", "accent")
	eq(quest:GetDisabledTexture():GetVertexColor(), nil, "disabled icons keep Blizzard's own look")
	local icon = env.CharacterMicroButton:GetNormalTexture()
	local r, g, b = K.Theme.Accent()
	local ir, ig, ib = icon:GetVertexColor()
	assert(near(ir, r) and near(ig, g) and near(ib, b), "accent tint colours the icons")
	eq(icon:GetDesaturation(), 1, "a tinted icon is desaturated first")
	K.Options.Write("DataBars", "micro.tint", "none")
	ir, ig, ib = icon:GetVertexColor()
	assert(near(ir, 1) and near(ig, 1) and near(ib, 1), "no tint restores the icons")
	eq(icon:GetDesaturation(), 0, "and their colour")
	eq(quest:GetNormalTexture():GetDesaturation(), 0.3, "each icon gets back its own desaturation")
	eq(quest:GetDisabledTexture():GetDesaturation(), 1, "and Blizzard's desaturated disabled icon stays so")

	K.Options.Write("DataBars", "bags.backdrop", false)
	eq(Skin.Parts(env.BagsBar).backdrop:IsShown(), false, "the bag bar's glass can be turned off")
	K.Options.Write("DataBars", "bags.tiles", false)
	eq(Skin.Parts(env.CharacterBag0Slot).backdrop:IsShown(), false, "bag tiles can be turned off")
	CheckUntouched(env, before)
	noErrors(env, K)
end

-- Switched off before the module starts: nothing is touched --------------------------------------------

do
	local env, K, _, _, before = New({ enable = false })
	K.Options.Write("DataBars", "micro.skin", false)
	K.Options.Write("DataBars", "bags.skin", false)
	K.Modules.Enable("DataBars")
	eq(env.MicroMenu.BorderArt:GetAlpha(), 1, "an unskinned micro menu keeps its art")
	eq(env.BagsBar.BorderArt:GetAlpha(), 1, "an unskinned bag bar keeps its art")
	eq(K.Skin.IsSkinned(env.MicroMenu, "Backdrop"), false, "and gets no glass")
	CheckUntouched(env, before)
	noErrors(env, K)
end

-- Off: KstyleUI's parts hide and the player is asked to reload -----------------------------------------

do
	local env, K = New()
	K.Modules.Disable("DataBars")
	eq(K.Skin.Parts(env.MicroMenu).backdrop:IsShown(), false, "the glass hides with the module")
	eq(K.Skin.Parts(env.CharacterBag0Slot).backdrop:IsShown(), false, "the tiles hide with the module")
	eq(K.Modules.NeedsReload(), true, "Blizzard's faded art needs a reload to come back")
	K.Modules.Enable("DataBars")
	eq(K.Skin.Parts(env.MicroMenu).backdrop:IsShown(), true, "the glass returns")
	noErrors(env, K)
end

do
	local env, K = New()
	K.Options.Write("DataBars", "micro.skin", false)
	eq(K.Skin.Parts(env.MicroMenu).backdrop:IsShown(), false, "turning the micro skin off hides the glass")
	assert(K.Widgets.DialogHost():IsShown(), "and offers a reload, since Blizzard's art stays faded")
	noErrors(env, K)
end

-- A client without the micro menu or bag bar runs the module without errors ----------------------------

do
	local env, K = D.New()
	eq(K.Modules.IsRunning("DataBars"), true, "no micro menu or bag bar, no problem")
	noErrors(env, K)
end

print("databars menus ok")
