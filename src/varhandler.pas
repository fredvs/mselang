{ MSElang Copyright (c) 2013-2017 by Martin Schreiber
   
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
unit varhandler;
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}

interface
uses
 msestrings,globtypes,parserglob,__mla__internaltypes;
 
const 
 pointervarkinds = [{dk_class,}dk_interface];
 
procedure handlevardefstart();
procedure handlevar3();
procedure handleextvar0entry();
procedure handleextvar0();
procedure handleextvar1();
procedure handleextvar2();
procedure handledectop();

procedure handlepointervar();

procedure handletypedconst2entry();
procedure handletypedconst();
procedure handletypedconstarraylevelentry();
procedure handletypedconstarraylevel();
procedure handletypedconstarrayitem();
procedure handletypedconstarray();

implementation
uses
 handlerutils,elements,errorhandler,handlerglob,opcode,llvmlists,segmentutils,
 identutils,gramse,grapas,parser,valuehandler,mseformatstr,
 stackops,msetypes,llvmbitcodes;
 
procedure handlevardefstart();
begin
{$ifdef mse_debugparser}
 outhandle('VARDEFSTART');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.kind:= ck_var;
  d.vari.indirectlevel:= 0;
  d.vari.flags:= [];
 end;
end;

procedure handleextvar0entry();
begin
{$ifdef mse_debugparser}
 outhandle('EXTVAR0ENTRY');
{$endif}
 with info,contextstack[contextstack[s.stacktop].parent] do begin
 {$ifdef mse_checkinternalerror}
  if d.kind <> ck_var then begin
   internalerror(ie_handler,'20171011C');
  end;
 {$endif}
  if sublevel > 0 then begin
   errormessage(err_cannotdeclarelocvarexternal,[]);
  end
  else begin
   include(d.vari.flags,vf_external);
   d.vari.libname:= 0;
   d.vari.varname:= 0;
  end;
 end;
end;

procedure handleextvar0();
var
 p1: pcontextitemty;
begin
{$ifdef mse_debugparser}
 outhandle('EXTVAR0');
{$endif}
 with info,contextstack[s.stacktop] do begin
  if (d.kind <> ck_const) or (d.dat.constval.kind <> dk_string) or 
                      (strf_empty in d.dat.constval.vstring.flags) then begin
   errormessage(err_libnameexpected,[]);
  end
  else begin
   p1:= @contextstack[contextstack[s.stackindex].parent];
  {$ifdef mse_checkinternalerror}
   if p1^.d.kind <> ck_var then begin
    internalerror(ie_handler,'20171011D');
   end;
  {$endif}
   p1^.d.vari.libname:= getident(d.dat.constval.vstring);
  end;
  s.stacktop:= s.stackindex;
 end;
end;

procedure handleextvar1();
begin
{$ifdef mse_debugparser}
 outhandle('EXTVAR1');
{$endif}
end;

procedure handleextvar2();
var
 p1: pcontextitemty;
begin
{$ifdef mse_debugparser}
 outhandle('EXTVAR2');
{$endif}
 with info,contextstack[s.stacktop] do begin
  if (d.kind <> ck_const) or (d.dat.constval.kind <> dk_string) or 
                      (strf_empty in d.dat.constval.vstring.flags) then begin
   errormessage(err_varnameexpected,[]);
  end
  else begin
   p1:= @contextstack[contextstack[s.stackindex].parent];
  {$ifdef mse_checkinternalerror}
   if p1^.d.kind <> ck_var then begin
    internalerror(ie_handler,'20171011E');
   end;
  {$endif}
   p1^.d.vari.varname:= getident(d.dat.constval.vstring);
  end;
  dec(s.stackindex);
  s.stacktop:= s.stackindex;
 end;
end;

procedure handledectop();
begin
{$ifdef mse_debugparser}
 outhandle('DECTOP');
{$endif}
 with info do begin
  dec(s.stackindex);
  s.stacktop:= s.stackindex;
 end;
