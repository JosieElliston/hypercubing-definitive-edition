# Hypercubing Definitive Edition @VERSION@ (for Linux)

The main hypercubing programs, ready to run on Linux. The Java ones run on a
bundled Java runtime. The Windows ones run on your own copy of Wine, with the
changes they need to work there already made (see below).

Requires a 64-bit x86 PC. It should work on any distribution.

## Installing

1. Extract this "hypercubing" folder somewhere your user can write to, such as
   your home folder. Programs save their settings inside it, so a system folder
   like /opt won't work.
2. Install Wine with your distribution's package manager, if you haven't already.
   The package is usually called "wine". Version 9 or newer is recommended.
3. Optionally, run `./install.sh` in this folder to add the programs to your
   application menu. Run it again if you move the folder, or run
   `./install.sh --uninstall` to remove them from the menu.

To start a program without the menu, run the `run` file in its folder.

## Contents

- Windows programs, run through Wine:
    - MagicTile          puzzles on 2D tilings, including hyperbolic ones
    - pCubes             nearly every 3D twisty puzzle
    - MC7D-KB            Magic Cube 7D (3D to 7D cubes), with keybinds
    - Magic Puzzle Ultimate  4D puzzles on many polytopes
    - Magic Simplex 5D   the 5D simplex puzzle
    - Magic Hyperbolic Tile  a puzzle on the {6,3,3} hyperbolic honeycomb
    - Magic Cube 5D      5D cubes, from 2^5 to 7^5
    - Magic120Cell       the 120-cell, a 4D megaminx
    - circleguy          rotating-circle puzzles
    - 3to4++             the physical 3x3x3x3 design, simulated
    - Geraniums Pot      intersecting-circle puzzles, with photos of the real ones
- Java programs:
    - Magic Cube 4D      the classic 4D puzzle program
    - Eleven Cell        Nan Ma's 11-cell
    - ElevenCell3D       another 11-cell simulator
    - Magic Cube 3D      a 3D Rubik's cube simulator
    - IsoCubeSim         isometric AxBxC cubes and N-layer megaminxes
    - Gelatinbrain       Virtual Magic Polyhedra: a huge, strange puzzle collection
- Native Linux programs:
    - Hyperspeedcube 1   the recommended place to start (version 1.0.12)
    - Hyperspeedcube 2   the in-development successor (2.0.0-zeta.12)
- Shared parts, in "Support" (don't open these directly):
    - jre                Java, which runs the Java programs
    - launch             starts every program

## Where your stuff goes

Everything stays inside this folder.

- Each program keeps its settings and saves in its own folder.
- The Windows programs share one simulated Windows computer, in
  "Support/wineprefix". It's created the first time you open any Windows
  program, which can take a minute. Wine may offer to download "Wine Mono"
  then: accept, since most of these programs need it.
- Inside the Windows programs, your Linux files are on drive Z:.
- Logs are in "Support/logs".

To update, extract a newer version over this folder. Settings and saves are
kept.

## Tips and known issues

- If a program doesn't open, look at its log in "Support/logs".
- To start the Windows programs over, quit them all, then delete
  "Support/wineprefix".
- To use a different Wine than the one on your PATH, set `WINE` to its `wine`
  command, e.g. `WINE=~/wine-11.0/bin/wine ./MagicTile/run`.
- Magic Puzzle Ultimate's Puzzle menu has an extra "hypercubing.xyz" submenu
  with the puzzle definitions from hypercubing.xyz's MPU page.

## Changes made for this bundle

Some Windows programs needed changes to run under Wine. They should look and
behave like the originals, and their saves and logs are compatible.

- MagicTile runs as a 64-bit program; under Wine, the original is much slower.
- MC7D-KB, Magic Puzzle Ultimate, Magic Simplex 5D and Magic Hyperbolic Tile
  were built on Microsoft's Managed DirectX, which doesn't work under Wine.
  They run unmodified on a stand-in written for this bundle, also as 64-bit
  programs. If one of them draws something wrong, the stand-in is the likely cause.
- Magic Cube 5D and Magic120Cell were partly written in C++/CLI, which only
  Microsoft's .NET can run. That part was rewritten.
- Gelatinbrain has fallback renderers for 11 puzzles whose shaders need GLSL
  1.30. They're only used if your graphics driver can't run those shaders;
  most Linux drivers can.
- circleguy and 3to4++ are Windows builds of their source, made for this bundle.
  Geraniums Pot is its author's own Windows build.

## Uninstalling

Run `./install.sh --uninstall`, then delete this folder.

## Credits

All programs belong to their authors. This bundle packages them, with the
changes listed above.
- Hyperspeedcube     Andrew Farkas (HactarCE)    github.com/HactarCE/Hyperspeedcube
- Magic Cube 4D      Melinda Green, Don Hatch, Jay Berkenbilt, Roice Nelson superliminal.com/cube
- MagicTile          Roice Nelson                github.com/roice3/MagicTile
- pCubes             Boris Mouradov              twistypuzzles.com forum, topic 27054
- MC7D-KB            Andrey Astrelin (Magic Cube 7D); keybinds fork by Aegyo  github.com/Aegyo/mc7d-kb
- Magic Puzzle Ultimate  Andrey Astrelin         superliminal.com/andrey/mpu
- Magic Simplex 5D   Andrey Astrelin             superliminal.com/andrey/ms5d
- Magic Hyperbolic Tile  Andrey Astrelin         superliminal.com/andrey/mht633
- Magic Cube 5D      Roice Nelson                github.com/roice3/MagicCube5D
- Magic120Cell       Roice Nelson                github.com/roice3/Magic120Cell
- Eleven Cell        Nan Ma                      superliminal.com/cube
- ElevenCell3D       SuperSnowman16              github.com/SuperSnowman16/ElevenCell3D
- Magic Cube 3D      rzhao271                    github.com/rzhao271/MC3D
- IsoCubeSim         mzrg                        mzrg.com/rubik/iso
- Gelatinbrain       gelatinbrain; packaged by Luna and Hactar  github.com/Hypercubers/gelatinbrain
- 3to4++             rayzchen; fork by gwstaten  github.com/gwstaten/3to4pp
- circleguy          henrydukepickle             github.com/henrydukepickle/circleguy
- Geraniums Pot      grigorusha                  github.com/grigorusha/GeraniumsPot
- Java runtime       Eclipse Temurin (Adoptium)

More hypercubing software and resources: hypercubing.xyz
