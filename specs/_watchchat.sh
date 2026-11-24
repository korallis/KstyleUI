# watchchat [since-iso]: wait (up to ~115 min) for #chat messages from anyone but Korallis newer than since; print them as JSON and exit
since=${1:-$(date -u +%Y-%m-%dT%H:%M:%S)}
q() {
	orca tab switch --index 2 >/dev/null 2>&1
	orca eval --expression "(()=>{const b=document.querySelector('[class*=jumpToPresent] button');if(b)b.click();let out=[],cur='';for(const li of document.querySelectorAll('li[id^=chat-messages]')){const u=(li.querySelector('[id^=message-username] span')||{}).innerText;if(u)cur=u;const tm=(li.querySelector('time')||{}).dateTime||'';if(cur!=='Korallis'&&tm>'$since')out.push({u:cur,time:tm,t:(li.querySelector('[id^=message-content]')||{}).innerText,imgs:[...li.querySelectorAll('a[href*=\"cdn.discordapp.com/attachments\"]')].map(a=>a.href)})}return JSON.stringify(out)})()" 2>/dev/null | tail -1
}
for i in $(seq 1 115); do
	r=$(q)
	if [ -n "$r" ] && [ "$r" != "[]" ]; then sleep 120; q; exit 0; fi
	sleep 60
done
echo "none since $since"
