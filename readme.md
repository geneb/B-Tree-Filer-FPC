# TurboPower B-Tree Filer v5.41 - Free Pascal version for Linux & Windows

22 years ago, TurboPower Software closed their doors as a retail software company and released all of their development libraries the for Borland[1]/CodeGear/Embarcadero Delphi compiler.  These items were released under a Mozilla 1.1 license.

Here's their original announcement: http://www.turbopower.com/

Unfortunately, nobody seems to have been able to get their attention about making their fantastic MS-DOS libraries for Turbo Pascal available online.

Their website clearly states, "TurboPower libraries released as open source".  Their MS-DOS libraries would appear to fall under that statement.  Maybe they figured, "Hey, it's 2003. Nobody's going to be interested in this ancient DOS stuff!"

Well dammit, **I'm** interested!  I'm sure I'm not the only one.

The original product description for B-Tree Filer can be found [here](https://web.archive.org/web/19990202093239/http://www.turbopower.com/products/btree/).

I owned a copy of B-Tree Filer that I used back in the mid 90's and after chasing down some patch updates, this repository is the result.  At some point, I'll be adding photos and binary images of my original diskettes.

While setting up this repository, I found that version 5.55 of B-Tree Filer for DOS may have been the last version released for DOS.  If you have that version, please reach out!

The original MS-DOS version of B-Tree Filer can be found here: https://github.com/geneb/B-Tree-Filer

## Free Pascal port

This version of B-Tree Filer has been ported to Free Pascal (tested with version 3.2.2) and runs under Windows and Linux. All inline machine code and assembler source has been replaced by Pascal code, and the MS-DOS specific parts were replaced as follows:

* File access uses the Windows API or the Linux system calls instead of INT 21h, through a small operating system layer in `src/basesupp.pas`.
* The multi-user (MsNet) version uses the byte range locking of the operating system: `LockFileEx` on Windows and open file description locks (`fcntl`) on Linux. Several programs on one computer, or on several computers sharing files over a network (if the network file system supports byte range locks), can work on the same fileblocks. Under Linux, locks are only advisory, so other programs that don't use B-Tree Filer can still read and write locked areas.
* EMS support has been removed; page buffers and sort buffers use the normal heap. Since the heap is practically unlimited, `MemAvail` and `MaxAvail` (in `basesupp.pas`) report the free space of a "virtual heap" whose size is set by `BTVirtualHeapSize` (4 MB by default). This limits the size of the page buffer allocated by `BTInitIsam`.
* The Novell NetWare, NetBIOS and IPX/SPX units and their example programs, the EMS units and the Borland Makefiles have no equivalent under Windows and Linux. They are kept, unchanged, in `src/unported`.
* The dependencies on Turbo Professional and Object Professional have been removed. `netdemo.pas` now contains its own simple entry screen and memo editor.
* Data and index files are binary compatible with the MS-DOS version (all records are byte packed and `Integer` stays 16 bit, as in Turbo Pascal). Your own record types may need attention: `Real` has 8 bytes in Free Pascal (use `Real48` for the 6 byte Turbo Pascal type), and `Extended` has 10 bytes on Linux but only 8 bytes on Win64.
* The default file name extensions are now lower case (`dat`, `ix`, `dia`, `sav`, `msg`), since Linux file names are case sensitive.

`changes.txt` lists every changed file.

* The original distribution source code can be found in the src/unported/lzh directory.  The LZH files can be opened with 7zip.
## Building

You need Free Pascal 3.2 or later. Change to the `src` directory and run `./build.sh` (Linux) or `build.bat` (Windows). This compiles all units into `src/units` and the example programs into `src/bin`. Options given on the command line are passed to the compiler, for example `./build.sh -Twin64` makes a 64 bit Windows cross build on Linux.

The file `src/btdefine.inc` has settings that can be changed in order to affect how B-Tree Filer is built and functions, for example `NoNet` for a single user version, or `AsciiZeroKeys` for C-style keys.  It would be worth your time to peruse that file - note that unless you know **why** you're going to change something, you probably should leave it the default.

## Using the units from your own programs

The B-Tree Filer units are compiled in `{$MODE TP}` with byte packed records (see the top of `btdefine.inc`). This keeps `Integer` 16 bits wide and the record layouts identical to Turbo Pascal, which is what keeps the data and index files compatible with the MS-DOS version.

The compiler mode is set per unit, so your own programs can use any mode, including `{$MODE OBJFPC}` or `{$MODE DELPHI}` with classes, exceptions and overloading. The simplest choice for code that comes from the MS-DOS version is to start the program with `{$I btdefine.inc}`, so it is compiled exactly like the B-Tree Filer units. If you use another mode, watch for two things:

* **Records stored in a fileblock.** In ObjFPC and Delphi mode `Integer` is 32 bits. Declare the record `packed` and use `SmallInt` where the MS-DOS version used `Integer` (`Word`, `LongInt`, `Byte` and `ShortInt` have the same size in all modes). Otherwise the record layout won't match existing data files.
* **Routines passed as pointers.** Callbacks such as the BuildKey function for `ReorgFileBlock`/`RebuildFileBlock`, the Browser routines and the MSort routines are passed as untyped `Pointer`s, so the compiler can't check their parameter lists. Where B-Tree Filer declares a parameter as `Integer`, your routine must use `SmallInt` (or `Word`), or it will misbehave at run time. The procedure types declared in the units (for example `ReorgBuildKeyFunc` in `reorg.pas` and `BrowseBuildRowProc` in `browser.pas`) show the expected parameter lists.

## Documentation

The help files in the `help` directory can be rebuilt using the MAKEHELP program in the `tools` directory (an MS-DOS program).

The manual for version 5.23 of B-Tree Filer is available here: https://archive.org/details/b-tree-filer-v-5.23

If you or someone you know has a more recent version of the B-Tree Filer manual, please reach out.  I can non-destructively scan it at my expense and return it.

Hopefully more people than just me will find this repository useful.




