#!/opt/homebrew/bin/bash
# Build the Linux edition into dist/linux/hypercubing and dist/hypercubing-linux-<VERSION>.tar.gz.
# Runs on the Mac, after ./build.sh and ./build.sh zip.
#
#   ./build-linux.sh
#
# The Linux edition reuses the Mac build's Windows payloads (MDX shim, MC5D/Magic120Cell ports,
# 64-bit flag patches) and Java jars unchanged, taken from dist/hypercubing-<VERSION>.zip, or from
# dist/hypercubing if there's no zip. Windows programs run on the user's own Wine (see NOTES.md,
# "Linux edition"), so no engine ships. New for Linux: a Linux Java runtime, Hyperspeedcube's Linux
# builds, JogAmp's Linux natives, and Windows builds of 3to4++, circleguy and Geraniums Pot.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/build.sh"   # helpers and pins only; see the guard in build.sh

OUT="$HERE/dist/linux/hypercubing"
# Linux jmods for the Mac's jlink to link from. Must be the same JDK build as $JDK_HOME: jlink only
# links its own version. Temurin 25's JDK tarball has no jmods; they're a separate download.
LINUX_JMODS=https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jmods_x64_linux_hotspot_25.0.5_8.tar.gz
LINUX_JMODS_SHA256=7f29246c5da4e4b0b0737f22001c6369dfb6913630bea2c3f49127ce53c98a0c

# The Mac build to take payloads from.
MAC=$(mktemp -d)
trap 'rm -rf "$MAC"' EXIT
zip="$HERE/dist/hypercubing-$HDE_VERSION.zip"
if [ -f "$zip" ]; then
  log "Taking payloads from $(basename "$zip")"
  # Not unzip: the zip (made by ditto) stores extended attributes as ._ AppleDouble entries, which
  # unzip extracts as literal files. Magic120Cell then parsed "._Rings.settings" and crashed.
  ditto -x -k "$zip" "$MAC"
  MAC="$MAC/hypercubing"
elif [ -d "$DIST/MC7D-KB.app" ]; then
  log "Taking payloads from dist/hypercubing"
  MAC="$DIST"
else
  echo "No Mac build: run ./build.sh (and ./build.sh zip) first." >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Support"
cp "$LIB/linux-launch.sh" "$OUT/Support/launch"
cp "$LIB/linux-install.sh" "$OUT/install.sh"
chmod +x "$OUT/Support/launch" "$OUT/install.sh"
sed "s/@VERSION@/$HDE_VERSION/" "$LIB/README-linux.md" >"$OUT/README.md"

# new_dir <name>: create a program folder with its run script and the Mac app's icon as icon.png.
new_dir() {
  local d="$OUT/$1" app="$MAC/$1.app" icon
  mkdir -p "$d"
  printf '#!/bin/sh\nexec "$(dirname "$0")/../Support/launch" "$(dirname "$0")" "$@"\n' >"$d/run"
  chmod +x "$d/run"
  icon=$(plutil -extract CFBundleIconFile raw "$app/Contents/Info.plist" 2>/dev/null || echo app)
  sips -s format png -Z 256 "$app/Contents/Resources/${icon%.icns}.icns" --out "$d/icon.png" >/dev/null
}

# wine_dir <name> <exe> <payload dir>: a Windows program.
wine_dir() {
  new_dir "$1"
  cp -R "$3/." "$OUT/$1/"
  printf 'KIND=wine\nEXE=%q\n' "$2" >"$OUT/$1/app.conf"
}

# ---------------------------------------------------------------- from the Mac build

