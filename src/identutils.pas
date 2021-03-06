{ MSElang Copyright (c) 2013-2018 by Martin Schreiber
   
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
unit identutils;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}
interface
uses
 globtypes,msehash,msestrings;
 
{$define caseinsensitive} 

type
 identnamety = record
  offset: int32; //relative to data block
 end;
 
 identheaderty = record
  ident: identty;
 end;
 pidentheaderty = ^identheaderty;
 identhashdataty = record
  header: hashheaderty;
  data: identheaderty;
 end;
 pidenthashdataty = ^identhashdataty;

 tidenthashdatalist = class(thashdatalist)
  protected
   function hashkey(const akey): hashvaluety; override;
   function checkkey(const akey; const aitem: phashdataty): boolean; override;
   function getrecordsize(): int32 override;
  public
//   constructor create(const asize: int32); 
                    //total datasize including identheaderty
   function adduniquedata(const akey: identty; out adata: pointer): boolean;
                              //false if duplicate
 end;
  
function getident(): identty; overload;
function getident(const astart,astop: pchar): identty;
function getident(const aname: lstringty): identty;
function getident(const aname: pchar; const alen: integer): identty;
function getident(const aname: string): identty;
function getident(const aname: stringvaluety): identty;
function getident(const anum: int32): identty; //0..255

function getstringident(const aindex: int32; out ident: identty): boolean;
            //string const -> ident, returns true if ok

function getidentname(const aident: identty; out name: identnamety): boolean;
                             //true if found
function getidentname(const aident: identty; out name: lstringty): boolean;
                             //true if found
function getidentname(const aname: string): identnamety;
function getidentname(const aident: identty): string;
function getidentname1(const aident: identty): lstringty;
function getidentname1(const aeledata: pointer): lstringty;
function getidentname2(const aident: identty): identnamety;
function getidentname2(const aeledata: pointer): identnamety;
function getidentname3(const aident: identty): stringvaluety;

function nametolstring(const aname: identnamety): lstringty; inline;

procedure clear();
procedure init();
      
implementation
uses
 mselfsr,parserglob,errorhandler,elements,mseformatstr;
type
 identoffsetty = int32;

 keyidentdataty = record
  header: identheaderty;
  keyname: identoffsetty; //
//  keylen: integer;
 end;
 keyidenthashdataty = record
  header: hashheaderty;
  data: keyidentdataty;
 end;
 pkeyidenthashdataty = ^keyidenthashdataty;

 tkeyidenthashdatalist = class(tidenthashdatalist)
  protected
   function getrecordsize(): int32 override;
 end;
 
 indexidentdataty = record
  key: identnamety; //index of null terminated string
  data: identty;
 end;
 pindexidentdataty = ^indexidentdataty;
 indexidenthashdataty = record
  header: hashheaderty;
  data: indexidentdataty;
 end;
 pindexidenthashdataty = ^indexidenthashdataty;
 
 tindexidenthashdatalist = class(thashdatalist)
// {$ifdef mse_debugparser}
  private
   fidents: tkeyidenthashdatalist;
// {$endif}
  protected
   function hashkey(const akey): hashvaluety; override;
   function checkkey(const akey; const aitem: phashdataty): boolean; override;
   function getrecordsize(): int32 override;
  public
   constructor create;
   destructor destroy; override;
   procedure clear; override;
   function identname(const aident: identty; out aname: lstringty): boolean;
   function identname(const aident: identty; out aname: identnamety): boolean;
   function getident(const aname: lstringty): pindexidenthashdataty;
 end;

var
 stringident: identty;
 identlist: tindexidenthashdatalist;
 stringindex,stringlen: identoffsetty;
 stringdata: pointer;

const
 mindatasize = 1024; 

type
 identbufferheaderty = record
  len: int32;
 end;
 identbufferty = record
  header: identbufferheaderty;
  data: record //null terminated array of char
  end;
 end;
 pidentbufferty = ^identbufferty;
 
