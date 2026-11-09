-- Mail.lua: the mail skin: the inbox, the send form and the open letter, with item tiles for every attachment.
local _, ns = ...

local K = KstyleUI
local L = K.L
local Kit = ns.PartBKit
local Skin = K.Skin

local INBOX_ITEMS = 7
local ATTACHMENTS = 16

local function Numbered(prefix, count, fn)
	for i = 1, count do
		local frame = _G[prefix .. i]
		if frame == nil then
			return
		end
		fn(frame)
	end
end

local WINDOW = "mail"

local function Attachment(button)
	Kit.Item(button, { window = WINDOW })
end

local function InboxItem(item)
	Skin.Strip(item)
	local button = item.Button
	if type(button) ~= "table" then
		return
	end
	local name = type(button.GetName) == "function" and button:GetName() or nil
	local cod = name and _G[name .. "CODBackground"] or nil
	Kit.Item(button, { window = WINDOW, keep = { cod } })
end

local function Inbox(frame)
	if not Kit.Have(frame, "InboxFrame") then
		return
	end
	Skin.Strip(frame)
	Numbered("MailItem", INBOX_ITEMS, InboxItem)
	Kit.Arrow(frame.PrevPageButton, "left")
	Kit.Arrow(frame.NextPageButton, "right")
	Kit.Button(frame.OpenAllMail)
end

local function SendForm(frame)
	if not Kit.Have(frame, "SendMailFrame") then
		return
	end
	local keep = {}
	if SendMailErrorCoin then
		keep[SendMailErrorCoin] = true
	end
	Skin.Strip(frame, { keep = keep })
	Kit.InputScroll(SendMailScrollFrame)
	Kit.EditBox(SendMailNameEditBox)
	Kit.EditBox(SendMailSubjectEditBox)
	Numbered("SendMailAttachment", ATTACHMENTS, function(button)
		Kit.Item(button, { window = WINDOW, normal = true })
	end)
	local money = SendMailMoney
	if type(money) == "table" then
		Kit.MoneyBox(money.gold)
		Kit.MoneyBox(money.silver)
		Kit.MoneyBox(money.copper)
	end
	Kit.CheckBox(SendMailSendMoneyButton)
	Kit.CheckBox(SendMailCODButton)
	Kit.Inset(SendMailMoneyInset)
	Skin.Strip(SendMailMoneyBg)
	Kit.Button(SendMailCancelButton)
	Kit.Button(SendMailMailButton)
end

local function Body(body)
	if type(body) ~= "table" or type(body.SetFont) ~= "function" or type(body.GetObjectType) ~= "function" then
		return
	end
	if body:GetObjectType() == "SimpleHTML" then
		ns.Style.Html(body, "body", "textEmphasis")
		return
	end
	Kit.Text(body, "body", "textEmphasis")
	body:SetJustifyH("LEFT")
end

local function Letter(frame)
	if not Kit.Have(frame, "OpenMailFrame") then
		return
	end
	Kit.Window(frame)
	Kit.InputScroll(OpenMailScrollFrame)
	Attachment(OpenMailLetterButton)
	Attachment(OpenMailMoneyButton)
	Numbered("OpenMailAttachmentButton", ATTACHMENTS, Attachment)
	Kit.Button(OpenMailReportSpamButton)
	Kit.Button(OpenMailCancelButton)
	Kit.Button(OpenMailDeleteButton)
	Kit.Button(OpenMailReplyButton)
	Body(OpenMailBodyText)
	ns.Style.Sweep(frame, { onShow = true })
end

local function Apply()
	local frame = MailFrame
	if not Kit.Have(frame, "MailFrame") then
		return false
	end
	Kit.Window(frame)
	Inbox(InboxFrame)
	SendForm(SendMailFrame)
	Letter(OpenMailFrame)
	return true
end

ns.Skins.Add({
	key = WINDOW,
	label = L["Mail"],
	help = L["Restyles the inbox, the send mail form and open letters."],
	addon = "Blizzard_MailFrame",
	frame = "MailFrame",
	defaults = { qualityRims = true },
	rows = {
		{ type = "toggle", key = "qualityRims", label = L["Quality rims"], help = L["Rings each item in the item's quality colour."] },
	},
	Apply = Apply,
})
