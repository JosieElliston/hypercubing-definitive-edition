#!/opt/homebrew/bin/bash
# Build the Hypercubing Definitive Edition into dist/hypercubing, then optionally install it.
#
#   ./build.sh                 build everything
#   ./build.sh magictile pcubes   build only these (plus shared parts they need)
#   ./build.sh install         copy dist/hypercubing/* into /Applications/hypercubing
#   ./build.sh zip             zip dist/hypercubing into dist/hypercubing-<VERSION>.zip
#   ./build.sh list            list program names
#
# Downloads are cached in cache/ (delete a file to refetch). Source checkouts live in checkouts/.
#
# Every program is pinned: a version in its URL, a sha256 for downloads whose URL has no version,
# or a commit for source checkouts. Updating a program means changing its pin, rebuilding, testing,
# then bumping VERSION and adding a line to CHANGES.md (see NOTES.md, "Versioning").
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$HERE/dist/hypercubing"
CACHE="$HERE/cache"
CO="$HERE/checkouts"
LIB="$HERE/lib"
INSTALL_DIR="/Applications/hypercubing"
HDE_VERSION=$(cat "$HERE/VERSION")
mkdir -p "$DIST" "$CACHE" "$CO"

# Pinned versions. Bump here.
ENGINE_TARBALL="WS12WineCX24.0.7_7.tar.xz"     # Sikarugir-App/Engines; "wine-9.0 (KegworksCX 24.0.7)"
TEMPLATE_TARBALL="Template-1.0.27.tar.xz"       # Sikarugir-App/Wrapper; provides the engine's dylibs
JDK_HOME="${JDK_HOME:-$(/usr/libexec/java_home 2>/dev/null || true)}"
DOTNET="${DOTNET:-$(command -v dotnet || echo "$HOME/.dotnet/dotnet")}"   # .NET SDK 8+, for the MDX shim
# Geraniums Pot: uv-managed CPython (downloaded into cache/uv-python) and its venv's packages,
# transitive ones included. pygame 2.6.1 has no wheels past CPython 3.13.
GP_PYTHON=3.13.18
GP_PIP=(pygame==2.6.1 pygame-widgets==1.3.2 pyperclip==1.11.0 pyinstaller==6.22.3 pyinstaller-hooks-contrib==2026.10
  altgraph==0.17.5 macholib==1.16.4 packaging==26.3 setuptools==84.2.1)

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }

# fetch <url> [<cache name>] [<sha256>]: download once into cache/, print the path. With a sha256,
# also check the file (cached or not) against it, for URLs that don't change when upstream
# releases a new version.
fetch() {
  local url=$1 name=${2:-$(basename "$1")} sum=${3:-}
  if [ ! -s "$CACHE/$name" ]; then
    curl -fsSL --retry 3 -o "$CACHE/$name.part" "$url" >&2
    mv "$CACHE/$name.part" "$CACHE/$name"
  fi
  if [ -n "$sum" ] && ! printf '%s  %s\n' "$sum" "$CACHE/$name" | shasum -a 256 -c --status; then
    echo "cache/$name doesn't match its pinned sha256: upstream probably released a new version." >&2
    echo "Test the new file, then update the sha256 in build.sh (and VERSION, CHANGES.md)." >&2
    exit 1
  fi
  printf '%s' "$CACHE/$name"
}

# make_icns <.svg|.ico|.png|.exe> <out.icns>
make_icns() {
  local src=$1 out=$2 tmp
  tmp=$(mktemp -d)
  case "$src" in
    *.svg) rsvg-convert -w 1024 -h 1024 -a "$src" -o "$tmp/r.png" && python3 -I "$LIB/icon2png.py" "$tmp/r.png" "$tmp/src.png" ;;
    *) python3 -I "$LIB/icon2png.py" "$src" "$tmp/src.png" ;;
  esac
  mkdir "$tmp/i.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$tmp/src.png" --out "$tmp/i.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$tmp/src.png" --out "$tmp/i.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$tmp/i.iconset" -o "$out"
  rm -rf "$tmp"
}

# lbicon <abbr>: the leaderboard's icon for a program (lb.hypercubing.xyz), as a cached .svg path.
lbicon() { fetch "https://assets.hypercubing.xyz/img/icons/programs/$1.svg" "lb-icon-$1.svg"; }

