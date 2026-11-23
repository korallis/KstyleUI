-- test-setup-selected-cards.lua: setup marks the picked HUD style and layout card with the accent edge and no glow wash, both HUD style cards keep their title, note and a picture framed alike, and no two Look or Controls tab labels touch or leave their strip in any locale.
local W = dofile("Tools/regression/widget_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene

local BARS = { bar1 = { buttons = 12, split = "off" }, bar2 = { buttons = 12, split = "off" }, useTray = true }
local SLACK = 0.5

local function Boot(screen, locale)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080 })
	rawset(_G, "RENDER_LOCALE", locale)
	local env, K = W.New(Common.ScreenOpts({ saved = Gallery.Saved({}), boot = false, setup = function(e)
		Gallery.Setup(e)
		e._textWidth = function(text, path, points) return Scene.TextWidth(Scene.PlainText(text), points, path) end
	end }))
	W.CoreEnv.Boot(env)
	for _, entry in ipairs(K.Setup.PICKER) do
		K.Modules.Register(W.CoreEnv.Module(entry.name, entry.name == "ActionBars" and { defaults = BARS } or nil))
	end
	return env, K
end

local function Settle(env)
	env.RunTimers(); W.Settle(env); env.RunTimers()
end

local function Inside(inner, outer)
	return inner:GetLeft() >= outer:GetLeft() - SLACK and inner:GetRight() <= outer:GetRight() + SLACK
		and inner:GetBottom() >= outer:GetBottom() - SLACK and inner:GetTop() <= outer:GetTop() + SLACK
end

-- Washed(card): a shown additive texture under the card's middle, the glow wash the client paints over the card.
local function Washed(card)
	local x, y = card:GetCenter()
	local function Walk(frame)
		for _, region in ipairs({ frame:GetRegions() }) do
			local blend = region._state and region._state.BlendMode
			if blend and blend[1] == "ADD" and region:IsVisible() and region:GetLeft() and region:GetLeft() < x and region:GetRight() > x
				and region:GetBottom() < y and region:GetTop() > y then
				return true
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:IsVisible() and Walk(child) then return true end
		end
		return false
	end
	return Walk(card)
end

local function Picked(K, cards, value, what)
	local accent = { K.Widgets.Rgba("accent") }
	for key, card in pairs(cards) do
		local edge = card.chrome.edge
		local lit = edge[1] == accent[1] and edge[2] == accent[2] and edge[3] == accent[3] and edge[4] == accent[4]
		assert(lit == (key == value), what .. ": only the picked card " .. value .. " wears the accent edge, " .. key .. " " .. (lit and "does" or "does not"))
		assert(not Washed(card), what .. ": the " .. key .. " card shows its pick with the accent edge, not a glow wash over the card")
	end
end

-- Labels(strip): the strip's shown tab labels, left to right.
local function Labels(strip)
	local list = {}
	for _, tab in ipairs(strip.buttons) do
		if tab:IsShown() then list[#list + 1] = tab.label end
	end
	table.sort(list, function(a, b) return a:GetLeft() < b:GetLeft() end)
	return list
end

for _, case in ipairs({ { "enUS", 1920, 1080 }, { "deDE", 1920, 1080 }, { "deDE", 5120, 1440 }, { "frFR", 1920, 1080 }, { "esES", 2560, 1440 }, { "zhCN", 1920, 1080 } }) do
	local locale, width, height = case[1], case[2], case[3]
	local label = locale .. " " .. width .. "x" .. height
	local env, K = Boot({ width, height }, locale)
	assert(K.Setup.Open(true))
	local panel = K.Setup.window
	for _, style in ipairs({ "medallions", "frames" }) do
		K.Setup.Choice().hudStyle = style
		K.Setup.Go(2)
		Settle(env)
		local what = label .. ", " .. style .. " picked"
		Picked(K, panel.styleCards, style, what .. ", HUD style step")
		local bottom
		for key, card in pairs(panel.styleCards) do
			local pad = K.Widgets.Snap(card, K.Tokens.Size("gapLarge"))
			for _, text in ipairs({ card.title, card.note }) do
				assert(text:IsVisible() and (text:GetText() or "") ~= "" and Inside(text, card), what .. ": the " .. key .. " card shows its title and note inside the card")
			end
			local picture = card.picture
			assert(picture:IsVisible() and picture:GetTexture() and Inside(picture, card), what .. ": the " .. key .. " card shows its picture inside the card")
			assert(picture:GetTop() <= card.note:GetBottom() + SLACK, what .. ": the " .. key .. " picture sits under its note")
			for side, gap in pairs({ left = picture:GetLeft() - card:GetLeft(), right = card:GetRight() - picture:GetRight(), bottom = picture:GetBottom() - card:GetBottom() }) do
				assert(math.abs(gap - pad) <= SLACK, what .. ": the " .. key .. " picture fills its card to one pad on the " .. side .. ", got " .. gap .. " for " .. pad)
			end
			bottom = bottom or picture:GetBottom()
			assert(math.abs(picture:GetBottom() - bottom) <= SLACK, what .. ": both HUD style pictures share one frame")
		end
		for _, strip in ipairs({ panel.lookTabs, panel.padTabs }) do
			assert(strip:IsVisible(), what .. ": the Look and Controls rows show")
			local labels = Labels(strip)
			assert(#labels >= 3, what .. ": every tab label draws")
			local first, last = labels[1], labels[#labels]
			assert(first:GetLeft() >= strip:GetLeft() - SLACK and last:GetRight() <= strip:GetRight() + SLACK,
				what .. ": \"" .. first:GetText() .. "\" and \"" .. last:GetText() .. "\" stay inside their strip; fit the tabs to their labels")
			for i = 2, #labels do
				local a, b = labels[i - 1], labels[i]
				assert(b:GetLeft() - a:GetRight() >= K.Tokens.Size("gapSmall") - SLACK, what .. ": \"" .. a:GetText() .. "\" and \"" .. b:GetText() .. "\" keep a gap; fit the tabs to their labels or shrink them")
			end
		end
		K.Setup.Go(3)
		Settle(env)
		for _, layout in ipairs({ "DPS", "Tank", "Healer" }) do
			panel.cards[layout].onClick()
			Settle(env)
			Picked(K, panel.cards, layout, what .. ", layout step")
			for key, card in pairs(panel.cards) do
				for _, text in ipairs({ card.title, card.note }) do
					assert(text:IsVisible() and (text:GetText() or "") ~= "" and Inside(text, card), what .. ": the " .. key .. " card shows its name and note inside the card")
				end
			end
		end
		K.Setup.Go(2)
	end
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
	collectgarbage("collect")
end
print("setup selected cards ok")
