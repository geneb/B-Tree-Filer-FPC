#
#                            FILER.MAK 5.41
#         Make file used to build Single-User B-Tree Filer 5.41
#
# This make file is designed to be used only with Borland's MAKE utility; it
# does NOT work with Microsoft's MAKE. To use this file, enter
#
#     MAKE -fFILER.MAK
#
# at the DOS command line.
#
# FILER.MAK is designed to work with Turbo Pascal 5.0-7.0, or
# Turbo Pascal for Windows, and either Turbo Assembler 1.0+ or the
# Microsoft Assembler 4.0+. This is made possible by MAKE's equivalent of
# conditional compilation directives. There are several macros that must
# either be defined or commented out, depending on what version of the
# compiler you have and what assembler, if any. See the comments in the
# Defines section of this file for further instructions.

# You may also need to modify the definitions below in order for MAKE to be
# able to find your compiler and assembler. To comment out a macro or define
# insert '#' at the beginning of the line, as is being done here.

# --------------------------------------------------------------------- Defines

# Uncomment this for Turbo Pascal for Windows or for a
# Borland Pascal 7.0 Windows target
# ForWindows=1

# If compiling for Windows, activate this line to use the Borland Pascal 7.0
# compiler or comment it out to use Turbo Pascal for Windows compiler
!if $d(ForWindows)
UseBP7=1
!endif

# Activate this line for Borland Pascal 7.0 pmode,
# or comment it out for real mode.
# ForPMode=1

# Set this to 1 for Turbo Assembler, or comment it out for Microsoft Assembler.
tasm=1

# Comment this line out if you do not have an assembler.
HaveAssembler=1

# ---------------------------------------------------------------------- Macros
# If your assembler or compiler is not located in a directory on the DOS path,
# or if you are running under DOS 2.x, insert the complete pathname of the
# relevant executable file in the following definitions. For example, if
# your copy of TPC.EXE is located in the directory C:\TP5 then you would
# change the following line to
#
#     compile=C:\TP5\TPC.EXE /M /$D- /$L- /L
#
# You may also want to change the default compilation directives by adding them
# at the end of command line.

!if $d(tasm)
assemble=TASM.EXE
!else
assemble=MASM.EXE
!endif

# You may need to modify these command line options and file extensions
!if $d(ForWindows)
!if !$d(UseBP7)
compile=TPCW.EXE /M /$D- /$L- /L
uext=TPU
!else
compile=BPC.EXE /CW /M /$D- /$L-
uext=TPW
!endif
!else
!if $d(ForPMode)
compile=BPC.EXE /CP /M /$D- /$L-
uext=TPP
!else
compile=TPC.EXE /M /$D- /$L- /L
uext=TPU
!endif
!endif

# --------------------------------------- Other factors that affect compilation
#
# Note that you must edit BTDEFINE.INC to specify a network option
# and other conditional defines that affect B-Tree Filer
# By default, BTDEFINE.INC specifies the NoNet option.

# ---------------------------------------- Force evaluation of all dependencies

!if $d(ForWindows)
dummy : numkeys.obj \
        basesupp.$(uext) \
        filer.$(uext) fixtovar.$(uext) isamtool.$(uext) \
        iscompat.$(uext) numkeys.$(uext) \
        rebuild.$(uext) reorg.$(uext) vrcompat.$(uext) \
        vrebuild.$(uext) vrec.$(uext) vreorg.$(uext) \
        carrconv.$(uext) dbimpexp.$(uext) \
        convert.exe example.exe
!else
!if $d(ForPMode)
dummy : numkeys.obj \
        basesupp.$(uext) \
        filer.$(uext) fixtovar.$(uext) isamtool.$(uext) \
        iscompat.$(uext) numkeys.$(uext) \
        rebuild.$(uext) reorg.$(uext) vrcompat.$(uext) \
        vrebuild.$(uext) vrec.$(uext) vreorg.$(uext) \
        browser.$(uext) \
        tpcmd.$(uext) \
        carrconv.$(uext) dbimpexp.$(uext) db2isam.exe isam2db.exe \
        simpdemo.exe convert.exe \
        example.exe