# new_app <App Name> <launcher template> <id slug>: create an empty bundle, print Contents path.
# APP_VERSION (set it on the build function's call, e.g. `APP_VERSION=4.3 java_app ...`) is the
# program's own version, shown in Finder's Get Info. Leave it unset when upstream has none.
new_app() {
  local name=$1 launcher=$2 slug=$3 c="$DIST/$1.app/Contents"
  rm -rf "$DIST/$name.app"
  mkdir -p "$c/MacOS" "$c/Resources"
  cp "$LIB/$launcher" "$c/MacOS/launcher"
  chmod +x "$c/MacOS/launcher"
  cat >"$c/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundleIdentifier</key><string>xyz.hypercubing.hde.$slug</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleDisplayName</key><string>$name</string>
  <key>CFBundleIconFile</key><string>app</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSHighResolutionCapable</key><true/>
EOF
  [ -n "${APP_VERSION:-}" ] && echo "  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>" >>"$c/Info.plist"
  # Windows apps: the launcher process never becomes a GUI app (Wine's own process shows the
  # window and Dock icon), so hide it, or the Dock shows a second icon bouncing until timeout.
  [ "$launcher" = wine-launcher.sh ] && echo '  <key>LSUIElement</key><true/>' >>"$c/Info.plist"
  echo '</dict></plist>' >>"$c/Info.plist"
  date +%Y%m%d%H%M%S >"$c/Resources/stamp"
  printf '%s' "$c"
}

# ---------------------------------------------------------------- shared parts

build_engine() {
  log "Wine engine"
  local out="$DIST/Support/engine" tmp
  rm -rf "$out"; mkdir -p "$out"
  tmp=$(mktemp -d)
  tar xJf "$(fetch "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/$ENGINE_TARBALL")" -C "$tmp"
  tar xJf "$(fetch "https://github.com/Sikarugir-App/Wrapper/releases/download/v1.0/$TEMPLATE_TARBALL")" -C "$tmp"
  mv "$tmp/wswine.bundle" "$out/wine"
  # The engine binaries have rpath @loader_path/../../, i.e. engine/, so the dylibs go there.
  cp -R "$tmp"/Template-*.app/Contents/Frameworks/. "$out/"
  # Not needed by any hypercubing program; together about 620 MB.
  rm -rf "$out/GStreamer.framework" "$out/renderer" "$out/moltenvkcx" "$out/wine/share/wine/gecko"
  rm -rf "$tmp"
  du -sh "$out"
}

build_jre() {
  log "Java runtime"
  [ -x "$JDK_HOME/bin/jlink" ] || { echo "need a JDK (set JDK_HOME)"; exit 1; }
  rm -rf "$DIST/Support/jre"
  # Modules found with jdeps over all bundled jars, plus jdk.unsupported for older libraries.
  "$JDK_HOME/bin/jlink" --add-modules java.desktop,java.management,java.prefs,java.logging,java.xml,java.datatransfer,java.naming,jdk.unsupported \
    --strip-debug --no-man-pages --no-header-files --compress=zip-6 --output "$DIST/Support/jre"
  du -sh "$DIST/Support/jre"
}

# ---------------------------------------------------------------- Windows programs

# wine_app <App Name> <slug> <folder name in C:\Program Files> <exe> <payload dir> [icon source]
wine_app() {
  local name=$1 slug=$2 folder=$3 exe=$4 payload=$5 icon=${6:-} c
  c=$(new_app "$name" wine-launcher.sh "$slug")
  printf 'NAME=%q\nEXE=%q\n' "$folder" "$exe" >"$c/Resources/program.conf"
  mkdir -p "$c/Resources/program"
  cp -R "$payload/." "$c/Resources/program/"
  if [ -n "$icon" ]; then
    make_icns "$icon" "$c/Resources/app.icns"
  else
    make_icns "$payload/$exe" "$c/Resources/app.icns" 2>/dev/null || true   # the exe's own icon, if any
  fi
}

build_magictile() {
  log "MagicTile"
  local tmp; tmp=$(mktemp -d)
  # The release tag is "latest" and the exe says 1.0.0.0, so it has no version to show.
  unzip -q "$(fetch https://github.com/roice3/MagicTile/releases/download/latest/MagicTile_v2.zip "" \
    4a40c8c1f1cae3b87d08344e3d454406f85987298796838313516282e7df78dc)" -d "$tmp"
  local dir; dir=$(dirname "$(find "$tmp" -name MagicTile.exe | head -1)")
  # Upstream builds x86; run it 64-bit so OpenGL calls avoid Wine's slow wow64 thunks.
  python3 -I "$HERE/scripts/corflags.py" "$dir/MagicTile.exe" anycpu
  wine_app MagicTile magictile MagicTile MagicTile.exe "$dir"
  rm -rf "$tmp"
}

build_pcubes() {
  log "pCubes"
  # pMetro.su/pCubes.zip truncates downloads (as of 2026-11-22); use the author's Yandex mirror.
  local href tmp
  if [ ! -s "$CACHE/pCubes.zip" ]; then
    href=$(curl -fsS "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=https://disk.yandex.com/d/ltT74a9XrJgwFg" |
      python3 -I -c 'import json,sys; print(json.load(sys.stdin)["href"])')
    fetch "$href" pCubes.zip >/dev/null
  fi
  tmp=$(mktemp -d)
  unzip -q "$(fetch unused pCubes.zip c78c45cd547e7339d73d19fb3ab31f9a0d30404de8a06efd232a411a39b06fb3)" -d "$tmp"
  APP_VERSION=0.3.0.169 wine_app pCubes pcubes pCubes pCubes.exe "$tmp"
  rm -rf "$tmp"
}

