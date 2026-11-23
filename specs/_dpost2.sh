# dpost2 <file1> <file2> <text>: post two attachments with text to the open Discord channel tab (run from the repo folder)
dpost2() {
	local text=$3 t i=0 f
	orca eval --expression "window.__f=[];1" >/dev/null
	for f in "$1" "$2"; do
		t=$(mktemp -d); base64 -w0 "$f" | split -b 24000 - $t/c
		orca eval --expression "window.__x=[];1" >/dev/null
		for c in $t/c*; do orca eval --expression "window.__x.push(\"$(cat $c)\");1" >/dev/null || { echo "fail $f"; rm -rf $t; return 1; }; done
		rm -rf $t
		NAME=$(basename "$f") node -e 'process.stdout.write(JSON.stringify(process.env.NAME))' > /tmp/dname.json
		orca eval --expression "(()=>{const name=$(cat /tmp/dname.json);const bin=atob(window.__x.join(''));const u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);window.__f.push(new File([u],name,{type:name.endsWith('.gif')?'image/gif':'image/jpeg'}));window.__x=[];return 1})()" >/dev/null
	done
	TEXT="$text" node -e 'process.stdout.write(JSON.stringify(process.env.TEXT))' > /tmp/dtext.json
	orca eval --expression "(()=>{const text=$(cat /tmp/dtext.json);const b=document.querySelector('[role=textbox][contenteditable=true]');b.focus();const dt=new DataTransfer();for(const f of window.__f)dt.items.add(f);b.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));const d2=new DataTransfer();d2.setData('text/plain',text);b.dispatchEvent(new ClipboardEvent('paste',{clipboardData:d2,bubbles:true,cancelable:true}));window.__f=[];return 1})()" >/dev/null
	sleep 3; orca keypress --key Enter >/dev/null; sleep 12
	echo "posted $(basename "$1")"
}
