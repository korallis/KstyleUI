-- test-skins-contextmenus.lua: KstyleUI's tracking, addon compartment and quest menus wear the card material through Forever's native menu pipeline without a single write to a secure, forbidden or unrelated object.
local E = dofile("Tools/regression/native_menu_env.lua")
local W = E.W

local OPEN = { tracking = E.Tracking, compartment = E.Compartment, quest = E.Quest }
local ORDER = { "tracking", "compartment", "quest" }
local TAGS = { tracking = "KSTYLEUI_TRACKING", compartment = "KSTYLEUI_COMPARTMENT", quest = "KSTYLEUI_QUEST" }
local STYLED = { "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }
local KINDS = { "protected", "forbidden", "secretprotected", "secretforbidden" }

local function NoErrors(env, what)
	assert(#env._errors == 0, what .. ": " .. tostring(env._errors[1]))
end

local function Open(name, env, nm, direct)
	local menu, owner = OPEN[name](env, nm, direct)
	assert(menu and menu.open, name .. " menu opens")
	return menu, owner
end

local function FontName(text)
	local font = text._state.FontObject and text._state.FontObject[1]
	return font and font._name
end

local function Counts(menu)
	local out = {}
	for i, row in ipairs(menu.rows) do
		out[i] = #menu.elements[row].initializers
	end
	return table.concat(out, ",")
end

local function Regions(menu)
	return { menu.frame:GetRegions() }
end

-- Baseline(opts) -> what each generator's menu looks like with the context-menu skin switched off, one environment per call.
local function Baseline(opts)
	opts = opts or {}
	opts.skin = false
	local env, _, _, nm = E.New(opts)
	local out = {}
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		out[name] = { snapshot = nm.Snapshot(menu), counts = Counts(menu), regions = #Regions(menu) }
		nm.Close(menu)
	end
	NoErrors(env, "baseline")
	assert(next(nm.registry) == nil, "with the skin off nothing is registered with Menu.ModifyMenu")
	return out
end

local BASE = Baseline()

local function SameAsBase(name, menu, nm, what)
	assert(nm.Snapshot(menu) == BASE[name].snapshot, name .. ": " .. what .. " leaves the native menu exactly as Blizzard draws it")
	assert(Counts(menu) == BASE[name].counts, name .. ": " .. what .. " adds no initializer")
	assert(#menu.description.acquired == 0, name .. ": " .. what .. " adds no menu-acquired callback")
end

-- What is registered: three tags, no hook, no replacement ----------------------------------------------------------------

do
	local env, K, _, nm = E.New({ material = "Flat" })
	local tags = {}
	for tag, callbacks in pairs(nm.registry) do
		tags[#tags + 1] = tag
		assert(#callbacks == 1, tag .. " has one callback, got " .. #callbacks)
	end
	table.sort(tags)
	assert(table.concat(tags, ",") == "KSTYLEUI_COMPARTMENT,KSTYLEUI_QUEST,KSTYLEUI_TRACKING", "only KstyleUI's three tags: " .. table.concat(tags, ","))
	for _, name in ipairs(ORDER) do
		local menu, owner = Open(name, env, nm)
		assert(menu.description.tag == TAGS[name], name .. "'s generator sets its own tag")
		assert(rawget(owner, "menuMixin") == nil and owner.menuMixin == nil, name .. ": the owner's menuMixin is never written")
		nm.Close(menu)
	end
	local o = nm.original
	assert(env.Menu == o.Menu and env.MenuUtil == o.MenuUtil, "Menu and MenuUtil are the native tables")
	assert(env.MenuUtil.CreateContextMenu == o.CreateContextMenu and env.MenuUtil.TraverseMenu == o.TraverseMenu, "MenuUtil's functions are the native ones")
	assert(env.Menu.PopulateDescription == o.PopulateDescription and env.Menu.ModifyMenu == o.ModifyMenu and env.Menu.GetManager == o.GetManager, "Menu's functions are the native ones")
	K.Options.Write("Skins", "contextMenus.enabled", false)
	K.Options.Write("Skins", "contextMenus.enabled", true)
	for tag, callbacks in pairs(nm.registry) do
		assert(#callbacks == 1, tag .. " is not registered again when the skin switches off and on")
	end
	NoErrors(env, "registration")
end

do
	local env, _, _, nm = E.New({ skins = false })
	assert(next(nm.registry) == nil, "with the Skins module off the minimap menus register nothing")
	for _, name in ipairs({ "tracking", "compartment" }) do
		local menu = Open(name, env, nm)
		SameAsBase(name, menu, nm, "the Skins module off")
		nm.Close(menu)
	end
	NoErrors(env, "module off")
end

-- Glass, a switched-off skin and combat change nothing --------------------------------------------------------------------

do
	local env, K, _, nm = E.New({ material = "Glass" })
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		SameAsBase(name, menu, nm, "Glass")
		nm.Close(menu)
	end
	K.Options.Write("Widgets", "cardMaterial", "Slate")
	local styled = Open("tracking", env, nm)
	assert(nm.Snapshot(styled) ~= BASE.tracking.snapshot, "Slate does change the menu")
	nm.Close(styled)
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		SameAsBase(name, menu, nm, "going back to Glass")
		nm.Close(menu)
	end
	NoErrors(env, "glass")
end

do
	local env, K, _, nm = E.New({ material = "ForgedBrackets", skin = false })
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		SameAsBase(name, menu, nm, "the skin switched off in the saved data")
		nm.Close(menu)
	end
	K.Options.Write("Skins", "contextMenus.enabled", true)
	local menu = Open("tracking", env, nm)
	assert(nm.Snapshot(menu) ~= BASE.tracking.snapshot, "switching it on styles the next menu without a reload")
	nm.Close(menu)
	K.Options.Write("Skins", "contextMenus.enabled", false)
	for _, name in ipairs(ORDER) do
		local reopened = Open(name, env, nm)
		SameAsBase(name, reopened, nm, "switching the skin off again")
		nm.Close(reopened)
	end
	NoErrors(env, "switch")
end

do
	local env, _, _, nm = E.New({ material = "Slate" })
	env.SetCombat(true)
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		SameAsBase(name, menu, nm, "combat")
		nm.Close(menu)
	end
	env.SetCombat(false)
	local menu = Open("tracking", env, nm)
	assert(nm.Snapshot(menu) ~= BASE.tracking.snapshot, "the first menu after combat is styled again")
	nm.Close(menu)
	NoErrors(env, "combat")
end

-- Each material, each generator ---------------------------------------------------------------------------------------------

local function CheckStyled(name, menu, env, K, ns, nm, material)
	local what = name .. " in " .. material
	local regions = Regions(menu)
	assert(#regions > 2, what .. ": the chrome attached to the menu")
	assert(regions[1]:GetAtlas() == "common-dropdown-bg" and not regions[1]:IsShown(), what .. ": the native background is hidden, not replaced")
	local fills, textures = 0, 0
	for i = 2, #regions do
		local region = regions[i]
		assert(nm.pooled[region] == "Texture" and region:GetParent() == menu.frame, what .. ": every chrome texture is a pooled attachment of the menu")
		local layer, sub = region:GetDrawLayer()
		if region:IsShown() then
			textures = textures + 1
		end
		if region:IsShown() and layer == "BACKGROUND" and sub == -7 then
			fills = fills + 1
			assert(select(4, region:GetVertexColor()) == 1, what .. ": the fill is opaque")
		end
	end
	assert(textures > 9 and fills == 9, what .. ": a nine-piece fill and a rim, got " .. fills .. " of " .. textures)
	assert(menu.frame._scripts.OnSizeChanged ~= nil, what .. ": the chrome follows the menu's size through a script")
	local body, title = ns.Style.Font("body"), ns.Style.Font("title")
	local seen = 0
	for index, row in ipairs(menu.rows) do
		local description = menu.elements[row]
		local text, highlight = row.fontString, row.highlight
		if description.kind == "divider" then
			assert(row.divider._state.Texture[1] == "Interface\\Common\\UI-TooltipDivider-Transparent", what .. ": a divider keeps Blizzard's texture")
		else
			seen = seen + 1
			local role, token = highlight and "body" or "title", highlight and "text" or "textEmphasis"
			local font = env["KstyleUIContextMenu" .. role]
			assert(text._state.FontObject[1] == font and font:GetFont() == (highlight and body or title), what .. ": row " .. index .. " wears the " .. role .. " face")
			local r, g, b = K.Tokens.Color(token)
			local tr, tg, tb = text:GetTextColor()
			assert(W.Near(tr, r) and W.Near(tg, g) and W.Near(tb, b), what .. ": row " .. index .. " wears the " .. token .. " colour")
			if highlight then
				assert(text.autoEnableTextColors, what .. ": the native final initializer still ran after the skin")
				local er, eg, eb = unpack(text.autoEnableTextColors[true])
				assert(W.Near(er, r) and W.Near(eg, g) and W.Near(eb, b), what .. ": the native enabled colour is the skin's colour")
				assert(text.autoEnableTextColors[false][1] == 0.5, what .. ": the native disabled colour is Blizzard's grey")
			else
				assert(text.autoEnableTextColors == nil, what .. ": a title has no final initializer")
			end
			assert(text:GetHeight() + 0.01 >= text:GetStringHeight() and row:GetHeight() + 0.5 >= text:GetHeight(), what .. ": row " .. index .. " is as tall as its text: row " .. row:GetHeight() .. ", text " .. text:GetHeight() .. " for " .. text:GetStringHeight())
			local lead = row.leftTexture1 and row.leftTexture1:GetWidth() + 7 or 0
			assert(not text:IsTruncated() and text:GetWidth() + 0.01 >= text:GetUnboundedStringWidth(), what .. ": row " .. index .. " (" .. tostring(text:GetText()) .. ") is refitted to the kit face: " .. tostring(text:GetWidth()) .. " for " .. tostring(text:GetUnboundedStringWidth()))
			assert(row:GetWidth() + 0.5 >= lead + text:GetWidth() and menu.frame:GetWidth() + 0.01 >= row:GetWidth() + 16, what .. ": row " .. index .. " and the menu are as wide as the text: row " .. row:GetWidth() .. ", lead " .. lead .. ", text " .. text:GetWidth() .. ", menu " .. menu.frame:GetWidth())
		end
		if highlight then
			local c = highlight._state.ColorTexture
			assert(c and c[1] == 1 and c[2] == 1 and c[3] == 1 and W.Near(c[4], 0.05), what .. ": the highlight is a faint white wash")
			assert(highlight._state.BlendMode[1] == "BLEND" and highlight._state.Texture[1] == nil, what .. ": drawn as a plain blend, not Blizzard's additive art")
			assert(not highlight:IsShown() and highlight:GetDrawLayer() == "BACKGROUND", what .. ": hidden at rest, on the native layer")
		end
		if row.leftTexture1 then
			assert(row.leftTexture1._state.Atlas[1] == "common-dropdown-ticksquare", what .. ": the tick box keeps its atlas")
		end
	end
	assert(seen >= 2, what .. ": text rows were checked")
end

do
	local env, K, ns, nm = E.New({ material = "Flat" })
	local seen = {}
	for _, material in ipairs(STYLED) do
		K.Options.Write("Widgets", "cardMaterial", material)
		for _, name in ipairs(ORDER) do
			local menu = Open(name, env, nm)
			CheckStyled(name, menu, env, K, ns, nm, material)
			local snapshot = nm.Snapshot(menu)
			assert(snapshot ~= BASE[name].snapshot, name .. " in " .. material .. " differs from Blizzard's")
			seen[name] = seen[name] or {}
			for other, previous in pairs(seen[name]) do
				assert(snapshot ~= previous, name .. ": " .. material .. " and " .. other .. " look the same")
			end
			seen[name][material] = snapshot
			assert(Counts(menu) ~= BASE[name].counts, name .. " in " .. material .. ": one initializer is added to each element")
			nm.Close(menu)
		end
	end
	NoErrors(env, "materials")
end

-- Wider faces and larger sizes: the label is refitted after the face changes, so no row clips and the menu grows -----------------

do
	local env, K, ns, nm = E.New({ material = "Slate" })
	local default = {}
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		default[name] = menu.frame:GetWidth()
		nm.Close(menu)
	end
	local grew, taller = 0, 0
	for _, face in ipairs({ "CinzelSemiBold", "InterSemiBold", "AlegreyaSansBold", "SourceSans3Semibold" }) do
		for _, size in ipairs({ 0.8, 1, 1.5 }) do
			K.Options.Write("Skins", "text.font", K.Tokens.FontPath(face))
			K.Options.Write("Skins", "text.size", size)
			for _, name in ipairs(ORDER) do
				local menu = Open(name, env, nm)
				CheckStyled(name, menu, env, K, ns, nm, face .. " at " .. size)
				if size == 1.5 and menu.frame:GetWidth() > default[name] then
					grew = grew + 1
				end
				if size == 1.5 and menu.rows[2]:GetHeight() > 20 then
					taller = taller + 1
				end
				nm.Close(menu)
			end
		end
	end
	assert(grew >= 6, "a larger size makes the menus wider, got " .. grew)
	assert(taller >= 6, "and the rows taller than Blizzard's 20, got " .. taller)
	NoErrors(env, "faces")
end

-- Row initializer order, the native final initializer, hover, disabled rows, actions, refresh --------------------------

do
	local env, K, _, nm = E.New({ material = "Slate" })
	local probe = {}
	env.Menu.ModifyMenu(TAGS.tracking, function(_, root)
		root:AddMenuAcquiredCallback(function(frame)
			probe.regions = #{ frame:GetRegions() }
			probe.rows = #nm.menus[frame].rows
		end)
		env.MenuUtil.TraverseMenu(root, function(description)
			if description.text == "Uncheck all" then
				description:SetEnabled(false)
			end
		end)
	end)
	local menu = Open("tracking", env, nm)
	assert(probe.regions > 2 and probe.rows == 0, "the chrome is attached before any row exists")
	local events = table.concat(nm.events, " ")
	assert(events:find("generate acquired init", 1, true), "background, then acquired callbacks, then initializers")
	local rows = menu.rows
	local repair, herbs, clear = rows[2], rows[3], rows[5]
	local body = K.Tokens.Color("text")

	W.Enter(repair)
	assert(repair.highlight:IsShown() and repair.highlight:GetAlpha() == 1, "the native OnEnter shows the highlight")
	W.Leave(repair)
	assert(not repair.highlight:IsShown(), "the native OnLeave hides it")

	assert(not clear:IsEnabled(), "the disabled row stays disabled")
	local grey = clear.fontString:GetTextColor()
	assert(grey == 0.5, "a disabled row's text takes Blizzard's grey, got " .. tostring(grey))
	W.Enter(clear)
	assert(clear.highlight:IsShown() and W.Near(clear.highlight:GetAlpha(), 0.4), "a disabled row still lights at Blizzard's 0.4")
	W.Leave(clear)
	local ran = 0
	menu.elements[clear].responder = function()
		ran = ran + 1
	end
	W.Click(clear)
	assert(ran == 0 and menu.open, "a disabled row does not act")
	clear:SetEnabled(true)
	local r = clear.fontString:GetTextColor()
	assert(W.Near(r, body), "enabling it again restores the skin's colour, not white")

	local before = #Regions(menu)
	local box = herbs.leftTexture2
	assert(box ~= nil, "Find Herbs is ticked")
	W.Click(repair)
	assert(env._tracking[2].active == true, "the checkbox's own action ran")
	assert(menu.open, "and the menu refreshed instead of closing")
	assert(#Regions(menu) == before, "refreshing neither adds nor drops chrome")
	assert(repair.leftTexture2 ~= nil and repair.fontString._state.FontObject[1] == env.KstyleUIContextMenubody, "the refreshed row is ticked and wears the kit face again")
	local tr = repair.fontString:GetTextColor()
	assert(W.Near(tr, body), "with its colour")
	assert(repair.fontString.autoEnableTextColors[false][1] == 0.5, "and the native colour cache was rebuilt")

	local clearRow = menu.rows[5]
	menu.elements[clearRow].enabled = true
	clearRow:SetEnabled(true)
	local cleared = false
	menu.elements[clearRow].responder = function()
		cleared = true
	end
	W.Click(clearRow)
	assert(cleared and not menu.open, "a button runs its action and closes the menu")
	NoErrors(env, "tracking actions")
end

do
	local env, _, _, nm = E.New({ material = "ForgedTicks" })
	local ran = {}
	env.AddonCompartmentFrame.registeredAddons = { { text = "Zeta", func = function() ran.Zeta = true end }, { text = "echo", func = function() ran.echo = true end } }
	local menu = Open("compartment", env, nm)
	W.Click(menu.rows[3])
	assert(ran.Zeta or ran.echo, "a compartment entry's action runs")
	assert(not menu.open, "and closes the menu")
	local quest = Open("quest", env, nm)
	local log = env._quests
	W.Click(quest.rows[3])
	assert(#log.Called("OpenToQuestDetails") == 1 and not quest.open, "the quest menu's native action runs through the styled row")
	NoErrors(env, "actions")
end

-- Protected, forbidden and secret objects get no write ----------------------------------------------------------------------

do
	local env, _, _, nm = E.New({ material = "Flat" })
	for _, kind in ipairs(KINDS) do
		for _, name in ipairs(ORDER) do
			local _, owner = Open(name, env, nm)
			nm.Close(nm.last)
			local setPoint = rawget(owner, "SetPoint")
			nm.Guard(owner, kind, "the owner")
			local menu = Open(name, env, nm, true)
			SameAsBase(name, menu, nm, "a " .. kind .. " owner")
			nm.Close(menu)
			assert(rawget(owner, "SetPoint") == setPoint, "the guard was lifted on close")

			nm.hooks.generated = function(_, frame)
				nm.Guard(frame, kind, "the menu")
			end
			menu = Open(name, env, nm)
			nm.hooks.generated = nil
			assert(nm.Snapshot(menu) == BASE[name].snapshot, name .. ": a " .. kind .. " menu keeps every native texture and font")
			nm.Close(menu)

			nm.hooks.generated = function(_, frame)
				nm.Guard(({ frame:GetRegions() })[1], kind, "the background")
			end
			menu = Open(name, env, nm)
			nm.hooks.generated = nil
			assert(nm.Snapshot(menu) == BASE[name].snapshot, name .. ": a " .. kind .. " background is not hidden, and the menu is not styled")
			nm.Close(menu)
		end
	end
	nm.hooks.generated = function(_, frame)
		nm.Guard(({ frame:GetRegions() })[1], "trap", "the background", {
			GetAtlas = function()
				return env.Secret("common-dropdown-bg")
			end,
		})
	end
	for _, name in ipairs(ORDER) do
		local menu = Open(name, env, nm)
		assert(nm.Snapshot(menu) == BASE[name].snapshot, name .. ": a secret atlas is not compared and nothing is written")
		nm.Close(menu)
	end
	nm.hooks.generated = nil
	NoErrors(env, "guards")
end

do
	local env, _, _, nm = E.New({ material = "Flat" })
	local probe = {}
	for _, tag in ipairs({ TAGS.tracking, TAGS.compartment }) do
		env.Menu.ModifyMenu(tag, function(_, root)
			env.MenuUtil.TraverseMenu(root, function(description)
				if description.kind == "button" or description.kind == "checkbox" then
					description:AddInitializer(function(frame)
						if probe.target then
							nm.Guard(probe.target == "row" and frame or frame[probe.target], probe.kind, "the " .. probe.target)
						end
					end, #description.initializers)
				end
			end)
		end)
	end
	for _, kind in ipairs(KINDS) do
		for _, target in ipairs({ "row", "fontString", "highlight" }) do
			probe.target, probe.kind = target, kind
			local menu = Open("tracking", env, nm)
			probe.target = nil
			local row = menu.rows[2]
			local what = "a " .. kind .. " " .. target
			if target == "row" or target == "fontString" then
				assert(FontName(row.fontString) == "GameFontHighlight" and row.fontString:GetTextColor() == 1, what .. ": the text keeps Blizzard's face and white")
			else
				assert(row.fontString._state.FontObject[1] == env.KstyleUIContextMenubody, what .. ": the text is still styled")
			end
			if target == "row" or target == "highlight" then
				assert(row.highlight._state.BlendMode[1] == "ADD" and row.highlight._state.ColorTexture == nil and row.highlight._state.Texture[1] ~= nil, what .. ": the highlight keeps Blizzard's additive art")
			else
				assert(row.highlight._state.ColorTexture ~= nil and row.highlight._state.BlendMode[1] == "BLEND", what .. ": the highlight is still styled")
			end
			assert(#Regions(menu) > 2 and menu.rows[1].fontString._state.FontObject[1] == env.KstyleUIContextMenutitle, what .. ": the rest of the menu is styled")
			nm.Close(menu)
		end
	end
	NoErrors(env, "row guards")
end

-- A secret label or a secret string height is never compared or formatted --------------------------------------------------------

do
	local env, _, _, nm = E.New({ material = "Slate" })
	local util = env.MenuUtil
	local getText = util.GetElementText
	util.GetElementText = function()
		return env.Secret("Secret label")
	end
	local menu = Open("tracking", env, nm)
	util.GetElementText = getText
	assert(#Regions(menu) > 2, "the menu is still styled")
	local row = menu.rows[2]
	assert(FontName(row.fontString) == "GameFontHighlight" and row.fontString:GetTextColor() == 1, "a row whose label is secret keeps Blizzard's face: it cannot be refitted")
	assert(row.highlight._state.BlendMode[1] == "BLEND", "its highlight is still styled")
	nm.Close(menu)

	util.GetElementText = function()
		return 42
	end
	menu = Open("tracking", env, nm)
	util.GetElementText = getText
	assert(FontName(menu.rows[2].fontString) == "GameFontHighlight", "a label that is not a string is left alone")
	nm.Close(menu)

	env.Menu.ModifyMenu(TAGS.tracking, function(_, root)
		env.MenuUtil.TraverseMenu(root, function(description)
			description:AddInitializer(function(frame)
				if frame.fontString then
					rawset(frame.fontString, "GetStringHeight", function()
						return env.Secret(40)
					end)
				end
			end, #description.initializers)
		end)
	end)
	menu = Open("tracking", env, nm)
	for _, candidate in ipairs(menu.rows) do
		if candidate.fontString then
			rawset(candidate.fontString, "GetStringHeight", nil)
		end
	end
	assert(FontName(menu.rows[2].fontString) == "KstyleUIContextMenubody" and menu.rows[2].fontString:GetHeight() == 20, "a secret string height is not compared: the row is styled and keeps Blizzard's height")
	nm.Close(menu)
	NoErrors(env, "secret text")
end

-- A background that is not one of Blizzard's two patterns is left alone ------------------------------------------------------

do
	local env, _, _, nm = E.New({ material = "Slate", variant = "classic" })
	local menu = Open("tracking", env, nm)
	local regions = Regions(menu)
	assert(#regions > 3 and not regions[1]:IsShown() and not regions[2]:IsShown(), "the classic style's atlas and its inner black fill are both hidden")
	assert(regions[1]:GetAtlas() == "common-dropdown-classic-bg" and regions[2]:GetAtlas() == nil, "they are the two native textures")
	nm.Close(menu)
	NoErrors(env, "classic")
end

for _, variant in ipairs({ "unknown", "foreign", "twobackgrounds", "threeregions" }) do
	local base = Baseline({ variant = variant }).tracking
	local env, _, _, nm = E.New({ material = "Slate", variant = variant })
	local menu = Open("tracking", env, nm)
	assert(nm.Snapshot(menu) == base.snapshot, variant .. " background: the menu keeps Blizzard's look")
	assert(#Regions(menu) == base.regions, variant .. " background: no chrome")
	nm.Close(menu)
	NoErrors(env, variant)
end

-- Pooled regions come back clean, and nothing restyles them ----------------------------------------------------------------

do
	local env, K, _, nm = E.New({ material = "Flat" })
	local styled = Open("tracking", env, nm)
	local used = {}
	for _, region in ipairs(Regions(styled)) do
		used[#used + 1] = region
	end
	for _, row in ipairs(styled.rows) do
		for _, region in ipairs({ row:GetRegions() }) do
			used[#used + 1] = region
		end
	end
	local frame = styled.frame
	nm.Close(styled)
	for _, region in ipairs(used) do
		assert(next(region._state) == nil and next(region._scripts) == nil and next(region._points) == nil, "a released region is reset")
		assert(not region:IsShown(), "and hidden")
		assert(getmetatable(region) == getmetatable(env.UIParent), "the compositor gave back the original metatable")
	end
	assert(next(frame._scripts) == nil, "the fixture resets the menu frame's scripts, as it assumes the pool does; the test below does not rely on it")
	assert(getmetatable(frame) == getmetatable(env.UIParent), "and its metatable is the original")

	local owner = E.Minimap(env).Map.column.buttons.tracking
	local plain = env.MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Plain")
		root:CreateButton("Open", function() end)
	end)
	assert(plain.frame == frame, "the pool hands the same menu frame to the next menu")
	local reused, mine = 0, {}
	for _, region in ipairs(used) do
		mine[region] = true
	end
	for _, region in ipairs(Regions(plain)) do
		reused = reused + (mine[region] and 1 or 0)
	end
	for _, row in ipairs(plain.rows) do
		for _, region in ipairs({ row:GetRegions() }) do
			reused = reused + (mine[region] and 1 or 0)
		end
	end
	assert(reused >= 3, "an untagged menu reuses the styled menu's pooled regions, got " .. reused)
	local before, calls = nm.Snapshot(plain), {}
	for _, region in ipairs(used) do
		calls[region] = #region._calls
	end
	K.Widgets.RestyleAll()
	K.Options.Write("Widgets", "cardMaterial", "Slate")
	K.Options.Write("Widgets", "panelOpacity", 0.8)
	K.Callbacks.Fire("ThemeChanged")
	K.Callbacks.Fire("ScaleChanged")
	env.RunTimers()
	W.Settle(env)
	assert(plain.open, "a material change does not close a native menu that took the styled menu's frame")
	assert(nm.Snapshot(plain) == before, "RestyleAll and every setting change leave the reused regions as Blizzard set them")
	frame:SetSize(333, 222)
	assert(not nm.Snapshot(plain):find("MaterialSlate", 1, true), "a size change reaches no stale chrome")
	for _, region in ipairs(used) do
		assert(#region._calls == calls[region], "no call reached a pooled region")
	end
	nm.Close(plain)
	NoErrors(env, "pooling")
end

do
	local env, K, _, nm = E.New({ material = "Slate" })
	local menu = Open("tracking", env, nm)
	local first = nm.Snapshot(menu)
	K.Options.Write("Widgets", "cardMaterial", "ForgedBrackets")
	assert(not menu.open, "a material change closes the styled menu")
	menu = Open("tracking", env, nm)
	assert(nm.Snapshot(menu) ~= first, "and the next one wears the new material")
	for _, change in ipairs({
		function() K.Callbacks.Fire("ThemeChanged") end,
		function() K.Callbacks.Fire("ScaleChanged") end,
		function() K.Callbacks.Fire("ProfileChanged") end,
		function() K.Options.Write("Skins", "contextMenus.enabled", false) end,
	}) do
		if not menu.open then
			K.Options.Write("Skins", "contextMenus.enabled", true)
			menu = Open("tracking", env, nm)
		end
		change()
		assert(not menu.open, "every theme, scale, profile and skin change closes the styled menu")
	end
	NoErrors(env, "closing")
end

-- Combat starting closes the styled menus and nothing else ----------------------------------------------------------------------

do
	for _, name in ipairs(ORDER) do
		local env, _, _, nm = E.New({ material = "Slate" })
		local menu, owner = Open(name, env, nm)
		local native = env.MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateButton("Unrelated", function() end)
		end)
		local chrome = #Regions(menu)
		assert(chrome > 2 and native.open, name .. ": a styled menu and an unrelated native one are open")
		env.SetCombat(true)
		assert(not menu.open, name .. ": the styled menu closes when combat starts")
		assert(native.open, name .. ": an unrelated native menu is left alone")
		assert(#Regions(menu) == 0, name .. ": its chrome went back to the pool")
		nm.Close(native)
		env.SetCombat(false)
		NoErrors(env, name .. " combat start")
	end
end

-- The Chrome change in Core/Widgets/Base.lua ------------------------------------------------------------------------------------

do
	local env, K, _, nm = E.New({ material = "Flat" })
	local function Spy(chrome)
		local count = { n = 0 }
		local restyle = chrome.Restyle
		chrome.Restyle = function(...)
			count.n = count.n + 1
			return restyle(...)
		end
		return count
	end
	local plain = env.CreateFrame("Frame", nil, env.UIParent)
	plain:SetSize(100, 60)
	local chrome = K.Widgets.Chrome(plain, { shape = "card", popup = true })
	local plainCalls = Spy(chrome)
	K.Widgets.RestyleAll()
	assert(plainCalls.n == 1, "an ordinary frame's chrome is still restyled by RestyleAll")

	local menu = env.MenuUtil.CreateContextMenu(E.Minimap(env).Map.column.buttons.tracking, function(_, root)
		root:CreateButton("Plain", function() end)
	end)
	local owned = K.Widgets.Chrome(menu.frame, { shape = "card", popup = true })
	assert(rawget(owned, "owner") == menu.frame or owned.owner == menu.frame, "chrome on a compositor frame")
	local before = #Regions(menu)
	local ownedCalls = Spy(owned)
	K.Widgets.RestyleAll()
	assert(ownedCalls.n == 0, "a compositor owner's chrome never joins the restyle registry")
	assert(not pcall(function() menu.frame:CreateTexture(nil, "BACKGROUND") end), "a raw CreateTexture on the menu raises, as the compositor does")
	menu.frame:SetSize(180, 120)
	menu.frame:SetSize(181, 121)
	assert(#Regions(menu) >= before, "its textures all came from AttachTexture, including the ones a resize makes")
	nm.Close(menu)
	NoErrors(env, "chrome")
end

-- The fixture holds the compositor's rules -----------------------------------------------------------------------------------------

do
	local env, _, _, nm = E.New({ material = "Flat" })
	local menu = Open("compartment", env, nm)
	local row = menu.rows[2]
	assert(not pcall(function() return row.CreateFontString(row, nil, "OVERLAY") end), "CreateFontString on a menu element raises")
	assert(not pcall(function() return row.CreateTexture(row) end), "CreateTexture on a menu element raises")
	assert(not pcall(function() row.fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end), "SetFont on a compositor font string raises")
	assert(pcall(function() row.fontString:SetFontObject(env.GameFontHighlight) end), "SetFontObject is allowed")
	nm.Close(menu)
	NoErrors(env, "fixture")
end

-- A width that was not refitted is caught: the fixture keeps the fitted width when only the face changes ---------------------------

do
	local env, K, ns, nm = E.New({ material = "Slate" })
	K.Options.Write("Skins", "text.font", K.Tokens.FontPath("CinzelSemiBold"))
	K.Options.Write("Skins", "text.size", 1.5)
	nm.staleFit = true
	local menu = Open("tracking", env, nm)
	local ok, err = pcall(CheckStyled, "tracking", menu, env, K, ns, nm, "stale")
	assert(not ok and tostring(err):find("refitted", 1, true), "a label left at its native width fails the check: " .. tostring(err))
	assert(menu.rows[2].fontString:GetWidth() < menu.rows[2].fontString:GetUnboundedStringWidth(), "and the fixture really left it too narrow")
	nm.Close(menu)
	nm.staleFit = false
	menu = Open("tracking", env, nm)
	CheckStyled("tracking", menu, env, K, ns, nm, "refitted")
	nm.Close(menu)
	NoErrors(env, "stale width")
end

-- Submenus a third-party addon adds to a KstyleUI menu --------------------------------------------------------------------------

do
	local hit = 0
	local function More(_, root)
		local more = root:CreateButton("More options", nil)
		more:CreateButton("Deeper choice", function()
			hit = hit + 1
		end)
		more:CreateButton("Another deeper choice", function()
			hit = hit + 1
		end)
	end
	local env, K, ns, nm = E.New({ material = "Slate", modify = { KSTYLEUI_TRACKING = More } })

	local function Parent()
		local menu = Open("tracking", env, nm)
		local row
		for _, candidate in ipairs(menu.rows) do
			if menu.elements[candidate]:CanOpenSubmenu() then
				row = candidate
			end
		end
		assert(row, "the added submenu row is there")
		return menu, row
	end

	local parent, row = Parent()
	W.Click(row)
	local child = parent.child
	assert(child and child.open and child.parent == parent and child.frame ~= parent.frame, "a click opens the submenu as a second menu")
	CheckStyled("tracking", parent, env, K, ns, nm, "Slate with a submenu open")
	CheckStyled("tracking submenu", child, env, K, ns, nm, "Slate")
	assert(#child.shared.acquired == #parent.shared.acquired and child.shared == parent.shared, "the child shares the root's callbacks, so it is styled by the same skin")

	nm.Close(parent)
	assert(not parent.open and not child.open and parent.child == nil, "closing the parent closes the submenu first")
	assert(nm.staleCloses == 0, "and nothing closed a menu twice")

	parent, row = Parent()
	W.Click(row)
	W.Click(parent.child.rows[1])
	assert(hit == 1 and not parent.open and not parent.child, "a leaf answered in the submenu runs and closes every menu")
	CheckStyled("tracking", Parent(), env, K, ns, nm, "Slate again on the pooled frames")
	nm.Close(nm.last)

	parent, row = Parent()
	W.Click(row)
	child = parent.child
	K.Options.Write("Widgets", "cardMaterial", "Flat")
	assert(not parent.open and not child.open, "a material change closes the parent and the submenu")
	assert(nm.staleCloses == 0, "the submenu was not asked to close again after its parent had released it: " .. nm.staleCloses)
	K.Options.Write("Widgets", "cardMaterial", "Slate")

	parent, row = Parent()
	W.Click(row)
	child = parent.child
	env.SetCombat(true)
	assert(not parent.open and not child.open, "entering combat closes the parent and the submenu")
	assert(nm.staleCloses == 0, "once each")
	env.SetCombat(false)
	NoErrors(env, "submenus")
end

-- A pooled menu frame that wore the card is later a native menu: nothing asks it to close ---------------------------------------

do
	local env, K, ns, nm = E.New({ material = "Slate" })
	local styled = Open("compartment", env, nm)
	local frame = styled.frame
	nm.Close(styled)
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	local plain = Open("compartment", env, nm)
	assert(plain.frame == frame, "the pool handed the same frame to the next menu")
	SameAsBase("compartment", plain, nm, "a pooled frame that wore the card")
	assert(#Regions(plain) == BASE.compartment.regions, "no chrome stayed on it")
	K.Options.Write("Widgets", "cardMaterial", "Flat")
	K.Options.Write("Skins", "text.size", 1.2)
	K.Callbacks.Fire("ThemeChanged")
	assert(plain.open and nm.staleCloses == 0, "a restyle does not close a native menu on a frame that used to be styled")
	nm.Close(plain)
	local again = Open("compartment", env, nm)
	assert(again.frame == frame, "and the frame is styled again when the material is back")
	CheckStyled("compartment", again, env, K, ns, nm, "Flat on the reused frame")
	nm.Close(again)
	NoErrors(env, "pooled frame")
end

-- A chrome that outlives its menu is inert: the callbacks it left behind reach no pooled region ----------------------------------

do
	local env, K, _, nm = E.New({ material = "Slate" })
	local made, queued, starve = {}, {}, false
	local chrome, mayMove, queue = K.Widgets.Chrome, K.Widgets.MayMove, K.Combat.Queue
	K.Widgets.Chrome = function(...)
		local c = chrome(...)
		made[#made + 1] = c
		return c
	end
	K.Widgets.MayMove = function(...)
		return not starve and mayMove(...)
	end
	K.Combat.Queue = function(fn)
		if starve then
			queued[#queued + 1] = fn
			return
		end
		queue(fn)
	end
	starve = true
	local styled = Open("tracking", env, nm)
	starve = false
	assert(#made == 1 and #queued >= 1, "the menu made one chrome and its layout and material work waits in the queue, got " .. #made .. " and " .. #queued)
	local owned, sizeChanged, frame = made[1], styled.frame._scripts.OnSizeChanged, styled.frame
	assert(type(sizeChanged) == "function" and not owned.released, "the size callback is captured while the menu is open")
	local used = {}
	for _, region in ipairs(Regions(styled)) do
		used[#used + 1] = region
	end
	nm.Close(styled)
	assert(owned.released == true, "releasing the menu releases its chrome")

	K.Options.Write("Widgets", "cardMaterial", "Glass")
	local plain = Open("tracking", env, nm)
	assert(plain.frame == frame, "the pool hands the same menu frame to a native menu")
	local before, calls, mine = nm.Snapshot(plain), {}, {}
	for _, region in ipairs(used) do
		mine[region] = true
	end
	for _, region in ipairs(Regions(plain)) do
		calls[region] = #region._calls
		mine[region] = true
	end
	for region in pairs(mine) do
		calls[region] = #region._calls
	end
	local created = nm.created.Texture
	for _, call in ipairs({
		function() sizeChanged(frame, 300, 200) end,
		function() owned:OnSizeChanged() end,
		function() owned:Restyle() end,
		function() owned:PaintMaterial() end,
	}) do
		local ok, err = pcall(call)
		assert(ok, "a released chrome callback must be inert, not raise: " .. tostring(err))
	end
	for _, fn in ipairs(queued) do
		fn()
	end
	assert(nm.created.Texture == created, "no texture was made")
	for region in pairs(mine) do
		assert(#region._calls == calls[region], "no call reached a pooled region the chrome once owned")
	end
	assert(nm.Snapshot(plain) == before, "the native menu on the reused frame is exactly as Blizzard drew it")
	frame:SetSize(333, 222)
	for region in pairs(mine) do
		assert(#region._calls == calls[region], "a resize reaches no region the chrome once owned")
	end
	K.Widgets.Chrome, K.Widgets.MayMove, K.Combat.Queue = chrome, mayMove, queue
	nm.Close(plain)
	NoErrors(env, "stale chrome")
end

-- A chrome that cannot be made leaves the native menu alone -------------------------------------------------------------------

do
	local env, K, ns, nm = E.New({ material = "Slate" })
	local chrome = K.Widgets.Chrome
	K.Widgets.Chrome = function()
		error("no chrome today")
	end
	local ok = pcall(OPEN.tracking, env, nm, true)
	K.Widgets.Chrome = chrome
	assert(not ok, "the failure surfaces to the engine's callback loop, as an error in an acquired callback does")
	local menu
	for _, candidate in pairs(nm.menus) do
		menu = candidate
	end
	assert(menu and #Regions(menu) == 1 and Regions(menu)[1]:IsShown(), "the native background is still there and still shown")
	assert(Regions(menu)[1]:GetAtlas() == "common-dropdown-bg", "and still Blizzard's")
	nm.Close(menu)

	local attach, attached, failAt
	nm.hooks.generated = function(_, frame)
		attach, attached = frame.AttachTexture, 0
		rawset(frame, "AttachTexture", function(...)
			attached = attached + 1
			if attached == failAt then
				error("no texture today")
			end
			return attach(...)
		end)
	end
	local total
	K.Widgets.Chrome = function(...)
		local c = chrome(...)
		total = attached
		return c
	end
	menu = Open("tracking", env, nm, true)
	K.Widgets.Chrome = chrome
	rawset(menu.frame, "AttachTexture", nil)
	nm.Close(menu)
	assert(total > 12, "the chrome attaches its textures to the menu frame while it is made, got " .. tostring(total))
	failAt = total
	ok = pcall(OPEN.tracking, env, nm, true)
	nm.hooks.generated = nil
	assert(not ok and attached == total, "a chrome whose last texture fails while it is made stops there, after " .. tostring(attached) .. " of " .. total)
	menu = nil
	for _, candidate in pairs(nm.menus) do
		menu = candidate
	end
	assert(menu and menu.frame._scripts.OnSizeChanged == nil, "no size hook survives a chrome that never finished its first draw")
	assert(Regions(menu)[1]:IsShown(), "the native background is still shown")
	rawset(menu.frame, "AttachTexture", nil)
	nm.Close(menu)

	local mayMove = K.Widgets.MayMove
	K.Widgets.MayMove = function()
		error("no layout today")
	end
	ok = pcall(OPEN.tracking, env, nm, true)
	K.Widgets.MayMove = mayMove
	assert(not ok, "a chrome whose first restyle fails raises")
	menu = nil
	for _, candidate in pairs(nm.menus) do
		menu = candidate
	end
	assert(menu and menu.frame._scripts.OnSizeChanged == nil, "no size hook survives a chrome whose first restyle failed")
	assert(Regions(menu)[1]:IsShown(), "and the native background is still shown")
	nm.Close(menu)

	local again = Open("tracking", env, nm)
	CheckStyled("tracking", again, env, K, ns, nm, "Slate after the failures")
	nm.Close(again)
end

print("ok")
