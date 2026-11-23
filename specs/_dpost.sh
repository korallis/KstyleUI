# dpost <file> <name> <text>: post one attachment with text to the open Discord channel tab (run from the repo folder)
dpost() {
	local f=$1 name=$2 text=$3 t n=0
	t=$(mktemp -d); base64 -w0 "$f" | split -b 24000 - $t/c
	orca eval --expression "window.__x=[];1" >/dev/null
	for c in $t/c*; do orca eval --expression "window.__x.push(\"$(cat $c)\");1" >/dev/null || { echo "fail at $n"; rm -rf $t; return 1; }; n=$((n+1)); done
	rm -rf $t
	TEXT="$text" NAME="$name" node -e 'process.stdout.write(JSON.stringify([process.env.NAME,process.env.TEXT]))' > /tmp/dpost.json
	orca eval --expression "(()=>{const [name,text]=$(cat /tmp/dpost.json);const bin=atob(window.__x.join(''));const u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);const b=document.querySelector('[role=textbox][contenteditable=true]');b.focus();const dt=new DataTransfer();dt.items.add(new File([u],name,{type:'image/gif'}));b.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));const d2=new DataTransfer();d2.setData('text/plain',text);b.dispatchEvent(new ClipboardEvent('paste',{clipboardData:d2,bubbles:true,cancelable:true}));window.__x=[];return 1})()" >/dev/null
	sleep 2; orca keypress --key Enter >/dev/null; sleep 10
	echo "$name posted ($n chunks)"
}
