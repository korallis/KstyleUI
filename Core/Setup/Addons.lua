-- Addons.lua: the setup's detected-addon choices, using the same toggles, notes and dropdowns as the other steps.
local _, K = ...
local Setup, Widgets = K.Setup, K.Widgets

local function Value(row)
	local choice = Setup.Choice()
	if row.key == "enabled" then return choice.modules[row.module] end
	return choice.addonSettings[row.module .. "." .. row.key]
end

function Setup.AddonsPage(page, width, changed)
	local scroll = CreateFrame("ScrollFrame", nil, page)
	Widgets.Fill(scroll, page)
	scroll:SetClipsChildren(true)
	scroll:EnableMouseWheel(true)
	local body = CreateFrame("Frame", nil, scroll)
	Widgets.Size(body, width, 1)
	scroll:SetScrollChild(body)
	local view = { scroll = scroll, body = body, groups = {}, active = {} }
	local function Scroll(offset)
		scroll:SetVerticalScroll(math.max(0, math.min(math.max(0, body:GetHeight() - scroll:GetHeight()), offset)))
	end
	scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(scroll:GetVerticalScroll() - delta * 44) end)
	function view:Sync()
		for _, group in ipairs(self.active) do
			for _, item in ipairs(group.active) do item.control:SetValue(Value(item.row), true) end
		end
	end
	function view:Restyle()
		local gap, tiny = K.Tokens.Size("gapLarge"), K.Tokens.Size("gapTiny")
		local column = (width - gap) / 2
		local heights = { 0, 0 }
		for _, group in ipairs(self.active) do
			local col = heights[1] <= heights[2] and 1 or 2
			Widgets.Size(group.frame, column, 1)
			Widgets.Point(group.frame, "TOPLEFT", body, "TOPLEFT", (col - 1) * (column + gap), -heights[col])
			Widgets.StyleText(group.title)
			group.title:SetWidth(column)
			local y = Widgets.WrappedHeight(group.title, column) + K.Tokens.Size("gapSmall")
			for _, item in ipairs(group.active) do
				local control, row = item.control, item.row
				control:Restyle()
				local indent = row.type == "toggle" and control.trackBox:GetWidth() + K.Tokens.Size("gapMedium") or 0
				if item.label then
					Widgets.StyleText(item.label)
					item.label:SetWidth(column)
					Widgets.Point(item.label, "TOPLEFT", group.frame, "TOPLEFT", 0, -y)
					y = y + Widgets.WrappedHeight(item.label, column) + tiny
				end
				Widgets.Point(control, "TOPLEFT", group.frame, "TOPLEFT", 0, -y)
				if row.type == "toggle" then control.label:SetWidth(column - indent) end
				y = y + control:GetHeight() + tiny
				item.note:Restyle()
				item.note:SetWidth(column - indent)
				Widgets.Point(item.note, "TOPLEFT", group.frame, "TOPLEFT", indent, -y)
				y = y + Widgets.WrappedHeight(item.note, column - indent) + K.Tokens.Size("gapSmall")
			end
			group.frame:SetHeight(y)
			heights[col] = heights[col] + y + gap
		end
		body:SetHeight(math.max(heights[1], heights[2]))
		Scroll(scroll:GetVerticalScroll() or 0)
	end
	function view:Refresh()
		for _, group in pairs(self.groups) do group.frame:Hide() end
		self.active = {}
		local function Group(name, label, rows)
			local group = self.groups[name]
			if not group then
				group = { frame = CreateFrame("Frame", nil, body), items = {} }
				group.title = Widgets.Text(group.frame, "caps", "textEmphasis")
				group.title:SetJustifyH("LEFT")
				group.title:SetWordWrap(true)
				Widgets.Point(group.title, "TOPLEFT", group.frame, "TOPLEFT")
				self.groups[name] = group
			end
			group.frame:Show()
			Widgets.SetText(group.title, label)
			for _, item in pairs(group.items) do item.frame:Hide() end
			group.active = {}
			for _, row in ipairs(rows) do
				local key = row.module .. "." .. row.key
				local item = group.items[key]
				if not item then
					item = { frame = CreateFrame("Frame", nil, group.frame), row = row }
					Widgets.Fill(item.frame, group.frame)
					local function Pick(value)
						local choice = Setup.Choice()
						if row.key == "enabled" then choice.modules[row.module] = value else choice.addonSettings[key] = value end
						changed()
					end
					if row.type == "dropdown" then
						item.label = Widgets.Text(item.frame, "body", "text")
						item.label:SetJustifyH("LEFT")
						item.label:SetText(row.label)
						item.control = Widgets.Dropdown(item.frame, { width = (width - K.Tokens.Size("gapLarge")) / 2, options = row.options, onChange = Pick })
					else
						item.control = Widgets.Toggle(item.frame, { label = row.label, onChange = Pick })
						item.control.label:SetJustifyH("LEFT")
					end
					item.note = Widgets.FontString(item.frame)
					item.note.Restyle = Setup.NoteStyle
					Widgets.Track(item.note)
					Widgets.TextColor(item.note, "text")
					item.note:SetJustifyH("LEFT")
					item.note:SetWordWrap(true)
					group.items[key] = item
				end
				item.frame:Show()
				item.note:SetText(row.help)
				group.active[#group.active + 1] = item
			end
			self.active[#self.active + 1] = group
		end
		for _, addon in ipairs(Setup.Choice().addons) do
			Group(addon.name, addon.label, addon.rows)
		end
		self:Sync()
		self:Restyle()
		Scroll(0)
	end
	return view
end
