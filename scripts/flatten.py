# flatten.py <in.png> <out.png> — composite the RGBA canvas over the page's #000 background -> RGB PNG
import sys; from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA'); bg = Image.new('RGBA', im.size, (0, 0, 0, 255))
Image.alpha_composite(bg, im).convert('RGB').save(sys.argv[2], 'PNG')
