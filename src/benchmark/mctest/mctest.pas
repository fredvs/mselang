program mctest;
{$ifdef fpc}
 {$mode objfpc}
uses
 sysutils,math,baseunix;
type
 card32 = longword;
{$else}
uses
 rtl_libc,rtl_fpccompatibility;

type
 longint = int32;
 smallint = int16;
 string = string8;
 single = flo32;
 double = flo64;
{$endif}

const
 defaultmwcseedw = 521288629;
 defaultmwcseedz = 362436069;

var
 fw: card32;
 fz: card32;

function mwcnoise: card32;
begin
 fz:= 36969 * (fz and $ffff) + (fz shr 16);
 fw:= 18000 * (fw and $ffff) + (fw shr 16);
 result:= fz shl 16 + fw;
end;

function random(const limit: int32): int32;
begin
 result:= mwcnoise();
 if limit > 0 then begin
  result:= card32(result) mod card32(limit);
 end
 else begin
  result:= 0;
 end;
end;

const
  s_w = 640;
  s_h = 400;
  math_pi = 3.14159265359;

var
  screen: array [0..s_h-1, 0..s_w-1] of LongInt;
  texmap : array[0..16*16*16*3-1] of LongInt;
  map : array[0..64*64*64-1] of smallint;

procedure  plot(x,y,c : LongInt) {$ifdef FPC}inline{$endif};
begin
  screen[y, x] := c;
end;
procedure makeTextures();
var
   j,m,k,i1,i2,i3,n : LongInt;
begin

    // each texture
    for j:=0 to 15 do begin

        k := 255 - random(96);

        // each pixel in the texture
        for m:=0  to (16 * 3)-1 do
            for n :=0 to 15 do begin

                i1 := $966C4A;
                i2 := 0;
                i3 := 0;

                if (j = 4) then
                    i1 := $7F7F7F;
                if ((j <> 4) or (random(3) = 0)) then
                    k := 255 - random(96);
                if ( j = 1 ) then
                begin
                    if m < ((((n * n * 3 + n * 81) shr 2) and $3) + 18) then
                        i1 := $6AAA40
                    else if m < ((((n * n * 3 + n * 81) shr 2) and $3) + 19) then
                        k := k * 2 div 3;
                end;
                if (j = 7) then
                begin
                    i1 := $675231;
                    if ((n > 0) and (n < 15) and (((m > 0) and (m < 15)) or ((m > 32) and (m < 47)))) then
                    begin
                        i1 := $BC9862;
                        i2 := n - 7;
                        i3 := (m and $F) - 7;
                        if (i2 < 0.0) then
                            i2 := 1 - i2;

                        if (i3 < 0.0) then
                            i3 := 1 - i3;

                        if (i3 > i2) then
                            i2 := i3;

                        k := 196 - random(32) + i2 mod 3 * 32;
                    end
                    else if (random(2) = 0) then
                        k := k * (150 - (n and $1) * 100) div 100;
                end;
                if (j = 5) then
                begin
                    i1 := $B53A15;
                    if (((n + m div 4 * 4) mod 8 = 0) or (m mod 4 = 0)) then
                        i1 := $BCAFA5;
                end;
                i2 := k;
                if (m >= 32) then
                    i2 := i2 div 2;
                if (j = 8) then
                begin
                    i1 := 5298487;
                    if (random(2) = 0) then
                    begin
                        i1 := 0;
                        i2 := 255;
                    end;
                end;

                // fixed point colour multiply between i1 and i2
                i3 :=
                    ((((i1 shr 16) and $FF) * i2 div 255) shl 16) or
                    ((((i1 shr  8) and $FF) * i2 div 255) shl  8) or
                      ((i1        and $FF) * i2 div 255);
                // pack the colour away
                texmap[ n + m * 16 + j * 256 * 3 ] := i3;
            end;
    end;
end;

procedure makeMap( ) ;
var x,y,z,i : longword;
    yd,zd,th : single;
begin
    // add random blocks to the map
    for x := 0 to 63 do begin
        for y := 0 to 63 do begin
             for z := 0 to 63 do begin
                i := (z shl 12) or (y shl 6) or x;
               yd := (y - 32.5) * 0.4;
               zd := (z - 32.5) * 0.4;
               map[i] := random( 16 );
               th := random( 256 ) / 256.0;

              if (th > sqrt( sqrt( yd * yd + zd * zd ) ) - 0.8) or (th < 0.5) then
                 map[i] := 0;
              end;
        end;
    end;
end;

// fixed point byte byte multiply
function fxmul( a,b : LongInt ):LongInt ; {$ifdef FPC}inline;{$endif}
begin
    result := (a*b) shr 8;
end;

// fixed point 8bit packed colour multiply
function  rgbmul(a,b : LongInt ):LongInt;
var _r,_g,_b : LongInt;
begin
    _r := (((a shr 16) and $ff) * b) shr 8;
    _g := (((a shr 8) and $ff) * b) shr 8;
    _b := (((a    ) and $ff) * b) shr 8;
    result := (_r shl 16) or (_g shl 8) or _b;
end;

var
 loopcount: int64;

