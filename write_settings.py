import os, stat

android = os.environ.get('ANDROID_HOME', '')
java = os.environ.get('JAVA_HOME', '')

content = f'[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "{android}"\nexport/android/java_sdk_path = "{java}"\n'

print("Writing settings:")
print(content)

os.makedirs(os.path.expanduser('~/.config/godot'), exist_ok=True)

for f in [
    os.path.expanduser('~/.config/godot/editor_settings-4.tres'),
    os.path.expanduser('~/.config/godot/editor_settings-4.3.tres')
]:
    with open(f, 'w') as file:
        file.write(content)
    os.chmod(f, stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)
    print('Written:', f)