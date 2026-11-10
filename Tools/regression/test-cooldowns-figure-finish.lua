-- test-cooldowns-figure-finish.lua: essential countdown optics share a snapped anchor without rewriting engine text, charges, geometry or saved choices.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W
local Geometry = dofile("Tools/regression/geometry.lua")

local env, K, ns = C.New({ setup = C.Game })
C.Enable(env, K)
assert(ns.Settings.defaults.essential.timerSize == 16.5, "essential figures use the picture's smaller 16.5-unit default")
assert(ns.Settings.current.essential.timerSize == 16.5, "clean reads preserve the fractional default instead of rounding it up")
for _, setting in ipairs(ns.Settings.schema) do
	if setting.key == "essential.timerSize" then
		assert(setting.step == 0.5, "the essential timer slider can select the measured half-unit default")
	elseif setting.key == "utility.timerSize" or setting.key == "buffs.timerSize" then
		assert(setting.step == 1, "other timer slider steps remain unchanged")
	end
end
assert(ns.Settings.defaults.essential.countSize == 10, "the corner charge size is unchanged")
assert(ns.Settings.defaults.utility.timerSize == 11 and ns.Settings.defaults.buffs.timerSize == 9, "utility retains 11 and tracked captions use the measured nine-unit size")

local function Integer(value, what)
	assert(math.abs(value - math.floor(value + 0.5)) < 1e-6, what .. " lands on whole physical pixels")
end

local function Figure(text, frame, itemScale, size)
	local _, actual = text:GetFont()
	assert(W.Near(actual, K.Widgets.FontSize(text, size * K.Theme.FontScale() / itemScale)), "the requested timer size is snapped in the text's own scale")
	Integer(actual * K.Widgets.ScaleFactor(text) / K.Scale.Pixel(1), "the font size")
	local p = text._points[1]
	assert(p[1] == "CENTER" and p[2] == frame and p[3] == "CENTER" and p[4] == 0, "only the essential text's optical vertical offset changes")
	assert(W.Near(p[5], -K.Widgets.Snap(frame, 2 / itemScale)), "the figure sits two root units optically lower, compensating native item scale")
	Integer(p[5] * K.Widgets.ScaleFactor(frame) / K.Scale.Pixel(1), "the optical offset")
end

local function NoTextReads()
	error("engine text and visibility must remain opaque")
end

local native = env._viewers.EssentialCooldownViewer._items[1]
local nativeText = native.Cooldown:GetCountdownFontString()
local nativeCount = native.ChargeCount.Current
local nativeBuff = env._viewers.BuffIconCooldownViewer._items[1]
local buffText = nativeBuff.Cooldown:GetCountdownFontString()
nativeText.GetText, nativeText.IsShown, nativeText.IsVisible = NoTextReads, NoTextReads, NoTextReads
nativeCount.GetText, nativeCount.IsShown, nativeCount.IsVisible = NoTextReads, NoTextReads, NoTextReads
buffText.GetText, buffText.IsShown, buffText.IsVisible = NoTextReads, NoTextReads, NoTextReads

local function SameRect(before, frame)
	local after = assert(Geometry.Rect(frame, K.Scale.Root()))
	for _, key in ipairs({ "left", "bottom", "right", "top" }) do
		assert(W.Near(before[key], after[key]), "countdown styling never moves or resizes the row or socket")
	end
end

for _, screen in ipairs({
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 },
	{ 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 },
	{ 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}) do
	env.GetPhysicalScreenSize = function() return screen[1], screen[2] end
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	for _, user in ipairs({ 0.6, 16 / 19, 1.25 }) do
		assert(K.Scale.SetUserScale(user))
		K.Options.Write("Cooldowns", "path", "mirror")
		local row = ns.Mirror.Row("essential")
		local icon = row.icons[1]
		local holder = assert(Geometry.Rect(row.holder, K.Scale.Root()))
		local socket = assert(Geometry.Rect(icon, K.Scale.Root()))
		icon:SetCount("3")
		for _, text in ipairs({ "4", "12", "2m", "3h" }) do
			icon.countdown:SetText(text)
			for pass = 1, 2 do
				if pass == 2 then icon:Restyle() end
				Figure(icon.countdown, icon, 1, 16.5)
				assert(icon.countdown:GetText() == text and icon.count:GetText() == "3", "restyling preserves native long formats and corner charges")
				assert(W.LastCall(icon.cooldown, "SetCountdownFormatter")[1] == nil, "essential formatting stays native and unitless")
			end
		end
		SameRect(holder, row.holder)
		SameRect(socket, icon)
		K.Options.Write("Cooldowns", "path", "reskin")
		for _, itemScale in ipairs({ 0.5, 1, 1.4 }) do
			native:SetScale(itemScale)
			nativeBuff:SetScale(itemScale)
			for _, value in ipairs({ env.Secret("4"), "12", "2m", "3h" }) do
				nativeText:SetText(value)
				nativeCount:SetText("3")
				local writes = #W.Calls(nativeText, "SetText")
				ns.Reskin.Refresh()
				Figure(nativeText, native, itemScale, 16.5)
				local path, size = buffText:GetFont()
				assert(path == K.Tokens.Font("caption") and W.Near(size, K.Widgets.FontSize(buffText, 9 * K.Theme.FontScale() / itemScale)), "tracked captions keep the lighter face and snapped configured size across screens and item scales")
				Integer(size * K.Widgets.ScaleFactor(buffText) / K.Scale.Pixel(1), "the tracked font size")
				assert(#W.Calls(nativeText, "SetText") == writes and W.LastCall(nativeText, "SetText")[1] == value, "native secret and long countdown text passes through untouched")
				assert(W.LastCall(nativeCount, "SetText")[1] == "3", "native charges stay intact")
				assert(W.LastCall(native.Cooldown, "SetCountdownFormatter")[1] == nil, "the reskin keeps native formatting too")
			end
		end
	end
end

local font = K.Tokens.Font("body")
K.Options.Write("Cooldowns", "essential.timerSize", 20)
K.Options.Write("Cooldowns", "essential.countSize", 12)
K.Options.Write("Cooldowns", "timerFont", font)
K.Options.Write("Cooldowns", "timerOutline", "OUTLINE")
assert(K.Theme.SetFontScale(1.2))
K.Callbacks.Fire("ProfileChanged")
for _, path in ipairs({ "mirror", "reskin" }) do
	K.Options.Write("Cooldowns", "path", path)
	local text, frame, scale
	if path == "mirror" then
		frame, scale = ns.Mirror.Row("essential").icons[1], 1
		text = frame.countdown
	else
		frame, scale, text = native, native:GetScale(), nativeText
	end
	Figure(text, frame, scale, 20)
	local actualFont, _, flags = text:GetFont()
	assert(actualFont == font and flags == "OUTLINE", "font and outline choices survive the new default")
	local saved = K.Store.Module("Cooldowns")
	assert(saved.essential.timerSize == 20 and saved.essential.countSize == 12, "explicit previous-size and charge settings are not migrated or overwritten")
	assert(ns.Settings.current.timerFont == font and ns.Settings.current.timerOutline == "OUTLINE", "clean reads preserve selected fonts and outlines")
end

print("cooldowns figure finish ok")
