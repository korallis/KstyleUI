-- test-chat-alignment.lua: native resize constraints, dock scale and optional side buttons stay inside the card at every supported screen.
local C = dofile("Tools/regression/chat_env.lua")
local G = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ {1920,1080}, {2560,1440}, {3440,1440}, {3456,2234}, {3840,2160}, {5120,1440} }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local env, K, ns = C.New({ width = screen[1], height = screen[2], setup = function(e)
			e._size, e._fitScale = "auto", true
			e.ChatFrame1.SetResizeBounds = function(self, ...) self._bounds = {...} end
			e.ChatFrame1.GetResizeBounds = function(self) return unpack(self._bounds) end
			e.ChatFrame1:SetResizeBounds(250, 120, 800, 800)
		end })
		C.Enable(env, K)
		local function check()
			local root, chat = K.Scale.Root(), env.ChatFrame1
			local card = assert(G.ScaledRect(ns.Panel.Holder(), env.UIParent, root))
			local message = assert(G.ScaledRect(chat, env.UIParent, root))
			local k = chat:GetEffectiveScale() / root:GetEffectiveScale()
			local minW, minH = chat:GetResizeBounds()
			local label = screen[1] .. "x" .. screen[2] .. " " .. style
			assert(minW*k + ns.Panel.Geometry(chat).left + ns.Panel.Geometry(chat).right >= 260 - 0.01 and minH*k + ns.Panel.Geometry(chat).top + ns.Panel.Geometry(chat).bottom >= 120 - 0.01, "native resizing must retain the card's sensible 260 by 120 minimum")
			assert((message.right-message.left)/k >= minW and (message.top-message.bottom)/k >= minH,
				label .. ": lower Blizzard's resize bounds while the card controls the message frame")
			C.Dock(env, function(text, size) return #text * size / 2 end)
			ns.Frames.FitTabs(env.GENERAL_CHAT_DOCK)
			for _, tab in ipairs({env.ChatFrame1Tab, env.ChatFrame2Tab}) do
				tab.Text:SetHeight(select(2, tab.Text:GetFont()))
				local text = assert(G.ScaledRect(tab.Text, env.UIParent, root))
				assert(text.top < card.top and text.bottom > message.top and text.left >= card.left,
					label .. ": anchor the tab row inside the card's header")
			end
			if K.Store.Module("Chat").buttons then
				local column = assert(G.ScaledRect(chat.buttonFrame, env.UIParent, root))
				assert(G.Outside(column, card) < K.Scale.Pixel(1), label .. ": reserve the side buttons inside the card")
				assert(column.right < message.left, label .. ": side buttons must leave the message text clear")
			end
		end
		env.RunTimers()
		check()
		K.Options.Write("Chat", "buttons", true)
		K.Layout.Update("chat.main", {width=300, height=240, x=70, y=45}, true)
		env.RunTimers()
		check()
		env.ChatFrame1:ClearAllPointsBase()
		env.ChatFrame1:SetPointBase("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 100, 150)
		env.ChatFrame1:SetSize(280, 160)
		env.ChatFrame1._rect = {100, 150, 280, 160}
		env.FCF_SavePositionAndDimensions(env.ChatFrame1)
		env.ChatFrame1._rect = nil
		env.RunTimers()
		assert(K.Layout.Get("chat.main").x ~= 70, "a native chat move updates the card's saved position")
		check()
		K.Modules.Disable("Chat")
		assert(select(2, env.ChatFrame1:GetResizeBounds()) == 120, "restore Blizzard's minimum when Chat is disabled")
	end
end
print("chat alignment: six screens, three styles, move/resize and side buttons ok")
