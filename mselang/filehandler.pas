{ MSElang Copyright (c) 2013 by Martin Schreiber
   
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
}
unit filehandler;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}
interface
uses
 msestrings;
 
function getunitfile(const aname: filenamety): filenamety;
function getunitfile(const aname: lstringty): filenamety;
function getincludefile(const aname: lstringty): filenamety;

implementation
uses
 msefileutils;
 
function getunitfile(const aname: filenamety): filenamety;
begin
 result:= filepath(aname+'.mla');
 if not findfile(result) then begin
  result:= '';
 end;
end;

function getunitfile(const aname: lstringty): filenamety;
begin
// result:= filepath(utf8tostring(aname)+'.pas');
 result:= filepath(utf8tostring(aname)+'.mla');
 if not findfile(result) then begin
  result:= '';
 end;
end;

function getincludefile(const aname: lstringty): filenamety;
begin
 result:= filepath(utf8tostring(aname));
 if not findfile(result) then begin
  result:= '';
 end;
end;

end.
