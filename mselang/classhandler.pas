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
{$ifdef FPC}{$mode objfpc}{$h+}{$endif}
interface
uses
 parserglob;

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

implementation
uses
 elements,handler,errorhandler,unithandler,grammar,handlerglob,handlerutils,
 parser,typehandler,opcode;
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
procedure handleclassdefstart();
var
 po1: ptypedataty;
// po2: pclassdataty;
// po3: pvisibledataty;
 id1: identty;

begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFSTART');
{$endif}
 with info do begin
  if stackindex < 3 then begin
   internalerror('H20140325D');
   exit;
  end;
  include(currentstatementflags,stf_classdef);
  with contextstack[stackindex] do begin
   d.kind:= ck_classdef;
   d.cla.visibility:= classpublishedvisi;
   d.cla.fieldoffset:= pointersize; //pointer to virtual methodtable
   d.cla.virtualindex:= 0;
//   d.cla.parentclass:= 0;
  end;
  with contextstack[stackindex-2] do begin
   if (d.kind = ck_ident) and 
                  (contextstack[stackindex-1].d.kind = ck_typetype) then begin
    id1:= d.ident.ident; //typedef
   end
   else begin
    errormessage(err_anonclassdef,[]);
    exit;
   end;
  end;
  contextstack[stackindex].b.eleparent:= ele.elementparent;
  with contextstack[stackindex-1] do begin
   if not ele.pushelement(id1,globalvisi,ek_type,d.typ.typedata) then begin
    identerror(stacktop-stackindex,err_duplicateidentifier,erl_fatal);
   end;
   currentclass:= d.typ.typedata;
   po1:= ele.eledataabs(currentclass);
   with po1^ do begin
    kind:= dk_class;
    datasize:= das_pointer;
    bytesize:= pointersize;
    bitsize:= pointersize*8;
    ancestor:= 0;
    infoclass.impl:= 0;
    infoclass.defs:= 0;
    infoclass.flags:= [];
    infoclass.pendingdescends:= 0;
   end;
  end;
{
  if not ele.addelement(id1,vis_max,ek_type,po1) then begin
   identerror(stacktop-stackindex,err_duplicateidentifier,erl_fatal);
  end
  else begin
   classesscopeset();
   ele.pushelement(id1,vis_max,ek_class,po2);
   currentclass:= ele.eledatarel(po2);
   currentclassvislevel:= vic_published; //default
  end;
 }
 end;
end;

procedure handleclassdefparam2();
var
 po1,po2: ptypedataty;
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFPARAM2');
{$endif}
 with info do begin
  po1:= ele.eledataabs(currentclass);
  ele.pushelementparent();
  ele.decelementparent; //interface or implementation
  if findkindelementsdata(1,[ek_type],allvisi,po2) then begin
   if po2^.kind <> dk_class then begin
    errormessage(err_classidentexpected,[]);
   end
   else begin
    po1^.ancestor:= ele.eledatarel(po2);
    with contextstack[stackindex-2] do begin
     d.cla.fieldoffset:= po2^.infoclass.allocsize;
     d.cla.virtualindex:= po2^.infoclass.virtualcount;
    end;
   end;
  end;
  ele.popelementparent;
//  dec(stackindex);
 end;
end;

procedure handleclassdefparam3a();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFPARAM3A');
{$endif}
 with info do begin
//  dec(stackindex);
 end;
end;

procedure handleclassdefreturn();
var
// po2: pclassesdataty;
 ele1: elementoffsetty;
 classdefs1: dataoffsty;
 classinfo1: pclassinfoty;
 parentinfoclass1: pinfoclassty;
 
begin
{$ifdef mse_debugparser}
 outhandle('CLASSDEFRETURN');
{$endif}
outinfo('***');
 with info do begin
  exclude(currentstatementflags,stf_classdef);
  with contextstack[stackindex-1],ptypedataty(ele.eledataabs(
                                                d.typ.typedata))^ do begin
   regclass(d.typ.typedata);
   indirectlevel:= d.typ.indirectlevel;
   classinfo1:= @contextstack[stackindex].d.cla;
   infoclass.allocsize:= classinfo1^.fieldoffset;
   infoclass.virtualcount:= classinfo1^.virtualindex;
   classdefs1:= getglobconstaddress(sizeof(classdefinfoty)+
                                   pointersize*infoclass.virtualcount);
   infoclass.defs:= classdefs1;   
   with pclassdefinfoty(pointer(constseg)+classdefs1)^ do begin
    header.fieldsize:= classinfo1^.fieldoffset;
    header.parentclass:= 0;
    if ancestor <> 0 then begin 
     parentinfoclass1:= @ptypedataty(ele.eledataabs(ancestor))^.infoclass;
     header.parentclass:= parentinfoclass1^.defs;
     if infoclass.virtualcount > 0 then begin
      if icf_virtualtablevalid in parentinfoclass1^.flags then begin
       copyvirtualtable(infoclass.defs,classdefs1,infoclass.virtualcount);
      end
      else begin
       regclassdescendant(d.typ.typedata,ancestor);
      end;
     end;
    end;
   end;
   ele1:= ele.addelementduplicate1(tks_classimp,globalvisi,ek_classimp);
   ptypedataty(ele.eledataabs(d.typ.typedata))^.infoclass.impl:= ele1;
              //possible capacity change
  end;
  ele.elementparent:= contextstack[stackindex].b.eleparent;
  currentclass:= 0;
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
 with info,contextstack[stackindex] do begin
  d.cla.visibility:= classprivatevisi;
 end;
end;

procedure handleclassprotected();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPROTECTED');
{$endif}
 with info,contextstack[stackindex] do begin
  d.cla.visibility:= classprotectedvisi;
 end;
end;

procedure handleclasspublic();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPUBLIC');
{$endif}
 with info,contextstack[stackindex] do begin
  d.cla.visibility:= classpublicvisi;
 end;
end;

procedure handleclasspublished();
begin
{$ifdef mse_debugparser}
 outhandle('CLASSPUBLISHED');
{$endif}
 with info,contextstack[stackindex] do begin
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
 with info,contextstack[stackindex-1] do begin
  checkrecordfield(d.cla.visibility,[vf_classfield],d.cla.fieldoffset);
 end;
 {
 with info do begin
  ele.addelement(contextstack[stackindex+2].d.ident.ident,
       currentclassvislevel,ek_var,po1);
  if po1 = nil then begin
   identerror(2,err_duplicateidentifier);   
  end;
  ele1:= ele.elementparent;
  classesscopereset();
  if findkindelementsdata(3,[ek_type],vis_max,po2) then begin
  end
  else begin
   identerror(stacktop-stackindex,err_identifiernotfound);
  end;
  ele.elementparent:= ele1;
 end;
 }
end;

procedure handlemethprocedureentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHPROCEDUREENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method];
 end;
end;

procedure handlemethfunctionentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHFUNCTIONENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_function,sf_header,sf_method];
 end;
end;

procedure handlemethconstructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHCONSTRUCTORENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method,sf_constructor];
 end;
end;

procedure handlemethdestructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('METHDESTRUCTORENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_header,sf_method,sf_destructor];
 end;
end;

procedure handleconstructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('CONSTRUCTORENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_method,sf_constructor];
 end;
end;

procedure handledestructorentry();
begin
{$ifdef mse_debugparser}
 outhandle('DESTRUCTORENTRY');
{$endif}
 with info,contextstack[stackindex].d do begin
  kind:= ck_subdef;
  subdef.flags:= [sf_method,sf_destructor];
 end;
end;

end.
