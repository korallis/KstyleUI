-- About.lua: the About page's Status section: the load check switch, each KstyleUI part's state, the setup in use, other addons and a copyable report.
local _, ns = ...

local K = KstyleUI
local L = K.L

function ns.StatusItems(add, SelectLater)
	add({ kind = "header", level = 1, label = L["Status"] })
	add({ kind = "toggle", label = L["Load check"], help = L["Warns once after login when part of KstyleUI fails to load, and lists each part's state here."],
		get = function() return K.Store.Account().healthChecks ~= false end,
		set = function(value) K.Store.Account().healthChecks = value; ns.Changed() end })
	if K.Store.Account().healthChecks == false then return end
	local Health, setup, modules, addons = K.Health, {}, {}, {}
	for _, fact in ipairs(Health.Facts()) do
		local list = fact.addons and addons or setup
		list[#list + 1] = fact.label .. ": " .. fact.text
	end
	for _, row in ipairs(Health.Modules()) do modules[#modules + 1] = row.label .. ": " .. Health.Text(row) end
	add({ kind = "note", label = table.concat(setup, "\n") })
	add({ kind = "header", level = 2, label = L["Modules"] })
	add({ kind = "note", label = table.concat(modules, "\n") })
	add({ kind = "header", level = 2, label = L["Existing addons"] })
	add({ kind = "note", label = table.concat(addons, "\n") })
	add({
		kind = "button", label = L["Copy report"], help = L["A one-line summary of this section for Discord, with no character or account details."],
		buttons = { { label = L["Copy"], onClick = function()
			SelectLater(K.Widgets.Popup({ title = L["Copy report"], text = L["Press Ctrl+C to copy this string, then share it."],
				editBox = { text = Health.Report() }, buttons = { { label = L["Close"], primary = true } } }))
		end } },
	})
end
