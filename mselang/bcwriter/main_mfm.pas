unit main_mfm;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}

interface

implementation
uses
 mseclasses,main;

const
 objdata: record size: integer; data: array[0..232] of byte end =
      (size: 233; data: (
  84,80,70,48,7,116,109,97,105,110,102,111,6,109,97,105,110,102,111,8,
  98,111,117,110,100,115,95,120,3,35,1,8,98,111,117,110,100,115,95,121,
  3,247,0,9,98,111,117,110,100,115,95,99,120,3,147,1,9,98,111,117,
  110,100,115,95,99,121,3,24,1,16,99,111,110,116,97,105,110,101,114,46,
  98,111,117,110,100,115,1,2,0,2,0,3,147,1,3,24,1,0,15,109,
  111,100,117,108,101,99,108,97,115,115,110,97,109,101,6,9,116,109,97,105,
  110,102,111,114,109,0,7,116,98,117,116,116,111,110,8,116,98,117,116,116,
  111,110,49,8,98,111,117,110,100,115,95,120,2,40,8,98,111,117,110,100,
  115,95,121,2,24,9,98,111,117,110,100,115,95,99,120,2,50,9,98,111,
  117,110,100,115,95,99,121,2,20,5,115,116,97,116,101,11,17,97,115,95,
  108,111,99,97,108,111,110,101,120,101,99,117,116,101,0,9,111,110,101,120,
  101,99,117,116,101,7,3,101,120,101,0,0,0)
 );

initialization
 registerobjectdata(@objdata,tmainfo,'');
end.