for app in "$MAC"/*.app; do
  name=$(basename "$app" .app) r="$app/Contents/Resources"
  if [ -d "$r/program" ]; then
    log "$name (Windows)"
    # shellcheck source=/dev/null
    (. "$r/program.conf"
      wine_dir "$name" "$EXE" "$r/program"
      # Shipped files the program saves settings into (KEEP on the Mac): ship as .default.
      for f in ${KEEP[@]+"${KEEP[@]}"}; do mv "$OUT/$name/$f" "$OUT/$name/$f.default"; done
      [ -z "${KEEP+x}" ] || printf 'DEFAULTS=(%s)\n' "${KEEP[*]@Q}" >>"$OUT/$name/app.conf")
  elif grep -q '^JAVA_ARGS=' "$r/program.conf" 2>/dev/null; then
    log "$name (Java)"
    new_dir "$name"
    d="$OUT/$name"
    [ -f "$r/app.jar" ] && cp "$r/app.jar" "$d/"
    [ -d "$r/data" ] && cp -R "$r/data/." "$d/"
    [ -d "$r/jogl" ] && cp -R "$r/jogl" "$d/"
    # The Mac paths $CONTENTS/Resources/x become $APPDIR/x (the launcher sets APPDIR).
    { echo KIND=java; grep -v '^APPNAME=' "$r/program.conf" | sed 's|\$CONTENTS/Resources/|$APPDIR/|g'; } >"$d/app.conf"
  fi
done

# Gelatinbrain: JogAmp's Linux natives instead of the Mac ones, from the same pinned commit.
if [ -d "$OUT/Gelatinbrain/jogl" ]; then
  rev=830fa61b4865a1b589916899c41f16808224857d   # keep in sync with build_gelatinbrain
  rm "$OUT"/Gelatinbrain/jogl/*-natives-macosx-universal.jar
  tar -xzf "$(fetch "https://codeload.github.com/Hypercubers/gelatinbrain/tar.gz/$rev" "gelatinbrain-$rev.tar.gz")" \
    --strip-components 2 -C "$OUT/Gelatinbrain/jogl" \
    "gelatinbrain-$rev/jogl/gluegen-rt-natives-linux-amd64.jar" "gelatinbrain-$rev/jogl/jogl-all-natives-linux-amd64.jar"
fi

# ---------------------------------------------------------------- Linux Java runtime

log "Java runtime (Linux x64)"
jdk=$(mktemp -d)
tar -xzf "$(fetch "$LINUX_JMODS" "" "$LINUX_JMODS_SHA256")" -C "$jdk"
# Same modules as build_jre, linked from the Linux jmods.
"$JDK_HOME/bin/jlink" --module-path "$(echo "$jdk"/*-jmods)" \
  --add-modules java.desktop,java.management,java.prefs,java.logging,java.xml,java.datatransfer,java.naming,jdk.unsupported \
  --strip-debug --no-man-pages --no-header-files --compress=zip-6 --output "$OUT/Support/jre"
rm -rf "$jdk"
# jlink silently links the Mac's own modules when the module path lacks java.base.
file "$OUT/Support/jre/bin/java" | grep -q 'ELF 64-bit.*x86-64' || { echo "Support/jre isn't a Linux x64 runtime" >&2; exit 1; }
du -sh "$OUT/Support/jre"

# ---------------------------------------------------------------- Linux-specific builds

for v in 1:v1.0.12 2:v2.0.0-zeta.12; do
  name="Hyperspeedcube ${v%%:*}" tag=${v#*:}
  log "$name"
  new_dir "$name"
  tar -xzf "$(fetch "https://github.com/HactarCE/Hyperspeedcube/releases/download/$tag/hyperspeedcube_linux.tar.gz" "hsc-${tag#v}-linux.tar.gz")" -C "$OUT/$name"
  printf 'KIND=native\nBIN=hyperspeedcube\n' >"$OUT/$name/app.conf"
done

# 3to4++, circleguy and Geraniums Pot are native on the Mac. On Linux they run as Windows builds
# under Wine like the rest, so nothing depends on the distribution's glibc or libraries.

log "3to4++ (Windows build)"
checkout gwstaten/3to4pp 3to4pp 3b031f95ec0bd4ff23789ce05811662c9e3023f6   # keep in sync with build_3to4pp
[ -d "$CO/glfw" ] || git clone -q --depth 1 --branch 3.4 https://github.com/glfw/glfw "$CO/glfw" 2>/dev/null
cmake -S "$CO/glfw" -B "$CO/glfw/build-mingw" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
  -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
  -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$CO/glfw/build-mingw" -j8 >/dev/null
src="$CO/3to4pp" obj=$(mktemp -d)
flags=(-w -O2 -DNDEBUG -DNO_DEMO_WINDOW -I"$src/include" -I"$src/imgui" -I"$src/imgui/backends" -I"$src/nfd/src/include" -I"$CO/glfw/include")
pids=()
for f in "$src"/*.cpp "$src"/imgui/imgui{,_draw,_tables,_widgets,_demo}.cpp "$src"/imgui/backends/imgui_impl_{glfw,opengl3}.cpp "$src/nfd/src/nfd_win.cpp"; do
  x86_64-w64-mingw32-g++ -std=c++11 "${flags[@]}" -c "$f" -o "$obj/$(basename "${f%.*}").o" &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || { echo "3to4++ compile failed"; exit 1; }; done
x86_64-w64-mingw32-gcc "${flags[@]}" -c "$src/gl.c" -o "$obj/gl.o"
x86_64-w64-mingw32-gcc "${flags[@]}" -c "$src/nfd/src/nfd_common.c" -o "$obj/nfd_common.o"
(cd "$src" && x86_64-w64-mingw32-windres resources.rc -O coff -o "$obj/resources.o")   # version info and icon
mkdir "$obj/out"
x86_64-w64-mingw32-g++ -mwindows -static -s "$obj"/*.o "$CO/glfw/build-mingw/src/libglfw3.a" \
  -lopengl32 -lgdi32 -lshell32 -lole32 -luuid -lcomdlg32 -o "$obj/out/3to4++.exe"
wine_dir "3to4++" "3to4++.exe" "$obj/out"
rm -rf "$obj"

log "circleguy (Windows build)"
checkout henrydukepickle/circleguy circleguy e76e7b3c83262df9836ac681e8af4fb5aaa71530   # keep in sync with build_circleguy
rustup target add x86_64-pc-windows-gnu >/dev/null 2>&1
(cd "$CO/circleguy" && CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
  cargo build -q --release --target x86_64-pc-windows-gnu 2>target/win-build.log) ||
  { cat "$CO/circleguy/target/win-build.log" >&2; exit 1; }   # upstream's warnings stay in the log otherwise
obj=$(mktemp -d)
cp "$CO/circleguy/target/x86_64-pc-windows-gnu/release/circleguy.exe" "$obj/"
cp -R "$CO/circleguy/Puzzles" "$CO/circleguy/Configs" "$obj/"   # read from the working directory
wine_dir circleguy circleguy.exe "$obj"
rm -rf "$obj"

log "Geraniums Pot (upstream Windows build)"
checkout grigorusha/GeraniumsPot GeraniumsPot 4bf9c31ea14be78f982ed8cff1256a7fe77084de   # keep in sync with build_geraniumspot
obj=$(mktemp -d)
/usr/bin/bsdtar -xf "$(ls "$CO/GeraniumsPot/Unpacked App"/*.7z | head -1)" -C "$obj"
wine_dir "Geraniums Pot" "Geraniums Pot.exe" "$obj/Geraniums Pot"
rm -rf "$obj"

# ---------------------------------------------------------------- tarball

find "$OUT" -name '._*' -delete   # AppleDouble leftovers, in case any came through anyway
n=$(find "$OUT" -mindepth 2 -maxdepth 2 -name run | wc -l | tr -d ' ')
[ "$n" = "${#PROGRAMS[@]}" ] || { echo "Built $n programs, expected ${#PROGRAMS[@]} (PROGRAMS in build.sh)" >&2; exit 1; }
tarball="$HERE/dist/hypercubing-linux-$HDE_VERSION.tar.gz"
log "Packing $tarball"
# No macOS extended attributes or owner names: GNU tar warns about them on every file.
/usr/bin/bsdtar --no-xattrs --no-mac-metadata --uid 0 --gid 0 --uname root --gname root \
  -czf "$tarball" -C "$(dirname "$OUT")" hypercubing
du -sh "$OUT" "$tarball"
