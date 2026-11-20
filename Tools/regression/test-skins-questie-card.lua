-- test-skins-questie-card.lua: Questie shares sibling cap geometry, styles new regions once and restores native art on every handover.
local Boot = dofile("Tools/regression/questcard_guide_env.lua")
local Questie = dofile("Tools/regression/questie_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Budget = dofile("Tools/regression/path_budget.lua")
local failures = {}
local function Check(name, run)
	local ok, err = pcall(run)
	if not ok then failures[#failures + 1] = name .. ": " .. tostring(err); print(failures[#failures]) end
end
local function Install(env, log)
	local other = Questie.Install(env, log)
	other.art = other.frame:CreateTexture(nil, "BACKGROUND")
	other.art:SetColorTexture(1, 1, 1, 0.7)
	local icon = env.CreateFrame("Button", nil, other.frame)
	icon.texture = icon:CreateTexture(nil, "BACKGROUND")
	icon.texture:SetColorTexture(1, 1, 1, 0.6)
	env.Questie_HeaderFrame.questieIcon = icon
	return other
end
local function Cap(R)
	for _, child in ipairs({ R.env.Questie_HeaderFrame:GetChildren() }) do
		if child.label and child.gem and child.rule then return child end
	end
	error("Questie must use the shared SectionCap")
end
for _, screen in ipairs({ { width = 1920, height = 1080 }, { width = 2560, height = 1440 }, { width = 5120, height = 1440 }, { width = 3840, height = 2160 } }) do
	screen.uiScale = 768 / 1080
	Check("caps " .. screen.width, function()
		local R = Boot(screen, nil, nil, true, Install)
		local cap, panel = Cap(R), R.K.Skin.Parts(R.questie.frame).backdrop
		local path = R.ns.RestedXP.Chrome.Path(R.rxp.RXPFrame)
		local function Offsets(c, glass)
			local r = assert(Geometry.ScaledRect(c.rule, R.env.UIParent, R.K.Scale.Root()))
			local g = assert(Geometry.ScaledRect(c.gem, R.env.UIParent, R.K.Scale.Root()))
			local p = assert(Geometry.ScaledRect(glass, R.env.UIParent, R.K.Scale.Root()))
			return p.top - r.top, g.left - p.left
		end
		for _ = 1, 2 do
			R.K.Options.Write("Integrations", "questTracker", "kstyleui")
			R.settle()
			local quest = R.ns.QuestCard.Parts()
			local qy, qx = Offsets(quest.cap, quest.glass)
			R.K.Options.Write("Integrations", "questTracker", "questie")
			R.settle()
			local gy, gx = Offsets(path.cap, R.K.Skin.Parts(R.rxp.RXPFrame).backdrop)
			local y, x = Offsets(cap, panel)
			for _, sibling in ipairs({ { qy, qx }, { gy, gx } }) do
				assert(math.abs(y - sibling[1]) <= R.K.Scale.Pixel(1) + 0.01, string.format("Anchor all three cap rules at the same y from their glass: %.2f vs %.2f", y, sibling[1]))
				assert(math.abs(x - sibling[2]) <= R.K.Scale.Pixel(1) + 0.01, string.format("Give all three cap gems the same glass inset: %.2f vs %.2f", x, sibling[2]))
			end
			collectgarbage("collect")
			R.ns.Style.RestyleAll()
			R.settle()
		end
	end)
	Check("scope " .. screen.width, function()
		local R = Boot(screen, nil, nil, true, Install)
		local other, K = R.questie, R.K
		local icon = R.env.Questie_HeaderFrame.questieIcon.texture
		assert(other.art:GetAlpha() == 0 and icon:GetAlpha() == 0, "Hide Questie art only while its shared card is active")
		other.art:SetColorTexture(1, 1, 1, 0.7)
		assert(other.art:GetAlpha() == 0, "Keep native recolouring hidden while Questie's card is active")
		for _, choice in ipairs({ "skin", "tracker", "module" }) do
			if choice == "skin" then K.Options.Write("Skins", "questie.enabled", false)
			elseif choice == "tracker" then K.Options.Write("Integrations", "questTracker", "kstyleui")
			else K.Modules.Disable("Skins") end
			R.settle()
			if choice == "skin" then assert(not K.Widgets.DialogHost():IsShown(), "A reversible Questie card switch needs no reload prompt") end
			assert(other.art:GetAlpha() == 0.7 and icon:GetAlpha() == 0.6, "Restore Questie's native art when either card setting or tracker choice is off")
			other.art:SetAlpha(0.8)
			assert(other.art:GetAlpha() == 0.8, "Let Questie update its native art while its skin is off")
			other.art:SetAlpha(0.7)
			if choice == "skin" then K.Options.Write("Skins", "questie.enabled", true)
			elseif choice == "tracker" then K.Options.Write("Integrations", "questTracker", "questie")
			else K.Modules.Enable("Skins") end
			R.settle()
			assert(other.art:GetAlpha() == 0 and icon:GetAlpha() == 0, "Reapply Questie's card art after reenable")
		end
		R.env.SetCombat(true)
		K.Options.Write("Skins", "questie.enabled", false)
		assert(other.art:GetAlpha() == 0, "Defer tracker art changes during combat")
		R.env.SetCombat(false)
		R.settle()
		assert(other.art:GetAlpha() == 0.7, "Restore native tracker art when the deferred switch leaves combat")
	end)
end
Check("cost and new regions", function()
	local R = Boot({ width = 1920, height = 1080 }, nil, nil, true, Install)
	for _ = 1, 250 do
		local line = R.env.CreateFrame("Frame", nil, R.questie.frame)
		local text = line:CreateFontString(nil, "ARTWORK")
		text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	end
	R.questie:Update()
	local sweeps, sweep = 0, R.ns.Style.Sweep
	R.ns.Style.Sweep = function(...) sweeps = sweeps + 1; return sweep(...) end
	local cost = Budget.Count(R.env, function()
		for _ = 1, 100 do R.questie:Update(); R.questie.frame:GetScript("OnSizeChanged")(R.questie.frame) end
	end)
	assert(sweeps == 0, "Do not sweep an already styled Questie tree during a burst of updates and size changes")
	Budget.Check(cost, 6000000, 160000, "Cache Questie's styled regions and unchanged cap text during tracker update bursts")
	local row = R.env.CreateFrame("Frame", nil, R.questie.frame)
	local nested = R.env.CreateFrame("Frame", nil, row)
	local text = nested:CreateFontString(nil, "ARTWORK")
	text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	R.questie:Update()
	assert(text:GetFont() ~= "Fonts\\FRIZQT__.TTF", "Style newly created nested Questie rows after the first tracker sweep")
	text:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
	assert(text:GetFont() ~= "Fonts\\ARIALN.TTF" and select(2, text:GetFont()) == 14, "Keep the shared face while Questie updates a reused row's native font")
	R.K.Options.Write("Skins", "questie.enabled", false)
	assert(text:GetFont() == "Fonts\\ARIALN.TTF", "Restore Questie's native font when its shared card is off")
	print(string.format("Questie update burst: %d instructions/%d widget calls", cost.instructions, cost.calls))
end)
Check("initially off and late frame", function()
	local R = Boot({ width = 1920, height = 1080 }, nil, nil, true, function(env, log)
		env.KstyleUI.Store.Module("Integrations").questTracker = "kstyleui"
		return Install(env, log)
	end)
	assert(R.questie.art:GetAlpha() == 0.7, "Leave Questie art untouched when KstyleUI's own tracker was chosen at startup")
	local late = Boot({ width = 1920, height = 1080 }, nil, nil, true)
	late.K.Options.Write("Skins", "questie.enabled", false)
	local other = Install(late.env, late.log)
	late.env.FireEvent("ADDON_LOADED", "Questie")
	late.settle()
	assert(other.art:GetAlpha() == 0.7, "Do not strip a late-created Questie frame while the shared card is off")
end)
assert(#failures == 0, table.concat(failures, "\n"))
print("test-skins-questie-card: ok")
