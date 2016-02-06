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
unit classhandler;
{$ifdef FPC}{$mode objfpc}{$h+}{$goto on}{$endif}
interface
uses
 globtypes,handlerglob,__mla__internaltypes;

type
 classintfnamedataty = record
  intftype: elementoffsetty;
  next: elementoffsetty;  //chain, root = infoclassty.interfacechain
 end;
 pclassintfnamedataty = ^classintfnamedataty;

 classintftypedataty = record
  intftype: elementoffsetty;
  intfindex: integer;
 end;
 pclassintftypedataty = ^classintftypedataty;
    
const 
 virtualtableoffset = sizeof(classdefheaderty);

procedure copyvirtualtable(const source,dest: segaddressty;
                                                 const itemcount: integer);
function getclassinterfaceoffset(const aclass: ptypedataty;
              const aintf: ptypedataty; out offset: integer): boolean;
                            //true if ok

procedure handleclassdefstart();
procedure handleclassdeferror();
procedure handleclassdefreturn();
procedure handleclassdefparam2();
procedure handleclassdefparam3a();
procedure handleclassprivate();
procedure handleclassprotected();
procedure handleclasspublic();
procedure handleclasspublished();
procedure handleclassfield();
procedure handlemethfunctionentry();
procedure handlemethprocedureentry();
procedure handlemethconstructorentry();
procedure handlemethdestructorentry();
procedure handleconstructorentry();
procedure handledestructorentry();
procedure classpropertyentry();
//procedure handleclasspropertytype();
procedure handlereadprop();
procedure handlewriteprop();
procedure handledefaultprop();
procedure handleclassproperty();

implementation
uses
 parserglob,elements,handler,errorhandler,unithandler,grammar,handlerutils,
 parser,typehandler,opcode,subhandler,segmentutils,interfacehandler,
 identutils,valuehandler;
{
const
 vic_private = vis_3;
 vic_protected = vis_2;
 vic_public = vis_1;
 vic_published = vis_0;
}
{
procedure classesscopeset();
var
 po2: pclassesdataty;
begin
 po2:= @pelementinfoty(
          ele.eleinfoabs(info.unitinfo^.classeselement))^.data;
 po2^.scopebefore:= ele.elementparent;
 ele.elementparent:= info.unitinfo^.classeselement;
end;

procedure classesscopereset();
var
 po2: pclassesdataty;
begin
 po2:= @pelementinfoty(
          ele.eleinfoabs(info.unitinfo^.classeselement))^.data;
 ele.elementparent:= po2^.scopebefore;
end;
}
procedure copyvirtualtable(const source,dest: segaddressty;
                                                 const itemcount: integer);
var
 ps,pd,pe: popaddressty;
begin
 ps:= getsegmentpo(seg_classdef,source.address + virtualtableoffset);
 pd:= getsegmentpo(seg_classdef,dest.address + virtualtableoffset);
 pe:= pd+itemcount;
 while pd < pe do begin
  if pd^ = 0 then begin
   pd^:= ps^;
  end;
  inc(ps);
  inc(pd);
 end;
end;

function getclassinterfaceoffset(const aclass: ptypedataty;
              const aintf: ptypedataty; out offset: integer): boolean;
                            //true if ok
var
 intfele: elementoffsetty;
 po1: pclassintftypedataty;
 
begin
 intfele:= ele.eledatarel(aintf);
 result:= ele.findchilddata(aclass^.infoclass.intftypenode,identty(intfele),
                                 [ek_classintftype],allvisi,pointer(po1));
 if result then begin
  offset:= aclass^.infoclass.allocsize - 
              (aclass^.infoclass.interfacecount-po1^.intfindex) * pointersize;
 end;
end;