end;

procedure handlevar3();
var
 po1: pvardataty;
 po2: pelementinfoty;
 po3: pelementoffsetty;
 datasize1: databitsizety;
 size1: integer;
 ident1: identty;
 ele1: elementoffsetty;
 bo1: boolean;
 i1: int32;
 n1: identnamety;
 ispointervar,isexternal: boolean;
begin
{$ifdef mse_debugparser}
 outhandle('VAR3');
{$endif}
 with info do begin
  if (s.stacktop-s.stackindex < 3) or 
            (contextstack[s.stacktop].d.kind <> ck_fieldtype) or
                       (contextstack[s.stacktop].d.typ.typedata = 0) then begin
   exit; //type not found
  end;
  with contextstack[s.stackindex] do begin
  {$ifdef mse_checkinternalerror}
   if d.kind <> ck_var then begin
    internalerror(ie_handler,'20150320A0');
   end;
  {$endif}
   isexternal:= vf_external in d.vari.flags;
   if isexternal and (s.stacktop-s.stackindex > 3) then begin
    errormessage(err_singleexternalonly,[]);
   end;

   for i1:= s.stackindex+2 to s.stacktop - 1 do begin
   {$ifdef mse_checkinternalerror}
    if contextstack[i1].d.kind <> ck_ident then begin
     internalerror(ie_handler,'20150320A0');
    end;
   {$endif}
    ident1:= contextstack[i1].d.ident.ident;
    bo1:= false;
    if (currentcontainer = 0) or not ele.findchild(info.currentcontainer,ident1,
                                                     [],allvisi,ele1) then begin
     if sublevel > 0 then begin
      ele.checkcapacity(elesizes[ek_var]); //no change by addvar
      po3:= @(psubdataty(ele.parentdata)^.varchain);
     end
     else begin
      po3:= @s.unitinfo^.varchain;
     end;
     bo1:= addvar(ident1,allvisi,po3^,po1);
    end;
    if not bo1 then begin //duplicate
     identerror(i1-s.stackindex,err_duplicateidentifier);
    end
    else begin
     with po1^ do begin
      address.flags:= [];
      vf.typ:= contextstack[s.stacktop].d.typ.typedata;
      po2:= ele.eleinfoabs(vf.typ);
      address.indirectlevel:= contextstack[s.stacktop].d.typ.indirectlevel;
      with ptypedataty(@po2^.data)^ do begin
       datasize1:= h.datasize;
       ispointervar:= false;
       if h.kind in pointervarkinds then begin
        ispointervar:= true;
        inc(address.indirectlevel);
       end;
       if not ispointervar and (address.indirectlevel = 0) or 
              ispointervar and (address.indirectlevel = 1) then begin
        size1:= h.bytesize;
        if datasize1 = das_bigint then begin
         size1:= h.bitsize;
        end;
        vf.flags:= vf.flags + 
                    h.flags * [tf_needsmanage,tf_needsini,tf_needsfini];
        if tf_needsmanage in h.flags then begin
         include(s.currentstatementflags,stf_needsmanage);
        end;
        if tf_needsini in h.flags then begin
         include(s.currentstatementflags,stf_needsini);
        end;
        if tf_needsfini in h.flags then begin
         include(s.currentstatementflags,stf_needsfini);
        end;
       end
       else begin
        size1:= targetpointersize;
       end;
       if sublevel = 0 then begin //global variable
        nameid:= -1;
        if address.indirectlevel > 0 then begin
         datasize1:= das_pointer;
         include(address.flags,af_segmentpo);
        end;
        if isexternal then begin
         include(address.flags,af_external);
        end;
        address.segaddress:= getglobvaraddress(datasize1,size1,address.flags);
        if not (us_implementation in s.unitinfo^.state) then begin
         nameid:= s.unitinfo^.nameid; //for llvm
        end;
        if (isexternal or 
               (info.o.debugoptions*[do_proginfo,do_names] <> [])) and 
                             (co_llvm in info.o.compileoptions) then begin
         if isexternal then begin //todo: handle libname
          if d.vari.varname <> 0 then begin
           ident1:= d.vari.varname;
          end;
         end;
         getidentname(ident1,n1);
         if do_names in info.o.debugoptions then begin
 
          s.unitinfo^.llvmlists.globlist.namelist.addname(
                                               n1,address.segaddress.address);
         end;
         if do_proginfo in info.o.debugoptions then begin
          s.unitinfo^.llvmlists.globlist.lastitem^.debuginfo:= 
                   s.unitinfo^.llvmlists.metadatalist.adddivariable(
                        nametolstring(n1),contextstack[i1].start.line,0,po1^);
         end;
        end;
       end
       else begin                //local variable
        address.locaddress:= getlocvaraddress(datasize1,size1,address.flags,
                                                                   -frameoffset);
       end;
      end;
     end;
    end;
   end;
  end;
 end;
