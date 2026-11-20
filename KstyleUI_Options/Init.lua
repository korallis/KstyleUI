-- Init.lua: the KstyleUI_Options addon table, which the module's files share.
local addonName, ns = ...

ns.addonName = addonName

local K, L = KstyleUI, KstyleUI.L
K.Store.RegisterDefaults("OptionsWindow", { searchPage = false })
K.Options.Register("OptionsWindow", function() return {
	{ type = "header", label = L["Window conveniences"] },
	{ type = "toggle", key = "searchPage", label = L["Search current page only"], help = L["Searches this page only. Off searches every settings page."] },
} end)

K.Store.RegisterDefaults("OptionsMovers", { moverOptions = false })
K.Options.Register("OptionsMovers", function() return {
	{ type = "toggle", key = "moverOptions", label = L["Double-click movers for settings"], help = L["Opens element settings on double-click. Action bars keep their own shortcut setting."] },
} end)