procedure handleclassdefstart();
var
 po1: ptypedataty;
 id1: identty;
 ele1,ele2,ele3: elementoffsetty;
 
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFSTART');
{$endif}
 with info do begin
 {$ifdef mse_checkinternalerror}
  if s.stackindex < 3 then begin
   internalerror(ie_handler,'20140325D');
  end;
 {$endif}
  include(s.currentstatementflags,stf_classdef);
  if sublevel > 0 then begin
   errormessage(err_localclassdef,[]);
  end;
  with contextstack[s.stackindex] do begin
   d.kind:= ck_classdef;
   d.cla.visibility:= classpublishedvisi;
   d.cla.intfindex:= 0;
   d.cla.fieldoffset:= pointersize; //pointer to virtual methodtable
   d.cla.virtualindex:= 0;
  end;
  with contextstack[s.stackindex-2] do begin
   if (d.kind = ck_ident) and 
                  (contextstack[s.stackindex-1].d.kind = ck_typetype) then begin
    id1:= d.ident.ident; //typedef
   end
   else begin
    errormessage(err_anonclassdef,[]);
    exit;
   end;
  end;
  contextstack[s.stackindex].b.eleparent:= ele.elementparent;
  with contextstack[s.stackindex-1] do begin
   if not ele.pushelement(id1,ek_type,globalvisi,d.typ.typedata) then begin
    identerror(s.stacktop-s.stackindex,err_duplicateidentifier,erl_fatal);
   end;
   ele1:= ele.addelementduplicate1(tks_classintfname,
                                          ek_classintfnamenode,globalvisi);
   ele2:= ele.addelementduplicate1(tks_classintftype,
                                   ek_classintftypenode,globalvisi);
   ele3:= ele.addelementduplicate1(tks_classimp,ek_classimpnode,globalvisi);

   currentcontainer:= d.typ.typedata;
   po1:= ele.eledataabs(currentcontainer);
   inittypedatasize(po1^,dk_class,d.typ.indirectlevel,das_pointer);
   with po1^ do begin
    fieldchain:= 0;
    infoclass.intfnamenode:= ele1;
    infoclass.intftypenode:= ele2;
    infoclass.implnode:= ele3;
    infoclass.defs.address:= 0;
    infoclass.flags:= [];
    infoclass.pendingdescends:= 0;
    infoclass.interfaceparent:= 0;
    infoclass.interfacecount:= 0;
    infoclass.interfacechain:= 0;
    infoclass.interfacesubcount:= 0;
   end;
  end;
 end;
end;

procedure classheader(const ainterface: boolean);
var
 po1,po2: ptypedataty;
 po3: pclassintfnamedataty;
 po4: pclassintftypedataty;
 ele1: elementoffsetty;
begin
 with info do begin
  ele.checkcapacity(elesizes[ek_classintfname]+elesizes[ek_classintftype]);
  po1:= ele.eledataabs(currentcontainer);
  ele1:= ele.elementparent;
  ele.decelementparent(); //interface or implementation scope
  if findkindelementsdata(1,[ek_type],allvisi,po2) then begin
   if ainterface then begin
    if po2^.h.kind <> dk_interface then begin
     errormessage(err_interfacetypeexpected,[]);
    end
    else begin
     ele.elementparent:= 
                 ptypedataty(ele.eledataabs(ele1))^.infoclass.intfnamenode;
     if ele.addelementduplicatedata(
           contextstack[s.stackindex+1].d.ident.ident,
           ek_classintfname,[vik_global],po3,allvisi-[vik_ancestor]) then begin
      with po3^ do begin
       intftype:= ele.eledatarel(po2);
       next:= po1^.infoclass.interfacechain;
       po1^.infoclass.interfacechain:= ele.eledatarel(po3);
      end;
      ele.elementparent:= 
                 ptypedataty(ele.eledataabs(ele1))^.infoclass.intftypenode;
      po4:= ele.addelementduplicatedata1(identty(po3^.intftype),
                   ek_classintftype,[vik_global]);
      with po4^ do begin
       intftype:= po3^.intftype;
       with contextstack[s.stackindex-2] do begin
        intfindex:= d.cla.intfindex;
        inc(d.cla.intfindex);
       end;
      end;
     end
     else begin
      identerror(1,err_duplicateidentifier);
     end;
    end;
   end
   else begin
    if po2^.h.kind <> dk_class then begin
     errormessage(err_classtypeexpected,[]);
    end
    else begin
     po1^.h.ancestor:= ele.eledatarel(po2);
     if po2^.infoclass.interfacecount > 0 then begin
      po1^.infoclass.interfaceparent:= po1^.h.ancestor;
     end
     else begin
      po1^.infoclass.interfaceparent:= po2^.infoclass.interfaceparent;
     end;
