# contact.py <stills-folder> <out.png> <series name> <note> — grid contact sheet of <id>.png stills with captions.
import sys, os, math
from PIL import Image, ImageDraw, ImageFont
d, out, name, note = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else ''
ids = sorted(int(f[:-4]) for f in os.listdir(d) if f.endswith('.png') and f[:-4].isdigit())
n = len(ids); cols = min(n, 2 if n <= 4 else 4 if n <= 16 else 5); rows = math.ceil(n / cols)
T = 480 if n <= 4 else 320 if n <= 16 else 240; PAD, CAP, HEAD = 12, 28, 40
def font(sz):
    for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf']:
        if os.path.exists(f): return ImageFont.truetype(f, sz)
    return ImageFont.load_default(size=sz)
W = cols * T + (cols + 1) * PAD; H = HEAD + rows * (T + CAP) + PAD
sheet = Image.new('RGB', (W, H), (24, 24, 24)); dr = ImageDraw.Draw(sheet)
dr.text((PAD, 12), f'{name} #{ids[0]}–#{ids[-1]} ({n} still{"s" if n != 1 else ""}) — {note}', fill=(235, 235, 235), font=font(15))
for i, tid in enumerate(ids):
    im = Image.open(os.path.join(d, f'{tid}.png')).convert('RGB'); w, h = im.size
    x = PAD + (i % cols) * (T + PAD); y = HEAD + (i // cols) * (T + CAP)
    sheet.paste(im.resize((T, T), Image.LANCZOS), (x, y))
    dr.text((x, y + T + 6), f'{name} #{tid}  ({w}x{h})', fill=(220, 220, 220), font=font(13))
sheet.save(out, 'PNG', optimize=True)
print(out, sheet.size)