procedure nextident;
begin
// repeat
//  lfsr321(stringident);
 inc(stringident);
// until stringident >= firstident;
end;

function getident(): identty;
begin
 result:= stringident;
 nextident; 
end;
 
function getident(const aname: lstringty): identty;
begin
 result:= identlist.getident(aname)^.data.data;
end;

function getident(const aname: pchar; const alen: integer): identty;
var
 lstr1: lstringty;
begin
 lstr1.po:= aname;
 lstr1.len:= alen;
 result:= identlist.getident(lstr1)^.data.data;
end;

function getident(const astart,astop: pchar): identty;
var
 lstr1: lstringty;
begin
 lstr1.po:= astart;
 lstr1.len:= astop-astart;
 result:= identlist.getident(lstr1)^.data.data;
end;

function getident(const aname: string): identty;
var
 lstr1: lstringty;
begin
 lstr1.po:= pointer(aname);
 lstr1.len:= length(aname);
 result:= identlist.getident(lstr1)^.data.data;
end;

function getident(const aname: stringvaluety): identty;
begin
 result:= getident(getstringconst(aname));
end;

var
 numidents: array[0..255] of identty;
 
function getident(const anum: int32): identty;
begin
{$ifdef mse_checkinternalerror}
 if (anum < 0) or (anum > high(numidents)) then begin
  internalerror(ie_idents,'20170516A');
 end;
{$endif}
 result:= numidents[anum];
end;

function getstringident(const aindex: int32;
                                   out ident: identty): boolean;
            //string const -> ident, returns true if ok
begin
 with info,contextstack[aindex] do begin
  if (d.kind <> ck_const) or 
        (d.dat.constval.kind <> dk_string) then begin
   errormessage(err_stringconstantexpected,[],aindex-s.stackindex);
   result:= false;
  end
  else begin
   ident:= getident(d.dat.constval.vstring);
   result:= true;
  end;
 end;
end;

function nametolstring(const aname: identnamety): lstringty;
var
 po1: pidentbufferty;
begin
 po1:= pointer(stringdata) + aname.offset;
 result.len:= po1^.header.len;
 result.po:=  @po1^.data;
end;

function getidentname(const aident: identty; out name: lstringty): boolean;
                             //true if found
begin
 result:= identlist.identname(aident,name);
end;

function getidentname(const aname: string): identnamety;
begin
 result:= identlist.getident(stringtolstring(aname))^.data.key;
end;

function getidentname(const aident: identty; out name: identnamety): boolean;
                             //true if found
begin
 result:= identlist.identname(aident,name);
end;

function getidentname(const aident: identty): string;
var
 lstr1: lstringty;
begin
 if getidentname(aident,lstr1) then begin
  result:= lstringtostring(lstr1);
 end
 else begin
  result:= '°';
 end;
end;

function getidentname1(const aident: identty): lstringty;
begin
{$ifdef mse_checkinternalerror}
 if not 
{$endif}
 getidentname(aident,result)
{$ifdef mse_checkinternalerror} then begin
  internalerror(ie_parser,'20151111A');
 end;
{$else}
 ;
{$endif}
end;

function getidentname1(const aeledata: pointer): lstringty;
begin
{$ifdef mse_checkinternalerror}
 if not 
{$endif}
 getidentname(datatoele(aeledata)^.header.name,result)
{$ifdef mse_checkinternalerror} then begin
  internalerror(ie_parser,'20151124A');
 end;
{$else}
 ;
{$endif}
end;

function getidentname2(const aident: identty): identnamety;
begin
{$ifdef mse_checkinternalerror}
 if not 
{$endif}
 getidentname(aident,result)
{$ifdef mse_checkinternalerror} then begin
  internalerror(ie_parser,'20151111B');
 end;
{$else}
 ;
{$endif}
end;

