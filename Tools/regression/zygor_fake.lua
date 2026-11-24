-- zygor_fake.lua: Zygor Guides Viewer's guide window, its skin table and its anchor save (ZygorGuidesViewerForever: MasterFrame.xml, Skins/Default/Skin.lua, Functions.lua 2237-2254), enough for the story rail to move it.
local Fake = {}

function Fake.Install(env, opts)
	opts = opts or {}
	env._loaded.ZygorGuidesViewerForever = true
	local master = env.CreateFrame("Frame", "ZygorGuidesViewerFrameMaster", env.UIParent)
	master:SetSize(40, 40)
	master:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	master:SetClampedToScreen(true)
	local frame = env.CreateFrame("Frame", "ZygorGuidesViewerFrame", master)
	frame:SetSize(320, 100)
	frame:SetPoint("TOPLEFT", master, "TOPLEFT", 0, 0)
	frame.Border = env.CreateFrame("Frame", nil, frame)
	frame.Border:SetAllPoints(frame)
	frame.Border.TitleBar = env.CreateFrame("Frame", nil, frame.Border)
	frame.Border.TitleBar:SetPoint("TOPLEFT", frame.Border, "TOPLEFT", 0, 0)
	frame.Border.TitleBar:SetPoint("TOPRIGHT", frame.Border, "TOPRIGHT", 0, 0)
	frame.Border.TitleBar:SetHeight(24)
	local container = env.CreateFrame("Frame", nil, frame)
	local step = env.CreateFrame("Frame", nil, container)
	local label = step:CreateFontString(nil, "OVERLAY")
	label:SetFont("Fonts\\FRIZQT__.TTF", 16)
	label:SetText("Kill |cffffaaaapygmy crawlers|r and loot |cffaaeeffmucus|r.")
	local writes = { font = 0, text = 0 }
	local setFont, setText = label.SetFont, label.SetText
	label.SetFont = function(self, ...)
		writes.font = writes.font + 1
		return setFont(self, ...)
	end
	label.SetText = function(self, ...)
		writes.text = writes.text + 1
		return setText(self, ...)
	end
	step.lines = { { label = label } }
	local stepNum = { Step = frame.Border.TitleBar:CreateFontString(nil, "OVERLAY") }
	stepNum.Step:SetFont("Fonts\\FRIZQT__.TTF", 12)
	frame.Controls = { StepContainer = container, Logo = frame.Border.TitleBar:CreateTexture(nil, "ARTWORK"), StepNum = stepNum }
	-- Zygor's title buttons re-set their icon through AssignTextures on every skin pass (Skins/Default/ViewerFrame.lua ZGV_DefaultSkin_TitleButton_Mixin).
	-- Zygor's menu button sits at the title bar's left (ViewerFrame.lua: MenuSettingsButton TOPLEFT 9,-7).
	local menu = env.CreateFrame("Button", nil, frame.Border)
	menu:SetSize(16, 16)
	menu:SetPoint("TOPLEFT", frame.Border.TitleBar, "TOPLEFT", 9, -7)
	frame.Controls.MenuSettingsButton = menu
	for _, key in ipairs({ "NextButton", "ReportStep" }) do
		local button = env.CreateFrame("Button", nil, frame.Border.TitleBar)
		button:SetSize(16, 16)
		local icon = button:CreateTexture(nil, "ARTWORK")
		button.GetNormalTexture = function() return icon end
		button.AssignTextures = function()
			icon:SetAlpha(1)
			icon:SetVertexColor(1, 1, 1, 1)
		end
		frame.Controls[key] = button
	end
	-- A step paints its own background from Zygor's opacity setting and each line from its goal colours (Skins/Default/ViewerFrame.lua:602, :713, :2397).
	step.SetBackdropColor = function(self, r, g, b, a) self.backdrop = { r, g, b, a } end
	step.SetBackdropBorderColor = function() end
	step.SetBackgroundForStep = function(self) self:SetBackdropColor(0.13, 0.13, 0.13, 1) end
	local back = env.CreateFrame("Frame", nil, step)
	back.Center = back:CreateTexture(nil, "BACKGROUND")
	back.GetBackdropColor = function() return 0.5, 0, 0, 1 end
	back.SetBackdropColor = function(self, r, g, b, a) self.Center:SetColorTexture(r, g, b, a) end
	step.lines[1].back = back
	frame.stepframes = { step }
	function frame:AddStep() step:SetBackgroundForStep() end
	local profile = { resizeup = opts.resizeup == true, fixedheight = false, showcountsteps = opts.allsteps and 0 or 1, framescale = 1, frame_anchor = { "CENTER", "CENTER", 0, 0 } }
	local handlers = {}
	local style = { WindowBackdropColor = { 1, 0, 0, 1 }, StepFontSizeMod = 1 }
	local fake = { master = master, frame = frame, profile = profile, style = style, natural = opts.natural or 240, applied = 0, saves = 0, sets = 0, label = label, writes = writes, step = step }
	local z = {
		Frame = not opts.late and frame or nil,
		db = { profile = profile },
		Font = "Fonts\\FRIZQT__.TTF",
		CurrentSkinStyle = style,
		CurrentGuide = { title_short = "Skyborne Starter (1-13)" },
		F = {},
	}
	env.ZygorGuidesViewer = z
	-- Zygor's guide tabs, re-anchored every 0.01 s by Tabs.ResizeTimer (Tabs.lua:19); each tab's text is made with Zygor's own font (:518).
	local tabText = frame:CreateFontString(nil, "OVERLAY")
	tabText:SetFont("Fonts\\FRIZQT__.TTF", 12)
	tabText._fontWrites = 0
	local tabSetFont = tabText.SetFont
	tabText.SetFont = function(self, ...)
		self._fontWrites = self._fontWrites + 1
		return tabSetFont(self, ...)
	end
	z.Tabs = { Pool = { { Text = tabText } }, ReanchorTabs = function() end }
	-- Zygor's waypoint arrow recolours its sprite every frame in ShowTraveling and sets its text font in Pointer:SetFontSize (Arrows/ArrowSkin.lua:43, Pointer.lua:1565).
	local arrowFrame = env.CreateFrame("Frame", nil, env.UIParent)
	arrowFrame.arrow = env.CreateFrame("Frame", nil, arrowFrame)
	arrowFrame.arrow.arr = arrowFrame.arrow:CreateTexture(nil, "ARTWORK")
	arrowFrame.arrow.arrspecular = arrowFrame.arrow:CreateTexture(nil, "OVERLAY")
	arrowFrame.title = arrowFrame:CreateFontString(nil, "OVERLAY")
	arrowFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 11)
	arrowFrame.ShowTraveling = function(self)
		self.arrow.arr:SetVertexColor(1, 0, 0)
		self.arrow.arrspecular:SetAlpha(0.7)
	end
	z.Pointer = { ArrowFrame = arrowFrame, SetFontSize = function(self, size) arrowFrame.title:SetFont("Fonts\\FRIZQT__.TTF", size) end }
	fake.arrow = arrowFrame

	function z.F.SaveFrameAnchor(region, name, context)
		fake.saves = fake.saves + 1
		if not (region and name) then
			return
		end
		local context2 = context or profile
		local point = { region:GetPoint(1) }
		point[2] = nil
		context2[name] = point
	end

	function z.F.SetFrameAnchor(region, data)
		fake.sets = fake.sets + 1
		if not (region and data) then
			return
		end
		region:ClearAllPoints()
		region:SetPoint(data[1], env.UIParent, data[2], data[3], data[4])
	end

	-- Zygor bounds the window's height on every resize; the client clamps a size to those bounds.
	local setHeight = frame.SetHeight
	frame.SetHeight = function(self, height)
		local bounds = self._resizeBounds
		if bounds then
			if bounds[2] and bounds[2] > 0 and height < bounds[2] then
				height = bounds[2]
			end
			if bounds[4] and bounds[4] > 0 and height > bounds[4] then
				height = bounds[4]
			end
		end
		return setHeight(self, height)
	end

	-- The window sizes itself to its steps unless the player pinned the height (ZygorGuidesViewer.lua 2970-2971).
	function z:ResizeFrame()
		if fake.resizing then
			return
		end
		fake.resizing = true
		env.C_Timer.After(0.001, function()
			fake.resizing = false
		end)
		local controls = 91.5
		local autoresize = not profile.fixedheight and profile.showcountsteps ~= 0
		frame:SetResizeBounds(120, controls + (autoresize and 0 or 80), 600, controls + 600)
		if profile.fixedheight then
			return
		end
		frame:SetHeight(fake.natural + controls)
	end

	-- ZGV:UpdateFrame ends by resizing the window (ZygorGuidesViewer.lua 2808).
	function z:UpdateFrame()
		z:ResizeFrame()
	end

	function z:ReanchorFrame()
		frame:ClearAllPoints()
		frame:SetPoint(profile.resizeup and "BOTTOMLEFT" or "TOPLEFT", master, profile.resizeup and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
		frame:SetClampRectInsets(0, 0, profile.resizeup and 0 or -68, profile.resizeup and 68 or 0)
	end

	-- Zygor makes its window in OnInitialize (ZygorGuidesViewer.lua:387 SetSkin, Skins/Default/Skin.lua:23), which can run after KstyleUI's ADDON_LOADED.
	function z:SetSkin()
		self.Frame = frame
	end

	function z:SetFrameScale()
		frame:SetScale(profile.framescale)
	end

	function z:ApplySkin()
		fake.applied = fake.applied + 1
	end

	function z:AddMessageHandler(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
	end

	function z:SendMessage(event, ...)
		for _, fn in ipairs(handlers[event] or {}) do
			fn(...)
		end
	end

	-- The client's own behaviour the rail must survive: a size change updates the window (which resizes it again), and the height is saved in the pinned modes.
	frame:SetScript("OnSizeChanged", function(self, width, height)
		if fake.resizing then
			return
		end
		fake.resizing = true
		env.C_Timer.After(0.001, function()
			fake.resizing = false
		end)
		z:UpdateFrame()
		if profile.fixedheight or profile.showcountsteps == 0 then
			profile.fullheight = height
		end
	end)

	function fake.Show()
		frame:Show()
		z:ReanchorFrame()
		z:ResizeFrame()
		z.F.SaveFrameAnchor(master, "frame_anchor")
		z:SendMessage("ZGV_FRAME_VISIBILITY", true)
	end

	function fake.Hide()
		frame:Hide()
		z:SendMessage("ZGV_FRAME_VISIBILITY", false)
	end

	function fake.Step()
		z:ResizeFrame()
		z:SendMessage("ZGV_STEP_CHANGED")
	end

	-- Zygor's action bar snaps above the viewer and re-saves its place whenever it is shown (ActionBar.lua:491-512, :417-458).
	local bar = env.CreateFrame("Frame", "ZygorGuidesViewer_ActionBar", env.UIParent)
	bar:SetSize(32, 32)
	bar:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 100)
	bar.snapped = true
	fake.bar = bar
	profile.actionbar_anchor = { "BOTTOMLEFT", "BOTTOMLEFT", 100, 100 }
	z.ActionBar = {
		Frame = bar,
		SavePosition = function(self)
			-- ActionBar.lua:421 multiplies the viewer's top by its scale with no nil check.
			local top = z.Frame:GetTop() * z.Frame:GetEffectiveScale() / bar:GetEffectiveScale()
			fake.positions = (fake.positions or 0) + 1
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, top + 5)
		end,
	}

	env._zygor = fake
	return fake
end

return Fake
