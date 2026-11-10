-- test-popup-materials.lua: floating surfaces use opaque selected materials without changing embedded tiles, popup geometry or authored fills.
local W = dofile("Tools/regression/widget_env.lua")
local materials = { "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }

local function Painted(K, chrome, material)
	local spec = K.Tokens.Material(material)
	assert(chrome:Material() == spec, material .. ": the popup resolves the selected material")
	local r, g, b = K.Tokens.Color(spec.fill)
	for _, piece in ipairs(chrome.fill) do
		assert(W.SameColor(piece, r, g, b, 1), material .. ": every popup fill piece is opaque")
	end
	assert((chrome.grain ~= nil and chrome.grain:IsShown()) == (spec.texture ~= nil), material .. ": grain follows the material")
	if spec.texture then
		assert(chrome.grain:GetTexture() == K.Tokens.Texture(spec.texture))
		assert(W.SameColor(chrome.grain, K.Widgets.Rgba("white", spec.grain)), "grain does not follow panel opacity")
	end
	if chrome.shapeName == "tile" then
		assert(chrome.line[1]:IsShown() and chrome.rim[1]:IsShown(), "tile popups retain the small legacy edge")
		assert(not chrome.materialFrame and not chrome.materialBrackets and not chrome.gilt, "tile popups never acquire a large card frame or finish")
	else
		assert((chrome.materialFrame ~= nil and chrome.materialFrame[1]:IsShown()) == (spec.frame == true), "card popups keep the selected material frame")
		assert((chrome.materialBrackets ~= nil and chrome.materialBrackets[1]:IsShown()) == (spec.brackets == true), "card popups keep the selected bracket finish")
		if spec.frame then
			assert(W.SameColor(chrome.materialFrame[1], K.Widgets.Rgba("white", 1)), "the popup frame is fully visible")
		end
	end
end

local function Legacy(K, chrome, alpha)
	local r, g, b = K.Tokens.Color("surface")
	for _, piece in ipairs(chrome.fill) do
		assert(W.SameColor(piece, r, g, b, alpha), "Glass retains its original surface and opacity")
	end
	assert(not chrome.grain or not chrome.grain:IsShown(), "Glass has no material grain")
	assert(not chrome.materialFrame or not chrome.materialFrame[1]:IsShown(), "Glass restores the legacy frame")
	assert(not chrome.materialBrackets or not chrome.materialBrackets[1]:IsShown(), "Glass has no forged brackets")
	assert(chrome.line[1]:IsShown() and chrome.rim[1]:IsShown(), "Glass restores the legacy edge")
end

local function Size(frame)
	return { frame:GetSize() }
end

local function SameSize(frame, size)
	assert(W.Near(frame:GetWidth(), size[1]) and W.Near(frame:GetHeight(), size[2]), "a material or opacity change must not resize popup content")
end

do
	local env, K = W.New()
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	K.Options.Write("Widgets", "panelOpacity", 0.75)
	local root, Widgets = K.Scale.Root(), K.Widgets
	local options = { { value = "one", label = "First option" }, { value = "two", label = "Second option" }, { value = "three", label = "Third option" } }
	local dropdown = Widgets.Dropdown(root, { width = 238, options = options, value = "two", maxRows = 2 })
	dropdown:SetPoint("CENTER", root, "CENTER")
	W.Click(dropdown)
	W.Settle(env)
	local menu = Widgets.DropdownMenu()
	assert(dropdown:IsOpen() and menu:IsShown() and menu.owner == dropdown, "the actual dropdown opens its shared menu")
	local menuSize, dropdownSize = Size(menu), Size(dropdown)
	assert(W.Near(menu:GetWidth(), dropdown:GetWidth()))
	assert(W.Near(menu:GetHeight(), Widgets.Snap(menu, 2 * K.Tokens.Size("rowHeight") + 2 * K.Tokens.Size("gapSmall"))))
	local radius, edgeTexture = menu.chrome:Radius(), menu.chrome.rim[1]:GetTexture()
	local edit = Widgets.EditBox(root, { text = "Embedded control" })
	local tileOwner = env.CreateFrame("Frame", nil, root)
	tileOwner:SetSize(180, 100)
	local embedded = Widgets.Chrome(tileOwner, { shape = "tile", fill = "surface" })
	local panel = Widgets.Panel(root, { width = 300, height = 180 })
	local popupPanel = Widgets.Panel(root, { width = 280, height = 160, popup = true })
	local backdropOwner = env.CreateFrame("Frame", nil, root)
	backdropOwner:SetSize(260, 150)
	local backdrop = K.Skin.Backdrop(backdropOwner, { shape = "tile", fill = "surface", popup = true })
	local windowOwner = env.CreateFrame("Frame", nil, root)
	windowOwner:SetSize(320, 200)
	local window = K.Skin.Window(windowOwner, { popup = true })
	local plainOwner = env.CreateFrame("Frame", nil, root)
	plainOwner:SetSize(260, 150)
	local plainBackdrop = K.Skin.Backdrop(plainOwner, { shape = "tile", fill = "surface" })
	local tip = Widgets.Tooltip()
	tip:SetOwner(dropdown, "ANCHOR_RIGHT")
	tip:AddTitle("Popup title")
	tip:AddLine("Popup body stays readable")
	tip:AddDoubleLine("Left", "Right")
	tip:SetIcon(K.Tokens.Texture("diamond"))
	tip:Show()
	local dialog = Widgets.Confirm({ title = "Confirm material", text = "Keep these popup colors?" })
	local host = Widgets.DialogHost()
	W.Settle(env)
	local tipSize, hostSize = Size(tip), Size(host)
	local title = tip.used[1].left:GetText()
	local buttonColor = { K.Tokens.Color("buttonFill") }
	Legacy(K, menu.chrome, 0.75)
	for _, material in ipairs(materials) do
		K.Options.Write("Widgets", "cardMaterial", material)
		for _, opacity in ipairs({ 0.5, 0.75, 1 }) do
			K.Options.Write("Widgets", "panelOpacity", opacity)
			for _, chrome in ipairs({ menu.chrome, tip.chrome, host.chrome, popupPanel.chrome, backdrop.chrome, window.chrome }) do
				Painted(K, chrome, material)
			end
			assert(dropdown:IsOpen() and menu.owner == dropdown and menu:IsShown(), "an open menu repaints without closing")
			SameSize(menu, menuSize)
			SameSize(dropdown, dropdownSize)
			SameSize(tip, tipSize)
			SameSize(host, hostSize)
			assert(dropdown.text:GetText() == "Second option" and dropdown:GetValue() == "two")
			for _, row in ipairs(menu.list.rows) do
				if row:IsShown() then
					assert(row.label:GetText() == options[row.index].label, "menu text survives material changes")
				end
			end
			assert(tip.used[1].left:GetText() == title and tip.used[2].left:GetText() == "Popup body stays readable")
			assert(tip.used[3].left:GetText() == "Left" and tip.used[3].right:GetText() == "Right")
			assert(host.body:GetText() == "Keep these popup colors?" and dialog:IsShown())
			assert(host.visibleButtons[1].label:GetText() == "Cancel" and host.visibleButtons[2].label:GetText() == "Accept")
			assert(menu.chrome:Radius() == radius and menu.chrome.rim[1]:GetTexture() == edgeTexture, "the menu keeps its small edge geometry")
			for _, chrome in ipairs({ dropdown.chrome, edit.chrome, tip.icon.chrome }) do
				assert(chrome:Material() == nil and W.SameColor(chrome.fill[5], unpack(buttonColor)), "embedded controls keep buttonFill")
			end
			for _, chrome in ipairs({ embedded, plainBackdrop.chrome }) do
				assert(chrome:Material() == nil and W.SameColor(chrome.fill[5], K.Widgets.Rgba("surface", opacity / 0.75)), "ordinary surface tiles keep their glass fill")
			end
			local spec = K.Tokens.Material(material)
			local r, g, b, a = K.Tokens.Color(spec.fill)
			assert(W.SameColor(panel.chrome.fill[5], r, g, b, math.min(1, a * opacity / 0.75)), "ordinary panels still honor panel opacity")
		end
	end
	K.Options.Write("Widgets", "panelOpacity", 0.75)
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	for _, chrome in ipairs({ menu.chrome, tip.chrome, host.chrome, popupPanel.chrome, backdrop.chrome, window.chrome }) do
		Legacy(K, chrome, 0.75)
	end
	assert(menu.chrome:Radius() == radius and menu.chrome.rim[1]:GetTexture() == edgeTexture)
	SameSize(menu, menuSize)
	SameSize(tip, tipSize)
	SameSize(host, hostSize)
	local original = K.Store.ProfileName()
	assert(K.Store.CreateProfile("Opaque popup"))
	assert(K.Store.SetProfile("Opaque popup"))
	K.Options.Write("Widgets", "cardMaterial", "Slate")
	K.Options.Write("Widgets", "panelOpacity", 0.5)
	assert(K.Store.SetProfile(original))
	Legacy(K, menu.chrome, 0.75)
	assert(K.Store.SetProfile("Opaque popup"))
	for _, chrome in ipairs({ menu.chrome, tip.chrome, host.chrome, backdrop.chrome, window.chrome }) do
		Painted(K, chrome, "Slate")
	end
	assert(dropdown:IsOpen() and menu.owner == dropdown)
	SameSize(menu, menuSize)
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K = W.New()
	local Widgets, root = K.Widgets, K.Scale.Root()
	local fonts, textures = Widgets.MediaOptions("font"), Widgets.MediaOptions("statusbar")
	assert(#fonts > 0 and #textures > 0)
	local font = Widgets.FontPicker(root, { value = fonts[1].value, width = 216, maxRows = 3 })
	local texture = Widgets.TexturePicker(root, { value = textures[1].value, width = 264, maxRows = 3 })
	local menu = Widgets.DropdownMenu()
	for _, picker in ipairs({ font, texture }) do
		K.Options.Write("Widgets", "cardMaterial", "Glass")
		picker:Open()
		W.Settle(env)
		local size = Size(menu)
		local selected = picker:GetValue()
		for _, material in ipairs(materials) do
			K.Options.Write("Widgets", "cardMaterial", material)
			for _, opacity in ipairs({ 0.5, 0.75, 1 }) do
				K.Options.Write("Widgets", "panelOpacity", opacity)
				Painted(K, menu.chrome, material)
				SameSize(menu, size)
				assert(menu.owner == picker and picker:IsOpen() and picker:GetValue() == selected)
				assert(W.SameColor(picker.chrome.fill[5], K.Tokens.Color("buttonFill")), "media picker controls remain buttonFill")
				for _, row in ipairs(menu.list.rows) do
					if row:IsShown() then
						local option = picker:GetOptions()[row.index]
						assert(row.label:GetText() == option.label)
						if picker == font then
							assert(row.label:GetFont() == option.value, "font rows retain their actual font samples")
						else
							assert(row.sample:IsShown() and row.sample:GetTexture() == option.value, "texture rows retain their actual samples")
						end
					end
				end
			end
		end
		K.Options.Write("Widgets", "panelOpacity", 0.75)
		K.Options.Write("Widgets", "cardMaterial", "Glass")
		Legacy(K, menu.chrome, 0.75)
		SameSize(menu, size)
		picker:Close()
		W.Settle(env)
	end
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

do
	local env, K = W.New()
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(300, 180)
	local tile = K.Widgets.Chrome(owner, { shape = "tile", fill = "surface", popup = true })
	local card = K.Widgets.Chrome(owner, { shape = "window", popup = true })
	for _, material in ipairs(materials) do
		K.Options.Write("Widgets", "cardMaterial", material)
		for _, chrome in ipairs({ tile, card }) do
			for _, alpha in ipairs({ 0, 0.15, 0.75, 1 }) do
				local r, g, b = K.Tokens.Color("surface")
				chrome:SetFillRGBA(r, g, b, alpha)
				Painted(K, chrome, material)
			end
			chrome:SetFill("surface", 0.25)
			Painted(K, chrome, material)
			chrome:SetFillRGBA(K.Widgets.Rgba("hostile", 0.4))
			assert(chrome:Material() == nil and W.SameColor(chrome.fill[5], K.Widgets.Rgba("hostile", 0.4)), "a popup's authored RGB and alpha are not replaced")
			assert(not chrome.grain or not chrome.grain:IsShown())
			assert(not chrome.materialFrame or not chrome.materialFrame[1]:IsShown())
			chrome:SetFill("buttonFill")
			assert(chrome:Material() == nil and W.SameColor(chrome.fill[5], K.Tokens.Color("buttonFill")), "a popup's named custom fill remains authored")
			chrome:SetFill("surface")
		end
	end
	K.Options.Write("Widgets", "cardMaterial", "Glass")
	card:SetFillRGBA(K.Widgets.Rgba("surface", 0.2))
	Legacy(K, card, 0.75 * 0.2)
	local schema = K.Options.Get("Widgets")
	local header
	for _, row in ipairs(schema) do
		if row.type == "header" then header = row.label end
		if row.key == "panelOpacity" then
			assert(header == K.L["Panel appearance"], "the opacity section is material-neutral")
		end
		assert(row.type ~= "header" or row.label ~= K.L["Glass"], "the old Glass section header is gone")
	end
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

print("popup materials: four opaque materials, opacity/profile changes, dropdown/media pickers, tooltip/dialog/backdrop propagation and authored-fill isolation passed")
