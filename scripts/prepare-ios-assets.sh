#!/bin/bash
# Derive Apple's required icon size from the original Android brand artwork.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$PROJECT_ROOT/ios/Meteor/Assets.xcassets/MeteorLogo.imageset/MeteorLogo.png"
OUTPUT="$PROJECT_ROOT/ios/Meteor/Assets.xcassets/AppIcon.appiconset/AppIcon.generated.png"
/usr/bin/sips --resampleHeightWidth 1024 1024 "$SOURCE" --out "$OUTPUT" >/dev/null
python3 - "$OUTPUT" <<'PY'
import struct, sys
from pathlib import Path
header = Path(sys.argv[1]).read_bytes()[:26]
if header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', header[16:24]) != (1024, 1024) or header[25] != 2:
    raise SystemExit('App icon must be an opaque 1024 x 1024 RGB PNG.')
print('App icon prepared: opaque 1024 x 1024 RGB PNG.')
PY
