{
  Simple program to reset the NetBIOS adapter (clears out the NetBIOS name
  table).

  Please address questions or comments regarding this utility on Compuserve in
  the PCVENB forum in section 6.

  by Richard S. Sadowsky
  5/3/90
}
program NBReset;
uses NetBIOS;

begin
  if ResetAdapter(0,0) = 0 then
    WriteLn('Adapter reset')
  else
    WriteLn('Error resetting adapter');
end.
