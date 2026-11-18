-- test-setup-welcome.lua: welcome branding fits the supported screens, scrolls at the text floor, and switches back to the original page without a reload.
local W = dofile("Tools/regression/widget_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local Guard = dofile("Tools/render/guard.lua")

local function boot(screen, style, locale, size)
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
		assert(K.Tokens.Texture("logoLarge"):match("%.tga$"), "use the client's TGA logo texture, not an unproven PNG path")
		assert(page.scroll:IsShown() and not page.classic:IsShown(), "the branded page opens")
		assert(page.branded:GetHeight() <= page.scroll:GetHeight() + 1, "all English welcome content fits without scrolling at Auto")
		local scene = clean(env)
		local logo, pictures, version = false, 0, false
		for _, item in ipairs(scene.items) do
			if item.path == K.Tokens.Texture("logoLarge") then logo = true end
			if item.file and item.file:match("HudStyle.*%.png$") then pictures = pictures + 1 end
			if item.kind == "text" and item.text == K.VERSION then version = true end
		end
		assert(logo and pictures == 3 and version, "welcome shows the logo, three HUD pictures and addon version")
		K.Options.Write("Widgets", "general.brandedWelcome", false)
		assert(page.classic:IsShown() and not page.scroll:IsShown(), "turning branding off immediately restores the original page")
		assert(K.Setup.window.welcomeTitle:GetText() == K.L["Welcome to KstyleUI"], "the original welcome copy returns")
		local classic = Scene.ToJSON(clean(env))
		K.Options.Write("Widgets", "general.brandedWelcome", true)
		clean(env)
		K.Options.Write("Widgets", "general.brandedWelcome", false)
		assert(Scene.ToJSON(clean(env)) == classic, "turning branding off again restores identical original pixels and text")
		collectgarbage("collect")
	end
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
	do
		local env, _, page = boot({ 1920, 1080 }, "Frames", locale)
		clean(env)
		assert(page.branded:GetHeight() <= page.scroll:GetHeight() + 1, locale .. ": the whole welcome fits at Auto")
	end
	local env, K, page = boot({ 1920, 1080 }, "Frames", locale, 0.6)
	clean(env, page)
	local scroll = page.scroll
	for _ = 1, 30 do scroll:GetScript("OnMouseWheel")(scroll, -1) end
	assert(scroll:GetVerticalScroll() == math.max(0, page.branded:GetHeight() - scroll:GetHeight()), "the smallest interface size can reach all welcome content")
	clean(env, page)
	local _, noteY, _, noteHeight = Scene.Rect(env, K.Setup.window.welcomeNote)
	local _, viewY, _, viewHeight = Scene.Rect(env, scroll)
	assert(noteY >= viewY and noteY + noteHeight <= viewY + viewHeight + 1, string.format("scrolling reaches the full close note at the text floor: %s note %.1f..%.1f, view %.1f..%.1f", locale, noteY, noteY + noteHeight, viewY, viewY + viewHeight))
	collectgarbage("collect")
end

local f = assert(io.open("Media/Logo/Logo256.tga", "rb"))
local header = f:read(18)
f:close()
assert(header:byte(3) == 2 and header:byte(13) == 0 and header:byte(14) == 1 and header:byte(15) == 0 and header:byte(16) == 1 and header:byte(17) == 32,
	"ship the welcome logo as a 256x256 RGBA TGA, a texture format proven in Forever's Camelot/FriendsFrame.lua")
rawset(_G, "RENDER_SCREEN", nil)
rawset(_G, "RENDER_HUD_STYLE", nil)
rawset(_G, "RENDER_LOCALE", nil)
print("setup welcome: screens, HUD styles, locales, text floor, original-page toggle and client logo format OK")
