-- ContextMenus.lua: opt-in native descriptions use pooled material chrome without touching secure or unrelated menus.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local active, fonts = {}, {}
local enabled = false

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function Writable(region)
	if not region or type(region.IsForbidden) ~= "function" or type(region.IsProtected) ~= "function" then
		return false
	end
	local forbidden = region:IsForbidden()
	if IsSecret(forbidden) or forbidden ~= false then
		return false
	end
	local protected = region:IsProtected()
	return not IsSecret(protected) and protected == false
end

local function Wanted()
	return enabled and not InCombatLockdown() and Widgets.Setting("cardMaterial") ~= "Glass"
end

local function CloseMenus()
	local menus = {}
	for menu in pairs(active) do
		menus[#menus + 1] = menu
	end
	for _, menu in ipairs(menus) do
		if active[menu] and Writable(menu) and type(menu.Close) == "function" then
			menu:Close()
		end
	end
end

local function Font(role, text)
	if type(CreateFont) ~= "function" then
		return nil
	end
	local font = fonts[role]
	if not font then
		font = CreateFont("KstyleUIContextMenu" .. role)
		fonts[role] = font
	end
	local path, size, flags = ns.Style.Font(role)
	if font:SetFont(path, Widgets.FontSize(text, size), flags) == false then
		return nil
	end
	font:SetShadowOffset(0, 0)
	return font
end

local function Row(frame, description, menu)
	if not active[menu] or not Wanted() or not Writable(frame) then
		return
	end
	local text, highlight = frame.fontString, frame.highlight
	if text and Writable(text) and type(text.SetFontObject) == "function" and type(text.SetTextToFit) == "function"
		and MenuUtil and type(MenuUtil.GetElementText) == "function" then
		local role = highlight and "body" or "title"
		local label = MenuUtil.GetElementText(description)
		local font = not IsSecret(label) and type(label) == "string" and Font(role, text)
		if font then
			text:SetFontObject(font)
			text:SetTextToFit(label)
			text:SetTextColor(Tokens.Color(highlight and "text" or "textEmphasis"))
			if type(text.GetStringHeight) == "function" then
				local needed, height = text:GetStringHeight(), text:GetHeight()
				if not IsSecret(needed) and not IsSecret(height) and type(needed) == "number" and type(height) == "number" and needed > height then
					text:SetHeight(needed)
				end
			end
		end
	end
	if highlight and Writable(highlight) then
		highlight:SetTexture(nil)
		highlight:SetColorTexture(Widgets.Rgba("white", 0.05))
		highlight:SetBlendMode("BLEND")
	end
end

local function Acquire(menu)
	if not Wanted() or not Writable(menu) or type(menu.AttachTexture) ~= "function" then
		return
	end
	local regions = { menu:GetRegions() }
	if #regions < 1 or #regions > 2 then
		return
	end
	local background, backgroundAtlas
	for _, region in ipairs(regions) do
		if not Writable(region) or type(region.GetAtlas) ~= "function" then
			return
		end
		local atlas = region:GetAtlas()
		if IsSecret(atlas) then
			return
		end
		if atlas == "common-dropdown-bg" or atlas == "common-dropdown-classic-bg" or atlas == "common-dropdown-classic-b-bg" then
			if background then
				return
			end
			background, backgroundAtlas = region, atlas
		elseif atlas ~= nil then
			return
		end
	end
	if not background then
		return
	end
	if (backgroundAtlas == "common-dropdown-bg" and #regions ~= 1) or (backgroundAtlas ~= "common-dropdown-bg" and #regions ~= 2) then
		return
	end
	for _, region in ipairs(regions) do
		if region ~= background then
			if type(region.GetNumPoints) ~= "function" or type(region.GetPoint) ~= "function" then
				return
			end
			local count = region:GetNumPoints()
			if IsSecret(count) or count ~= 2 then
				return
			end
			for i = 1, 2 do
				local _, relative = region:GetPoint(i)
				if IsSecret(relative) or relative ~= background then
					return
				end
			end
		end
	end
	local chrome = Widgets.Chrome(menu, { shape = "card", popup = true })
	active[menu] = chrome
	for _, region in ipairs(regions) do
		region:Hide()
	end
end

local function Modify(owner, root)
	if not Wanted() or not Writable(owner) then
		return
	end
	local mixin = owner.menuMixin
	if IsSecret(mixin) or mixin ~= nil then
		return
	end
	if type(root.AddMenuAcquiredCallback) ~= "function" or type(root.AddMenuReleasedCallback) ~= "function"
		or not MenuUtil or type(MenuUtil.TraverseMenu) ~= "function" then
		return
	end
	root:AddMenuAcquiredCallback(Acquire)
	root:AddMenuReleasedCallback(function(menu)
		if active[menu] then
			active[menu]:Release()
		end
		active[menu] = nil
	end)
	MenuUtil.TraverseMenu(root, function(description)
		if type(description.AddInitializer) == "function" then
			description:AddInitializer(Row)
		end
	end)
end

ns.Skins.Add({
	key = "contextMenus",
	label = K.L["Context menus"],
	help = K.L["Style KstyleUI's tracking, addon and quest menus outside combat. Glass keeps Blizzard's look."],
	sweep = false,
	live = true,
	Apply = function()
		if not Menu or type(Menu.ModifyMenu) ~= "function" then
			K.DevTest.Log("Skins", "Menu.ModifyMenu is missing; context menus keep Blizzard's look")
			return
		end
		enabled = true
		for _, tag in ipairs({ "KSTYLEUI_TRACKING", "KSTYLEUI_COMPARTMENT", "KSTYLEUI_QUEST" }) do
			Menu.ModifyMenu(tag, Modify)
		end
		for _, event in ipairs({ "ThemeChanged", "ScaleChanged", "ProfileChanged" }) do
			K.Callbacks.Register(event, "SkinContextMenus", CloseMenus)
		end
		K.Callbacks.Register("SettingChanged", "SkinContextMenus", function(_, module)
			if module == "Widgets" or module == "Skins" then
				CloseMenus()
			end
		end)
		K.Events.Register("SkinContextMenus", "PLAYER_REGEN_DISABLED", CloseMenus)
	end,
	OnSwitch = function(_, on)
		enabled = on
		CloseMenus()
	end,
})
