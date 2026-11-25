-- Feed.lua: the loot feed: the player's own item and money gains as short lines above the chat card, each item in a quality-rimmed icon tile with its name in its quality colour and a stack count, money in coin colours, on a card that hugs the lines, or bare on the world when the chat is bare.
local _, ns = ...

local K = ns.K
local Widgets, Tokens, Theme, Motion = K.Widgets, K.Tokens, K.Theme, K.Motion
local Layouts, L = K.Setup.Layouts, ns.L
local LootText = ns.LootText

local KEY = "qol.lootfeed"
local STRATA = "BACKGROUND"
local COIN_ICON = 133784
local ICON_CROP = 0.07
local COINS = {
	{ per = 10000, format = "%sg", token = "coinGold" },
	{ per = 100, format = "%ss", token = "coinSilver" },
	{ per = 1, format = "%sc", token = "coinCopper" },
}

local quality = Enum and Enum.ItemQuality or {}
local RIM_FROM = quality.Uncommon or 2

local OWNER = "QoL.feed"
local WORLD_FLAGS = "OUTLINE"

local Feed = { lines = {}, free = {}, leaving = {}, pending = {} }
ns.Feed = Feed

local holder, backdrop, listening

function Feed.Bare()
	local ok, chat = pcall(K.Store.Module, "Chat")
	return ok and type(chat) == "table" and chat.framing == "bare"
end

local function Inset()
	return Widgets.WindowInset(backdrop)
end

local function Active()
	return ns.running == true and ns.Get("lootFeed") == true and holder ~= nil
end

local function SetLive(live)
	if K.Layout and K.Layout.SetLive then
		K.Layout.SetLive(KEY, live)
	end
end

local function Style(text, role, color)
	local path, _, flags = Tokens.Font(role)
	local bare = Feed.Bare()
	Widgets.ApplyFont(text, path, Tokens.Size("lootText"), bare and WORLD_FLAGS or flags)
	if bare then
		local offset = K.Scale.Border() / Widgets.ScaleFactor(text)
		text:SetShadowColor(Tokens.Color("textShadow"))
		text:SetShadowOffset(offset, -offset)
	end
	if color then
		text:SetTextColor(Tokens.Color(color))
	end
end

