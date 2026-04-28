#!/usr/bin/env bash
# Extract the Cursor AppImage's .desktop + icons inside the image build, drop a
# wrapper at /usr/lib/cursor/cursor, and symlink /usr/bin/cursor.
set -euo pipefail

cd /usr/lib/cursor
./Cursor.AppImage --appimage-extract >/dev/null

# Move icons + desktop file to system locations.
install -D -m 0644 squashfs-root/cursor.desktop /usr/share/applications/cursor.desktop
sed -i 's|^Exec=.*|Exec=/usr/lib/cursor/cursor %F|' /usr/share/applications/cursor.desktop

if [ -d squashfs-root/usr/share/icons ]; then
    cp -a squashfs-root/usr/share/icons/. /usr/share/icons/
fi

# Wrapper. AppImage wants FUSE; use --appimage-extract-and-run to skip FUSE.
cat >/usr/lib/cursor/cursor <<'EOF'
#!/usr/bin/env bash
exec /usr/lib/cursor/Cursor.AppImage --appimage-extract-and-run "$@"
EOF
chmod 0755 /usr/lib/cursor/cursor

ln -sf /usr/lib/cursor/cursor /usr/bin/cursor

rm -rf squashfs-root