//     po1^.infoclass.interfacecount:= po2^.infoclass.interfacecount;
//     po1^.infoclass.interfacesubcount:= po2^.infoclass.interfacesubcount;
     with contextstack[s.stackindex-2] do begin
      d.cla.fieldoffset:= po2^.infoclass.allocsize;
      d.cla.virtualindex:= po2^.infoclass.virtualcount;
     end;
    end;
   end;
  end;
  ele.elementparent:= ele1;
 end;
end;

procedure handleclassdefparam2();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFPARAM2');
{$endif}
 classheader(false); //ancestordef
end;

procedure handleclassdefparam3a();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFPARAM3A');
{$endif}
 classheader(true); //interfacedef
 with info do begin
//  dec(s.stackindex);
 end;
end;

function checkinterface(const ainstanceoffset: int32;
                        const ainterface: pclassintfnamedataty): dataoffsty;
             //todo: name alias, delegation and the like

type
 scaninfoty = record
  intfele: elementoffsetty;
  sub: pintfitemty;
  seg: segaddressty;
 end;
              
 procedure dointerface(var scaninfo: scaninfoty);
 var
  intftype: ptypedataty;
  ele1: elementoffsetty;
  po1: pelementinfoty;
  po2: psubdataty;
  po3: pancestorchaindataty;
 begin
  with scaninfo do begin
   intftype:= ele.eledataabs(intfele);
   ele1:= intftype^.infointerface.subchain;
   while ele1 <> 0 do begin
    dec(sub);
    dec(seg.address,sizeof(intfitemty));
    po1:= ele.eleinfoabs(ele1);
                    //todo: overloaded subs
    if (ele.findcurrent(po1^.header.name,[ek_sub],allvisi,po2) <> ek_sub)
                                or not checkparams(@po1^.data,po2) then begin
               //todo: compose parameter message
     errormessage(err_nomatchingimplementation,[
         getidentname(ele.eleinfoabs(ainterface^.intftype)^.header.name)+'.'+
         getidentname(po1^.header.name)]);
    end
    else begin
     include(po2^.flags,sf_intfcall);
     if sf_virtual in po2^.flags then begin
      if po2^.trampolineaddress = 0 then begin
       linkmark(po2^.trampolinelinks,seg{,sizeof(intfitemty.instanceshift)});
      end                                               //offset
      else begin
       sub^.subad:= po2^.trampolineaddress-1;
      end;
     end
     else begin
      if po2^.address = 0 then begin
       linkmark(po2^.adlinks,seg{,sizeof(intfitemty.instanceshift)});
      end                                     //offset
      else begin
       sub^.subad:= po2^.address-1;
      end;
     end;
    end;
//    sub^.instanceshift:= instanceshift;
    ele1:= psubdataty(@po1^.data)^.next;
   end;
   ele1:= intftype^.h.ancestor;
//   ele1:= intftype^.infointerface.ancestorchain;
   while ele1 <> 0 do begin
    po3:= ele.eledataabs(ele1);
    intfele:= po3^.intftype;
    dointerface(scaninfo);
    ele1:= po3^.next;
   end;
  end;
 end;
 
var
 intftypepo: ptypedataty;
 int1: integer;
 scaninfo: scaninfoty;
 
begin
 scaninfo.intfele:= ainterface^.intftype;
 intftypepo:= ptypedataty(ele.eledataabs(scaninfo.intfele));
 pint32(allocsegmentpo(seg_intfitemcount,sizeof(int32)))^:= 
                                           intftypepo^.infointerface.subcount;
// int1:= intftypepo^.infointerface.subcount*sizeof(intfitemty);
 int1:= sizeof(intfdefheaderty)+
                       intftypepo^.infointerface.subcount*sizeof(intfitemty);
 result:= allocsegmentoffset(seg_intf,int1);
 with scaninfo do begin
  seg.address:= result+int1;       //top-down
  sub:= getsegmentpo(seg_intf,seg.address);
  seg.segment:= seg_intf;
 end;
 dointerface(scaninfo); 
 with pintfdefheaderty(pointer(scaninfo.sub)-
                             sizeof(intfdefheaderty))^ do begin
  instanceoffset:= ainstanceoffset;
 end;
