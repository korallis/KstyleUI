# watchchat [since-iso]: wait (up to ~115 min) for #chat messages from anyone but Korallis newer than since that look like KstyleUI talk
# (an image, a mention, or a word like bug/error/kstyle/setup/map); print every new message as JSON and exit. Casual chat alone does not wake.
since=${1:-$(date -u +%Y-%m-%dT%H:%M:%S)}
q() {
	orca tab switch --index 2 >/dev/null 2>&1
	orca eval --expression "(()=>{const b=document.querySelector('[class*=jumpToPresent] button');if(b)b.click();let out=[],cur='';for(const li of document.querySelectorAll('li[id^=chat-messages]')){const u=(li.querySelector('[id^=message-username] span')||{}).innerText;if(u)cur=u;const tm=(li.querySelector('time')||{}).dateTime||'';if(cur!=='Korallis'&&tm>'$since')out.push({u:cur,time:tm,t:(li.querySelector('[id^=message-content]')||{}).innerText,imgs:[...li.querySelectorAll('a[href*=\"cdn.discordapp.com/attachments\"]')].map(a=>a.href),men:!!li.querySelector('[class*=mentioned]')})}return JSON.stringify(out)})()" 2>/dev/null | tail -1
}
hot='"men":true|cdn\.discordapp|[Kk]style|[Bb]ug|[Ee]rror|[Ll]ua|[Ff]ix|[Bb]roke|[Ss]etup|[Mm]ap|[Cc]rest|[Ff]rame|[Bb]ar|[Aa]ddon|[Cc]rash|[Tt]aint|[Ii]ssue|[Pp]roblem|[Ff]eature|[Uu]pdate|[Rr]elease|[Ss]kin|[Tt]ooltip|[Bb]ag|[Mm]edall|[Tt]rack|[Rr]une|[Ss]pell|[Cc]ooldown|[Bb]uff'
for i in $(seq 1 115); do
	r=$(q)
	if echo "$r" | grep -qE "$hot"; then sleep 120; q; exit 0; fi
	sleep 60
done
echo "quiet since $since:"; q
