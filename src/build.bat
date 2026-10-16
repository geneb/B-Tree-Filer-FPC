@echo off
rem Builds the B-Tree Filer units and the example programs with Free Pascal.
rem
rem Usage:  build [additional fpc options]
rem
rem The compiled units are written to .\units, the programs to .\bin.

cd /d "%~dp0"
if not exist units mkdir units
if not exist bin mkdir bin

for %%U in (basesupp filer numkeys reorg rebuild vrec vreorg vrebuild fixtovar iscompat vrcompat isamtool tpalloc msort tpcmd browser carrconv dbimpexp) do (
  fpc %* -FUunits -Fuunits %%U.pas
  if errorlevel 1 goto error
)
for %%P in (bigsort convert db2isam isam2db example netexamp traffic simpdemo netdemo) do (
  fpc %* -FUunits -Fuunits -FEbin %%P.pas
  if errorlevel 1 goto error
)
echo Build completed.
goto end

:error
echo Build failed.
exit /b 1

:end