!else
dummy : numkeys.obj \
        basesupp.$(uext) emsheap.$(uext) emssupp.$(uext) \
        filer.$(uext) fixtovar.$(uext) isamtool.$(uext) \
        iscompat.$(uext) msort.$(uext) numkeys.$(uext) \
        rebuild.$(uext) reorg.$(uext) vrcompat.$(uext) \
        vrebuild.$(uext) vrec.$(uext) vreorg.$(uext) \
        browser.$(uext) \
        tpalloc.$(uext) \
        tpcmd.$(uext) \
        carrconv.$(uext) dbimpexp.$(uext) db2isam.exe isam2db.exe \
        bigsort.exe simpdemo.exe \
        convert.exe example.exe
!endif
!endif

# -------------------------------------------------------------- Implicit rules

!if $d(HaveAssembler)
.asm.obj:
  $(assemble) $*;
!endif

.pas.exe:
  $(compile) $*

.pas.$(uext):
  $(compile) $*

.pas.dll:
  $(compile) $*

# ---------------------------------------------------- Assembly Language Source

!if $d(HaveAssembler)

numkeys.obj: numkeys.asm

!endif

# ---------------------------------------------------- Library Units

basesupp.$(uext): basesupp.pas btdefine.inc

browser.$(uext): browser.pas browser.inc btdefine.inc filer.$(uext) \
           vrec.$(uext) tpcmd.$(uext)

carrconv.$(uext): carrconv.pas btdefine.inc

dbimpexp.$(uext): dbimpexp.pas btdefine.inc dbimpexp.in1 dbimpexp.in2 \
           carrconv.$(uext) filer.$(uext)

!if !$d(ForWindows)
!if !$d(ForPMode)
emsheap.$(uext): emsheap.pas btdefine.inc emssupp.$(uext)

emssupp.$(uext): emssupp.pas btdefine.inc basesupp.$(uext)
!endif
!endif

!if $d(ForWindows) || $d(ForPMode)
filer.$(uext): filer.pas btdefine.inc filer.cfg \
           basesupp.$(uext) \
           filer.inc \
           isambase.inc isamlow.inc isamwork.inc
!else
filer.$(uext): filer.pas btdefine.inc filer.cfg \
           emsheap.$(uext) basesupp.$(uext) \
           filer.inc \
           isambase.inc isamlow.inc isamwork.inc
!endif

fixtovar.$(uext): fixtovar.pas btdefine.inc \
           filer.$(uext) reorg.$(uext) vreorg.$(uext)

isamtool.$(uext): isamtool.pas btdefine.inc basesupp.$(uext) filer.$(uext)

iscompat.$(uext): iscompat.pas btdefine.inc filer.$(uext)

!if !$d(ForWindows)
!if !$d(ForPMode)
msort.$(uext): msort.pas btdefine.inc msortems.inc msortinf.inc \
           tpalloc.$(uext) emssupp.$(uext)
!endif
!endif

numkeys.$(uext): numkeys.pas btdefine.inc numkeys.obj

rebuild.$(uext): rebuild.pas btdefine.inc filer.$(uext) reorg.$(uext)

reorg.$(uext): reorg.pas btdefine.inc filer.$(uext)

tpalloc.$(uext): tpalloc.pas

tpcmd.$(uext): tpcmd.pas

vrcompat.$(uext): vrcompat.pas btdefine.inc vrec.$(uext) filer.$(uext)

vrebuild.$(uext): vrebuild.pas btdefine.inc filer.$(uext) vreorg.$(uext)

vrec.$(uext): vrec.pas btdefine.inc filer.$(uext)

vreorg.$(uext): vreorg.pas btdefine.inc filer.$(uext) vrec.$(uext)

# ---------------------------------------------------- Demo Programs

!if !$d(ForWindows)
!if !$d(ForPMode)
bigsort.exe: bigsort.pas msort.$(uext)
!endif
!endif

simpdemo.exe: simpdemo.pas btdefine.inc filer.$(uext) \
        rebuild.$(uext) browser.$(uext)

# NETDEMO is not included so the make file will work for folks who don't
# own Turbo Professional.
# Activate the following lines if you have Turbo Professional and want
# to update NETDEMO.EXE regularly.

# netdemo.exe: netdemo.pas btdefine.inc filer.$(uext) vrec.$(uext) \
#              vrebuild.$(uext) browser.$(uext)

# ---------------------------------------------------- Misc Programs

convert.exe: convert.pas filer.$(uext) reorg.$(uext)

example.exe: example.pas filer.$(uext)

db2isam.exe: db2isam.pas filer.$(uext) dbimpexp.$(uext)

isam2db.exe: isam2db.pas filer.$(uext) dbimpexp.$(uext)

