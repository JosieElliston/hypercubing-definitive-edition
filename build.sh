#!/opt/homebrew/bin/bash
# Build the Hypercubing Definitive Edition for Mac and Linux. Runs on a Mac.
#
#   ./build.sh                       build both editions
#   ./build.sh mac|linux             build one edition
#   ./build.sh [mac|linux] mpu ...   build only these programs (plus shared parts that are missing)
#   ./build.sh install               copy dist/mac/hypercubing/* into /Applications/hypercubing
#   ./build.sh package               dist/hypercubing-mac-<VERSION>.zip, dist/hypercubing-linux-<VERSION>.tar.gz
#   ./build.sh list                  list program names
#
# Two stages. First each program's payload: its files and a manifest, in build/ (see "Payloads").
# Then each edition's packager turns payloads into dist/mac/hypercubing (.app bundles, a Wine
# engine, a Mac Java runtime) or dist/linux/hypercubing (program folders that Support/launch runs on
# the user's own Wine, a Linux Java runtime). Most payloads are shared by both editions, so both
# ship the same Windows exes and jars; a few programs have a payload per edition.
#
# Downloads are cached in cache/ (delete a file to refetch). Source checkouts live in checkouts/.
#
# Every program is pinned: a version in its URL, a sha256 for downloads whose URL has no version,
# or a commit for source checkouts. Updating a program means changing its pin, rebuilding, testing,
# then bumping VERSION and adding a line to CHANGES.md (see NOTES.md, "Versioning").
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
MAC_DIST="$HERE/dist/mac/hypercubing"
LINUX_DIST="$HERE/dist/linux/hypercubing"
CACHE="$HERE/cache"
CO="$HERE/checkouts"
LIB="$HERE/lib"
INSTALL_DIR="/Applications/hypercubing"
HDE_VERSION=$(cat "$HERE/VERSION")
mkdir -p "$BUILD" "$CACHE" "$CO"

# Pinned versions. Bump here.
ENGINE_TARBALL="WS12WineCX24.0.7_7.tar.xz"     # Sikarugir-App/Engines; "wine-9.0 (KegworksCX 24.0.7)"
TEMPLATE_TARBALL="Template-1.0.27.tar.xz"       # Sikarugir-App/Wrapper; provides the engine's dylibs
JDK_HOME="${JDK_HOME:-$(/usr/libexec/java_home 2>/dev/null || true)}"
# Linux jmods for the Mac's jlink to link from. Must be the same JDK build as $JDK_HOME: jlink only
# links its own version. Temurin 25's JDK tarball has no jmods; they're a separate download.
LINUX_JMODS=https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jmods_x64_linux_hotspot_25.0.5_8.tar.gz
LINUX_JMODS_SHA256=7f29246c5da4e4b0b0737f22001c6369dfb6913630bea2c3f49127ce53c98a0c
# Modules found with jdeps over all bundled jars, plus jdk.unsupported for older libraries.
JRE_MODULES=java.desktop,java.management,java.prefs,java.logging,java.xml,java.datatransfer,java.naming,jdk.unsupported
DOTNET="${DOTNET:-$(command -v dotnet || echo "$HOME/.dotnet/dotnet")}"   # .NET SDK 8+, for the MDX shim
# Programs built for both editions, each edition in its own way.
HSC1_TAG=v1.0.12
HSC2_TAG=v2.0.0-zeta.12
CIRCLEGUY_REV=e76e7b3c83262df9836ac681e8af4fb5aaa71530
FLAT_HYPERCUBE_REV=5ef65e4999608c351de2bd9cf87a1eea6f854035
LAMINATED_REV=8f303d5cccff6ae9651831048b066b02d0260956
THREETOFOUR_REV=3b031f95ec0bd4ff23789ce05811662c9e3023f6
GERANIUMSPOT_REV=4bf9c31ea14be78f982ed8cff1256a7fe77084de
# Geraniums Pot for Mac: uv-managed CPython (downloaded into cache/uv-python) and its venv's
# packages, transitive ones included. pygame 2.6.1 has no wheels past CPython 3.13.
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

# lbicon <abbr>: the leaderboard's icon for a program (lb.hypercubing.xyz), as a cached .svg path.
lbicon() { fetch "https://assets.hypercubing.xyz/img/icons/programs/$1.svg" "lb-icon-$1.svg"; }

# checkout <github owner/repo> <dir name> <commit>: clone into checkouts/ and check out the pinned
# commit (detached).
checkout() {
  local g="$CO/$2"
  [ -d "$g/.git" ] || git clone -q "https://github.com/$1" "$g"
  git -C "$g" cat-file -e "$3^{commit}" 2>/dev/null || git -C "$g" fetch -q --tags origin
  git -C "$g" -c advice.detachedHead=false checkout -q "$3"
  git -C "$g" submodule -q update --init --recursive
}

apply_patch_once() {
  local src="$CO/$1" patch="$HERE/patches/$2"
  git -C "$src" apply --reverse --check "$patch" 2>/dev/null || git -C "$src" apply "$patch"
}

# describe_version <checkout dir> <tag prefix>: the checkout's `git describe`, minus the tag prefix
# (e.g. "0.7-14-ge76e7b3": 14 commits after tag v0.7).
describe_version() { git -C "$CO/$1" describe --tags | sed "s/^$2//"; }

# ================================================================ Payloads
#
# A payload is a directory, build/<edition or "any">/<program>/, holding:
#   manifest   Bash assignments, which become the program's config file in both editions (the
#              launchers source it): NAME (app or folder name; on Mac also the Windows program's
#              folder in C:\Program Files and the Java/native program's data folder), SLUG, KIND
#              (wine, java, native, or app for a prebuilt Mac .app), VERSION (optional), then
#              EXE and KEEP for wine, JAVA_ARGS for java, BIN and optional TERMINAL=1 for native.
#              JAVA_ARGS refers to res/
#              files as "$RES/...", which each launcher sets.
#   data/      files that go in the program's working directory, which it may write to. For wine
#              programs, the program folder with the exe.
#   res/       read-only files, such as a Java program's jar.
#   icon.png   1024x1024.
#   mac/, linux/  more data/ and res/ files for that edition only.
#   contents/  (Mac only) merged into the .app's Contents. app/ (KIND=app) holds the whole .app.
#
# payload_<program> builds a payload both editions use, into build/any. A program that differs
# per edition has payload_<program>_mac and payload_<program>_linux instead, into build/mac and
# build/linux. The functions write to $P, which new_payload sets.

