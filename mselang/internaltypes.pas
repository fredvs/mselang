{ MSElang Copyright (c) 2013-2014 by Martin Schreiber

    See the file COPYING.MSE, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}
unit internaltypes;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}
interface

type

 refcountty = integer;
 managedsizety = integer;
 stringsizety = managedsizety;
 pstringsizety = ^stringsizety;
 
 refinfoty = record
  count: refcountty;
 end;
 prefinfoty = ^refinfoty;
 refsizeinfoty = record
  ref: refinfoty;
  sizedummy: managedsizety;
 end;
 prefsizeinfoty = ^refsizeinfoty;
 
 string8headerty = record
  ref: refinfoty;
  len: stringsizety;
 end; //following stringdata + terminating #0
 pstring8headerty = ^string8headerty;
 
const
 string8headersize = sizeof(string8headerty);
 string8allocsize = string8headersize+1; //terminating #0

implementation
end.