end;

procedure handlepointervar();
begin
{$ifdef mse_debugparser}
 outhandle('POINTERVAR');
{$endif}
 with info,contextstack[s.stackindex].d.vari do begin
  if indirectlevel > 0 then begin
   errormessage(err_typeidentexpected,[]);
  end;
  inc(indirectlevel);
 end;
end;

function checkconstrange(p1: ptypedataty): boolean;
begin
 with info do begin
  result:= tryconvert(@contextstack[s.stacktop],p1,
                                      p1^.h.indirectlevel,[]);
  if result then begin
   with contextstack[s.stacktop],d.dat.constval do begin
    if d.kind <> ck_const then begin
     errormessage(err_constexpressionexpected,[]);
    end
    else begin
     case p1^.h.kind of
      dk_boolean,dk_enum,dk_string: begin
      end;
      dk_integer: begin
       case p1^.h.datasize of
        das_8: begin
         with p1^.infoint8 do begin
          if (vinteger < min) or (vinteger > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_16: begin
         with p1^.infoint16 do begin
          if (vinteger < min) or (vinteger > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_32: begin
         with p1^.infoint32 do begin
          if (vinteger < min) or (vinteger > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_64: begin
         with p1^.infoint64 do begin
          if (vinteger < min) or (vinteger > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
       end;
      end;
      dk_cardinal: begin
       case p1^.h.datasize of
        das_8: begin
         with p1^.infocard8 do begin
          if (vcardinal < min) or (vcardinal > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_16: begin
         with p1^.infocard16 do begin
          if (vcardinal < min) or (vcardinal > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_32: begin
         with p1^.infocard32 do begin
          if (vcardinal < min) or (vcardinal > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_64: begin
         with p1^.infocard64 do begin
          if (vcardinal < min) or (vcardinal > max) then begin
           errormessage(err_valuerange,[inttostrmse(min),inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
       end;
      end;
      dk_float: begin
       case p1^.h.datasize of
        das_f32: begin
         with p1^.infofloat32 do begin
          if (vfloat < min) or (vfloat > max) then begin
           errormessage(err_valuerange,[realtostrmse(min),
                               realtostrmse(max)],minint,0,erl_warning);
          end;
         end;
        end;
        das_f64: begin
         with p1^.infofloat64 do begin
          if (vfloat < min) or (vfloat > max) then begin
           errormessage(err_valuerange,[realtostrmse(min),
                               realtostrmse(max)],minint,0,erl_warning);
          end;
         end;
        end;
       end;
      end;
      dk_character: begin
       case p1^.h.datasize of
        das_8: begin
         with p1^.infochar8 do begin
          if (vcharacter < min) or (vcharacter > max) then begin
           errormessage(err_valuerange,[''''+char8(min)+'''',
                                             ''''+char8(max)+''''],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_16: begin
         with p1^.infochar16 do begin
          if (vcharacter < min) or (vcharacter > max) then begin
           errormessage(err_valuerange,[''''+char16(min)+'''',
                                                ''''+char16(max)+''''],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
        das_32: begin
         with p1^.infochar32 do begin
          if (vcharacter < min) or (vcharacter > max) then begin
           errormessage(err_valuerange,[inttostrmse(min)+inttostrmse(max)],
                                                       minint,0,erl_warning);
          end;
         end;
        end;
       end;
      end;
      else begin
       notimplementederror('20170613E');
      end;
     end;
    end;
   end;
  end
  else begin
   typeconversionerror(contextstack[s.stacktop].d,p1,p1^.h.indirectlevel,
                                                      err_incompatibletypes);
  end;
 end;
end;

procedure setconstval(p1: ptypedataty; p3: pointer);
var
 seg1: segaddressty;
begin
 with info do begin
  with contextstack[s.stacktop],d.dat.constval do begin
   case p1^.h.datasize of
    das_1: begin
     pboolean(p3)^:= vboolean;
    end;
    das_8: begin
     pint8(p3)^:= vinteger;
    end;
    das_16: begin
     pint16(p3)^:= vinteger;
    end;
    das_32: begin
     pint32(p3)^:= vinteger;
    end;
    das_64: begin
     pint64(p3)^:= vinteger;
    end;
    das_f32: begin
     pflo32(p3)^:= vfloat;
    end;
    das_f64: begin
     pflo64(p3)^:= vfloat;
    end;
    das_pointer: begin
     case p1^.h.kind of
      dk_string: begin
       seg1:= allocstringconst(vstring);
       if seg1.segment = seg_nil then begin
        ppointer(p3)^:= nil;
       end
       else begin
        pptruint(p3)^:= seg1.address+sizeof(stringheaderty);
        seg1.address:= getsegmentoffset(seg_globconst,p3);
        addreloc(seg1.segment,seg1);
       end;
      end;
      else begin
       internalerror1(ie_handler,'20170615C');
      end;
     end;
    end;
    else begin
     internalerror1(ie_handler,'20170615B');
    end;
   end;
  end;
 end;
end;

procedure handletypedconst();

var
 ident1: identty;

 procedure updatellvmvar(const i1: int32; const avar: pvardataty);
 var
  linkage1: linkagety;
  n1: identnamety;
 begin
  with info,avar^ do begin 
   if sublevel > 0 then begin
    linkage1:= li_internal;
   end
   else begin
    linkage1:= info.s.globlinkage;
   end;
   address.segaddress.segment:= seg_globconst;
   address.segaddress.address:=
      s.unitinfo^.llvmlists.globlist.addinitvalue(gak_const,i1,linkage1);
   if not (us_implementation in s.unitinfo^.state) then begin
    nameid:= s.unitinfo^.nameid; //for llvm
   end;
   if (info.o.debugoptions*[do_proginfo,do_names] <> []) then begin
    getidentname(ident1,n1);
    if do_names in info.o.debugoptions then begin

     s.unitinfo^.llvmlists.globlist.namelist.addname(
                                          n1,address.segaddress.address);
    end;
    if do_proginfo in info.o.debugoptions then begin
     s.unitinfo^.llvmlists.globlist.lastitem^.debuginfo:= 
      s.unitinfo^.llvmlists.metadatalist.adddivariable(
               nametolstring(n1),contextstack[s.stackindex+1].start.line,
                                                                    0,avar^);
    end;
   end;
  end;
 end; //updatellvmvar

var
 p1: ptypedataty;
 p2: pvardataty;
 p3: pointer;
 datasize1: databitsizety;
 size1: int32;
 i1: int32;
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONST');
{$endif}
 with info do begin
  if (currenttypedef <> 0) then begin
   p1:= ele.eledataabs(currenttypedef);
  {$ifdef mse_checkinternalerror}
   if (s.stacktop <= s.stackindex) or 
          (contextstack[s.stackindex+1].d.kind <> ck_ident) then begin
    internalerror(ie_handler,'20170613C');
   end;
  {$endif}
   if p1^.h.indirectlevel <> 0 then begin
    notimplementederror('20170613D');
   end;   
   ident1:= contextstack[s.stackindex+1].d.ident.ident;
   p2:= ele.addelementdata(ident1,ek_var,allvisi);
   if p2 = nil then begin
    identerror(1,err_duplicateidentifier);
   end
   else begin
    with p2^ do begin
     vf.typ:= currenttypedef;
     vf.flags:= p1^.h.flags;
     vf.defaultconst:= 0;
     vf.next:= 0;
     address.indirectlevel:= p1^.h.indirectlevel;
     nameid:= -1;
     datasize1:= p1^.h.datasize;
     if address.indirectlevel > 0 then begin
      datasize1:= das_pointer;
      include(address.flags,af_segmentpo);
      size1:= targetpointersize;
     end
     else begin
      size1:= p1^.h.bytesize;
     end;
     address.flags:= [af_segment,af_const];
     if datasize1 = das_none then begin
      include(address.flags,af_aggregate);
     end;
    end;
    if p1^.h.kind = dk_array then begin
     p2^.address.segaddress:= contextstack[s.stacktop].d.arrayconst.segad;
     if co_llvm in info.o.compileoptions then begin
      updatellvmvar(s.unitinfo^.llvmlists.constlist.addvalue(
                             p2^.address.segaddress,p1^.h.bytesize).listid,p2);
      movesegmenttop(seg_globconst,-p1^.h.bytesize);
     end;
    end
    else begin
     if checkconstrange(p1) then begin
      with contextstack[s.stacktop],d.dat.constval do begin
       with p2^ do begin
        if co_llvm in info.o.compileoptions then begin
         with contextstack[s.stacktop],d.dat.constval do begin
          case datasize1 of
           das_1: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addi1(vboolean).listid;
           end;
           das_8: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addi8(vinteger).listid;
           end;
           das_16: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addi16(vinteger).listid;
           end;
           das_32: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addi32(vinteger).listid;
           end;
           das_64: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addi64(vinteger).listid;
           end;
           das_f32: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addf32(vfloat).listid;
           end;
           das_f64: begin
            i1:= info.s.unitinfo^.llvmlists.constlist.addf64(vfloat).listid;
           end;
           das_pointer: begin
            case p1^.h.kind of
             dk_string: begin
              i1:= info.s.unitinfo^.llvmlists.constlist.addaddress(
                           allocstringconst(vstring).address,
                                               sizeof(stringheaderty)).listid;
             end;
             else begin
              internalerror1(ie_handler,'20170615F');
             end;
            end;
           end;
           else begin
            internalerror1(ie_handler,'20170614A');
           end;
          end;
         end;
         updatellvmvar(i1,p2);
        end
        else begin
         address.segaddress:= allocsegment(seg_globconst,p1^.h.bytesize,p3);
         setconstval(p1,p3);
        end;
       end;
      end;
     end;
    end;
   end;
  end;
//  dec(s.stackindex);
  s.stacktop:= s.stackindex;
 end;
end;

procedure handletypedconst2entry();
var
 p1: ptypedataty;
 cont1: pcontextty;
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONST2ENTRY');
{$endif}
 with info do begin
  if currenttypedef <> 0 then begin
   p1:= ele.eledataabs(currenttypedef);
   if p1^.h.indirectlevel = 0 then begin
    cont1:= nil;
    case p1^.h.kind of
     dk_array: begin
      case s.dialect of
       dia_mse: cont1:= @gramse.typedconstarrayco;
       dia_pas: cont1:= @grapas.typedconstarrayco;
       else internalerror1(ie_dialect,'20170612B');
      end;
      with contextstack[s.stacktop] do begin
       d.kind:= ck_arrayconst;
       d.arrayconst.itemtype:= currenttypedef;
       d.arrayconst.segad:=
               allocsegment(seg_globconst,p1^.h.bytesize,d.arrayconst.datapo);
                 //todo: alignment
       d.arrayconst.datapopo:= @d.arrayconst.datapo;
       d.arrayconst.itemcount:= 0; //dummy
       d.arrayconst.curindex:= 0;
      end;
//      s.stacktop:= s.stackindex;
     end;
    end;
    switchcontext(cont1,false);
   end
   else begin
    internalerror1(ie_notimplemented,'20170512A');
    //todo: handle addresses
   end;
  end;
 end;
end;

procedure handletypedconstarraylevelentry();
var
 p1,p2: ptypedataty;
 i1: int32;
 context1: pcontextitemty;
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONSTARRAYLEVELENTRY');
{$endif}
 with info,contextstack[s.stackindex] do begin
 {$ifdef mse_checkinternalerror}
  if contextstack[s.stackindex-1].d.kind <> ck_arrayconst then begin
   internalerror(ie_handler,'20170613A');
  end;
 {$endif}
  d.kind:= ck_arrayconst;
  context1:= @contextstack[s.stackindex-1];
  inc(context1^.d.arrayconst.curindex);
  p1:= ele.eledataabs(context1^.d.arrayconst.itemtype);
  d.arrayconst.datapopo:= context1^.d.arrayconst.datapopo;
  d.arrayconst.curindex:= 0;
  if p1^.h.kind <> dk_array then begin
   tokenexpectederror(';',erl_fatal);
  end
  else begin
   d.arrayconst.itemtype:= p1^.infoarray.i.itemtypedata;
   d.arrayconst.itemcount:= p1^.infoarray.i.totitemcount;
   p2:= ele.eledataabs(p1^.infoarray.i.itemtypedata);
   if (p2^.h.kind = dk_array) then begin
    if (p2^.infoarray.i.totitemcount <> 0) then begin
     d.arrayconst.itemcount:= d.arrayconst.itemcount div
                                     p2^.infoarray.i.totitemcount;
    end;
    d.arrayconst.itemsize:= 0;
   end
   else begin
    d.arrayconst.itemsize:= p2^.h.bytesize; //todo: alignment
   end;
  end;
 end;
end;

procedure handletypedconstarraylevel();
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONSTARRAYLEVEL');
{$endif}
 with info,contextstack[s.stackindex] do begin
  with d.arrayconst do begin
   if curindex < itemcount then begin
    errormessage(err_moreitemsexpected,[inttostrmse(itemcount-curindex)]);
   end;
  end;
  dec(s.stackindex);
 end;
end;

procedure handletypedconstarrayitem();
var
 p1: ptypedataty;
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONSTARRAYITEM');
{$endif}
 with info,contextstack[s.stackindex] do begin
 {$ifdef mse_checkinternalerror}
  if d.kind <> ck_arrayconst then begin
   internalerror(ie_handler,'20170613B');
  end;
 {$endif}
  with d.arrayconst do begin
   inc(curindex);
   if curindex > itemcount then begin
    errormessage(err_toomanyarrayitems,[]);
   end
   else begin
    p1:= ele.eledataabs(itemtype);
    if checkconstrange(p1) then begin
     setconstval(p1,datapopo^);
    end;
    if itemsize <> 0 then begin
     inc(datapopo^,itemsize);
    end;
   end;
  end;
  s.stacktop:= s.stackindex;
 end;
end;

procedure handletypedconstarray();
var
 p1: ptypedataty;
begin
{$ifdef mse_debugparser}
 outhandle('TYPEDCONSTARRAY');
{$endif}
 handletypedconst();
 with info do begin
  dec(s.stackindex);
//  with contextstack[s.stackindex] do begin
//   include(transitionflags,bf_continue);
//  end;
 end;
end;

end.