end;

//class instance layout:
// header, pointer to virtual table
// fields
// interface table  <- fieldsize
//                  <- allocsize

procedure handleclassdefreturn();
var
 ele1: elementoffsetty;
 classdefs1: segaddressty;
 classinfo1: pclassinfoty;
 parentinfoclass1: pinfoclassty;
 intfcount: integer;
 intfsubcount: integer;
 fla1: addressflagsty;
 int1: integer;
 po1: pdataoffsty;
 interfacealloc: int32;
 
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFRETURN');
{$endif}
 with info do begin
  exclude(s.currentstatementflags,stf_classdef);
  with contextstack[s.stackindex-1],ptypedataty(ele.eledataabs(
                                                d.typ.typedata))^ do begin
   regclass(d.typ.typedata);
   h.flags:= d.typ.flags;
   h.indirectlevel:= d.typ.indirectlevel;
   classinfo1:= @contextstack[s.stackindex].d.cla;

                     
   intfcount:= 0;
   intfsubcount:= 0;
   ele1:= infoclass.interfacechain;
   while ele1 <> 0 do begin          //count interfaces
    with pclassintfnamedataty(ele.eledataabs(ele1))^ do begin
     intfsubcount:= intfsubcount + 
            ptypedataty(ele.eledataabs(intftype))^.infointerface.subcount;
     ele1:= next;
    end;
    inc(intfcount);
   end;
   infoclass.interfacecount:= {infoclass.interfacecount +} intfcount;
   infoclass.interfacesubcount:= {infoclass.interfacesubcount +} intfsubcount;

         //alloc classinfo
   interfacealloc:= infoclass.interfacecount*pointersize;
   infoclass.allocsize:= classinfo1^.fieldoffset + interfacealloc;
   infoclass.virtualcount:= classinfo1^.virtualindex;
   int1:= sizeof(classdefinfoty)+ pointersize*infoclass.virtualcount;
                    //interfacetable start
   classdefs1:= getclassinfoaddress(
                                 int1+interfacealloc,infoclass.interfacecount);
   infoclass.defs:= classdefs1;
   with classdefinfopoty(getsegmentpo(classdefs1))^ do begin
    header.allocs.size:= infoclass.allocsize;
    header.allocs.instanceinterfacestart:= classinfo1^.fieldoffset;
    header.allocs.classdefinterfacestart:= int1;
    header.parentclass:= -1;
    header.interfaceparent:= -1;
    if h.ancestor <> 0 then begin 
     parentinfoclass1:= @ptypedataty(ele.eledataabs(h.ancestor))^.infoclass;
     header.parentclass:= 
                     parentinfoclass1^.defs.address; //todo: relocate
     if parentinfoclass1^.virtualcount > 0 then begin
      fillchar(virtualmethods,parentinfoclass1^.virtualcount*pointersize,0);
      if icf_virtualtablevalid in parentinfoclass1^.flags then begin
       copyvirtualtable(infoclass.defs,classdefs1,
                                       parentinfoclass1^.virtualcount);
      end
      else begin
       regclassdescendent(d.typ.typedata,h.ancestor);
      end;
     end;
    end;
    if infoclass.interfaceparent <> 0 then begin
     header.interfaceparent:= ptypedataty(ele.eledataabs(
            infoclass.interfaceparent))^.infoclass.defs.address;
                                                         //todo: relocate
    end;
    if intfcount <> 0 then begin       //alloc interface table
     po1:= pointer(@header) + header.allocs.classdefinterfacestart;
     inc(po1,infoclass.interfacecount); //top - down
     int1:= -infoclass.allocsize; 
     ele1:= infoclass.interfacechain;
     while ele1 <> 0 do begin
      inc(int1,pointersize);
      dec(po1);
      po1^:= checkinterface(int1,ele.eledataabs(ele1));
      ele1:= pclassintfnamedataty(ele.eledataabs(ele1))^.next;
     end;
    end;
   end;
  {
   ele1:= ele.addelementduplicate1(tks_classimp,globalvisi,ek_classimp);
   ptypedataty(ele.eledataabs(d.typ.typedata))^.infoclass.impl:= ele1;
              //possible capacity change
  }
  end;
    
  ele.elementparent:= contextstack[s.stackindex].b.eleparent;
  currentcontainer:= 0;
 end;
