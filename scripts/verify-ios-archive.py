#!/usr/bin/env python3
"""Check a real-device Release archive; this never signs or uploads it."""
from pathlib import Path
import json
import plistlib
import subprocess
import sys

archive = Path(sys.argv[1]).resolve()
apps = list((archive / 'Products/Applications').glob('*.app'))
if len(apps) != 1:
    raise SystemExit('Expected exactly one application in the iOS archive.')
app = apps[0]
info = plistlib.loads((app / 'Info.plist').read_bytes())
archive_info = plistlib.loads((archive / 'Info.plist').read_bytes())
if archive_info.get('ApplicationProperties', {}).get('ApplicationPath') != 'Applications/' + app.name:
    raise SystemExit('Xcode produced a generic archive rather than an application archive.')
if info.get('CFBundleIdentifier') != 'hu.csaladitv.meteor.ios' or info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
    raise SystemExit('Unexpected bundle identifier or platform.')
if info.get('UIDeviceFamily') != [1, 2]:
    raise SystemExit('Both iPhone and iPad must be supported.')
for key in ['CFBundleIcons', 'CFBundleIcons~ipad']:
    if info.get(key, {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconName') != 'AppIcon':
        raise SystemExit('Missing primary app icon: ' + key)
if not (app / 'Assets.car').is_file() or not list(app.glob('AppIcon*.png')):
    raise SystemExit('Compiled icon assets are missing.')
if not (app / 'PrivacyInfo.xcprivacy').is_file():
    raise SystemExit('Privacy manifest is missing.')
if info.get('NSAppTransportSecurity'):
    raise SystemExit('Unexpected App Transport Security exception.')
binary = app / info['CFBundleExecutable']
archs = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True).split()
if archs != ['arm64']:
    raise SystemExit('Expected a native arm64 device executable, got: ' + ' '.join(archs))
if (app / 'embedded.mobileprovision').exists():
    raise SystemExit('The verification archive must not contain a provisioning profile.')
report = {
    'bundle_id': info['CFBundleIdentifier'],
    'version': info['CFBundleShortVersionString'],
    'build': info['CFBundleVersion'],
    'platform': 'iPhoneOS',
    'minimum_ios': info['MinimumOSVersion'],
    'architectures': archs,
    'device_families': ['iPhone', 'iPad'],
    'primary_icon': 'AppIcon',
    'distribution_signed': False,
    'installable': False,
}
Path('ios-device-archive-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