# new_payload <slug> <Name> <kind>: start an empty payload in $P. APP_VERSION (set it on the call,
# e.g. `APP_VERSION=4.3 java_payload ...`) is the program's own version, shown in Finder's Get Info.
# Leave it unset when upstream has none.
new_payload() {
  P="$BUILD/$PAYLOAD_PLAT/$1"
  rm -rf "$P"; mkdir -p "$P"
  printf 'NAME=%q\nSLUG=%q\nKIND=%q\n' "$2" "$1" "$3" >"$P/manifest"
  if [ -n "${APP_VERSION:-}" ]; then printf 'VERSION=%q\n' "$APP_VERSION" >>"$P/manifest"; fi
}

# payload_icon <.svg|.ico|.png|.exe>: render the icon as $P/icon.png.
payload_icon() {
  local tmp
  case "$1" in
    *.svg)
      tmp=$(mktemp -d)
      rsvg-convert -w 1024 -h 1024 -a "$1" -o "$tmp/r.png"
      python3 -I "$LIB/icon2png.py" "$tmp/r.png" "$P/icon.png"
      rm -rf "$tmp" ;;
    *) python3 -I "$LIB/icon2png.py" "$1" "$P/icon.png" ;;
  esac
}

# wine_payload <Name> <slug> <exe> <program dir> [icon source]: a Windows program. Without an icon
# source, it uses the exe's own icon, if any.
wine_payload() {
  local name=$1 slug=$2 exe=$3 dir=$4 icon=${5:-}
  new_payload "$slug" "$name" wine
  printf 'EXE=%q\n' "$exe" >>"$P/manifest"
  mkdir "$P/data"
  cp -R "$dir/." "$P/data/"
  if [ -n "$icon" ]; then
    payload_icon "$icon"
  else
    payload_icon "$P/data/$exe" 2>/dev/null || rm -f "$P/icon.png"
  fi
}

# java_payload <Name> <slug> <jar path> [icon] -- <java args...>   ($JAR in args = the jar)
java_payload() {
  local name=$1 slug=$2 jar=$3 icon=${4:-} a
  shift 4; [ "${1:-}" = -- ] && shift
  new_payload "$slug" "$name" java
  mkdir "$P/res"
  cp "$jar" "$P/res/app.jar"
  {
    printf 'JAVA_ARGS=('
    for a in "$@"; do
      if [ "$a" = '$JAR' ]; then printf '"$RES/app.jar" '; else printf '%q ' "$a"; fi
    done
    printf ')\n'
  } >>"$P/manifest"
  # No guessing from images inside the jar: that picked a trophy for MC4D and a font atlas for
  # ElevenCell3D. Without an icon, macOS shows the generic one.
  if [ -n "$icon" ]; then payload_icon "$icon"; fi
}

# ---------------------------------------------------------------- Windows programs

payload_magictile() {
  log "MagicTile"
  local tmp; tmp=$(mktemp -d)
  # The release tag is "latest" and the exe says 1.0.0.0, so it has no version to show.
  unzip -q "$(fetch https://github.com/roice3/MagicTile/releases/download/latest/MagicTile_v2.zip "" \
    4a40c8c1f1cae3b87d08344e3d454406f85987298796838313516282e7df78dc)" -d "$tmp"
  local dir; dir=$(dirname "$(find "$tmp" -name MagicTile.exe | head -1)")
  # Upstream builds x86; run it 64-bit so OpenGL calls avoid Wine's slow wow64 thunks.
  python3 -I "$HERE/scripts/corflags.py" "$dir/MagicTile.exe" anycpu
  wine_payload MagicTile magictile MagicTile.exe "$dir"
  rm -rf "$tmp"
}

