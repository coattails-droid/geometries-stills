# flatten.py <in.png> <out.png> [size] — composite the RGBA canvas over the page's #000 background -> RGB PNG.
# If size is given and differs from the canvas, Lanczos-resize to size x size (Luminous: 900 -> 1000).
import sys; from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA'); bg = Image.new('RGBA', im.size, (0, 0, 0, 255))
out = Image.alpha_composite(bg, im).convert('RGB')
size = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 0
if size and out.size != (size, size):
    out = out.resize((size, size), Image.LANCZOS); out.save(sys.argv[2], 'PNG', optimize=True)
else:
    out.save(sys.argv[2], 'PNG')
