-- WorldMapServices.lua: remembers where service NPCs stand when the player visits them, pins them on the map and finds the nearest.
local _, ns = ...

local K = KstyleUI
local L, Widgets = K.L, K.Widgets
local Lumen, Roads, R, Skins = ns.Lumen, ns.WorldMapRoads, ns.WorldMapRoutes, ns.Skins
local Services = {}
ns.WorldMapServices = Services

local OWNER = "WorldMapServices"
local KINDS = { "inn", "trainer", "bank", "auction", "repair", "reagent" }
local LABELS = { inn = L["Innkeeper"], trainer = L["Trainer"], bank = L["Bank"], auction = L["Auction house"], repair = L["Repair vendor"], reagent = L["Reagent vendor"] }
local NEAREST = { inn = L["Nearest innkeeper"], trainer = L["Nearest trainer"], bank = L["Nearest bank"], auction = L["Nearest auction house"],
	repair = L["Nearest repair vendor"], reagent = L["Nearest reagent vendor"] }
local COLORS = { inn = "questGold", trainer = "magic", bank = "coinSilver", auction = "coinGold", repair = "steelLit", reagent = "uncommon" }
local TYPES = { Trainer = "trainer", Banker = "bank", CharacterBanker = "bank", AccountBanker = "bank", Auctioneer = "auction", Binder = "inn" }
local pins, registered, hookedScale, drawn = {}
Services.KINDS, Services.NEAREST, Services.pins = KINDS, NEAREST, pins

local function Valid(row)
	return type(row) == "table" and R.Plain(row.name, "string") and R.Number(row.continent) and R.Number(row.wx) and R.Number(row.wy)
		and R.Number(row.map) and R.Number(row.x) and R.Number(row.y)
end

local function Faction()
	return type(UnitFactionGroup) == "function" and R.Plain(UnitFactionGroup("player"), "string") or nil
end

local function List(kind)
	local saved, out, faction = K.Store.Account().mapServices, {}, Faction()
	for _, row in pairs(type(saved) == "table" and type(saved[kind]) == "table" and saved[kind] or {}) do
		if Valid(row) and row.faction == faction then out[#out + 1] = row end
	end
	return out
end

local function Here()
	local map = R.Number(R.Call(C_Map, "GetBestMapForUnit", "player"))
	local x, y
	if map then x, y = R.XY(R.Call(C_Map, "GetPlayerMapPosition", map, "player")) end
	if x then return map, x, y, R.World(map, x, y) end
end

local function Record(kind)
	local map, x, y, continent, wx, wy = Here()
	local name = type(UnitName) == "function" and R.Plain(UnitName("npc"), "string")
	if not continent or not name or name == "" then return end
	local guid = type(UnitGUID) == "function" and R.Plain(UnitGUID("npc"), "string")
	local id = guid and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)") or name
	local account, faction = K.Store.Account(), Faction()
	account.mapServices = type(account.mapServices) == "table" and account.mapServices or {}
	local saved = account.mapServices
	saved[kind] = type(saved[kind]) == "table" and saved[kind] or {}
	local list, key, n = saved[kind], id, 1
	while Valid(list[key]) and (list[key].continent ~= continent or list[key].faction ~= faction or (list[key].wx - wx) ^ 2 + (list[key].wy - wy) ^ 2 > 900) do
		n = n + 1
		key = id .. "#" .. n
	end
	list[key] = { name = name, map = map, x = x, y = y, continent = continent, wx = wx, wy = wy, faction = faction }
	if drawn then Services.Draw(drawn.canvas, drawn.id, true) end
end

local function SellsReagents()
	local count = type(GetMerchantNumItems) == "function" and R.Number(GetMerchantNumItems()) or 0
	local reagent = type(Enum) == "table" and R.Field(Enum.ItemClass, "Reagent", "number")
	if not reagent or type(GetMerchantItemID) ~= "function" then return end
	for i = 1, count do
		local id = R.Number(GetMerchantItemID(i))
		if id and R.Number(select(6, R.Call(C_Item, "GetItemInfoInstant", id))) == reagent then return true end
	end
end

local function Merchant()
	if type(CanMerchantRepair) == "function" and R.Plain(CanMerchantRepair(), "boolean") then Record("repair") end
	if SellsReagents() then Record("reagent") end
end

local function Interaction(_, kind)
	local types = type(Enum) == "table" and R.Plain(Enum.PlayerInteractionType, "table")
	kind = R.Number(kind)
	if not types or not kind then return end
	if kind == types.Merchant then Merchant() end
	for name, service in pairs(TYPES) do
		if types[name] == kind then Record(service) end
	end
end

local function Gossip()
	local binder = type(Enum) == "table" and R.Field(Enum.PlayerInteractionType, "Binder", "number")
	if binder and R.Plain(R.Call(C_PlayerInteractionManager, "IsInteractingWithNpcOfType", binder), "boolean") then Record("inn") end
end

local function Sync()
	local on = K.Modules.IsRunning("Skins") and Skins.IsOn("worldMap") and Skins.Setting("worldMap", "routes") == true and Skins.Setting("worldMap", "services") == true
	if on == registered then return end
	registered = on
	if not on then K.Events.UnregisterAll(OWNER) return end
	K.Events.Register(OWNER, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Interaction)
	K.Events.Register(OWNER, "MERCHANT_UPDATE", Merchant)
	K.Events.Register(OWNER, "GOSSIP_SHOW", Gossip)
	K.Events.Register(OWNER, "CONFIRM_BINDER", function() Record("inn") end)