function getidentname2(const aeledata: pointer): identnamety;
begin
{$ifdef mse_checkinternalerror}
 if not 
{$endif}
 getidentname(datatoele(aeledata)^.header.name,result)
{$ifdef mse_checkinternalerror} then begin
  internalerror(ie_parser,'20151111C');
 end;
{$else}
 ;
{$endif}
end;

function getidentname3(const aident: identty): stringvaluety;
begin
 result:= newstringconst(getidentname1(aident));
end;

const
 hashmask: array[0..7] of longword =
  (%10101010101010100101010101010101,
   %01010101010101011010101010101010,
   %11001100110011000011001100110011,
   %00110011001100111100110011001100,
   %01100110011001111001100110011000,
   %10011001100110000110011001100111,
   %11100110011001100001100110011001,
   %00011001100110011110011001100110
   );
   
function hashkey1(const akey: lstringty): hashvaluety;
var
 int1: integer;
 wo1: word;
 by1: byte;
 po1: pchar;
begin
 wo1:= hashmask[0];
 po1:= akey.po;
 for int1:= 0 to akey.len-1 do begin
 {$ifdef caseinsensitive}
  by1:= byte(lowerchars[po1[int1]]);
 {$else}
  by1:= byte(po1[int1]);
 {$endif}
  wo1:= ((wo1 + by1) xor by1);
 end;
 wo1:= (wo1 xor wo1 shl 7);
 result:= (wo1 or (longword(wo1) shl 16)) xor hashmask[akey.len and $7];
end;

function storestring(const astr: lstringty): identnamety; 
                                                   //offset from stringdata
var
 int1,int2: integer;
 po1: pidentbufferty;
begin
 int1:= stringindex;
 int2:= astr.len;
 stringindex:= (stringindex + int2 + 1 + sizeof(identbufferheaderty) + 3) 
                                                    and not 3;        //align 4
 if stringindex >= stringlen then begin
  stringlen:= stringindex*2+mindatasize;
  reallocmem(stringdata,stringlen);
  fillchar((pchar(pointer(stringdata))+int1)^,stringlen-int1,0);
 end;
 po1:= stringdata + int1;
 po1^.header.len:= int2;
 move(astr.po^,po1^.data,int2);
 result.offset:= int1;
 nextident();
end;

procedure clear();
begin
 identlist.clear;
 if stringdata <> nil then begin
  freemem(stringdata);
  stringdata:= nil;
 end;
 stringindex:= 0;
 stringlen:= 0;
 stringident:= 0;
end;

procedure init();
var
 i1: int32;
begin
 stringident:= idstart; //invalid
 nextident();
 for i1:= 0 to high(numidents) do begin
  numidents[i1]:= getident(inttostr(i1));
 end;
end;

{ tidenthashdatalist }
{
constructor tidenthashdatalist.create(const asize: int32);
begin
 inherited create(asize);
end;
}
function tidenthashdatalist.getrecordsize(): int32;
begin
 result:= sizeof(identhashdataty);
end;

function tidenthashdatalist.hashkey(const akey): hashvaluety;
begin
 result:= identty(akey);
end;

function tidenthashdatalist.checkkey(const akey; const aitem: phashdataty): boolean;
begin
 result:= identty(akey) = pidenthashdataty(aitem)^.data.ident;
end;


function tidenthashdatalist.adduniquedata(const akey: identty;
                                         out adata: pointer): boolean;
begin
 adata:= internalfind(akey);
 result:= adata = nil;
 if result then begin
  adata:= addr(pidenthashdataty(internaladd(akey))^.data);
  pidentheaderty(adata)^.ident:= akey;
 end
 else begin
  inc(adata,sizeof(hashheaderty));
 end;
end;

{ tkeyidenthashdatalist }

function tkeyidenthashdatalist.getrecordsize(): int32;
begin
 result:= sizeof(keyidenthashdataty);
end;

{ tindexidenthashdatalist }

constructor tindexidenthashdatalist.create;
begin
 inherited;
