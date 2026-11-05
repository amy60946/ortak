# App Store rakip ekran görüntülerini indirip uygulama başına tek pano (contact sheet) yapar.
# Kaynak: Apple iTunes Search / Lookup API (anahtar gerekmez). Ağ: apps.apple.com, itunes.apple.com,
# is1..is5-ssl.mzstatic.com (Default ortamına 4 Kasım 2026'da eklendi).
# Kullanım:
#   python3 fetch_shots.py ara "SimplePractice" "TherapyNotes"        # kimlik bul (ABD mağazası)
#   python3 fetch_shots.py indir gruplar.json <çıktı klasörü>          # panolar + meta.json
# gruplar.json: {"g1": [["Ad", trackId, "us"|"tr"], ...], "g2": [...]}
# Panoları ana pencereye değil alt ajana inceletin (ortak CLAUDE.md kural 8). Görseller rakibe aittir:
# yalnız iç benchmark için; depoya, yayına ya da paylaşılan sayfaya konmaz.
import json, os, re, sys, time, urllib.request, urllib.parse
from PIL import Image, ImageDraw, ImageFont

UA = {'User-Agent': 'Mozilla/5.0 benchmark-script'}

def get(url, raw=False):
    err = None
    for i in range(4):  # ardışık isteklerde 403 olabiliyor: bekleyip yeniden dene
        try:
            r = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30)
            return r.read() if raw else json.load(r)
        except Exception as e:
            err = e; time.sleep(3 * (i + 1))
    raise err

def ara(terms, country='us'):
    for t in terms:
        q = urllib.parse.urlencode({'term': t, 'entity': 'software', 'limit': 3, 'country': country})
        for r in get('https://itunes.apple.com/search?' + q)['results']:
            print(f"{t[:22]:22} | {r['trackId']} | {r['trackName'][:44]:44} | {r.get('sellerName', '')[:24]:24} | puan {r.get('userRatingCount', 0)}")
        time.sleep(1.5)

def indir(groups_file, out, n_iphone=8, n_ipad=0):
    groups = json.load(open(groups_file)); os.makedirs(out, exist_ok=True); meta = {}
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
    except Exception: font = ImageFont.load_default()
    for g, apps in groups.items():
        for name, tid, country in apps:
            res = get(f'https://itunes.apple.com/lookup?id={tid}&country={country}')['results']
            if not res: print('yok', name); continue
            r = res[0]
            for kind, urls in (('iphone', r.get('screenshotUrls', [])[:n_iphone]), ('ipad', r.get('ipadScreenshotUrls', [])[:n_ipad])):
                if not urls: continue
                size = '300x650bb.jpg' if kind == 'iphone' else '480x640bb.jpg'
                imgs = []
                for u in urls:
                    p = os.path.join(out, '_tmp.jpg')
                    open(p, 'wb').write(get(re.sub(r'/[^/]+$', '/' + size, u), raw=True))
                    imgs.append(Image.open(p).convert('RGB'))
                h = max(i.height for i in imgs); w = sum(i.width for i in imgs) + 10 * (len(imgs) - 1)
                sheet = Image.new('RGB', (w, h + 40), 'white')
                ImageDraw.Draw(sheet).text((6, 6), f"{name} ({country}, {kind}) — mağaza sırası 1..{len(imgs)}", fill='black', font=font)
                x = 0
                for i in imgs: sheet.paste(i, (x, 40)); x += i.width + 10
                fn = f"{g}_{re.sub(r'[^a-z0-9]+', '-', name.lower())}_{country}_{kind}.jpg"
                sheet.save(os.path.join(out, fn), quality=85)
                meta[fn] = {'app': r['trackName'], 'seller': r.get('sellerName'), 'ratings': r.get('userRatingCount'),
                            'rating': r.get('averageUserRating'), 'genre': r.get('primaryGenreName'),
                            'n_iphone': len(r.get('screenshotUrls', [])), 'n_ipad': len(r.get('ipadScreenshotUrls', [])),
                            'url': r.get('trackViewUrl'), 'desc_start': (r.get('description') or '')[:400]}
                print('ok', fn, len(imgs))
            time.sleep(1)
    json.dump(meta, open(os.path.join(out, 'meta.json'), 'w'), ensure_ascii=False, indent=1)
    if os.path.exists(os.path.join(out, '_tmp.jpg')): os.remove(os.path.join(out, '_tmp.jpg'))

if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == 'ara': ara(sys.argv[2:])
    elif len(sys.argv) > 3 and sys.argv[1] == 'indir': indir(sys.argv[2], sys.argv[3], n_ipad=int(os.environ.get('IPAD', '0')))
    else: print(__doc__ if __doc__ else open(__file__).read().split('import')[0])
