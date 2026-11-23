# Hypercubing Definitive Edition @VERSION@ (for Mac)

The main hypercubing programs, ready to run on a Mac. The Windows ones run
through a bundled copy of Wine, and the Java ones on a bundled Java runtime,
so you don't need to install either.

Requires an Apple Silicon Mac.

## Installing

1. Move this whole `hypercubing` folder into `/Applications`. You can put it
   somewhere else, but keep the `Support` folder next to the apps: every app
   uses it.
2. macOS blocks downloaded apps that aren't signed by a registered Apple
   developer, and these aren't. To allow them, open Terminal and run this
   (with the folder's real location, if you put it somewhere else):

   ```sh
   xattr -dr com.apple.quarantine /Applications/hypercubing
   ```

3. The Windows programs need Rosetta, Apple's Intel translator. If you've never
   installed it, run this in Terminal:

   ```sh
   softwareupdate --install-rosetta --agree-to-license
   ```

## Contents

- Windows programs, run through Wine:
  - **MagicTile** — puzzles on 2D tilings, including hyperbolic ones
  - **pCubes** — nearly every 3D twisty puzzle
  - **MC7D-KB** — Magic Cube 7D (3D to 7D cubes), with keybinds
  - **Magic Puzzle Ultimate** — 4D puzzles on many polytopes
  - **Magic Simplex 5D** — the 5D simplex puzzle
  - **Magic Hyperbolic Tile** — a puzzle on the {6,3,3} hyperbolic honeycomb
  - **Magic Cube 5D** — 5D cubes, from 2^5 to 7^5
  - **Magic120Cell** — the 120-cell, a 4D megaminx
- Java programs:
  - **Magic Cube 4D** — the classic 4D puzzle program
  - **Eleven Cell** — Nan Ma's 11-cell
  - **ElevenCell3D** — another 11-cell simulator
  - **Magic Cube 3D** — a 3D Rubik's cube simulator
  - **IsoCubeSim** — isometric AxBxC cubes and N-layer megaminxes
  - **Gelatinbrain** — Virtual Magic Polyhedra: a huge, strange puzzle collection
- Native Mac programs:
  - **Hyperspeedcube 1** — the recommended place to start (version 1.0.12)
  - **Hyperspeedcube 2** — the in-development successor (2.0.0-zeta.12)
  - **circleguy** — rotating-circle puzzles
  - **Flat Hypercube** — terminal simulator for hypercubes up to 10D
  - **Laminated** — laminated cube, octahedron, and dodecahedron puzzles
  - **3to4++** — the physical 3x3x3x3 design, simulated
  - **Geraniums Pot** — 610 intersecting-circle puzzles, with photos of the real ones
- Shared parts (in `Support`; don't open these directly):
  - `engine` — Wine, which runs the Windows programs (about 490 MB)
  - `jre` — Java, which runs the Java programs (about 51 MB)

Sharing one copy of Wine and one of Java keeps the folder to about 800 MB.

## Where your stuff goes

Most programs store settings, saved puzzles, and logs in
`~/Library/Application Support/Hypercubing/`.

- The Windows programs share one simulated Windows computer, stored in the `prefix`
  folder there. It's created the first time you open any Windows program, which
  takes about 30 seconds. After that, they start in a few seconds.
- Inside Windows programs, `C:\users\crossover\Desktop`, Documents and Downloads
  are your real Mac Desktop, Documents and Downloads folders. Save logs there to
  find them easily.
- The other programs keep their files in a folder named after the program,
  except Hyperspeedcube, which uses its usual `~/Library/Application Support/Hyperspeedcube/`.
- Flat Hypercube writes new solve logs to the terminal's current directory and
  resolves relative paths for logs, filters, and preferences from there.
- Installing a newer version of this folder keeps your settings and saves.

## Tips and known issues

- Windows programs show up in the Dock under their Windows name (for example `MagicTile.exe`).
- If a program doesn't open, look at its log in the `logs` folder (see above).
- To start the Windows programs over, quit them all, then delete the `prefix`
  folder. This loses their settings, and any saves you kept inside the simulated
  Windows computer.
- Magic Puzzle Ultimate's Puzzle menu has an extra "hypercubing.xyz" submenu
  with the puzzle definitions from hypercubing.xyz's MPU page.
- Run Flat Hypercube from Terminal with the layer count and dimension, or with
  `--log` to resume a solve. For the full list of flags, run
  `"/Applications/hypercubing/Flat Hypercube.app/Contents/MacOS/launcher" --help`.
  Opening its icon starts it without arguments, so it reports the missing
  arguments and exits.
- Geraniums Pot's puzzle files are in the `Garden` folder in its folder. `F7` saves
  a screenshot there, but doesn't copy it to the clipboard as it does on Windows.

## Changes made for this bundle

Some programs needed changes to run on a Mac. They should look and behave like
the originals, and their saves and logs are compatible.

- MagicTile runs as a 64-bit program; under Wine, the original is much slower.
- MC7D-KB, Magic Puzzle Ultimate, Magic Simplex 5D and Magic Hyperbolic Tile
  were built on Microsoft's Managed DirectX, which doesn't work under Wine.
  They run unmodified on a stand-in written for this bundle, also as 64-bit
  programs. If one of them draws something wrong, the stand-in is the likely cause.
- Magic Cube 5D and Magic120Cell were partly written in C++/CLI, which only
  Microsoft's .NET can run. That part was rewritten.
- Gelatinbrain uses fallback renderers for 11 puzzles that would otherwise
  show a blank canvas because their shaders require GLSL 1.30.
- circleguy and 3to4++ are Mac builds of their source, made for this bundle.
- Geraniums Pot is a Mac build of its source, made for this bundle, with
  three Mac-only fixes: it no longer crashes on start, ring markers no longer
  show black boxes while turning, and it keeps its settings in its own folder
  instead of your home folder.

## Uninstalling

Delete this folder and `~/Library/Application Support/Hypercubing/`.

## Credits

All programs belong to their authors. This bundle packages them, with the
changes listed above.

| Program or component | Author or project | Link |
| --- | --- | --- |
| Hyperspeedcube | Andrew Farkas (HactarCE) | [github.com/HactarCE/Hyperspeedcube](https://github.com/HactarCE/Hyperspeedcube) |
| Magic Cube 4D | Melinda Green, Don Hatch, Jay Berkenbilt, Roice Nelson | [superliminal.com/cube](https://superliminal.com/cube) |
| MagicTile | Roice Nelson | [github.com/roice3/MagicTile](https://github.com/roice3/MagicTile) |
| pCubes | Boris Mouradov | twistypuzzles.com forum, topic 27054 |
| MC7D-KB | Andrey Astrelin (Magic Cube 7D); keybinds fork by Aegyo | [github.com/Aegyo/mc7d-kb](https://github.com/Aegyo/mc7d-kb) |
| Magic Puzzle Ultimate | Andrey Astrelin | [superliminal.com/andrey/mpu](https://superliminal.com/andrey/mpu) |
| Magic Simplex 5D | Andrey Astrelin | [superliminal.com/andrey/ms5d](https://superliminal.com/andrey/ms5d) |
| Magic Hyperbolic Tile | Andrey Astrelin | [superliminal.com/andrey/mht633](https://superliminal.com/andrey/mht633) |
| Magic Cube 5D | Roice Nelson | [github.com/roice3/MagicCube5D](https://github.com/roice3/MagicCube5D) |
| Magic120Cell | Roice Nelson | [github.com/roice3/Magic120Cell](https://github.com/roice3/Magic120Cell) |
| Eleven Cell | Nan Ma | [superliminal.com/cube](https://superliminal.com/cube) |
| ElevenCell3D | SuperSnowman16 | [github.com/SuperSnowman16/ElevenCell3D](https://github.com/SuperSnowman16/ElevenCell3D) |
| Magic Cube 3D | rzhao271 | [github.com/rzhao271/MC3D](https://github.com/rzhao271/MC3D) |
| IsoCubeSim | mzrg | [mzrg.com/rubik/iso](https://mzrg.com/rubik/iso) |
| Gelatinbrain | gelatinbrain; packaged by Luna and Hactar | [github.com/Hypercubers/gelatinbrain](https://github.com/Hypercubers/gelatinbrain) |
| 3to4++ | rayzchen; fork by gwstaten | [github.com/gwstaten/3to4pp](https://github.com/gwstaten/3to4pp) |
| circleguy | henrydukepickle | [github.com/henrydukepickle/circleguy](https://github.com/henrydukepickle/circleguy) |
| Flat Hypercube | Milo Jacquet | [github.com/milojacquet/flat-hypercube](https://github.com/milojacquet/flat-hypercube) |
| Laminated | Milo Jacquet | [github.com/milojacquet/laminated](https://github.com/milojacquet/laminated) |
| Geraniums Pot | grigorusha | [github.com/grigorusha/GeraniumsPot](https://github.com/grigorusha/GeraniumsPot) |
| Wine engine | WineHQ, CodeWeavers, and the Sikarugir project | |
| Java runtime | Eclipse Temurin (Adoptium) | |

More hypercubing software and resources: [hypercubing.xyz](https://hypercubing.xyz)
