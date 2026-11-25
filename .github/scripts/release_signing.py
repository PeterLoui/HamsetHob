"""Point the release build at the fixed signing key.

flutter create generates android/app/build.gradle(.kts) on every CI run with release signed by the debug key,
and the debug key is new on every runner, so each APK used to have a different signature and could not be
installed over the previous one. This adds a "release" signing config that reads the key from environment
variables (set from repository secrets) and uses it for the release build type.
"""
import os
import re
import sys

KTS = 'android/app/build.gradle.kts'
GROOVY = 'android/app/build.gradle'

if os.path.exists(KTS):
    path = KTS
    s = open(path, encoding='utf-8').read()
    block = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("HAMSET_KEYSTORE_PATH"))
            storePassword = System.getenv("HAMSET_STORE_PASSWORD")
            keyAlias = System.getenv("HAMSET_KEY_ALIAS")
            keyPassword = System.getenv("HAMSET_KEY_PASSWORD")
        }
    }

'''
    old = 'signingConfig = signingConfigs.getByName("debug")'
    new = 'signingConfig = signingConfigs.getByName("release")'
elif os.path.exists(GROOVY):
    path = GROOVY
    s = open(path, encoding='utf-8').read()
    block = '''    signingConfigs {
        release {
            storeFile file(System.getenv("HAMSET_KEYSTORE_PATH"))
            storePassword System.getenv("HAMSET_STORE_PASSWORD")
            keyAlias System.getenv("HAMSET_KEY_ALIAS")
            keyPassword System.getenv("HAMSET_KEY_PASSWORD")
        }
    }

'''
    old = 'signingConfig = signingConfigs.debug'
    new = 'signingConfig = signingConfigs.release'
else:
    sys.exit('no android/app/build.gradle(.kts) to patch')

if s.count(old) != 1:
    sys.exit(f'{path}: expected one "{old}", found {s.count(old)}; the Flutter template changed')
s = s.replace(old, new)
s, n = re.subn(r'(\n    buildTypes \{)', '\n' + block.rstrip('\n') + r'\n\1', s, count=1)
if n != 1:
    sys.exit(f'{path}: no "buildTypes {{" block found')
open(path, 'w', encoding='utf-8').write(s)
print(f'{path}: release builds are signed with the fixed key')
