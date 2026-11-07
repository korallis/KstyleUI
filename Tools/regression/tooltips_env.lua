-- tooltips_env.lua: load the core and KstyleUI_Tooltips into a stub environment with stand-in Blizzard tooltips.
--
--   local T = dofile("Tools/regression/tooltips_env.lua")
--   local env, K, ns = T.New()           -- core and module loaded, saved data loaded, PLAYER_LOGIN fired
--   K.Modules.Enable("Tooltips")
--   T.PostCall(env, env.GameTooltip, { type = env.Enum.TooltipDataType.Item, id = 19019 })
--
-- The stand-ins answer the GameTooltip methods Blizzard's code calls (AddLine, AddDoubleLine, NumLines,
-- ClearLines, SetOwner, GetOwner, GetLeftLine, GetRightLine) as plain fields the test sets before it
-- takes a snapshot, so T.Check can fail on any field the module writes onto a Blizzard object.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local T = { W = W }

local FOLDER = "KstyleUI_Tooltips"

local files
function T.Files()
	if not files then
		files = {}
		for _, path in ipairs(TocFiles("%.lua$")) do
			if path:sub(1, #FOLDER + 1) == FOLDER .. "/" then
				files[#files + 1] = path
			end
		end
		assert(#files > 0, "no KstyleUI_Tooltips files found")
	end
	return files
end

-- Methods a hook may add: hooksecurefunc replaces the hooked method on the object it hooks.
T.HOOKED = { SetAlpha = true, SetValue = true, SetVertexColor = true }

local function fields(object)
	local out = {}
	for k in pairs(object) do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = true
		end
	end
	return out
end

local function line(tip, index)
	local left = tip._left[index]
	if not left then
		left = tip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
		local right = tip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
		left._standIn, right._standIn = true, true
		tip._left[index], tip._right[index] = left, right
		tip._made[#tip._made + 1] = left
		tip._made[#tip._made + 1] = right
	end
	return tip._left[index], tip._right[index]
end

local function setLine(region, text, r, g, b)
	region:SetText(text)
	region:SetTextColor(r or 1, g or 0.82, b or 0)
	region:Show()
end

-- Tooltip(env, name, opts) -> a stand-in GameTooltip. opts.statusBar adds the unit health bar,
-- opts.itemTooltip the embedded item frame, opts.compareHeader the shopping tooltips' header.
function T.Tooltip(env, name, opts)
	opts = opts or {}
	local tip = env.CreateFrame("GameTooltip", name, env.UIParent)
	tip._made = { tip }
	tip._shown = false
	tip._left, tip._right, tip._count = {}, {}, 0
	tip:SetFrameStrata("TOOLTIP")
	local nine = env.CreateFrame("Frame", nil, tip)
	tip._made[#tip._made + 1] = nine
	for _ = 1, 9 do
		local piece = nine:CreateTexture(nil, "BORDER")
		piece:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
		tip._made[#tip._made + 1] = piece
	end
	tip.NineSlice = nine
	tip.TextLeft1, tip.TextRight1 = line(tip, 1)
	tip.TextLeft2, tip.TextRight2 = line(tip, 2)
	tip.AddLine = function(self, text, r, g, b)
		self._count = self._count + 1
		local left, right = line(self, self._count)
		setLine(left, text, r, g, b)
		right:SetText(nil)
		right:Hide()
	end
	tip.AddDoubleLine = function(self, leftText, rightText, lr, lg, lb, rr, rg, rb)
		self._count = self._count + 1
		local left, right = line(self, self._count)
		setLine(left, leftText, lr, lg, lb)
		setLine(right, rightText, rr, rg, rb)
	end
	tip.NumLines = function(self)
		return self._count
	end
	tip.ClearLines = function(self)
		for i = 1, self._count do
			self._left[i]:SetText(nil)
			self._left[i]:Hide()
			self._right[i]:SetText(nil)
			self._right[i]:Hide()
		end
		self._count = 0
		local cleared = self:GetScript("OnTooltipCleared")
		if cleared then
			cleared(self)
		end
	end
	tip.SetOwner = function(self, owner, anchor, x, y)
		self._owner, self._anchor = owner, { anchor, x, y }
		self:ClearLines()
	end
	tip.GetOwner = function(self)
		return self._owner
	end
	tip.GetLeftLine = function(self, index)
		return self._left[index]
	end
	tip.GetRightLine = function(self, index)
		return self._right[index]
	end
	if opts.statusBar then
		local bar = env.CreateFrame("StatusBar", nil, tip)
		bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
		bar:SetMinMaxValues(0, 1)
		bar:Hide()
		tip.StatusBar = bar
		tip._made[#tip._made + 1] = bar
		tip._made[#tip._made + 1] = bar:GetStatusBarTexture()
	end
	if opts.compareHeader then
		local header = env.CreateFrame("Frame", nil, tip)
		local art = header:CreateTexture(nil, "BACKGROUND")
		art:SetAtlas("tooltip-compare-label")
		header.Label = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		tip.CompareHeader = header
		tip._made[#tip._made + 1] = header
		tip._made[#tip._made + 1] = art
		tip._made[#tip._made + 1] = header.Label
	end
	if opts.closeButton then
		local close = env.CreateFrame("Button", nil, tip)
		local art = close:CreateTexture(nil, "ARTWORK")
		art:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		tip.CloseButton = close
		tip._made[#tip._made + 1] = close
		tip._made[#tip._made + 1] = art
	end
	if opts.itemTooltip then
		local item = env.CreateFrame("Frame", nil, tip)
		item.Icon = item:CreateTexture(nil, "ARTWORK")
		item.IconBorder = item:CreateTexture(nil, "OVERLAY")
		item.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
		item.IconOverlay = item:CreateTexture(nil, "OVERLAY")
		item.IconOverlay2 = item:CreateTexture(nil, "OVERLAY")
		item:Hide()
		tip.ItemTooltip = item
		for _, object in ipairs({ item, item.Icon, item.IconBorder, item.IconOverlay, item.IconOverlay2 }) do
			tip._made[#tip._made + 1] = object
		end
	end
	return tip
end

-- Font(env) -> a stand-in font object such as GameTooltipText, with Blizzard's own font.
local function Font(env, size)
	local font = env.UIParent:CreateFontString(nil, "ARTWORK")
	font:SetFont("Fonts\\FRIZQT__.TTF", size, "")
	font:SetShadowOffset(1, -1)
	font:SetShadowColor(0, 0, 0, 1)
	return font
end

T.TOOLTIPS = {
	GameTooltip = { statusBar = true, itemTooltip = true },
	ShoppingTooltip1 = { compareHeader = true },
	ShoppingTooltip2 = { compareHeader = true },
	ItemRefTooltip = { statusBar = true, closeButton = true },
	ItemRefShoppingTooltip1 = { compareHeader = true },
	ItemRefShoppingTooltip2 = { compareHeader = true },
	EmbeddedItemTooltip = { statusBar = true, itemTooltip = true },
}

-- Blizzard(env) installs the stand-in tooltips, font objects, tooltip data processor and the game
-- data the module reads. env._postCalls[type] lists the registered post-calls.
function T.Blizzard(env)
	env.Enum = {
		TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, UnitAura = 7, Mount = 10, Macro = 25 },
		ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7 },
	}
	local function color(r, g, b)
		return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end }
	end
	env.NORMAL_FONT_COLOR = color(1, 0.82, 0)
	env.HIGHLIGHT_FONT_COLOR = color(1, 1, 1)
	env.GREEN_FONT_COLOR = color(0.1, 1, 0.1)
	env._postCalls = {}
	env.TooltipDataProcessor = {
		AllTypes = "ALL",
		AddTooltipPostCall = function(kind, fn)
			assert(kind ~= nil and type(fn) == "function", "AddTooltipPostCall(type, fn)")
			env._postCalls[kind] = env._postCalls[kind] or {}
			table.insert(env._postCalls[kind], fn)
		end,
	}
	env.GameTooltipHeaderText = Font(env, 14)
	env.GameTooltipText = Font(env, 12)
	env.GameTooltipTextSmall = Font(env, 10)
	env.GameTooltipDefaultContainer = env.CreateFrame("Frame", "GameTooltipDefaultContainer", env.UIParent)
	env._blizzard = {}
	for name, opts in pairs(T.TOOLTIPS) do
		env._blizzard[#env._blizzard + 1] = T.Tooltip(env, name, opts)
	end
	env.GameTooltip_SetDefaultAnchor = function(tooltip, parent)
		tooltip:SetOwner(parent, "ANCHOR_NONE")
		tooltip:ClearAllPoints()
		tooltip:SetPoint("BOTTOMRIGHT", env.GameTooltipDefaultContainer, "BOTTOMRIGHT")
	end
	env._items = {}
	env.C_Item = {
		GetItemQualityByID = function(info)
			local item = env._items[info]
			return item and item.quality
		end,
		GetItemIconByID = function(info)
			local item = env._items[info]
			return item and item.icon
		end,
	}
end

-- New(opts) -> env, KstyleUI, the module's addon table. opts: the widget_env options, plus
--   login   false to stop after the module loads, before PLAYER_LOGIN
function T.New(opts)
	opts = opts or {}
	local setup = opts.setup
	local env, K = W.New({
		boot = false,
		saved = opts.saved,
		width = opts.width,
		height = opts.height,
		setup = function(env)
			T.Blizzard(env)
			if setup then
				setup(env)
			end
		end,
	})
	W.CoreEnv.LoadSaved(env)
	Load(T.Files(), env)
	if opts.login ~= false then
		W.CoreEnv.Login(env)
	end
	return env, K, env._addons[FOLDER]
end

-- Snapshot(env) remembers the fields and the call count of every stand-in Blizzard object.
function T.Snapshot(env)
	local snap = {}
	for _, tip in ipairs(env._blizzard) do
		for _, object in ipairs(tip._made) do
			snap[object] = { fields = fields(object), calls = #object._calls }
		end
	end
	return snap
end

-- Check(env, snap) fails on a field written onto a stand-in Blizzard object since the snapshot, other
-- than a hooked method, and on SetScript, SetParent or Hide called on one. The stand-ins' own line
-- handling (ClearLines hides unused lines) is Blizzard's, so it does not count.
function T.Check(env, snap)
	for _, tip in ipairs(env._blizzard) do
		for _, object in ipairs(tip._made) do
			local before = snap[object] or { fields = {}, calls = 0 }
			for k in pairs(fields(object)) do
				assert(before.fields[k] or T.HOOKED[k], "a field was written onto a Blizzard object: " .. tostring(k))
			end
			for i = before.calls + 1, #object._calls do
				local method = object._calls[i].method
				assert(method ~= "SetScript", "SetScript on a Blizzard object")
				assert(method ~= "SetParent", "SetParent on a Blizzard object")
				assert(method ~= "Hide" or object._standIn, "Hide on a Blizzard object")
			end
		end
	end
end

-- BlizzardShow(object, shown) shows or hides a stand-in as Blizzard's code would, and runs its
-- OnShow or OnHide script, without counting as a call the module made.
function T.BlizzardShow(object, shown)
	object._shown = shown and true or false
	local script = object:GetScript(shown and "OnShow" or "OnHide")
	if script then
		script(object)
	end
end

-- PostCall(env, tooltip, data) runs the registered post-calls for data.type, as TooltipDataProcessor does.
function T.PostCall(env, tooltip, data)
	for _, kind in ipairs({ "ALL", data.type }) do
		for _, fn in ipairs(env._postCalls[kind] or {}) do
			fn(tooltip, data)
		end
	end
end

-- Lines(tooltip) -> { { left, right }, ... } for the lines the tooltip shows.
function T.Lines(tooltip)
	local out = {}
	for i = 1, tooltip:NumLines() do
		out[i] = { tooltip._left[i]:GetText(), tooltip._right[i]:GetText() }
	end
	return out
end

-- Glass(K, tooltip) -> the module's glass frame on a tooltip, or nil.
function T.Glass(ns, tooltip)
	return ns.Style.Glass(tooltip)
end

T.Near = W.Near

return T
