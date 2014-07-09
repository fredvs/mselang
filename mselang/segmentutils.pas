{ MSElang Copyright (c) 2013-2014 by Martin Schreiber
   
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
unit segmentutils;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}
interface
uses
 parserglob,msetypes;
 
  //todo: use inline
  
function allocsegmentoffset(const asegment: segmentty;
                                    const asize: integer): dataoffsty;
function allocsegmentpo(const asegment: segmentty;
                                    const asize: integer): pointer;
function allocsegmentpo(const asegment: segmentty;
                          const asize: integer; var buffer: pointer): pointer;
procedure checksegmentcapacity(const asegment: segmentty;
                               const asize: integer; var buffer: pointer);
function checksegmentcapacity(const asegment: segmentty;
                               const asize: integer): pointer;
                                 //returns alloc top
function alignsegment(const asegment: segmentty): pointer;

procedure setsegmenttop(const asegment: segmentty; const atop: pointer);

function getsegmentoffset(const asegment: segmentty;
                                    const apo: pointer): dataoffsty;
function getsegmentpo(const asegment: segmentty;
                                    const aoffset: dataoffsty): pointer;
function getsegmenttoppo(const asegment: segmentty): pointer;
function getsegmenttopoffset(const asegment: segmentty): dataoffsty;
function getsegmentbase(const asegment: segmentty): pointer;
function getsegmentsize(const asegment: segmentty): integer;
                               
procedure init();
procedure deinit();

implementation
uses
 errorhandler,stackops;
 
type
 segmentinfoty = record
  toppo: pointer;
  endpo: pointer;
  data: bytearty;
 end;
const
 minsize: array[segmentty] of integer = (
//seg_stack,seg_globvar,seg_globconst,seg_op,seg_rtti
  0,        0,          1024,         1024,  1024);          
  
var
 segments: array[segmentty] of segmentinfoty;
 
procedure init();
var
 seg1: segmentty;
begin
 for seg1:= low(segmentty) to high(segmentty) do begin
  with segments[seg1] do begin
   toppo:= pointer(data);
   endpo:= toppo+length(data);
  end;
 end;
// fillchar(segments,sizeof(segments),0);
end;

procedure deinit();
begin
// finalize(segments);
end;

procedure grow(const asegment: segmentty; var ref: pointer);
var
 po1: pointer;
begin
 with segments[asegment] do begin
  po1:= pointer(data);
  setlength(data,(toppo-po1)*2+minsize[asegment]);
  endpo:= @data[length(data)];
  toppo:= toppo + (pointer(data) - po1);
  ref:= ref + (pointer(data) - po1);
 end;
end;

procedure grow(const asegment: segmentty);
var
 po1: pointer;
begin
 grow(asegment,po1);
end;

function allocsegmentoffset(const asegment: segmentty;
                                    const asize: integer): dataoffsty;
begin
 with segments[asegment] do begin
  result:= toppo-pointer(data);
  inc(toppo,asize);
  if toppo > endpo then begin
   grow(asegment);
  end;
 end;
end;

function allocsegmentpo(const asegment: segmentty;
                                    const asize: integer): pointer;
begin
 with segments[asegment] do begin
  result:= toppo;
  inc(toppo,asize);
  if toppo > endpo then begin
   grow(asegment,result);
  end;
 end;
end;

function allocsegmentpo(const asegment: segmentty;
                          const asize: integer; var buffer: pointer): pointer;
var
 po1: pointer;
begin
 with segments[asegment] do begin
  result:= toppo;
  inc(toppo,asize);
  if toppo > endpo then begin
   po1:= result;
   grow(asegment,result);
   buffer:= buffer + (result-po1);
  end;
 end;
end;

procedure checksegmentcapacity(const asegment: segmentty;
                               const asize: integer; var buffer: pointer);
begin
 with segments[asegment] do begin
  inc(toppo,asize);
  if toppo > endpo then begin
   grow(asegment,buffer);
  end;
  dec(toppo,asize);
 end;
end;

function checksegmentcapacity(const asegment: segmentty;
                               const asize: integer): pointer;
                                 //returns alloc top
begin
 with segments[asegment] do begin
  inc(toppo,asize);
  if toppo > endpo then begin
   grow(asegment);
  end;
  dec(toppo,asize);
  result:= toppo;
 end;
end;

function alignsegment(const asegment: segmentty): pointer;
begin
 with segments[asegment] do begin
  toppo:= pointer((ptruint(toppo)+alignstep) and alignmask);
  if toppo > endpo then begin
   grow(asegment);
  end;
  result:= toppo;
 end;
end;

procedure setsegmenttop(const asegment: segmentty; const atop: pointer);
begin
 with segments[asegment] do begin
  toppo:= atop;
 {$ifdef mse_checkinternalerror}
  internalerror(ie_segment,'20140709');
 {$endif}
 end; 
end;

function getsegmentoffset(const asegment: segmentty;
                                    const apo: pointer): dataoffsty;
begin
 result:= apo - pointer(segments[asegment].data);
end;

function getsegmentpo(const asegment: segmentty;
                                    const aoffset: dataoffsty): pointer;
begin
 result:= pointer(segments[asegment].data) + aoffset;
end;

function getsegmenttoppo(const asegment: segmentty): pointer;
begin
 result:= segments[asegment].toppo;
end;

function getsegmenttopoffset(const asegment: segmentty): dataoffsty;
begin
 with segments[asegment] do begin
  result:= toppo-pointer(data);
 end;
end;

function getsegmentbase(const asegment: segmentty): pointer;
begin
 result:= pointer(segments[asegment].data);
end;

function getsegmentsize(const asegment: segmentty): integer;
begin
 with segments[asegment] do begin
  result:= toppo-pointer(data);
 end;
end;

end.
