# mkzip.py <folder> <out.zip> — zip the folder itself at the zip root (folder/1.png, ...), sorted numerically,
# fixed timestamps so the zip is reproducible.
import sys, os, zipfile
d, out = sys.argv[1].rstrip('/'), sys.argv[2]; base = os.path.basename(d)
files = sorted(os.listdir(d), key=lambda f: (int(f.split('.')[0]) if f.split('.')[0].isdigit() else 1e9, f))
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    zi = zipfile.ZipInfo(f'{base}/', (2026, 1, 1, 0, 0, 0)); zi.external_attr = 0o40755 << 16; z.writestr(zi, b'')
    for f in files:
        zi = zipfile.ZipInfo(f'{base}/{f}', (2026, 1, 1, 0, 0, 0)); zi.compress_type = zipfile.ZIP_DEFLATED; zi.external_attr = 0o644 << 16
        z.writestr(zi, open(os.path.join(d, f), 'rb').read())