end;

procedure handleclassdeferror();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFERROR');
{$endif}
 tokenexpectederror(tk_end);
end;

procedure handleclassprivate();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPRIVATE');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.cla.visibility:= classprivatevisi;
 end;
end;

procedure handleclassprotected();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPROTECTED');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.cla.visibility:= classprotectedvisi;
 end;
end;

procedure handleclasspublic();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPUBLIC');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.cla.visibility:= classpublicvisi;
 end;
end;

procedure handleclasspublished();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPUBLISHED');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.cla.visibility:= classpublishedvisi;
 end;
end;

procedure handleclassfield();
var
 po1: pvardataty;
 po2: ptypedataty;
 ele1: elementoffsetty;
begin
{$ifdef mse_debugparser}
 outhandle('CLASSFIELD');
{$endif}
 with info,contextstack[s.stackindex-1] do begin
  checkrecordfield(d.cla.visibility,[af_classfield],d.cla.fieldoffset,
                                   contextstack[s.stackindex-2].d.typ.flags);
 end;
end;

procedure handlemethprocedureentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHPROCEDUREENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method];
 end;
end;

procedure handlemethfunctionentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHFUNCTIONENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_function,sf_header,sf_method];
 end;
end;

procedure handlemethconstructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHCONSTRUCTORENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method,sf_constructor];
 end;
end;

procedure handlemethdestructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHDESTRUCTORENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method,sf_destructor];
 end;
end;