payload_pcubes() {
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
  APP_VERSION=0.3.0.169 wine_payload pCubes pcubes pCubes.exe "$tmp"
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

# mdx_payload <Name> <slug> <exe> <program dir> [icon]
mdx_payload() {
  local name=$1 slug=$2 exe=$3 dir=$4 icon=${5:-}
  rm -f "$dir"/Microsoft.DirectX*.dll
  cp "$MDXSHIM_OUT"/Microsoft.DirectX*.dll "$dir/"
  python3 -I "$HERE/scripts/mdx-config.py" "$dir/$exe.config"
  # The x86 flag was only there for the real MDX's native code; run 64-bit (see Decisions).
  python3 -I "$HERE/scripts/corflags.py" "$dir/$exe" anycpu
  wine_payload "$name" "$slug" "$exe" "$dir" "$icon"
}

# mdx_zip_payload <zip url> <exe> <Name> <slug> [icon] [sha256]: unpack an upstream zip and build
# it with mdx_payload.
mdx_zip_payload() {
  local url=$1 exe=$2 name=$3 slug=$4 icon=${5:-} sum=${6:-} tmp
  tmp=$(mktemp -d)
  unzip -q "$(fetch "$url" "" "$sum")" -d "$tmp"
  mdx_payload "$name" "$slug" "$exe" "$(dirname "$(find "$tmp" -name "$exe" | head -1)")" "$icon"
  rm -rf "$tmp"
}

payload_mc7dkb() {
  log "MC7D-KB"
  APP_VERSION=0.8.4 mdx_zip_payload https://github.com/Aegyo/mc7d-kb/releases/download/v0.8.4/MC7D-KB_v0.8.4_x86.zip mc7d.exe MC7D-KB mc7dkb "$(lbicon MC7D)"
}

# Andrey's three zips have unversioned URLs, hence the sha256 pins. Their only version numbers are
# the exes' build-stamped file versions, so those are what APP_VERSION shows.
payload_mpu() {
  log "Magic Puzzle Ultimate"
  local tmp dir; tmp=$(mktemp -d)
  unzip -q "$(fetch https://superliminal.com/andrey/mpu/MPUlt.zip "" 3b5d2fbd26bf97b3e5ef9161e911a7246a34d953b8065e362392e31bf3813017)" -d "$tmp"
  dir=$(dirname "$(find "$tmp" -name MPUlt.exe | head -1)")
  # Add the definitions published on hypercubing.xyz's MPU page as a "hypercubing.xyz" menu.
  # Pinned to a commit of the site's repo; bump it to pick up page edits.
  local page_rev=005024287726f8270f000272ced1c76086e598eb
  python3 -I "$HERE/scripts/mpu-merge-puzzles.py" "$dir/MPUlt_puzzles.txt" \
    "$(fetch "https://raw.githubusercontent.com/Hypercubers/hypercubing.xyz/$page_rev/docs/software/magicpuzzleultimate.md" "mpu-page-$page_rev.md")"
  APP_VERSION=1.0.6044.17726 mdx_payload "Magic Puzzle Ultimate" mpu MPUlt.exe "$dir" "$(lbicon MPU)"
  rm -rf "$tmp"
  # MPU saves its settings into this shipped file (SaveSettings in rubikHT.cs); updates must not
  # overwrite it.
  echo 'KEEP=(MPUlt_settings.txt)' >>"$P/manifest"
}

payload_ms5d() {
  log "Magic Simplex 5D"
  APP_VERSION=1.0.4048.40728 mdx_zip_payload https://superliminal.com/andrey/ms5d/Simplex5DBin.zip MS5D.exe "Magic Simplex 5D" ms5d \
    "" 9a435c594347b60e851d629dea63b6c45c7e7b402729a73a11d52757b4602684
}

payload_mht633() {
  log "Magic Hyperbolic Tile"
  APP_VERSION=1.0.4010.35702 mdx_zip_payload https://superliminal.com/andrey/mht633/M3dHT633.zip m3dht633.exe "Magic Hyperbolic Tile" mht633 \
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

payload_mc5d() {
  log "Magic Cube 5D"
  port_checkout roice3/MagicCube5D MagicCube5D "$HERE/patches/MagicCube5D-hde-port.patch"
  local s="$CO/MagicCube5D/src" out icon; out=$(mktemp -d); icon=$(mktemp -d)
  # Embed our icon in the exe: Wine's Mac driver shows the exe's icon in the Dock, and the
  # port's app.ico (upstream's) is a generic window. Passed as a property, so the patch keeps it.
  rsvg-convert -w 256 -h 256 -a "$HERE/icons/MC5D.svg" -o "$icon/i.png"
  python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2], sizes=[(16,16),(32,32),(48,48),(256,256)])' "$icon/i.png" "$icon/MC5D.ico"
  "$DOTNET" build "$s/MagicCubeGui" -c Release -nologo -v q -o "$out" -p:ApplicationIcon="$icon/MC5D.ico" >/dev/null
  rm -rf "$icon"
  mkdir "$out/obj"
  mingw_compile "$out/obj" "" "$s/MagicCube5D" -- "$s/MagicCube5D/coreApi.cpp" "$s"/MagicCube5D/workFiles/*.cpp
  mingw_link "$out/MagicCube5DCore.dll" "$out/obj"
  rm -rf "$out/obj"
  wine_payload "Magic Cube 5D" mc5d MagicCube5D.exe "$out" "$HERE/icons/MC5D.svg"
  rm -rf "$out"
}

payload_m120c() {
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
  wine_payload Magic120Cell m120c Magic120Cell.exe "$out" "$(lbicon M120C)"
  rm -rf "$out"
}

# ---------------------------------------------------------------- Java programs

payload_mc4d() {
  log "Magic Cube 4D"
  APP_VERSION=4.3.343 java_payload "Magic Cube 4D" mc4d "$(fetch https://github.com/cutelyaware/magiccube4d/releases/download/v4.3.343/mc4d-4-3-343.jar)" "$(lbicon MC4D)" -- -jar '$JAR'
}

payload_elevencell() {
  log "Eleven Cell (Nan Ma)"
  # Unversioned URL, and the jar carries no version.
  java_payload "Eleven Cell" elevencell "$(fetch https://superliminal.com/cube/ElevenCell.jar "" bb8876e7d8530f2086e6bf665a0db36a15f681c97052f92fc872216b5c13de6d)" "$HERE/icons/NM11C.svg" -- -jar '$JAR'
}

elevencell3d_payload() {
  log "ElevenCell3D"
  APP_VERSION=0.2.0 java_payload "ElevenCell3D" elevencell3d "$(fetch https://github.com/SuperSnowman16/ElevenCell3D/releases/download/v0.2.0/ElevenCell3D-v0.2.0.jar)" "$HERE/icons/11C3D.svg" -- --enable-native-access=ALL-UNNAMED "$@"
}

payload_elevencell3d() {
  elevencell3d_payload -jar '$JAR'
}

payload_elevencell3d_mac() {
  # Invoke Main directly so the launcher owns the GLFW process.
  elevencell3d_payload -XstartOnFirstThread -cp '$JAR' Main
  local tmp scala_version=2.13.16 scala_url component compiler_cp=
  tmp=$(mktemp -d)
  scala_url=https://repo.maven.apache.org/maven2/org/scala-lang
  for component in scala-compiler scala-library scala-reflect; do
    compiler_cp="${compiler_cp:+$compiler_cp:}$(fetch "$scala_url/$component/$scala_version/$component-$scala_version.jar")"
  done
  mkdir -p "$tmp/src/main/scala" "$tmp/classes"
  cp "$(fetch https://raw.githubusercontent.com/SuperSnowman16/ElevenCell3D/de47b1853c92d0e4ef126c38c61199af6cc1728c/src/main/scala/Main.scala ElevenCell3D-v0.2.0-Main.scala)" "$tmp/src/main/scala/Main.scala"
  patch -s -d "$tmp" -p1 <"$HERE/patches/ElevenCell3D-macos-dialogs.patch"
  "$JDK_HOME/bin/java" -cp "$compiler_cp" scala.tools.nsc.Main \
    -release:17 -classpath "$P/res/app.jar" -d "$tmp/classes" "$tmp/src/main/scala/Main.scala"
  "$JDK_HOME/bin/jar" uf "$P/res/app.jar" -C "$tmp/classes" .
  clang -O2 -arch arm64 -mmacosx-version-min=11.0 -fobjc-arc -dynamiclib -framework AppKit \
    -I"$JDK_HOME/include" -I"$JDK_HOME/include/darwin" \
    "$LIB/elevencell3d-dialog.m" -o "$P/res/libelevencell3d-dialog.dylib"
  rm -rf "$tmp"
}

payload_mc3d() {
  log "Magic Cube 3D"
  APP_VERSION=1.0.0 java_payload "Magic Cube 3D" mc3d "$(fetch https://github.com/rzhao271/MC3D/releases/download/v1.0.0/mc3d.jar)" "$HERE/icons/MC3D.svg" -- -jar '$JAR'
}

payload_isocubesim() {
  log "IsoCubeSim"
  local tmp; tmp=$(mktemp -d)
  unzip -q "$(fetch https://mzrg.com/rubik/iso/IsoCubeSim_v4.1.zip)" -d "$tmp"
  APP_VERSION=4.1 java_payload "IsoCubeSim" isocubesim "$tmp/IsoCubeSim v4.1.jar" "$(lbicon MZRG)" -- -jar '$JAR'
  rm -rf "$tmp"
}

payload_gelatinbrain() {
  log "Gelatinbrain"
  # Branch fix/macos-puzzle-switch on Hypercubers/gelatinbrain (PR #7) vendors the JogAmp build that
  # fixes puzzle switching on macOS.
  local rev=830fa61b4865a1b589916899c41f16808224857d archive src
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

  APP_VERSION=$version new_payload gelatinbrain Gelatinbrain java
  # permuzzle.jar reads images/ and writes sessions/ next to itself, so it goes in the working
  # directory. JogAmp loads the natives jar for the running platform from next to its jars.
  mkdir -p "$P/data" "$P/res/jogl" "$P/mac/res/jogl" "$P/linux/res/jogl"
  cp -R "$src/permuzzle" "$P/data/"
  cp "$jogl"/{gluegen-rt,jogl-all}.jar "$jogl"/{gluegen,jogl}.LICENSE.txt "$P/res/jogl/"
  cp "$jogl"/{gluegen-rt,jogl-all}-natives-macosx-universal.jar "$P/mac/res/jogl/"
  cp "$jogl"/{gluegen-rt,jogl-all}-natives-linux-amd64.jar "$P/linux/res/jogl/"
  rm -rf "$src"
  cat >>"$P/manifest" <<'EOF'
# Allow JogAmp to load its native libraries on the bundled Java runtime.
JAVA_ARGS=(--add-exports java.base/java.lang=ALL-UNNAMED --add-exports java.desktop/sun.awt=ALL-UNNAMED
  --add-exports java.desktop/sun.java2d=ALL-UNNAMED --enable-native-access=ALL-UNNAMED
  -cp "permuzzle/permuzzle.jar:$RES/jogl/gluegen-rt.jar:$RES/jogl/jogl-all.jar" jzzz.CStart)
EOF
  payload_icon "$HERE/icons/Gelatinbrain.svg"
}

# ---------------------------------------------------------------- per-edition programs
# On Linux, Hyperspeedcube, circleguy, Flat Hypercube and Laminated run natively. 3to4++ and
# Geraniums Pot use Windows builds under Wine to avoid depending on the Linux build host's glibc
# and libraries.

# Hyperspeedcube: upstream's own builds for each platform.
hsc_mac() {
  local n=$1 tag=$2 tmp
  log "Hyperspeedcube $n"
  new_payload "hsc$n" "Hyperspeedcube $n" app
  tmp=$(mktemp -d)
  tar xzf "$(fetch "https://github.com/HactarCE/Hyperspeedcube/releases/download/$tag/hyperspeedcube_macos.tar.gz" "hsc-${tag#v}-macos.tar.gz")" -C "$tmp"
  mkdir "$P/app"
  mv "$(find "$tmp" -maxdepth 2 -name '*.app' | head -1)" "$P/app/"
  xattr -cr "$P/app"
  rm -rf "$tmp"
}
# hsc_linux <n> <tag> <icon path in the repo>: the icon the app itself uses. (assets/icon-1024.png,
# the website's, has HSC 1's faces in other colors.)
hsc_linux() {
  local n=$1 tag=$2 icon=$3
  log "Hyperspeedcube $n"
  APP_VERSION=${tag#v} new_payload "hsc$n" "Hyperspeedcube $n" native
  echo 'BIN=hyperspeedcube' >>"$P/manifest"
  mkdir "$P/data"
  tar -xzf "$(fetch "https://github.com/HactarCE/Hyperspeedcube/releases/download/$tag/hyperspeedcube_linux.tar.gz" "hsc-${tag#v}-linux.tar.gz")" -C "$P/data"
  payload_icon "$(fetch "https://raw.githubusercontent.com/HactarCE/Hyperspeedcube/$tag/$icon" "hsc-${tag#v}-$(basename "$icon")")"
}
payload_hsc1_mac() { hsc_mac 1 "$HSC1_TAG"; }
payload_hsc2_mac() { hsc_mac 2 "$HSC2_TAG"; }
payload_hsc1_linux() { hsc_linux 1 "$HSC1_TAG" resources/icon/hyperspeedcube_256x256.png; }
payload_hsc2_linux() { hsc_linux 2 "$HSC2_TAG" crates/hyperspeedcube/resources/icon/hyperspeedcube.svg; }

payload_circleguy_mac() {
  log "circleguy"
  checkout henrydukepickle/circleguy circleguy "$CIRCLEGUY_REV"
  (cd "$CO/circleguy" && cargo build -q --release)
  APP_VERSION=$(describe_version circleguy v) new_payload circleguy circleguy native
  # The binary goes in Contents/MacOS so macOS treats it as this bundle's process (our name and
  # icon in the Dock). From Resources/bin it showed up as a generic "exec" icon.
  echo 'BIN=../MacOS/circleguy' >>"$P/manifest"
  mkdir -p "$P/contents/MacOS" "$P/data"
  cp "$CO/circleguy/target/release/circleguy" "$P/contents/MacOS/"
  cp -R "$CO/circleguy/Puzzles" "$CO/circleguy/Configs" "$P/data/"   # read from the working directory
  payload_icon "$CO/circleguy/resources/icon.png"
}

# rust_linux_build <checkout> <binary>: cross-compile and verify the executable's glibc baseline.
RUST_LINUX_TARGET=x86_64-unknown-linux-gnu
rust_linux_build() {
  local src=$1 program=$2 glibc=2.28
  local bin="$1/target/$RUST_LINUX_TARGET/release/$2" logfile="$1/target/linux-build.log"
  log "$program (Linux x64, glibc $glibc)"
  command -v zig >/dev/null && command -v cargo-zigbuild >/dev/null ||
    { echo "Building $program for Linux requires Zig and cargo-zigbuild on PATH." >&2; exit 1; }
  rustup target add "$RUST_LINUX_TARGET"
  mkdir -p "$src/target"
  (cd "$src" && cargo zigbuild -q --locked --release --target "$RUST_LINUX_TARGET.$glibc") >"$logfile" 2>&1 ||
    { cat "$logfile" >&2; exit 1; }
  # Check the linked executable's version requirements before putting it in the bundle.
  xcrun llvm-objdump --private-headers "$bin" | awk -v program="$program" -v max_minor="${glibc#2.}" '
    $NF ~ /^GLIBC_/ {
      split(substr($NF, 7), version, /[.]/)
      if (version[1] != 2 || version[2] > max_minor) {
        print program " requires unsupported " $NF > "/dev/stderr"
        incompatible = 1
      }
    }
    END { exit incompatible }
  '
}

payload_circleguy_linux() {
  local src="$CO/circleguy"
  checkout henrydukepickle/circleguy circleguy "$CIRCLEGUY_REV"
  rust_linux_build "$src" circleguy
  APP_VERSION=$(describe_version circleguy v) new_payload circleguy circleguy native
  echo 'BIN=circleguy' >>"$P/manifest"
  mkdir -p "$P/data"
  cp "$src/target/$RUST_LINUX_TARGET/release/circleguy" "$P/data/"
  cp -R "$src/Puzzles" "$src/Configs" "$P/data/"
  payload_icon "$src/resources/icon.png"
}

payload_flat-hypercube() {
  local src="$CO/flat-hypercube" target=
  checkout milojacquet/flat-hypercube flat-hypercube "$FLAT_HYPERCUBE_REV"
  apply_patch_once flat-hypercube flat-hypercube-cli.patch
  if [ "$PAYLOAD_PLAT" = mac ]; then
    log "Flat Hypercube (Mac)"
    (cd "$src" && cargo build -q --locked --release)
  else
    rust_linux_build "$src" flat-hypercube
    target="$RUST_LINUX_TARGET/"
  fi
  APP_VERSION=$(describe_version flat-hypercube v) new_payload flat-hypercube 'Flat Hypercube' native
  printf 'BIN=flat-hypercube\nTERMINAL=1\n' >>"$P/manifest"
  mkdir "$P/res"
  cp "$src/target/${target}release/flat-hypercube" "$P/res/"
  if [ "$PAYLOAD_PLAT" = mac ]; then
    cp "$LIB/mac-terminal.command" "$P/res/run.command"
    chmod +x "$P/res/run.command"
  fi
  payload_icon "$(lbicon FHC)"
}

payload_flat-hypercube_mac() { payload_flat-hypercube; }
payload_flat-hypercube_linux() { payload_flat-hypercube; }

payload_laminated() {
  local src="$CO/laminated"
  log "Laminated"
  checkout milojacquet/laminated laminated "$LAMINATED_REV"
  apply_patch_once laminated laminated-dependencies.patch
  cp "$HERE/patches/laminated.Cargo.lock" "$src/Cargo.lock"
  APP_VERSION=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$src/Cargo.toml") new_payload laminated Laminated native
  mkdir "$P/res"
  cp "$src/LICENSE" "$P/res/LICENSE"
  if [ "$PAYLOAD_PLAT" = mac ]; then
    (cd "$src" && cargo build -q --locked --release)
    echo 'BIN=../MacOS/laminated' >>"$P/manifest"
    mkdir -p "$P/contents/MacOS"
    cp "$src/target/release/laminated" "$P/contents/MacOS/"
  else
    rust_linux_build "$src" laminated
    echo 'BIN=laminated' >>"$P/manifest"
    cp "$src/target/$RUST_LINUX_TARGET/release/laminated" "$P/res/"
  fi
  payload_icon "$HERE/icons/Laminated.svg"
}

payload_laminated_mac() { payload_laminated; }
payload_laminated_linux() { payload_laminated; }

# 3to4++: gwstaten's fork of rayzchen/3to4pp. Upstream only ships Windows builds, but it's GLFW +
# OpenGL 3.3 core + Dear ImGui, so it builds anywhere. GLFW is linked statically, so the program
# needs nothing outside the OS. No tags or version number upstream.
threetofour_sources() {
  local src="$CO/3to4pp"
  printf '%s\n' "$src"/*.cpp "$src"/imgui/imgui{,_draw,_tables,_widgets,_demo}.cpp "$src"/imgui/backends/imgui_impl_{glfw,opengl3}.cpp
}

# glfw_build <build dir name> [cmake args...]: build GLFW 3.4 into checkouts/glfw/<dir>.
glfw_build() {
  local dir=$1; shift
  [ -d "$CO/glfw" ] || git clone -q --depth 1 --branch 3.4 https://github.com/glfw/glfw "$CO/glfw" 2>/dev/null
  cmake -S "$CO/glfw" -B "$CO/glfw/$dir" -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
    -DCMAKE_BUILD_TYPE=Release "$@" >/dev/null
  cmake --build "$CO/glfw/$dir" -j8 >/dev/null
}

payload_3to4pp_mac() {
  log "3to4++"
  checkout gwstaten/3to4pp 3to4pp "$THREETOFOUR_REV"
  glfw_build build -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
  local src="$CO/3to4pp" out="$CO/3to4pp/build-mac" f
  rm -rf "$out"; mkdir -p "$out"
  local flags=(-w -O2 -DNDEBUG -DNO_DEMO_WINDOW -mmacosx-version-min=11.0 -I"$src/include" -I"$src/imgui" -I"$src/imgui/backends" -I"$src/nfd/src/include" -I"$CO/glfw/include")
  while read -r f; do
    clang++ -std=c++11 "${flags[@]}" -c "$f" -o "$out/$(basename "${f%.*}").o"
  done < <(threetofour_sources)
  clang "${flags[@]}" -c "$src/gl.c" -o "$out/gl.o"
  clang "${flags[@]}" -c "$src/nfd/src/nfd_common.c" -o "$out/nfd_common.o"
  # nativefiledialog's Cocoa backend predates ARC.
  clang "${flags[@]}" -Wno-deprecated-declarations -c "$src/nfd/src/nfd_cocoa.m" -o "$out/nfd_cocoa.o"
  clang++ -mmacosx-version-min=11.0 "$out"/*.o "$CO/glfw/build/src/libglfw3.a" \
    -framework Cocoa -framework IOKit -framework OpenGL -framework CoreFoundation -o "$out/3to4++"
  new_payload 3to4pp "3to4++" native
  # It reads scramble.txt from the working directory.
  echo 'BIN=../MacOS/3to4++' >>"$P/manifest"
  mkdir -p "$P/contents/MacOS"
  cp "$out/3to4++" "$P/contents/MacOS/"
  payload_icon "$src/icons/icon128x128.png"
}

payload_3to4pp_linux() {
  log "3to4++ (Windows build)"
  checkout gwstaten/3to4pp 3to4pp "$THREETOFOUR_REV"
  glfw_build build-mingw -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres
  local src="$CO/3to4pp" obj f pids=() p; obj=$(mktemp -d)
  local flags=(-w -O2 -DNDEBUG -DNO_DEMO_WINDOW -I"$src/include" -I"$src/imgui" -I"$src/imgui/backends" -I"$src/nfd/src/include" -I"$CO/glfw/include")
  while read -r f; do
    x86_64-w64-mingw32-g++ -std=c++11 "${flags[@]}" -c "$f" -o "$obj/$(basename "${f%.*}").o" &
    pids+=($!)
  done < <(threetofour_sources; echo "$src/nfd/src/nfd_win.cpp")
  for p in "${pids[@]}"; do wait "$p" || { echo "3to4++ compile failed"; exit 1; }; done
  x86_64-w64-mingw32-gcc "${flags[@]}" -c "$src/gl.c" -o "$obj/gl.o"
  x86_64-w64-mingw32-gcc "${flags[@]}" -c "$src/nfd/src/nfd_common.c" -o "$obj/nfd_common.o"
  (cd "$src" && x86_64-w64-mingw32-windres resources.rc -O coff -o "$obj/resources.o")   # version info and icon
  mkdir "$obj/out"
  x86_64-w64-mingw32-g++ -mwindows -static -s "$obj"/*.o "$CO/glfw/build-mingw/src/libglfw3.a" \
    -lopengl32 -lgdi32 -lshell32 -lole32 -luuid -lcomdlg32 -o "$obj/out/3to4++.exe"
  wine_payload "3to4++" 3to4pp "3to4++.exe" "$obj/out" "$src/icons/icon128x128.png"
  rm -rf "$obj"
}

# Geraniums Pot: a pygame program. Upstream ships Windows (PyInstaller) builds only, which Linux
# uses. For the Mac we freeze its unmodified Source/ with PyInstaller, through our own entry point
# lib/geraniumspot_main.py (its docstring says what it changes). Python comes from uv
# (python-build-standalone, which includes Tk).
payload_geraniumspot_mac() {
  log "Geraniums Pot"
  checkout grigorusha/GeraniumsPot GeraniumsPot "$GERANIUMSPOT_REV"
  local g="$CO/GeraniumsPot" b="$CO/GeraniumsPot-build" tmp
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
  APP_VERSION=$(describe_version GeraniumsPot geranium) new_payload geraniumspot "Geraniums Pot" native
  echo 'BIN=../MacOS/GeraniumsPot' >>"$P/manifest"
  # The binary is in Contents/MacOS, so the Dock shows our name and icon.
  mkdir "$P/contents"
  cp -R "$pyi/MacOS" "$pyi/Frameworks" "$pyi/Resources" "$P/contents/"
  rm "$P/contents/Resources/icon-windowed.icns"
  # It reads Garden/ (puzzles), fonts/, Photo/ and its png from the working directory.
  # Source/Garden.zip matches the Windows build's Garden folder.
  mkdir -p "$P/data/fonts"
  unzip -q "$g/Source/Garden.zip" -d "$P/data"
  cp "$g/Source/Geraniums Pot.png" "$P/data/"
  # fonts/arialn.ttf (arrow markers) is only in the Windows build. /usr/bin/bsdtar reads 7z.
  tmp=$(mktemp -d)
  /usr/bin/bsdtar -xf "$(ls "$g/Unpacked App"/*.7z | head -1)" -C "$tmp" '*/fonts/arialn.ttf'
  cp "$tmp"/*/fonts/arialn.ttf "$P/data/fonts/"
  rm -rf "$tmp"
  # Photos of the real puzzles (Photo button, F5), about 12 MB. They're read-only, so they stay in
  # the bundle, and the entry point symlinks ./Photo to them.
  unzip -q "$g/Photo.zip" -d "$P/contents/Resources"
  payload_icon "$g/Source/Geraniums Pot.png"
}

payload_geraniumspot_linux() {
  log "Geraniums Pot (upstream Windows build)"
  checkout grigorusha/GeraniumsPot GeraniumsPot "$GERANIUMSPOT_REV"
  local g="$CO/GeraniumsPot" tmp; tmp=$(mktemp -d)
  /usr/bin/bsdtar -xf "$(ls "$g/Unpacked App"/*.7z | head -1)" -C "$tmp"
  APP_VERSION=$(describe_version GeraniumsPot geranium) \
    wine_payload "Geraniums Pot" geraniumspot "Geraniums Pot.exe" "$tmp/Geraniums Pot" "$g/Source/Geraniums Pot.png"
  rm -rf "$tmp"
}

# ================================================================ Mac edition

# make_icns <1024px png> <out.icns>
make_icns() {
  local tmp; tmp=$(mktemp -d)
  mkdir "$tmp/i.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$1" --out "$tmp/i.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$1" --out "$tmp/i.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$tmp/i.iconset" -o "$2"
  rm -rf "$tmp"
}

# new_app <App Name> <launcher template> <id slug> [version]: create an empty bundle, print its
# Contents path.
new_app() {
  local name=$1 launcher=$2 slug=$3 version=${4:-} c="$MAC_DIST/$1.app/Contents"
  rm -rf "$MAC_DIST/$name.app"
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
  [ -n "$version" ] && echo "  <key>CFBundleShortVersionString</key><string>$version</string>" >>"$c/Info.plist"
  # Windows apps: the launcher process never becomes a GUI app (Wine's own process shows the
  # window and Dock icon), so hide it, or the Dock shows a second icon bouncing until timeout.
  [ "$launcher" = mac-wine-launcher.sh ] && echo '  <key>LSUIElement</key><true/>' >>"$c/Info.plist"
  echo '</dict></plist>' >>"$c/Info.plist"
  date +%Y%m%d%H%M%S >"$c/Resources/stamp"
  printf '%s' "$c"
}

# package_mac <payload dir>: make <NAME>.app. Bundle layout: Contents/Resources holds program.conf
# (the manifest), res/ files and app.icns; data/ goes in Resources/program (Windows programs) or
# Resources/data (others), which the launcher copies to where the program runs.
package_mac() (
  p=$1 RES=   # RES: JAVA_ARGS mentions it, but only the launcher needs its value
  # shellcheck source=/dev/null
  . "$p/manifest"
  if [ "$KIND" = app ]; then
    rm -rf "$MAC_DIST/$NAME.app"
    cp -R "$p"/app/*.app "$MAC_DIST/$NAME.app"
    exit 0
  fi
  c=$(new_app "$NAME" "mac-$KIND-launcher.sh" "$SLUG" "${VERSION:-}")
  cp "$p/manifest" "$c/Resources/program.conf"
  if [ -d "$p/contents" ]; then cp -R "$p/contents/." "$c/"; fi
  data=data; [ "$KIND" = wine ] && data=program
  for s in "$p" "$p/mac"; do
    if [ -d "$s/res" ]; then cp -R "$s/res/." "$c/Resources/"; fi
    if [ -d "$s/data" ]; then mkdir -p "$c/Resources/$data"; cp -R "$s/data/." "$c/Resources/$data/"; fi
  done
  if [ -f "$p/icon.png" ]; then make_icns "$p/icon.png" "$c/Resources/app.icns"; fi
)

mac_engine() {
  log "Wine engine (Mac)"
  local out="$MAC_DIST/Support/engine" tmp
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

mac_jre() {
  log "Java runtime (Mac)"
  [ -x "$JDK_HOME/bin/jlink" ] || { echo "need a JDK (set JDK_HOME)"; exit 1; }
  rm -rf "$MAC_DIST/Support/jre"
  "$JDK_HOME/bin/jlink" --add-modules "$JRE_MODULES" \
    --strip-debug --no-man-pages --no-header-files --compress=zip-6 --output "$MAC_DIST/Support/jre"
  du -sh "$MAC_DIST/Support/jre"
}

mac_base() {
  mkdir -p "$MAC_DIST/Support"
  # Keep its program list in sync with PROGRAMS. Its title says @VERSION@.
  sed "s/@VERSION@/$HDE_VERSION/" "$LIB/README-mac.md" >"$MAC_DIST/README.md"
  [ -d "$MAC_DIST/Support/engine" ] || mac_engine
  [ -d "$MAC_DIST/Support/jre" ] || mac_jre
}

mac_finish() {
  # Finder and the Dock cache icons per bundle path; without this, rebuilt apps can keep an old or
  # missing icon (seen 2026-11-22 for MC7D-KB and pCubes).
  local lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister a
  for a in "$MAC_DIST"/*.app; do touch "$a"; "$lsregister" -f "$a"; done
}

# ================================================================ Linux edition

# package_linux <payload dir>: make the folder <NAME>/ holding the program's data/ and res/ files,
# app.conf (the manifest), icon.png, and a `run` script that calls Support/launch.
package_linux() (
  p=$1 RES=   # RES: JAVA_ARGS mentions it, but only the launcher needs its value
  # shellcheck source=/dev/null
  . "$p/manifest"
  [ "$KIND" != app ] || { echo "$NAME: a prebuilt .app can't go in the Linux edition" >&2; exit 1; }
  d="$LINUX_DIST/$NAME"
  rm -rf "$d"; mkdir -p "$d"
  for s in "$p" "$p/linux"; do
    for t in data res; do if [ -d "$s/$t" ]; then cp -R "$s/$t/." "$d/"; fi; done
  done
  # Files the program saves its settings into ship as <file>.default, so extracting a newer version
  # over the folder doesn't reset them; the launcher makes the real file on first launch.
  for f in ${KEEP[@]+"${KEEP[@]}"}; do mv "$d/$f" "$d/$f.default"; done
  cp "$p/manifest" "$d/app.conf"
  printf '#!/bin/sh\nexec "$(dirname "$0")/../Support/launch" "$(dirname "$0")" "$@"\n' >"$d/run"
  chmod +x "$d/run"
  if [ -f "$p/icon.png" ]; then sips -s format png -Z 256 "$p/icon.png" --out "$d/icon.png" >/dev/null; fi
)

linux_jre() {
  log "Java runtime (Linux x64)"
  [ -x "$JDK_HOME/bin/jlink" ] || { echo "need a JDK (set JDK_HOME)"; exit 1; }
  local jdk out="$LINUX_DIST/Support/jre"; jdk=$(mktemp -d)
  rm -rf "$out"
  tar -xzf "$(fetch "$LINUX_JMODS" "" "$LINUX_JMODS_SHA256")" -C "$jdk"
  "$JDK_HOME/bin/jlink" --module-path "$(echo "$jdk"/*-jmods)" --add-modules "$JRE_MODULES" \
    --strip-debug --no-man-pages --no-header-files --compress=zip-6 --output "$out"
  rm -rf "$jdk"
  # jlink silently links the Mac's own modules when the module path lacks java.base.
  file "$out/bin/java" | grep -q 'ELF 64-bit.*x86-64' || { echo "Support/jre isn't a Linux x64 runtime" >&2; exit 1; }
  du -sh "$out"
}

linux_base() {
  mkdir -p "$LINUX_DIST/Support"
  cp "$LIB/linux-launch.sh" "$LINUX_DIST/Support/launch"
  cp "$LIB/linux-install.sh" "$LINUX_DIST/install.sh"
  chmod +x "$LINUX_DIST/Support/launch" "$LINUX_DIST/install.sh"
  # Keep its program list in sync with PROGRAMS. Its title says @VERSION@.
  sed "s/@VERSION@/$HDE_VERSION/" "$LIB/README-linux.md" >"$LINUX_DIST/README.md"
  [ -d "$LINUX_DIST/Support/jre" ] || linux_jre
}

linux_finish() { :; }

# ================================================================ driver

PROGRAMS=(magictile pcubes mc7dkb mpu ms5d mht633 mc5d m120c mc4d elevencell elevencell3d mc3d isocubesim hsc1 hsc2 circleguy 3to4pp gelatinbrain geraniumspot flat-hypercube laminated)
MDX_PROGRAMS=" mc7dkb mpu ms5d mht633 "

# check_complete <edition>: fail unless the edition's folder has every program.
check_complete() {
  local n
  case $1 in
    mac) n=$(find "$MAC_DIST" -mindepth 1 -maxdepth 1 -name '*.app' | wc -l) ;;
    linux) n=$(find "$LINUX_DIST" -mindepth 2 -maxdepth 2 -name run | wc -l) ;;
  esac
  n=$((n))
  [ "$n" = "${#PROGRAMS[@]}" ] || { echo "$1 edition has $n programs, expected ${#PROGRAMS[@]}: run ./build.sh $1" >&2; exit 1; }
}

case "${1:-}" in
  list) printf '%s\n' "${PROGRAMS[@]}"; exit 0 ;;
  install)
    log "Installing into $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    for item in "$MAC_DIST"/*; do
      dest="$INSTALL_DIR/$(basename "$item")"
      rm -rf "$dest"
      cp -cR "$item" "$dest" 2>/dev/null || cp -R "$item" "$dest"
    done
    exit 0 ;;
  package)
    check_complete mac
    check_complete linux
    zip="$HERE/dist/hypercubing-mac-$HDE_VERSION.zip"
    log "Zipping $zip"
    rm -f "$zip"
    # ditto keeps symlinks and macOS metadata, which zip(1) would drop.
    ditto -c -k --keepParent "$MAC_DIST" "$zip"
    tarball="$HERE/dist/hypercubing-linux-$HDE_VERSION.tar.gz"
    log "Packing $tarball"
    # No macOS extended attributes or owner names: GNU tar warns about them on every file.
    /usr/bin/bsdtar --no-xattrs --no-mac-metadata --uid 0 --gid 0 --uname root --gname root \
      -czf "$tarball" -C "$(dirname "$LINUX_DIST")" hypercubing
    du -h "$zip" "$tarball"
    exit 0 ;;
esac

editions=(mac linux)
case "${1:-}" in mac|linux) editions=("$1"); shift ;; esac
if [ $# = 0 ]; then
  targets=("${PROGRAMS[@]}")
  # A full build starts from empty folders, so nothing stale ships.
  for e in "${editions[@]}"; do
    if [ "$e" = mac ]; then rm -rf "$MAC_DIST"; else rm -rf "$LINUX_DIST"; fi
  done
else
  targets=("$@")
fi
for t in "${targets[@]}"; do
  [[ " ${PROGRAMS[*]} " == *" $t "* ]] || { echo "unknown program $t (see ./build.sh list)" >&2; exit 1; }
done

for t in "${targets[@]}"; do
  if [[ $MDX_PROGRAMS == *" $t "* ]]; then build_mdxshim; break; fi
done
for e in "${editions[@]}"; do "${e}_base"; done
for t in "${targets[@]}"; do
  shared=""
  for e in "${editions[@]}"; do
    if declare -F "payload_${t}_$e" >/dev/null; then
      PAYLOAD_PLAT=$e; "payload_${t}_$e"
      p="$BUILD/$e/$t"
    else
      if [ -z "$shared" ]; then PAYLOAD_PLAT=any; "payload_$t"; shared=1; fi
      p="$BUILD/any/$t"
    fi
    "package_$e" "$p"
  done
done
for e in "${editions[@]}"; do "${e}_finish"; done
log "Done: $(for e in "${editions[@]}"; do [ "$e" = mac ] && printf '%s ' "$MAC_DIST" || printf '%s ' "$LINUX_DIST"; done)"