# ---------------------------------------------------------------- Managed DirectX programs
# Unmodified .NET 2.0 exes that use Managed DirectX 1.1. They run on the shim in shim/ instead of
# the real (mixed-mode, unloadable) MDX DLLs. See NOTES.md, "MDX shim".

MDXSHIM_OUT="$HERE/shim/Microsoft.DirectX.Direct3DX/bin/Release/net48"

build_mdxshim() {
  log "Managed DirectX shim"
  "$DOTNET" build "$HERE/shim/Microsoft.DirectX.Direct3DX" -c Release -nologo -v q
}

# mdx_app <App Name> <slug> <folder name in C:\Program Files> <exe> <payload dir> [icon]
mdx_app() {
  local name=$1 slug=$2 folder=$3 exe=$4 dir=$5 icon=${6:-}
  rm -f "$dir"/Microsoft.DirectX*.dll
  cp "$MDXSHIM_OUT"/Microsoft.DirectX*.dll "$dir/"
  python3 -I "$HERE/scripts/mdx-config.py" "$dir/$exe.config"
  # The x86 flag was only there for the real MDX's native code; run 64-bit (see Decisions).
  python3 -I "$HERE/scripts/corflags.py" "$dir/$exe" anycpu
  wine_app "$name" "$slug" "$folder" "$exe" "$dir" "$icon"
}

# mdx_zip_app <zip url> <exe> <App Name> <slug> [icon] [sha256]: unpack an upstream zip and build it
# with mdx_app. The app's folder name in C:\Program Files is the app name.
mdx_zip_app() {
  local url=$1 exe=$2 name=$3 slug=$4 icon=${5:-} sum=${6:-} tmp
  tmp=$(mktemp -d)
  unzip -q "$(fetch "$url" "" "$sum")" -d "$tmp"
  mdx_app "$name" "$slug" "$name" "$exe" "$(dirname "$(find "$tmp" -name "$exe" | head -1)")" "$icon"
  rm -rf "$tmp"
}

build_mc7dkb() {
  log "MC7D-KB"
  APP_VERSION=0.8.4 mdx_zip_app https://github.com/Aegyo/mc7d-kb/releases/download/v0.8.4/MC7D-KB_v0.8.4_x86.zip mc7d.exe MC7D-KB mc7dkb "$(lbicon MC7D)"
}

# Andrey's three zips have unversioned URLs, hence the sha256 pins. Their only version numbers are
# the exes' build-stamped file versions, so those are what APP_VERSION shows.
build_mpu() {
  log "Magic Puzzle Ultimate"
  local tmp dir; tmp=$(mktemp -d)
  unzip -q "$(fetch https://superliminal.com/andrey/mpu/MPUlt.zip "" 3b5d2fbd26bf97b3e5ef9161e911a7246a34d953b8065e362392e31bf3813017)" -d "$tmp"
  dir=$(dirname "$(find "$tmp" -name MPUlt.exe | head -1)")
  # Add the definitions published on hypercubing.xyz's MPU page as a "hypercubing.xyz" menu.
  # Pinned to a commit of the site's repo; bump it to pick up page edits.
  local page_rev=005024287726f8270f000272ced1c76086e598eb
  python3 -I "$HERE/scripts/mpu-merge-puzzles.py" "$dir/MPUlt_puzzles.txt" \
    "$(fetch "https://raw.githubusercontent.com/Hypercubers/hypercubing.xyz/$page_rev/docs/software/magicpuzzleultimate.md" "mpu-page-$page_rev.md")"
  APP_VERSION=1.0.6044.17726 mdx_app "Magic Puzzle Ultimate" mpu "Magic Puzzle Ultimate" MPUlt.exe "$dir" "$(lbicon MPU)"
  rm -rf "$tmp"
  # MPU saves its settings into this shipped file (SaveSettings in rubikHT.cs); don't clobber on update.
  echo 'KEEP=(MPUlt_settings.txt)' >>"$DIST/Magic Puzzle Ultimate.app/Contents/Resources/program.conf"
}

build_ms5d() {
  log "Magic Simplex 5D"
  APP_VERSION=1.0.4048.40728 mdx_zip_app https://superliminal.com/andrey/ms5d/Simplex5DBin.zip MS5D.exe "Magic Simplex 5D" ms5d \
    "" 9a435c594347b60e851d629dea63b6c45c7e7b402729a73a11d52757b4602684
}

build_mht633() {
  log "Magic Hyperbolic Tile"
  APP_VERSION=1.0.4010.35702 mdx_zip_app https://superliminal.com/andrey/mht633/M3dHT633.zip m3dht633.exe "Magic Hyperbolic Tile" mht633 \
    "" 23f720f5dcfd19f986acf12b2a86f062ab2ff3956715a41756173c8c9f989547
}

