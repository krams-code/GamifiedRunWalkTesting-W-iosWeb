import json, sys, os
from playwright.sync_api import sync_playwright
from PIL import Image, ImageDraw
HTML = """<html><body style='margin:0;background:%s'><div id=c style='width:%dpx;height:%dpx'></div>
<script src='file://%s/node_modules/lottie-web/build/player/lottie.min.js'></script></body></html>"""
base = os.getcwd()
BG = {'confetti':'#2b3a67','default':'#2f3a5e'}
names = sys.argv[1:] or [f[:-5] for f in sorted(os.listdir('out'))]
frames_for = {
 'unlock_burst':[0,5,10,16,24,34],'confetti':[6,26,46,66,86,110],'level_burst':[0,15,30,45,60,75],
 'coin_spin':[0,8,16,24,32,42],'gem_pop':[3,8,12,18,26,40],'run_loader':[0,4,8,12,16,20],
 'pointing_hand':[0,6,10,14,20,30],'arrow_bounce':[0,6,12,15,22,28]}
os.makedirs('prev', exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch()
    for n in names:
        data = json.load(open(f'out/{n}.json'))
        w,h = data['w'],data['h']
        sc = 220/max(w,h)
        pg = b.new_page(viewport={'width':w,'height':h}, device_scale_factor=sc)
        open('t.html','w').write(HTML%(BG.get(n,BG['default']),w,h,base))
        pg.goto('file://'+base+'/t.html')
        pg.evaluate("d=>{window.a=lottie.loadAnimation({container:document.getElementById('c'),renderer:'svg',loop:false,autoplay:false,animationData:d});}", data)
        pg.wait_for_timeout(300)
        ims=[]
        for f in frames_for[n]:
            pg.evaluate("f=>window.a.goToAndStop(f,true)", f)
            pg.wait_for_timeout(60)
            pg.screenshot(path='prev/_f.png')
            ims.append(Image.open('prev/_f.png').convert('RGB'))
        W,H = ims[0].size
        S = Image.new('RGB',(W*len(ims), H+16),(20,24,40))
        d = ImageDraw.Draw(S)
        for i,im in enumerate(ims):
            S.paste(im,(i*W,16)); d.text((i*W+4,2),f'{n} f{frames_for[n][i]}',fill=(255,255,255))
        S.save(f'prev/{n}.png'); pg.close()
    b.close()
print('ok')