end
for _, name in ipairs({ "ModuleChanged", "SettingChanged", "ProfileChanged" }) do K.Callbacks.Register(name, OWNER, Sync) end

function Services.OnMap(id)
	local out = {}
	if type(CreateVector2D) ~= "function" then return out end
	for _, kind in ipairs(KINDS) do
		for _, row in ipairs(List(kind)) do
			local same
			for _, other in ipairs(out) do
				if other.name == row.name and (other.wx - row.wx) ^ 2 + (other.wy - row.wy) ^ 2 <= 900 then same = other end
			end
			if same then same.kinds[#same.kinds + 1] = kind else
				local mapID, point = R.Call(C_Map, "GetMapPosFromWorldPos", row.continent, CreateVector2D(row.wx, row.wy), id)
				local px, py = R.XY(point)
				if px and R.Number(mapID) == id then
					out[#out + 1] = { kinds = { kind }, name = row.name, map = row.map, x = row.x, y = row.y, wx = row.wx, wy = row.wy, px = px, py = py }
				end
			end
		end
	end
	return out
end

function Services.Nearest(kind, roads)
	local map, _, _, continent, wx, wy = Here()
	if not continent then return nil, L["Your position is unavailable here."] end
	local mounted = type(IsMounted) == "function" and R.Plain(IsMounted(), "boolean") or false
	local time, best, cost, reached
	for _, row in ipairs(List(kind)) do
		if row.continent == continent then
			if time == nil then
				local graph = roads and Roads.Graph(continent)
				time = graph and Roads.Times(graph, wx, wy, mounted, R.Flights(graph, map, continent)) or false
			end
			local seconds = time and time(row.wx, row.wy)
			local road = seconds and true or false
			seconds = seconds or math.sqrt((row.wx - wx) ^ 2 + (row.wy - wy) ^ 2) / (mounted and 14 or 7)
			if not best or road and not reached or road == reached and seconds < cost then best, cost, reached = row, seconds, road end
		end
	end
	return best, not best and L["None recorded on this continent yet. Talk to one and KstyleUI remembers where it stands."] or nil
end

function Services.Route(kind, roads)
	local row, reason = Services.Nearest(kind, roads)
	if row and R.Pick({ kind = "service", owner = "services", mapID = row.map, name = row.name, x = row.x, y = row.y }) then return true end
	R.Notice(NEAREST[kind], reason or L["The game does not allow a waypoint there."], "services")
end

local function NewPin(canvas)
	local pin = CreateFrame("Button", nil, canvas)
	pin.outline = pin:CreateTexture(nil, "ARTWORK", nil, 1)
	pin.fill = pin:CreateTexture(nil, "ARTWORK", nil, 2)
	for _, region in ipairs({ pin.outline, pin.fill }) do
		region:SetPoint("CENTER")
		region:SetRotation(math.pi / 4)
	end
	pin.outline:SetColorTexture(Lumen.Color("edgeOuter"))
	pin:SetScript("OnClick", function(self)
		local row = self.row
		R.Pick({ kind = "service", owner = "services", mapID = row.map, name = row.name, x = row.x, y = row.y })
	end)
	Widgets.AttachTooltip(pin, function(tip, self)
		tip:AddTitle(self.row.name)
		for _, kind in ipairs(self.row.kinds) do tip:AddLine(LABELS[kind]) end
		tip:AddLine(L["Click to route here."], "textDisabled")
	end)
	return pin
end

local function Place()
	local canvas = drawn.canvas
	local width, height, unit = R.Number(canvas:GetWidth()), R.Number(canvas:GetHeight()), Lumen.Size(canvas, 1)
	if not width or not height then return end
	for i = 1, drawn.count do
		local pin = pins[i]
		pin:SetSize(16 * unit, 16 * unit)
		pin.outline:SetSize(12 * unit, 12 * unit)
		pin.fill:SetSize(9 * unit, 9 * unit)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.row.px * width, -pin.row.py * height)
	end
end

function Services.Draw(canvas, id, on)
	for _, pin in ipairs(pins) do pin:Hide() end
	drawn = on and canvas and { canvas = canvas, id = id, count = 0 } or nil
	local map = WorldMapFrame
	if on and not hookedScale and type(map) == "table" and type(map.OnCanvasScaleChanged) == "function" then
		hookedScale = true
		hooksecurefunc(map, "OnCanvasScaleChanged", function() if drawn then Place() end end)
	end
	if not drawn or not R.Number(id) or not R.Plain(canvas:IsVisible(), "boolean") then return end
	local zone = type(Enum) == "table" and R.Field(Enum.UIMapType, "Zone", "number")
	local mapType = R.Field(R.Call(C_Map, "GetMapInfo", id), "mapType", "number")
	if not zone or not mapType or mapType < zone or not R.Number(canvas:GetWidth()) or not R.Number(canvas:GetHeight()) then return end
	for i, row in ipairs(Services.OnMap(id)) do
		local pin = pins[i] or NewPin(canvas)
		pins[i], pin.row, drawn.count = pin, row, i
		pin.fill:SetColorTexture(Lumen.Color(COLORS[row.kinds[1]]))
		pin:Show()
	end
	Place()
end