# ---------------------------------------------------------------- Roice Nelson's C++/CLI programs
# Magic Cube 5D and Magic120Cell were mixed-mode C++/CLI exes, which wine-mono can't load. Our port
# (patches/*.patch, branch hde-port in each checkout) builds the C++ core as a native x64 DLL with
# mingw-w64 and moves the managed glue into the C# GUI, which becomes the exe. See NOTES.md.

# port_checkout <github owner/repo> <dir name> <patch>: clone upstream into checkouts/ and put the
# port on branch hde-port. An existing hde-port branch is used as is (that's where the port is
# developed; regenerate the patch with `git diff master hde-port`). Upstream is not pulled, since
# the patch might not apply to a newer upstream.
port_checkout() {
  local repo=$1 dir=$2 patch=$3 g="$CO/$2"
  [ -d "$g/.git" ] || git clone -q "https://github.com/$repo" "$g"
  if ! git -C "$g" rev-parse -q --verify refs/heads/hde-port >/dev/null; then
    git -C "$g" checkout -q -b hde-port
    git -C "$g" apply --index --whitespace=nowarn "$patch"
    git -C "$g" -c user.name=hde -c user.email=hde@localhost commit -q -m "Port to a native core DLL plus C# exe (no C++/CLI)"
  fi
  [ "$(git -C "$g" branch --show-current)" = hde-port ] || git -C "$g" checkout -q hde-port
}

# mingw_compile <obj dir> <name prefix> <include dir>... -- <sources...>: cross-compile sources for
# x64 Windows in parallel, into <obj dir>/<prefix><basename>.o. The first include dir decides which
# stdafx.h `#include <stdafx.h>` finds, as in the upstream projects.
mingw_compile() {
  local obj=$1 pre=$2 inc=() f pids=() p; shift 2
  while [ "$1" != -- ]; do inc+=(-I"$1"); shift; done; shift
  for f in "$@"; do
    x86_64-w64-mingw32-g++ -std=c++17 -O2 -w -DNDEBUG "${inc[@]}" -c "$f" -o "$obj/$pre$(basename "${f%.*}").o" &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p" || { echo "mingw compile failed"; exit 1; }; done
}