procedure render(  );
var
   tnow: tdatetime;
   xRot,yRot,yCos,
   ySin,xCos,xSin,___xd,
   __yd,__zd,___zd,_yd,
  _xd,_zd,ddist,closest,
  ox,oy,oz,dimLength,ll,
  xd,yd,zd,initial,dist,
  xp,yp,zp: single;
   x,y ,col,br,d,tex,u,v,cc: longword;
begin
  { tnow := (SDL_GetTicks( ) mod 10000) / 10000; }
  tnow:= 0.5;
  xRot := sin(tnow * math_pi * 2) * 0.4 + math_pi / 2;
  yRot := cos(tnow * math_pi * 2) * 0.4;
  yCos := cos(yRot);
  ySin := sin(yRot);
  xCos := cos(xRot);
  xSin := sin(xRot);

  ox := 32.5 + tnow * 64.0;
  oy := 32.5;
  oz := 32.5;

  // for each column
  for x :=0 to s_w -1 do begin
    // get the x axis delta
    ___xd := (x - s_w / 2) / s_h;
    // for each row
    for y :=0 to s_h-1 do begin
      // get the y axis delta
      __yd := (y - s_h / 2) / s_h;
      __zd := 1;
      ___zd :=  __zd * yCos +  __yd * ySin;
      _yd :=  __yd * yCos -  __zd * ySin;
      _xd := ___xd * xCos + ___zd * xSin;
      _zd := ___zd * xCos - ___xd * xSin;

      col := 0;
      br := 255;
      ddist := 0;

      closest := 32.0;

      // for each principle axis  x,y,z
      for d :=0 to 2 do begin
        dimLength := _xd;
        if (d = 1) then
          dimLength := _yd
        else if (d = 2) then
          dimLength := _zd;
        if dimLength < 0.0 then
          dimLength := -dimLength;
        ll := 1.0 / dimLength;
        xd := _xd * ll;
        yd := _yd * ll;
        zd := _zd * ll;

        initial := ox - floor(ox);
        if (d = 1) then initial := oy - floor(oy);
        if (d = 2) then initial := oz - floor(oz);

        if (dimLength > 0.0) then initial := 1 - initial;

        dist := ll * initial;

        xp := ox + xd * initial;
        yp := oy + yd * initial;
        zp := oz + zd * initial;

        if (dimLength < 0.0) then begin
          if (d = 0) then xp:=xp-1;
          if (d = 1) then yp:=yp-1;
          if (d = 2) then zp:=zp-1;
        end;

        // while we are concidering a ray that is still closer then the best so far
        while (dist < closest) do begin
          // quantize to the map grid
          tex := map[ ((trunc(zp) and 63) shl 12) or ((trunc(yp) and 63) shl 6) or (trunc(xp) and 63) ];

          // if this voxel has a texture applied
          if (tex > 0) then begin
            // find the uv coordinates of the intersection point
            u := (round((xp + zp) * 16)) and 15;
            v := (round(yp    * 16)  and 15) + 16;

            // fix uvs for alternate directions?
            if (d = 1) then begin
              u :=  (round(xp * 16)) and 15;
              v := ((round(zp * 16)) and 15);
              if (yd < 0.0) then
                inc(v, 32);
            end;

            //find the colour at the intersection point
            cc := texmap[ u + v * 16 + tex * 256 * 3 ];
            // if the colour is not transparent
            if (cc > 0) then begin
              col := cc;
              ddist := 255 - ((dist / 32 * 255));
              br := 255 * (255 - ((d + 2) mod 3) * 50) div 255;
              //we now have the closest hit point (also terminates this ray)
              closest := dist;
            end;
            inc(loopcount);
          end;
          // advance the ray
          xp:=xp+xd;
          yp:=yp+yd;
          zp:=zp+zd;
          dist:=dist+ll;
        end;
      end;

      plot( x, y, rgbmul( col, fxmul( br, round(ddist) ) ) );
    end;
  end;
end;

const
 runs = 100;
var
 ti1,ti2: tdatetime;
 i1,i2,i3: int32;
begin
 fw:= defaultmwcseedw;
 fz:= defaultmwcseedz;

 maketextures();
 makemap();

 i2:= 0;
 for i1:= 0 to high(texmap) do begin
  i2:= i2 + (texmap[i1] xor i1);
 end;
 writeln('Texmap checksum: ',i2);
 i2:= 0;
 for i1:= 0 to high(map) do begin
  i2:= i2 + (map[i1] xor i1);
 end;
 writeln('Map checksum: ',i2);

 loopcount:= 0;

 ti1:= now();
 for i1:= 0 to runs-1 do begin
  render();
 end;
 ti2:= now();

 i3:= 0;
 for i1:= 0 to high(screen) do begin
  for i2:= 0 to high(screen[0]) do begin
   i3:= i3 + (screen[i1][i2] xor (i1+i2));
  end;
 end;
 writeln('Loopcount: ',loopcount,' Screen checksum: ',i3);

 writeln(runs/((ti2-ti1)*24*60*60),' FPS');
 i1:= fpopen(pchar('test.pix'),o_rdwr or o_creat or o_trunc);
 fpwrite(i1,pchar(@screen),sizeof(screen));
 fpclose(i1);
end.