procedure handleconstructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('CONSTRUCTORENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_method,sf_constructor];
 end;
end;

procedure handledestructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('DESTRUCTORENTRY');
{$endif}
 with info,contextstack[s.stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_method,sf_destructor];
 end;
end;

procedure classpropertyentry();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPROPERTYENTRY');
{$endif}
 with info,contextstack[s.stackindex] do begin
  d.kind:= ck_classprop;
  d.classprop.flags:= [];
  d.classprop.errorref:= errors[erl_error];
 end;
end;
(*
procedure handleclasspropertytype();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPROPERTYTYPE');
{$endif}
 with info do begin
  if s.stacktop > s.stackindex+1 then begin
  end;
  s.stacktop:= s.stackindex+2;
 end;
end;
*)
var testvar: pvardataty;
function checkpropaccessor(const awrite: boolean): boolean;

 procedure illegalsymbol();
 begin
  errormessage(err_illegalpropsymbol,[]);
  result:= false;
 end; //illegalsymbol

 function checkindex(const indexcount: int32; const sub: psubdataty): boolean;
 var
  popar,pe: pelementoffsetty;
  pocontext: pcontextitemty;
 begin
  result:= true;
  if indexcount > 0 then begin
   pocontext:= @info.contextstack[info.s.stackindex+3];
   popar:= pelementoffsetty(@sub^.paramsrel)+2; //first index param
   pe:= popar + indexcount;
   while popar < pe do begin
   {$ifdef checkinternalerror}
    if (pocontext^.d.kind <> ck_paramsdef) or 
                        ((pocontext+2)^.d.kind <> ck_fieldtype) then begin
     internalerror(ie_parser,'20160106A');
    end;
   {$endif}
testvar:= pvardataty(ele.eledataabs(popar^));
    with pvardataty(ele.eledataabs(popar^))^ do begin
     if ((pocontext+2)^.d.typ.typedata <> vf.typ) or 
       ((paramkinds[pocontext^.d.paramsdef.kind] >< address.flags) * 
                                               paramflagsmask <> []) then begin
      illegalsymbol();
      result:= false;
      exit;
     end;
    end;
    inc(popar);
    inc(pocontext,3);
   end;
  end;
 end;  //checkindex
 
var
 po1: pointer;
 elekind1: elementkindty;
 typeele1: elementoffsetty;
 indi1: int32;
 ele1: elementoffsetty;
 i1: int32;
 offs1: int32;
 idstart1: int32;
 indexcount1: int32;
label
 endlab;
begin
 result:= false;
 with info,contextstack[s.stackindex] do begin
 {$ifdef mse_checkinternalerror}
  if contextstack[s.stackindex].d.kind <> ck_classprop then begin
   internalerror(ie_handler,'20151214A');
  end;
  if contextstack[s.stackindex+1].d.kind <> ck_ident then begin
   internalerror(ie_handler,'20151201A');
  end;
  if contextstack[s.stacktop].d.kind <> ck_ident then begin
   internalerror(ie_handler,'20151214B');
  end;
 {$endif}
  idstart1:= s.stacktop;
  while contextstack[idstart1].d.kind = ck_ident do begin
   dec(idstart1);
  end;
 {$ifdef mse_checkinternalerror}
  if contextstack[idstart1].d.kind <> ck_typeref then begin
   internalerror(ie_handler,'20151201B');
  end;
 {$endif}
  typeele1:= contextstack[idstart1].d.typeref;
  indi1:= ptypedataty(ele.eledataabs(typeele1))^.h.indirectlevel;
  indexcount1:= 0;
  i1:= idstart1 - s.stackindex;
  if i1 > 1 then begin
   indexcount1:= (i1 - 3) div 3;
  end;
  inc(idstart1);
  elekind1:= ele.findcurrent(contextstack[idstart1].d.ident.ident,[],
                                                           [vik_ancestor],po1);
  ele1:= ele.eledatarel(po1);
  case elekind1 of
   ek_none: begin
    identerror(s.stacktop-s.stackindex,err_identifiernotfound);
   end;
   ek_field: begin
    if indexcount1 > 0 then begin
     illegalsymbol();
     goto endlab;
    end;
    offs1:= pfielddataty(po1)^.offset;
    for i1:= idstart1+1 to s.stacktop do begin
     if ele.findchild(pfielddataty(po1)^.vf.typ,contextstack[i1].d.ident.ident,
                            [ek_field],allvisi,ele1,po1) <> ek_field then begin
      identerror(i1-s.stackindex,err_unknownrecordfield);
      goto endlab;
     end;
     offs1:= offs1 + pfielddataty(po1)^.offset;
    end;
    with pfielddataty(po1)^ do begin
     if (vf.typ = typeele1) and (indirectlevel = indi1) then begin
      if awrite then begin
       d.classprop.writeele:= ele1;
       d.classprop.writeoffset:= offs1;
       include(d.classprop.flags,pof_writefield);
      end
      else begin
       d.classprop.readele:= ele1;
       d.classprop.readoffset:= offs1;
       include(d.classprop.flags,pof_readfield);
      end;
      result:= true;
     end
     else begin
      incompatibletypeserror(typeele1,vf.typ);
     end;
    end;
   end;
   ek_sub: begin   //todo: index option
    with psubdataty(po1)^ do begin
     if (sf_method in flags) then begin
      if awrite then begin
       if not (sf_function in flags) and (paramcount = 2 + indexcount1) and
         (pvardataty(ele.eledataabs(
                 pelementoffsetty(@paramsrel)[1]))^.vf.typ = typeele1) then begin
        d.classprop.writeele:= ele1;
        d.classprop.writeoffset:= 0;
        include(d.classprop.flags,pof_writesub);
        result:= checkindex(indexcount1,po1);
       end
       else begin
        illegalsymbol();
       end;
      end
      else begin
       if (sf_function in flags) and (paramcount = 2 + indexcount1) and 
            (resulttype.typeele = typeele1) and 
                            (resulttype.indirectlevel = indi1) then begin
                            //necessary?
        d.classprop.readele:= ele1;
        d.classprop.readoffset:= 0;
        include(d.classprop.flags,pof_readsub);
        result:= checkindex(indexcount1,po1);
       end
       else begin
        illegalsymbol();
       end;
      end;
     end
     else begin
      illegalsymbol();
     end;
    end;
   end;
   else begin
    identerror(s.stacktop-s.stackindex,err_unknownfieldormethod);
   end;
  end;
endlab:
  s.stacktop:= idstart1-1;
 end;
end;

procedure handlereadprop();
begin
{$ifdef mse_debugparser}
 outhandle('READPROP');
{$endif}
 with info,contextstack[s.stackindex] do begin  
 {$ifdef mse_checkinternalerror}
  if d.kind <> ck_classprop then begin
   internalerror(ie_handler,'20151201A');
  end;
 {$endif}
  if checkpropaccessor(false) then begin
  end;
 end;
end;

procedure handlewriteprop();
begin
{$ifdef mse_debugparser}
 outhandle('WRITEPROP');
{$endif}
 with info,contextstack[s.stackindex] do begin
 {$ifdef mse_checkinternalerror}
  if d.kind <> ck_classprop then begin
   internalerror(ie_handler,'20151201A');
  end;
 {$endif}
  if checkpropaccessor(true) then begin
  end;
 end;
end;

procedure handledefaultprop();
var
 po1: ptypedataty;
begin
{$ifdef mse_debugparser}
 outhandle('DEFAULTPROP');
{$endif}
 with info,contextstack[s.stacktop] do begin
 {$ifdef mse_checkinternalerror}
  if contextstack[s.stacktop-1].d.kind <> ck_typeref then begin
   internalerror(ie_handler,'20151202C');
  end;
 {$endif}
  if d.kind <> ck_const then begin
   errormessage(err_constexpressionexpected,[]);
  end
  else begin
   po1:= ele.eledataabs(contextstack[s.stacktop-1].d.typeref);
   if not tryconvert(s.stacktop-s.stackindex,po1,
                               po1^.h.indirectlevel,[]) then begin
    incompatibletypeserror(contextstack[s.stacktop-1].d.typeref,
                                                        d.dat.datatyp.typedata);
   end
   else begin
    include(contextstack[s.stackindex].d.classprop.flags,pof_default);
   end;
  end;
 end; 
end;

procedure handleclassproperty();
var
 po1: ppropertydataty;
 typeeleid1: int32;
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPROPERTY');
{$endif}
 with info,contextstack[s.stackindex] do begin
  if d.classprop.errorref = errors[erl_error] then begin //no error
  {$ifdef mse_checkinternalerror}
   if s.stacktop-s.stackindex < 2 then begin
    internalerror(ie_handler,'20151207B');
   end;
   if d.kind <> ck_classprop then begin
    internalerror(ie_handler,'20151202B');
   end;
   if contextstack[s.stackindex+1].d.kind <> ck_ident then begin
    internalerror(ie_handler,'20151202C');
   end;
  {$endif}
   if not ele.addelementdata(contextstack[s.stackindex+1].d.ident.ident,
                           ek_property,[vik_ancestor],po1) then begin
    identerror(1,err_duplicateidentifier);
   end
   else begin
    with po1^ do begin
     flags:= d.classprop.flags;
     if pof_default in flags then begin
     {$ifdef mse_checkinternalerror}
      if contextstack[s.stacktop].d.kind <> ck_const then begin
       internalerror(ie_handler,'20151202D');
      end;
      if contextstack[s.stacktop-1].d.kind <> ck_typeref then begin
       internalerror(ie_handler,'20151207A');
      end;
     {$endif}
      with contextstack[s.stacktop] do begin
       defaultconst.typ:= d.dat.datatyp;
       defaultconst.d:= d.dat.constval;
      end;
      typ:= contextstack[s.stacktop-1].d.typeref;
     end
     else begin
     {$ifdef mse_checkinternalerror}
      if contextstack[s.stacktop].d.kind <> ck_typeref then begin
       internalerror(ie_handler,'20151207A');
      end;
     {$endif}
      typ:= contextstack[s.stacktop].d.typeref;
     end;
     if flags * canreadprop <> [] then begin
      readele:= d.classprop.readele;
      readoffset:= d.classprop.readoffset;
     end
     else begin
      readele:= 0;
      readoffset:= 0;
     end;
     if flags * canwriteprop <> [] then begin
      writeele:= d.classprop.writeele;
      writeoffset:= d.classprop.writeoffset;
     end
     else begin
      writeele:= 0;
      writeoffset:= 0;
     end;
    end;     
   end;
  end;
  dec(s.stackindex);
 end;
end;

end.
