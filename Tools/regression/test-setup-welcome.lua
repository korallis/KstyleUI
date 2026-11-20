-- test-setup-welcome.lua: welcome branding fits the supported screens, scrolls at the text floor, and switches back to the original page without a reload.
local W = dofile("Tools/regression/widget_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local Guard = dofile("Tools/render/guard.lua")
local Audit = dofile("Tools/regression/pixel_audit_lib.lua")

local function boot(screen, style, locale, size, version)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = size or "auto" })
	rawset(_G, "RENDER_HUD_STYLE", style)
	rawset(_G, "RENDER_LOCALE", locale)
	local env, K = W.New(Common.ScreenOpts({
		saved = Gallery.Saved({}),
		boot = false,
		setup = function(env)
			Gallery.Setup(env)
			env._textWidth = function(text, path, points)
				return Scene.TextWidth(Scene.PlainText(text), points, path)
			end
		end,
	}))
	W.CoreEnv.Boot(env)
	if version then K.VERSION = version end
	assert(K.Setup.Open(true))
	W.Settle(env)
	return env, K, K.Setup.window.pages[1]
end

local function clean(env, root)
	local scene = Scene.Build(env, root and { roots = { root } } or nil)
	local findings = Guard.Check(scene)
	assert(#findings == 0, "welcome must fit: " .. (findings[1] and findings[1].subject or ""))
	assert(#env._errors == 0, tostring(env._errors[1]))
	return scene
end

for _, screen in ipairs({ { 1920, 1080 }, { 3456, 2234 }, { 5120, 1440 } }) do
	for _, style in ipairs({ "Frames", "Orbs", "Medallions" }) do
		local env, K, page = boot(screen, style, "enUS")
		assert(K.Options.Read("Widgets", "general.brandedWelcome") == true, "branding is on by default")
		assert(K.Tokens.Texture("logoLarge"):match("%.tga$"), "the selected logo export is TGA; keep its token and asset format in sync")
		assert(page.scroll:IsShown() and not page.classic:IsShown(), "the branded page opens")
		assert(page.branded:GetHeight() <= page.scroll:GetHeight() + 1, "all English welcome content fits without scrolling at Auto")
		local scene = clean(env)
		local logo, pictures = false, 0
		for _, item in ipairs(scene.items) do
			if item.path == K.Tokens.Texture("logoLarge") then logo = true end
			if item.file and item.file:match("HudStyle.*%.png$") then
				assert(item.path:match("%.tga$"), "HUD preview tokens select TGA and Chrome uses PNG companions")
				pictures = pictures + 1
			end
			assert(item.kind ~= "text" or not item.text:find("@project-version@", 1, true), "hide the unpackaged version marker in a checkout")
		end
		assert(logo and pictures == 3, "welcome shows the logo and three HUD pictures")
		assert(page.branded.version:GetText() == "", "a checkout hides the unpackaged version marker")
		K.Options.Write("Widgets", "general.brandedWelcome", false)
		assert(page.classic:IsShown() and not page.scroll:IsShown(), "turning branding off immediately restores the original page")
		assert(K.Setup.window.welcomeTitle:GetText() == K.L["Welcome to KstyleUI"], "the original welcome copy returns")
		local classic = Scene.ToJSON(clean(env))
		K.Options.Write("Widgets", "general.brandedWelcome", true)
		clean(env)
		K.Options.Write("Widgets", "general.brandedWelcome", false)
		assert(Scene.ToJSON(clean(env)) == classic, "turning branding off again restores identical original pixels and text")
		K.Setup.Keep()
		K.Setup.window:Close()
		assert(page.classic.note:IsShown(), "retain the original close note during the first-run closing fade")
		collectgarbage("collect")
	end
end

do
	local _, _, page = boot({ 1920, 1080 }, "Frames", "enUS", nil, "v0.2.6")
	assert(page.branded.version:GetText() == "v0.2.6", "packaged builds show their addon version")
end

do
	local env, K, page = boot({ 1920, 1080 }, "Medallions", "enUS")
	K.Theme.SetFontScale(K.Theme.MAX_FONT_SCALE)
	K.Theme.SetTypeSet("Lumen")
	clean(env, page)
	K.Setup.Open(false)
	W.Settle(env)
	assert(not K.Setup.window.welcomeNote:IsShown(), "reopening setup hides the first-run close promise")
	K.Setup.Open(true)
	W.Settle(env)
	assert(K.Setup.window.welcomeNote:IsShown(), "opening for first run restores and reflows the close note")
	clean(env, page)
end

for _, locale in ipairs({ "deDE", "frFR", "esES", "zhCN" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 3456, 2234 }, { 5120, 1440 } }) do
		local env, _, page = boot(screen, "Frames", locale)
		clean(env)
		assert(page.branded:GetHeight() <= page.scroll:GetHeight() + 1, string.format("%s at %dx%d: fit the whole welcome at Auto (content %.2f, view %.2f)", locale, screen[1], screen[2], page.branded:GetHeight(), page.scroll:GetHeight()))
		collectgarbage("collect")
	end
	local env, K, page = boot({ 1920, 1080 }, "Frames", locale, 0.6)
	K.Theme.SetFontScale(K.Theme.MAX_FONT_SCALE)
	W.Settle(env)
	clean(env, page)
	local scroll = page.scroll
	scroll:GetScript("OnMouseWheel")(scroll, -1)
	local offset = scroll:GetVerticalScroll() / K.Widgets.Snap(scroll, K.Scale.Pixel(1))
	assert(math.abs(offset - math.floor(offset + 0.5)) < 0.01, "snap welcome scrolling to whole physical pixels")
	local offenders = Audit.Check(clean(env, page), 1080)
	assert(#offenders == 0, "keep the scrolled welcome on the pixel grid: " .. table.concat(Audit.Lines("welcome", offenders), "\n"))
	local viewX, _, viewWidth = Scene.Rect(env, scroll)
	local thumbX = Scene.Rect(env, page.bar)
	local overflow = page.branded:GetHeight() > scroll:GetHeight() + 1
	assert(page.bar:IsShown() == overflow, "show the scroll thumb when welcome content overflows")
	assert(not overflow or thumbX > viewX + viewWidth, "keep the scroll thumb beside the content, where the banner cannot cover it")
	for _ = 1, 30 do scroll:GetScript("OnMouseWheel")(scroll, -1) end
	assert(math.abs(scroll:GetVerticalScroll() - math.max(0, page.branded:GetHeight() - scroll:GetHeight())) < 1, "the smallest interface size can reach all welcome content")
	clean(env, page)
	local _, noteY, _, noteHeight = Scene.Rect(env, K.Setup.window.welcomeNote)
	local _, viewY, _, viewHeight = Scene.Rect(env, scroll)
	assert(noteY >= viewY and noteY + noteHeight <= viewY + viewHeight + 1, string.format("scrolling reaches the full close note at the text floor: %s note %.1f..%.1f, view %.1f..%.1f", locale, noteY, noteY + noteHeight, viewY, viewY + viewHeight))
	collectgarbage("collect")
end

for _, locale in ipairs({ "enUS", "deDE", "frFR", "esES", "zhCN" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local env, K, page = boot(screen, "Frames", locale, "default")
		K.Layout.Set("setup.window", "scale", 0.9)
		W.Settle(env)
		clean(env)
		local _, noteY, _, noteHeight = Scene.Rect(env, K.Setup.window.welcomeNote)
		local _, viewY, _, viewHeight = Scene.Rect(env, page.scroll)
		assert(page.branded:GetHeight() <= page.scroll:GetHeight() + 1 and noteY >= viewY and noteY + noteHeight <= viewY + viewHeight + 1,
			string.format("%s at %dx%d, the pre-Auto size and a 0.9 window: grow the window so the close note shows without scrolling (content %.1f, view %.1f)",
				locale, screen[1], screen[2], page.branded:GetHeight(), page.scroll:GetHeight()))
		collectgarbage("collect")
	end
end

local f = assert(io.open("Media/Logo/Logo256.tga", "rb"))
local header = f:read(18)
f:close()
assert(header:byte(3) == 2 and header:byte(13) == 0 and header:byte(14) == 1 and header:byte(15) == 0 and header:byte(16) == 1 and header:byte(17) == 32,
	"the selected welcome logo export must be a 256x256 RGBA TGA matching its PNG companion")
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
rawset(_G, "RENDER_LOCALE", nil)
print("setup welcome: screens, HUD styles, locales, text floor, original-page toggle and logo export format OK")