local function Hex(token)
	local r, g, b = Tokens.Color(token)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function MoneyText(copper)
	if ns.Get("coinIcons") and C_CurrencyInfo and type(C_CurrencyInfo.GetCoinTextureString) == "function" then
		local text = C_CurrencyInfo.GetCoinTextureString(copper)
		if not ns.IsSecret(text) and type(text) == "string" then return text end
	end
	local parts = {}
	for _, coin in ipairs(COINS) do
		local amount = math.floor(copper / coin.per)
		copper = copper - amount * coin.per
		if amount > 0 then
			parts[#parts + 1] = Hex(coin.token) .. string.format(L[coin.format], tostring(amount)) .. "|r"
		end
	end
	return table.concat(parts, " ")
end

local function PlainText(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Rest(slot)
	return slot * (Tokens.Size("lootTile") + Tokens.Size("gapSmall"))
end

local function Place(line, y)
	line.y = y
	if not Widgets.MayMove(line) then
		return
	end
	line:ClearAllPoints()
	local inset = Inset()
	Widgets.Point(line, "BOTTOMLEFT", holder, "BOTTOMLEFT", Widgets.Snap(holder, inset), Widgets.Snap(holder, inset + y))
end

local function Fit(box, t)
	local from, to = box.from, box.to
	Widgets.Size(box, from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t)
end

local function Refit()
	local count = #Feed.lines
	if count == 0 then
		return
	end
	if Feed.Bare() then
		Motion.Stop(backdrop.fit, true)
		backdrop:Hide()
		return
	end
	local tile, gap, inset = Tokens.Size("lootTile"), Tokens.Size("gapSmall"), Inset()
	local widest = 0
	for _, line in ipairs(Feed.lines) do
		widest = math.max(widest, line.width)
	end
	local width = math.min(holder:GetWidth(), widest + 2 * inset)
	local height = count * tile + (count - 1) * gap + 2 * inset
	if not backdrop:IsShown() then
		Motion.Stop(backdrop.fit, true)
		Widgets.Size(backdrop, width, height)
		backdrop:Show()
		return
	end
	local w, h = backdrop:GetSize()
	backdrop.from, backdrop.to = { w, h }, { width, height }
	backdrop.fit = Motion.Tween(backdrop, Fit, 0, 1, Motion.Slides() and Tokens.Duration("fade") or 0, Tokens.Easing("fade"))
end

local function Paint(line)
	local entry = line.entry
	if entry.kind == "money" then
		line.name:SetText(MoneyText(entry.copper))
		line.name:SetTextColor(Tokens.Color("textEmphasis"))
		line.icon:SetTexture(COIN_ICON)
		line.tile.chrome:SetRim()
	else
		line.name:SetText(entry.name)
		line.name:SetTextColor(Theme.QualityColor(entry.quality))
		line.icon:SetTexture(entry.icon)
		if type(entry.quality) == "number" and entry.quality >= RIM_FROM then
			line.tile.chrome:SetRim(Theme.QualityColor(entry.quality))
		else
			line.tile.chrome:SetRim()
		end
	end
	local count = entry.count or 1
	line.count:SetShown(count > 1)
	if count > 1 then
		line.count:SetText("x" .. count)
	end
	local tile, gapSmall, gapMedium = Tokens.Size("lootTile"), Tokens.Size("gapSmall"), Tokens.Size("gapMedium")
	local lead = gapMedium + gapSmall + tile + gapMedium
	local room = holder:GetWidth() - 2 * Inset() - lead
	local countWidth = count > 1 and (Widgets.TextWidth(line.count, 0) + gapSmall) or 0
	local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(holder)
	local nameWidth = math.min(math.ceil(Widgets.TextWidth(line.name, room) / pixel), math.floor((room - countWidth) / pixel)) * pixel
	line.name:SetWidth(nameWidth)
	line.width = lead + nameWidth + countWidth
end

local function Arrange(line)
	local tile, gapSmall, gapMedium = Tokens.Size("lootTile"), Tokens.Size("gapSmall"), Tokens.Size("gapMedium")
	Widgets.Size(line, holder:GetWidth() - 2 * Inset(), tile)
	Style(line.plus, "number", "gilt")
	Style(line.name, "body")
	Style(line.count, "number", "muted")
	line.plus:ClearAllPoints()
	Widgets.Point(line.plus, "LEFT", line, "LEFT", 0, 0)
	Widgets.Size(line.tile, tile, tile)
	line.tile:ClearAllPoints()
	Widgets.Point(line.tile, "LEFT", line, "LEFT", Widgets.Snap(line, gapMedium + gapSmall), 0)
	local inset = Widgets.Snap(line.tile, math.max(Widgets.Border(line.tile) * 2, tile * 0.1))
	Widgets.Fill(line.icon, line.tile, inset, inset, inset, inset)
	line.name:ClearAllPoints()
	Widgets.Point(line.name, "LEFT", line.tile, "RIGHT", Widgets.Snap(line, gapMedium), 0)
	line.count:ClearAllPoints()
	Widgets.Point(line.count, "LEFT", line.name, "RIGHT", Widgets.Snap(line, gapSmall), 0)
end

local function NewLine()
	local line = CreateFrame("Frame", nil, holder)
	line:SetFrameLevel(backdrop:GetFrameLevel() + 1)
	line.plus = Widgets.FontString(line)
	line.plus:SetText("+")
	line.tile = CreateFrame("Frame", nil, line)
	line.tile.chrome = Widgets.IconChrome(line.tile, { size = Tokens.Size("lootTile") })
	line.icon = line.tile:CreateTexture(nil, "ARTWORK")
	line.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	line.name = Widgets.FontString(line)
	line.name:SetJustifyH("LEFT")
	line.name:SetWordWrap(false)
	line.count = Widgets.FontString(line)
	line.y, line.width, line.token = 0, 0, 0
	return line
end

local function Retire(line)
	for i, leaving in ipairs(Feed.leaving) do
		if leaving == line then
			table.remove(Feed.leaving, i)
			break
		end
	end
	line.entry = nil
	line:Hide()
	Feed.free[#Feed.free + 1] = line
end

local function Spare()
	local line = table.remove(Feed.free)
	if line or #Feed.leaving <= Layouts.FEED_LINES then
		return line
	end
	line = table.remove(Feed.leaving, 1)
	Motion.Stop(line.sliding)
	Motion.Stop(line.fading)
	line.entry = nil
	line:Hide()
	return line
end

local function Leave(line)
	for i, live in ipairs(Feed.lines) do
		if live == line then
			table.remove(Feed.lines, i)
			break
		end
	end
	line.token = line.token + 1
	Feed.leaving[#Feed.leaving + 1] = line
	local duration, easing = Tokens.Duration("panelClose"), Tokens.Easing("panelClose")
	line.sliding = Motion.Tween(line, Place, line.y, line.y + Tokens.Size("gapMedium"), Motion.Slides() and duration or 0, easing)
	line.fading = Motion.Tween(line, "SetAlpha", line:GetAlpha(), 0, duration, easing, Retire)
	if #Feed.lines == 0 then
		backdrop:Hide()
		return
	end
	for index, live in ipairs(Feed.lines) do
		Motion.Tween(live, Place, live.y, Rest(#Feed.lines - index), Motion.Slides() and Tokens.Duration("fade") or 0, Tokens.Easing("fade"))
	end
	Refit()
end

local function Expire(line)
	local token = line.token
	C_Timer.After(Tokens.Duration("lootHold"), function()
		if line.token == token and line.entry then
			Leave(line)
		end
	end)
end

local function Resolve(entry)
	local icon = select(5, C_Item.GetItemInfoInstant(entry.id))
	entry.icon = ns.Number(icon) or C_Item.GetItemIconByID(entry.id)
	local found = C_Item.GetItemQualityByID(entry.id)
	if ns.Number(found) then
		entry.quality = found
		return
	end
	if not Feed.pending[entry.id] then
		Feed.pending[entry.id] = true
		C_Item.RequestLoadItemDataByID(entry.id)
	end
end

local function Add(entry)
	if entry.kind == "item" then
		Resolve(entry)
	end
	for _, line in ipairs(Feed.lines) do
		local live = line.entry
		if live.kind == entry.kind and live.id == entry.id then
			if live.kind == "item" then
				live.count = (live.count or 1) + (entry.count or 1)
			else
				live.copper = live.copper + entry.copper
			end
			line.token = line.token + 1
			Paint(line)
			Expire(line)
			Refit()
			return
		end
	end
	if #Feed.lines >= Layouts.FEED_LINES then
		Leave(Feed.lines[1])
	end
	for index, live in ipairs(Feed.lines) do
		Motion.Tween(live, Place, live.y, Rest(#Feed.lines - index + 1), Motion.Slides() and Tokens.Duration("fade") or 0, Tokens.Easing("fade"))
	end
	local line = Spare() or NewLine()
	line.entry, line.token = entry, line.token + 1
	Feed.lines[#Feed.lines + 1] = line
	Arrange(line)
	Paint(line)
	Place(line, Rest(0) - Tokens.Size("gapMedium"))
	Refit()
	Motion.FadeIn(line, Tokens.Duration("panelOpen"))
	Motion.Tween(line, Place, line.y, Rest(0), Motion.Slides() and Tokens.Duration("panelOpen") or 0, Tokens.Easing("panelOpen"))
	Expire(line)
end

local function OnLoot(_, text)
	if not Active() then
		return
	end
	local id, name, count = LootText.Item(text)
	if id then
		Add({ kind = "item", id = id, name = PlainText(name), count = count })
	end
end

local function OnMoney(_, text)
	if not Active() then
		return
	end
	local copper = LootText.Money(text)
	if copper then
		Add({ kind = "money", copper = copper })
	end
end

local function OnItemData(_, id, success)
	if not Feed.pending[id] then
		return
	end
	Feed.pending[id] = nil
	local found = success == true and C_Item.GetItemQualityByID(id) or nil
	if not ns.Number(found) then
		return
	end
	for _, line in ipairs(Feed.lines) do
		local entry = line.entry
		if entry.id == id then
			entry.quality = found
			Paint(line)
		end
	end
end

local function Build()
	if holder then
		return
	end
	local width, height = Layouts.Footprint("DPS", KEY)
	holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetFrameStrata(STRATA)
	Widgets.Size(holder, width, height)
	backdrop = Widgets.Panel(holder, { strata = STRATA, shape = "window" })
	backdrop:SetFixedFrameStrata(true)
	Widgets.Point(backdrop, "BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	backdrop:Hide()
	holder.Restyle = function()
		Widgets.Size(holder, width, height)
		for index, line in ipairs(Feed.lines) do
			Arrange(line)
			Paint(line)
			Place(line, Rest(#Feed.lines - index))
		end
		Refit()
	end
	Widgets.Track(holder)
	Widgets.Place(holder, KEY, Layouts.Default(KEY), { label = Layouts.Element(KEY).label, module = ns.MODULE, resizable = false })
end

local function Clear()
	for i = #Feed.lines, 1, -1 do
		local line = table.remove(Feed.lines, i)
		line.token = line.token + 1
		Retire(line)
	end
	Feed.pending = {}
	if backdrop then
		backdrop:Hide()
	end
end

local function Restyle()
	if holder then
		holder.Restyle()
	end
end

local function Reframe(_, module, key)
	if module == "Chat" and (key == nil or key == "framing") then
		Restyle()
	end
end

local function Listen(on)
	if on == listening then
		return
	end
	listening = on
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, Reframe)
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
	end
end

local function Sync()
	if ns.running and ns.Get("lootFeed") then
		Build()
		SetLive(true)
		Listen(true)
		return
	end
	Listen(false)
	Clear()
	if holder then
		SetLive(false)
	end
end

function Feed.Holder()
	return holder
end

function Feed.Backdrop()
	return backdrop
end

ns.AddPart({
	name = "feed",
	events = { CHAT_MSG_LOOT = OnLoot, CHAT_MSG_MONEY = OnMoney, ITEM_DATA_LOAD_RESULT = OnItemData },
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or key == "lootFeed" then
			Sync()
		end
		if key == nil or key == "coinIcons" then
			Restyle()
		end
	end,
})
