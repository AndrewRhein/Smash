"""Create a self-contained offline sprite review page; no runtime dependencies."""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT/'art/characters/gandalf/manifest.json').read_text())
records = []
for name, record in data['animations'].items():
    records.append({'name':name,'count':record['frame_count'],'fps':record['fps'],'loop':record['loop'],
                    'image':'data:image/png;base64,'+base64.b64encode((ROOT/'art/characters/gandalf'/record['texture']).read_bytes()).decode()})
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Realms Rumble — character animation review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#0e1420;color:#dce5f2;font:15px system-ui,sans-serif}header{padding:30px 36px 18px;border-bottom:1px solid #28364d}h1{margin:0 0 8px;font-size:27px;letter-spacing:.04em}p{color:#9eafc8;line-height:1.5;margin:8px 0}.tag{color:#7ed8ff}nav{position:sticky;top:0;z-index:2;background:#121c2af5;padding:14px 36px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #28364d}button,select{background:#273c54;color:#eef7ff;border:1px solid #45617e;border-radius:6px;padding:9px 15px;cursor:pointer}button:hover{background:#355370}label{display:flex;gap:8px;align-items:center}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px}article{border:1px solid #28364d;border-radius:10px;background:#172132;overflow:hidden}h2{font-size:14px;margin:15px 16px 5px;text-transform:uppercase;letter-spacing:.09em}.meta{margin:0 16px;color:#8ca4c3;font-size:12px}canvas{display:block;margin:auto;width:256px;height:256px;image-rendering:pixelated}footer{padding:12px 36px 30px;color:#9eafc8}.warn{color:#f2c784}a{color:#8cdbff}input{accent-color:#7ed8ff}
</style><header><div class="tag">REALMS RUMBLE / ART REVIEW BUILD</div><h1>Gandalf · 14 animation states</h1><p>70 playback frames · 67 distinct source poses · transparent sprites · shared palette</p><p class="warn">Vader artwork is unavailable: image generation was blocked. These are review assets, not a finished match.</p></header>
<nav><button id="pause">Pause</button><button id="replay">Replay all</button><button id="step">Step 1/12 s</button><label>Speed <select id="speed"><option value="0.25">0.25×</option><option value="0.5">0.5×</option><option value="1" selected>1×</option><option value="2">2×</option></select></label><label><input id="flip" type="checkbox">Mirror</label><label><input id="repeat" type="checkbox" checked>Repeat actions</label><span id="clock"></span></nav>
<main id="grid"></main><footer>Character size here is 112 pixels tall when standing. Use the Godot art lab for a 3× view and procedural effects. Repeated poses in casting sequences are intentional holds replacing invalid generated frames. Timing here is visual playback only; gameplay owns hit timing.</footer>
<script>
const records=__DATA__;
let elapsed=0,paused=false,last=performance.now(),ready=0;
const items=records.map(record=>{const article=document.createElement('article');const heading=document.createElement('h2');heading.textContent=record.name.replaceAll('_',' ');article.append(heading);const meta=document.createElement('div');meta.className='meta';article.append(meta);const canvas=document.createElement('canvas');canvas.width=256;canvas.height=256;canvas.setAttribute('aria-label',record.name+' animation preview');article.append(canvas);document.getElementById('grid').append(article);const image=new Image();image.onload=()=>{ready++;draw()};image.src=record.image;return{...record,image,canvas,ctx:canvas.getContext('2d'),meta}});
function draw(){const flipped=document.getElementById('flip').checked;const repeat=document.getElementById('repeat').checked;for(const item of items){const c=item.ctx;c.clearRect(0,0,256,256);c.imageSmoothingEnabled=false;c.strokeStyle='#293c54';c.beginPath();c.moveTo(0,208.5);c.lineTo(256,208.5);c.stroke();let time=elapsed;if(!item.loop&&repeat)time%=Math.max(1.6,item.count/item.fps+.6);let frame=Math.floor(time*item.fps);frame=item.loop?frame%item.count:Math.min(frame,item.count-1);c.save();if(flipped){c.translate(256,0);c.scale(-1,1)}if(item.image.complete&&item.image.naturalWidth)c.drawImage(item.image,frame*256,0,256,256,0,0,256,256);c.restore();item.meta.textContent=`${frame+1}/${item.count} frames · ${item.fps} fps · ${item.loop?'loop':'one-shot'}`;item.canvas.dataset.frame=frame;}document.getElementById('clock').textContent=elapsed.toFixed(2)+' s';}
function tick(now){if(!paused)elapsed+=Math.min((now-last)/1000,.1)*Number(document.getElementById('speed').value);last=now;draw();requestAnimationFrame(tick)}
document.getElementById('pause').onclick=()=>{paused=!paused;document.getElementById('pause').textContent=paused?'Resume':'Pause'};
document.getElementById('replay').onclick=()=>{elapsed=0;draw()};
document.getElementById('step').onclick=()=>{paused=true;document.getElementById('pause').textContent='Resume';elapsed+=1/12;draw()};
document.getElementById('flip').onchange=draw;document.getElementById('repeat').onchange=draw;
window.artReview={get loaded(){return ready},get time(){return elapsed},get paused(){return paused}};
requestAnimationFrame(tick);
</script></html>'''
target = ROOT/'art/previews/character_gallery.html'
target.write_text(page.replace('__DATA__',json.dumps(records)),encoding='utf-8')
print(target)