// inherited create(sizeof(indexidentdataty));
// fidents:= tidenthashdatalist.create(sizeof(identdataty));
 fidents:= tkeyidenthashdatalist.create();
end;

destructor tindexidenthashdatalist.destroy;
begin
 inherited;
 fidents.free;
end;

function tindexidenthashdatalist.getrecordsize(): int32;
begin
 result:= sizeof(indexidenthashdataty);
end;

procedure tindexidenthashdatalist.clear;
begin
 inherited;
 fidents.clear;
end;

function tindexidenthashdatalist.identname(const aident: identty;
                   out aname: lstringty): boolean;
var
 po1: pkeyidenthashdataty;
 po2: pidentbufferty;
begin
 po1:= pkeyidenthashdataty(fidents.internalfind(aident,aident));
 if po1 <> nil then begin
  result:= true;
  po2:= pointer(stringdata)+po1^.data.keyname;
  aname.len:= po2^.header.len;
  aname.po:= @po2^.data;
 end
 else begin
  result:= false;
  aname.po:= nil;
  aname.len:= 0;
 end;
end;

function tindexidenthashdatalist.identname(const aident: identty;
               out aname: identnamety): boolean;
var
 po1: pkeyidenthashdataty;
begin
 po1:= pkeyidenthashdataty(fidents.internalfind(aident,aident));
 if po1 <> nil then begin
  result:= true;
  aname.offset:= po1^.data.keyname;
 end
 else begin
  result:= false;
  aname.offset:= -1;
 end;
end;

function tindexidenthashdatalist.getident(const aname: lstringty): 
                                                     pindexidenthashdataty;
var
 po1: pindexidenthashdataty;
 ha1: hashvaluety;
begin
 if aname.len > maxidentlen then begin
  errormessage(err_identtoolong,[lstringtostring(aname)]);
  result:= nil;
  exit;
 end;
 ha1:= hashkey1(aname);
 po1:= pointer(internalfind(aname,ha1));
 if po1 = nil then begin
  po1:= pointer(internaladdhash(ha1));
  with po1^.data do begin
   data:= stringident;
   key:= storestring(aname);
   with pkeyidenthashdataty(fidents.internaladdhash(data))^.data do begin
    header.ident:= data;
    keyname:= key.offset;
   end;
  end;
 end;  
 result:= po1;
// result:= po1^.data.data;
end;

function tindexidenthashdatalist.hashkey(const akey): hashvaluety;
var
 po1,po2: pchar;
 wo1: word;
 by1: byte;
begin
 with indexidentdataty(akey) do begin
  po1:= stringdata + key.offset + sizeof(identbufferheaderty);
  po2:= po1;
  wo1:= hashmask[0];
  while true do begin
  {$ifdef caseinsensitive}
   by1:= byte(lowerchars[po1^]);
  {$else}
   by1:= byte(po1^);
  {$endif}
   if by1 = 0 then begin
    break;
   end;
   wo1:= ((wo1 + by1) xor by1);
  end;
  wo1:= (wo1 xor wo1 shl 7);
  result:= (wo1 or (longword(wo1) shl 16)) xor hashmask[(po1-po2) and $7];
 end;
end;

function tindexidenthashdatalist.checkkey(const akey;
                                     const aitem: phashdataty): boolean;
var
 po1,po2: pchar;
 int1: integer;
begin
 result:= false;
 with lstringty(akey) do begin
  po1:= po;
  po2:= stringdata + pindexidenthashdataty(aitem)^.data.key.offset + 
                                                  sizeof(identbufferty);
  for int1:= 0 to len-1 do begin
  {$ifdef caseinsensitive}
   if lowerchars[po1[int1]] <> lowerchars[po2[int1]] then begin
  {$else}
   if po1[int1] <> po2[int1] then begin
  {$endif}
    exit;
   end;
  end;
  result:= po2[len] = #0;
 end;
end;

initialization
 identlist:= tindexidenthashdatalist.create;
 init();
finalization
 clear();
 identlist.free();
end.
