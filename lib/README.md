# Hypercubing Definitive Edition 1.0 (for Mac)

This folder has the main hypercubing programs, ready to run on a Mac.
The Windows ones run through a bundled copy of Wine,
and the Java ones use a bundled Java runtime.

Requires an Apple Silicon Mac.

## Installing

1. Move this whole "hypercubing" folder into Applications. You can put it
   somewhere else, but keep the "Support" folder next to the apps, because every
   app uses it.
2. macOS blocks apps downloaded from the internet that aren't signed by a
   registered Apple developer, and these aren't. To allow them, open Terminal and
   run:
```
xattr -dr com.apple.quarantine /Applications/hypercubing
```
3. The Windows programs need Rosetta, Apple's Intel translator. If you have never
   installed it, run this in Terminal:
```
softwareupdate --install-rosetta --agree-to-license
```

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
- Java programs:
    - Magic Cube 4D      the classic 4D puzzle program
    - Eleven Cell        Nan Ma's 11-cell
    - ElevenCell3D       another 11-cell simulator
    - Magic Cube 3D      a 3D Rubik's cube simulator
    - IsoCubeSim         isometric AxBxC cubes and N-layer megaminxes
    - Gelatinbrain       Virtual Magic Polyhedra: a huge, strange puzzle collection
- Native Mac programs:
    - Hyperspeedcube 1   the recommended place to start (version 1.0.12)
    - Hyperspeedcube 2   the in-development successor (2.0.0-zeta.12)
    - circleguy          rotating-circle puzzles
    - 3to4++             the physical 3x3x3x3 design, simulated
    - Geraniums Pot      610 intersecting-circle puzzles, with photos of the real ones
- Shared parts (in "Support"; don't open these directly):
    - engine             Wine, which runs the Windows programs (about 490 MB)
    - jre                Java, which runs the Java programs (about 51 MB)

Everything runs on that one copy of Wine and one copy of Java,
so the folder is about 1 GB.

## Where your stuff goes

Settings, saved puzzles, and logs go in `~/Library/Application Support/Hypercubing/`,
not in this folder.

- The Windows programs share one simulated Windows computer, stored in "prefix" there.
  It is created the first time you open any Windows program,
  which takes about 30 seconds once.
  After that, they start in a few seconds.
- Inside Windows programs, C:\users\crossover\Desktop, Documents, and Downloads
  are your real Mac Desktop, Documents, and Downloads folders.
  Save logs there to find them easily.
- Java programs, circleguy and Geraniums Pot keep their files in a folder named after the program.
- Updating this folder never removes your settings or saves.

## Tips and known issues

- Windows programs show up in the Dock under their Windows name (for example "MagicTile.exe").
- If a program doesn't open, look at its log in the "logs" folder (see above).
- Starting over with the Windows programs: quit them all,
  then delete the "prefix" folder. This loses their settings and saves.
- MagicTile is modified slightly so it runs as a 64-bit program.
  Under Wine, the unmodified version is much slower.
- MC7D-KB, Magic Puzzle Ultimate, Magic Simplex 5D and Magic Hyperbolic Tile
  were built on Microsoft's Managed DirectX, which doesn't work under Wine.
  They run on a stand-in written for this bundle, also as 64-bit programs.
  If one of them draws something wrong, the stand-in is the likely cause.
- Magic Cube 5D and Magic120Cell were modified for this bundle: part of each
  was written in a variant of C++ (C++/CLI) that only Microsoft's .NET can run,
  and it was rewritten so they run under Wine. They should look and behave
  the same as the originals, and their log files are compatible.
- Magic Puzzle Ultimate's Puzzle menu has an extra "hypercubing.xyz" submenu
  with the puzzle definitions published on hypercubing.xyz's MPU page.
- Geraniums Pot's F7 saves a screenshot into its folder (see above), but doesn't copy it
  to the clipboard as it does on Windows. Its puzzle files are in the "Garden" folder there.

## Uninstalling

Delete this folder and `~/Library/Application Support/Hypercubing/`.

## Credits

All programs belong to their authors. This bundle only packages them.
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
- Wine engine        WineHQ, CodeWeavers, and the Sikarugir project

More hypercubing software and resources: hypercubing.xyz