# mingw_link <out.dll> <obj dir>: link a native x64 Windows DLL. libstdc++/libgcc are linked
# statically, so the DLL needs only Windows system DLLs.
mingw_link() {
  x86_64-w64-mingw32-g++ -shared -static -s -o "$1" "$2"/*.o -lopengl32 -lglu32 -lgdi32 -luser32 -lshlwapi
}

build_mc5d() {
  log "Magic Cube 5D"
  port_checkout roice3/MagicCube5D MagicCube5D "$HERE/patches/MagicCube5D-hde-port.patch"
  local s="$CO/MagicCube5D/src" out; out=$(mktemp -d)
  "$DOTNET" build "$s/MagicCubeGui" -c Release -nologo -v q -o "$out" >/dev/null
  mkdir "$out/obj"
  mingw_compile "$out/obj" "" "$s/MagicCube5D" -- "$s/MagicCube5D/coreApi.cpp" "$s"/MagicCube5D/workFiles/*.cpp
  mingw_link "$out/MagicCube5DCore.dll" "$out/obj"
  rm -rf "$out/obj"
  wine_app "Magic Cube 5D" mc5d "Magic Cube 5D" MagicCube5D.exe "$out" "$HERE/icons/MC5D.svg"
  rm -rf "$out"
}

build_m120c() {
  log "Magic120Cell"
  port_checkout roice3/Magic120Cell Magic120Cell "$HERE/patches/Magic120Cell-hde-port.patch"
  local s="$CO/Magic120Cell" out; out=$(mktemp -d)
  "$DOTNET" build "$s/Magic120CellGui" -c Release -nologo -v q -o "$out" >/dev/null
  # The core is Magic120Cell/ plus Roice's geometryLib (a static library upstream). The source
  # lists are the vcxproj's: geometryLib/glInit.cpp is an unused older copy of gl/glInit.cpp.
  local g="$s/geometryLib"
  mkdir "$out/obj"
  mingw_compile "$out/obj" m_ "$s/Magic120Cell" "$g" -- "$s/Magic120Cell/coreApi.cpp" "$s"/Magic120Cell/workFiles/*.cpp
  mingw_compile "$out/obj" g_ "$g" -- "$g"/gl/{displayList,glInit}.cpp "$g"/{helper,polygon,renderer,vectorND}.cpp \
    "$g"/magictile/puzzle.cpp "$g"/puzzle/{state,twist,twistHistory}.cpp
  mingw_link "$out/Magic120CellCore.dll" "$out/obj"
  rm -rf "$out/obj"
  # The installer's preset view settings, read from the working directory, and its sample log.
  cp "$s"/Magic120CellInstall/installConfig/* "$out/"
  wine_app Magic120Cell m120c Magic120Cell Magic120Cell.exe "$out" "$(lbicon M120C)"
  rm -rf "$out"
}

# ---------------------------------------------------------------- Java programs

# java_app <App Name> <slug> <jar path> [icon] -- <java args...>   ($JAR in args = bundled jar path)
java_app() {
  local name=$1 slug=$2 jar=$3 icon=${4:-} c
  shift 4; [ "${1:-}" = -- ] && shift
  c=$(new_app "$name" java-launcher.sh "$slug")
  cp "$jar" "$c/Resources/app.jar"
  {
    printf 'APPNAME=%q\nJAVA_ARGS=(' "$name"
    local a
    for a in "$@"; do
      if [ "$a" = '$JAR' ]; then printf '"$CONTENTS/Resources/app.jar" '; else printf '%q ' "$a"; fi
    done
    printf ')\n'
  } >"$c/Resources/program.conf"
  # No guessing from images inside the jar: that picked a trophy for MC4D and a font atlas for
  # ElevenCell3D. Without an icon, macOS shows the generic one.
  if [ -n "$icon" ]; then make_icns "$icon" "$c/Resources/app.icns"; fi
}

build_mc4d() {
  log "Magic Cube 4D"
  APP_VERSION=4.3.343 java_app "Magic Cube 4D" mc4d "$(fetch https://github.com/cutelyaware/magiccube4d/releases/download/v4.3.343/mc4d-4-3-343.jar)" "$(lbicon MC4D)" -- -jar '$JAR'
}

build_elevencell() {
  log "Eleven Cell (Nan Ma)"
  # Unversioned URL, and the jar carries no version.
  java_app "Eleven Cell" elevencell "$(fetch https://superliminal.com/cube/ElevenCell.jar "" bb8876e7d8530f2086e6bf665a0db36a15f681c97052f92fc872216b5c13de6d)" "$HERE/icons/NM11C.svg" -- -jar '$JAR'
}

build_elevencell3d() {
  log "ElevenCell3D"
  APP_VERSION=0.2.0 java_app "ElevenCell3D" elevencell3d "$(fetch https://github.com/SuperSnowman16/ElevenCell3D/releases/download/v0.2.0/ElevenCell3D-v0.2.0.jar)" "$HERE/icons/11C3D.svg" -- --enable-native-access=ALL-UNNAMED -jar '$JAR'
}

build_mc3d() {
  log "Magic Cube 3D"
  APP_VERSION=1.0.0 java_app "Magic Cube 3D" mc3d "$(fetch https://github.com/rzhao271/MC3D/releases/download/v1.0.0/mc3d.jar)" "$HERE/icons/MC3D.svg" -- -jar '$JAR'
}

build_isocubesim() {
  log "IsoCubeSim"
  local tmp; tmp=$(mktemp -d)
  unzip -q "$(fetch https://mzrg.com/rubik/iso/IsoCubeSim_v4.1.zip)" -d "$tmp"
  APP_VERSION=4.1 java_app "IsoCubeSim" isocubesim "$tmp/IsoCubeSim v4.1.jar" "$(lbicon MZRG)" -- -jar '$JAR'
  rm -rf "$tmp"
}

# ---------------------------------------------------------------- native Mac programs

# copy_upstream_app <tarball url> <cache name> <App Name>: upstream ships a .app; rename it.
copy_upstream_app() {
  local url=$1 cname=$2 name=$3 tmp
  tmp=$(mktemp -d)
  tar xzf "$(fetch "$url" "$cname")" -C "$tmp"
  rm -rf "$DIST/$name.app"
  mv "$(find "$tmp" -maxdepth 2 -name '*.app' | head -1)" "$DIST/$name.app"
  xattr -cr "$DIST/$name.app"
  rm -rf "$tmp"
}

build_hsc1() {
  log "Hyperspeedcube 1"
  copy_upstream_app https://github.com/HactarCE/Hyperspeedcube/releases/download/v1.0.12/hyperspeedcube_macos.tar.gz hsc-1.0.12-macos.tar.gz "Hyperspeedcube 1"
}

build_hsc2() {
  log "Hyperspeedcube 2"
  copy_upstream_app https://github.com/HactarCE/Hyperspeedcube/releases/download/v2.0.0-zeta.12/hyperspeedcube_macos.tar.gz hsc-2.0.0-zeta.12-macos.tar.gz "Hyperspeedcube 2"
}

# checkout <github owner/repo> <dir name> <commit>: clone into checkouts/ and check out the pinned
# commit (detached).
checkout() {
  local g="$CO/$2"
  [ -d "$g/.git" ] || git clone -q "https://github.com/$1" "$g"
  git -C "$g" cat-file -e "$3^{commit}" 2>/dev/null || git -C "$g" fetch -q --tags origin
  git -C "$g" -c advice.detachedHead=false checkout -q "$3"
  git -C "$g" submodule -q update --init --recursive
}

# describe_version <checkout dir> <tag prefix>: the checkout's `git describe`, minus the tag prefix
# (e.g. "0.7-14-ge76e7b3": 14 commits after tag v0.7).
describe_version() { git -C "$CO/$1" describe --tags | sed "s/^$2//"; }

build_circleguy() {
  log "circleguy"
  checkout henrydukepickle/circleguy circleguy e76e7b3c83262df9836ac681e8af4fb5aaa71530
  (cd "$CO/circleguy" && cargo build -q --release)
  local c; c=$(APP_VERSION=$(describe_version circleguy v) new_app circleguy native-launcher.sh circleguy)
  mkdir -p "$c/Resources/data"
  # The binary goes in Contents/MacOS so macOS treats it as this bundle's process (our name and
  # icon in the Dock). From Resources/bin it showed up as a generic "exec" icon.
  cp "$CO/circleguy/target/release/circleguy" "$c/MacOS/"
  cp -R "$CO/circleguy/Puzzles" "$CO/circleguy/Configs" "$c/Resources/data/"
  printf 'APPNAME=%q\nBIN=../MacOS/circleguy\nTERMINAL=0\n' circleguy >"$c/Resources/program.conf"
  local ico; ico=$(find "$CO/circleguy/assets" "$CO/circleguy/resources" -iname '*.png' 2>/dev/null | head -1)
  [ -n "$ico" ] && make_icns "$ico" "$c/Resources/app.icns"
}

build_3to4pp() {
  log "3to4++"
  # gwstaten's fork of rayzchen/3to4pp. Upstream only ships Windows builds, but it's GLFW +
  # OpenGL 3.3 core + Dear ImGui, so it builds natively. GLFW is linked statically so the app
  # has no dependencies outside macOS.
  # No tags or version number upstream.
  checkout gwstaten/3to4pp 3to4pp 3b031f95ec0bd4ff23789ce05811662c9e3023f6
  [ -d "$CO/glfw" ] || git clone -q --depth 1 --branch 3.4 https://github.com/glfw/glfw "$CO/glfw" 2>/dev/null
  cmake -S "$CO/glfw" -B "$CO/glfw/build" -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 >/dev/null
  cmake --build "$CO/glfw/build" -j8 >/dev/null
  local src="$CO/3to4pp" out="$CO/3to4pp/build-mac" f
  rm -rf "$out"; mkdir -p "$out"
  local flags=(-w -O2 -DNDEBUG -DNO_DEMO_WINDOW -mmacosx-version-min=11.0 -I"$src/include" -I"$src/imgui" -I"$src/imgui/backends" -I"$src/nfd/src/include" -I"$CO/glfw/include")
  for f in "$src"/*.cpp "$src"/imgui/imgui{,_draw,_tables,_widgets,_demo}.cpp "$src"/imgui/backends/imgui_impl_{glfw,opengl3}.cpp; do
    clang++ -std=c++11 "${flags[@]}" -c "$f" -o "$out/$(basename "${f%.*}").o"
  done
  clang "${flags[@]}" -c "$src/gl.c" -o "$out/gl.o"
  clang "${flags[@]}" -c "$src/nfd/src/nfd_common.c" -o "$out/nfd_common.o"
  # nativefiledialog's Cocoa backend predates ARC.
  clang "${flags[@]}" -Wno-deprecated-declarations -c "$src/nfd/src/nfd_cocoa.m" -o "$out/nfd_cocoa.o"
  clang++ -mmacosx-version-min=11.0 "$out"/*.o "$CO/glfw/build/src/libglfw3.a" \
    -framework Cocoa -framework IOKit -framework OpenGL -framework CoreFoundation -o "$out/3to4++"
  local c; c=$(new_app "3to4++" native-launcher.sh 3to4pp)
  cp "$out/3to4++" "$c/MacOS/"
  # It reads scramble.txt from the working directory, i.e. the per-user data folder.
  printf 'APPNAME=%q\nBIN=../MacOS/3to4++\nTERMINAL=0\n' "3to4++" >"$c/Resources/program.conf"
  make_icns "$src/icons/icon128x128.png" "$c/Resources/app.icns"
}

build_gelatinbrain() {
  log "Gelatinbrain"
  # Branch fix/macos-puzzle-switch on Hypercubers/gelatinbrain (PR #7) vendors the JogAmp build that
  # fixes puzzle switching on macOS.
  local rev=830fa61b4865a1b589916899c41f16808224857d archive src c
  archive=$(fetch "https://codeload.github.com/Hypercubers/gelatinbrain/tar.gz/$rev" "gelatinbrain-$rev.tar.gz")
  src=$(mktemp -d)
  tar -xzf "$archive" --strip-components 1 -C "$src"

  # Build the GL2 rendering fallback against the exact game and JOGL jars we package.
  local game="$src/permuzzle/permuzzle.jar" jogl="$src/jogl"
  local game_url=https://zqjxkvby.com/permuzzle version=1.21058 game_archive images sources
  game_archive=$(fetch "$game_url/permuzzle.jar" "gelatinbrain-$version-permuzzle.jar" \
    1311f9fcb7c0e1da01cf5bce87836492974da005dac2f5416013c306684427ac)
  images=$(fetch "$game_url/images.zip" "gelatinbrain-$version-images.zip" \
    d36f8c70a4894d09e387cdb650ce1daaf93c8ddc74ce2422f1ef60895bbf2b92)
  unzip -oq "$images" -d "$src/permuzzle"

  sources=$(fetch "$game_url/sources.zip" "gelatinbrain-$version-sources.zip" \
    914d9d72cd769224f0f754a1c5c3851d329b190c7e427cba329fb714843fd0e8)
  mkdir -p "$src/renderer-source" "$src/empty"
  unzip -jq "$sources" 'permuzzle.java/jzzz/CGl192Cube.java' 'permuzzle.java/jzzz/CGl48TrianglesCube.java' \
    'permuzzle.java/jzzz/CGl8x24Cube.java' 'permuzzle.java/jzzz/CGlShaderCube.java' -d "$src/renderer-source"
  patch -s -d "$src/renderer-source" -p1 < "$HERE/patches/gelatinbrain-new-cube-renderers.patch"
  "$JDK_HOME/bin/javac" --release 19 -sourcepath "$src/empty" \
    -cp "$game_archive:$jogl/gluegen-rt.jar:$jogl/jogl-all.jar" \
    -d "$src/classes" "$LIB"/gelatinbrain/Legacy{Cube,Dodeca,Shader}Renderer.java "$src"/renderer-source/*.java
  "$JDK_HOME/bin/java" "$LIB/gelatinbrain/PatchGelatinbrain.java" \
    "$game_archive" "$game" "$src/classes"

  c=$(APP_VERSION=$version new_app Gelatinbrain java-launcher.sh gelatinbrain)
  # permuzzle.jar reads images/ and writes sessions/ next to itself, so it lives in the per-user
  # data folder (copied from Resources/data), not in the bundle.
  mkdir -p "$c/Resources/data" "$c/Resources/jogl"
  cp -R "$src/permuzzle" "$c/Resources/data/"
  cp "$jogl"/{gluegen-rt,jogl-all}{,-natives-macosx-universal}.jar \
    "$jogl"/{gluegen,jogl}.LICENSE.txt "$c/Resources/jogl/"
  rm -rf "$src"
  cat >"$c/Resources/program.conf" <<'EOF'
APPNAME=Gelatinbrain
# Allow JogAmp to load its native libraries on the bundled Java runtime.
JAVA_ARGS=(--add-exports java.base/java.lang=ALL-UNNAMED --add-exports java.desktop/sun.awt=ALL-UNNAMED
  --add-exports java.desktop/sun.java2d=ALL-UNNAMED --enable-native-access=ALL-UNNAMED
  -cp "permuzzle/permuzzle.jar:$CONTENTS/Resources/jogl/gluegen-rt.jar:$CONTENTS/Resources/jogl/jogl-all.jar" jzzz.CStart)
EOF
  make_icns "$HERE/icons/Gelatinbrain.svg" "$c/Resources/app.icns"
}

build_geraniumspot() {
  log "Geraniums Pot"
  # A pygame program. Upstream ships Windows (PyInstaller) builds only; we freeze its unmodified
  # Source/ with PyInstaller, through our own entry point lib/geraniumspot_main.py (its docstring
  # says what it changes). Python comes from uv (python-build-standalone, which includes Tk).
  checkout grigorusha/GeraniumsPot GeraniumsPot 4bf9c31ea14be78f982ed8cff1256a7fe77084de
  local g="$CO/GeraniumsPot" b="$CO/GeraniumsPot-build" c tmp
  local pins="python $GP_PYTHON; ${GP_PIP[*]}"
  if [ "$(cat "$b/venv/.hde-pins" 2>/dev/null)" != "$pins" ]; then
    UV_PYTHON_INSTALL_DIR="$CACHE/uv-python" uv venv -q --clear --managed-python --python "$GP_PYTHON" "$b/venv"
    uv pip install -q --python "$b/venv/bin/python" "${GP_PIP[@]}"
    echo "$pins" >"$b/venv/.hde-pins"
  fi
  rm -rf "$b/dist"
  # Upstream's glob.py shadows the stdlib glob, which PyInstaller would bundle in its place.
  # Ship it as data under another name; the entry point loads it as "glob".
  cp "$g/Source/glob.py" "$b/gp-glob.py"
  # The program has no sound, so drop pygame's mixer and its dylibs (fluidsynth, glib, sndfile...).
  # pygame imports the mixer optionally. Together with --strip, this takes the build from 43 to 36 MB.
  # --windowed makes a .app layout (Contents/MacOS, Frameworks, Resources), which we merge into ours.
  # A plain onedir build doesn't run from Contents/MacOS: its bootloader then looks for
  # libpython in ../Frameworks.
  "$b/venv/bin/pyinstaller" --noconfirm --clean --log-level ERROR --windowed --onedir --strip --name GeraniumsPot \
    --target-arch arm64 --paths "$g/Source" --add-data "$b/gp-glob.py:." --distpath "$b/dist" --workpath "$b/work" --specpath "$b" \
    --exclude-module pygame.mixer --exclude-module pygame.mixer_music --exclude-module pygame._sdl2.mixer \
    --exclude-module pygame.examples --exclude-module pygame.tests --exclude-module pygame.docs \
    "$LIB/geraniumspot_main.py" 2>&1 | grep -v -e '^pygame ' -e '^Hello from the pygame' >&2 || true
  local pyi="$b/dist/GeraniumsPot.app/Contents"
  [ -x "$pyi/MacOS/GeraniumsPot" ] || { echo "PyInstaller failed"; exit 1; }
  c=$(APP_VERSION=$(describe_version GeraniumsPot geranium) new_app "Geraniums Pot" native-launcher.sh geraniumspot)
  # The binary is in Contents/MacOS, so the Dock shows our name and icon.
  cp -R "$pyi/MacOS" "$pyi/Frameworks" "$pyi/Resources" "$c/"
  rm "$c/Resources/icon-windowed.icns"
  # It reads Garden/ (puzzles), fonts/, Photo/ and its png from the working directory, i.e. the
  # per-user data folder. Source/Garden.zip matches the Windows build's Garden folder.
  mkdir -p "$c/Resources/data/fonts"
  unzip -q "$g/Source/Garden.zip" -d "$c/Resources/data"
  cp "$g/Source/Geraniums Pot.png" "$c/Resources/data/"
  # fonts/arialn.ttf (arrow markers) is only in the Windows build. /usr/bin/bsdtar reads 7z.
  tmp=$(mktemp -d)
  /usr/bin/bsdtar -xf "$(ls "$g/Unpacked App"/*.7z | head -1)" -C "$tmp" '*/fonts/arialn.ttf'
  cp "$tmp"/*/fonts/arialn.ttf "$c/Resources/data/fonts/"
  rm -rf "$tmp"
  # Photos of the real puzzles (Photo button, F5), about 12 MB. They're read-only, so they stay in
  # the bundle, and the entry point symlinks ./Photo to them.
  unzip -q "$g/Photo.zip" -d "$c/Resources"
  printf 'APPNAME=%q\nBIN=../MacOS/GeraniumsPot\nTERMINAL=0\n' "Geraniums Pot" >"$c/Resources/program.conf"
  make_icns "$g/Source/Geraniums Pot.png" "$c/Resources/app.icns"
  du -sh "$DIST/Geraniums Pot.app"
}

# ---------------------------------------------------------------- driver

PROGRAMS=(magictile pcubes mc7dkb mpu ms5d mht633 mc5d m120c mc4d elevencell elevencell3d mc3d isocubesim hsc1 hsc2 circleguy 3to4pp gelatinbrain geraniumspot)
JAVA_PROGRAMS=" mc4d elevencell elevencell3d mc3d isocubesim gelatinbrain "
WINE_PROGRAMS=" magictile pcubes mc7dkb mpu ms5d mht633 mc5d m120c "
MDX_PROGRAMS=" mc7dkb mpu ms5d mht633 "

case "${1:-all}" in
  list) printf '%s\n' "${PROGRAMS[@]}"; exit 0 ;;
  install)
    log "Installing into $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    for item in "$DIST"/*; do
      dest="$INSTALL_DIR/$(basename "$item")"
      rm -rf "$dest"
      cp -cR "$item" "$dest" 2>/dev/null || cp -R "$item" "$dest"
    done
    exit 0 ;;
  zip)
    zip="$HERE/dist/hypercubing-$HDE_VERSION.zip"
    log "Zipping into $zip"
    rm -f "$zip"
    # ditto keeps symlinks and macOS metadata, which zip(1) would drop.
    ditto -c -k --keepParent "$DIST" "$zip"
    du -h "$zip"
    exit 0 ;;
  all) targets=("${PROGRAMS[@]}"); shared=(engine jre mdxshim) ;;
  *)
    targets=("$@"); shared=()
    for t in "$@"; do
      [[ $WINE_PROGRAMS == *" $t "* && ! -d $DIST/Support/engine ]] && shared+=(engine)
      [[ $JAVA_PROGRAMS == *" $t "* && ! -d $DIST/Support/jre ]] && shared+=(jre)
      [[ $MDX_PROGRAMS == *" $t "* ]] && shared+=(mdxshim)   # incremental, so always run
    done ;;
esac
# Keep its program list in sync with PROGRAMS. Its title says @VERSION@.
sed "s/@VERSION@/$HDE_VERSION/" "$LIB/README.md" >"$DIST/README.md"
for s in $(printf '%s\n' "${shared[@]}" | sort -u); do "build_$s"; done
for t in "${targets[@]}"; do "build_$t"; done
# Finder and the Dock cache icons per bundle path; without this, rebuilt apps can keep an old or
# missing icon (seen 2026-11-22 for MC7D-KB and pCubes).
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for a in "$DIST"/*.app; do touch "$a"; "$LSREGISTER" -f "$a"; done
log "Done: $DIST"
