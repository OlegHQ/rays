// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
const store = (rt, s, index, value) => {
  const i = Number(rt.coerce("int", index));
  if (s instanceof rt.TextArray) {
    if (i < 0 || i >= s.data.length) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    if (typeof value !== 'string') rt.fail("E_ARRAY_TYPE", "Text arrays contain text values.");
    s.data[i] = value;
  } else if (s instanceof rt.PArray) {
    const n = s.data.length / s.width;
    if (i < 0 || i >= n) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    if (s.data instanceof BigInt64Array) {
      if (typeof value !== 'number' && typeof value !== 'bigint' && typeof value !== 'boolean')
        rt.fail("E_ARRAY_TYPE", "Packed integer arrays contain integer values.");
      s.data[i] = rt.coerce("int", value);
      return;
    }
    const comps = value instanceof Float64Array ? value : Array(s.width).fill(rt.float(value));
    if (comps.length !== s.width) rt.fail("E_ARRAY_TYPE", "Packed array element has the wrong vector width.");
    for (let j = 0; j < s.width; j++)
      s.data[i * s.width + j] = Number.isFinite(comps[j]) ? comps[j] : rt.fail("E_NONFINITE", "array produced a nonfinite value.");
  } else {
    if (i < 0 || i >= s.length) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    s[i] = value;
  }
};
export function frame(input, state, rt) {
  K ??= [-1000, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 0n, 1n, true, 0n, false, 0n, 2n, true, 1n, 0n, 0n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 1n, 1n, true, 0n, false, 1n, 2n, true, 1n, 0n, 10n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 2n, 1n, true, 0n, false, 2n, 2n, true, 1n, 0n, 20n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 0n, 1n, true, 0n, false, 0n, 2n, true, 1n, 0n, 0n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 1n, 1n, true, 0n, false, 1n, 2n, true, 1n, 0n, 10n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], 4096n, 0n, 2n, 1n, true, 0n, false, 2n, 2n, true, 1n, 0n, 20n, 1n, 0n, 1n, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61, l62, l63;
  let l64, l65, l66, l67, l68, l69, l70, l71, l72, l73, l74, l75, l76, l77, l78, l79;
  let l80, l81, l82, l83, l84, l85, l86, l87, l88, l89, l90, l91, l92, l93, l94, l95;
  let l96, l97, l98, l99, l100, l101, l102, l103, l104, l105, l106, l107, l108, l109, l110, l111;
  let l112, l113, l114, l115, l116, l117, l118, l119, l120, l121, l122, l123, l124, l125, l126, l127;
  let l128, l129, l130, l131, l132, l133, l134, l135, l136, l137, l138, l139, l140, l141, l142, l143;
  let l144, l145, l146, l147, l148, l149, l150, l151, l152, l153, l154, l155, l156, l157, l158, l159;
  let l160, l161, l162, l163, l164, l165, l166, l167, l168, l169, l170, l171, l172, l173, l174, l175;
  let l176, l177, l178, l179, l180, l181, l182, l183, l184, l185, l186, l187, l188, l189, l190, l191;
  let l192, l193, l194, l195, l196, l197, l198, l199, l200, l201, l202, l203, l204, l205, l206, l207;
  let l208, l209, l210, l211, l212, l213, l214, l215, l216, l217, l218, l219, l220, l221, l222, l223;
  let l224, l225, l226, l227, l228, l229, l230, l231, l232, l233, l234, l235, l236, l237, l238, l239;
  let l240, l241, l242, l243, l244, l245, l246, l247, l248, l249, l250, l251, l252, l253, l254, l255;
  let l256, l257, l258, l259, l260, l261, l262, l263, l264, l265, l266, l267, l268, l269, l270, l271;
  let l272, l273, l274, l275, l276, l277, l278, l279, l280, l281, l282, l283, l284, l285, l286, l287;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = K[1];
      at = 5; l5 = l4;
      at = 6; l6 = K[2];
      at = 7; l7 = l6;
      at = 8; l8 = K[3];
      at = 9; l9 = rt.sequence_build(l8);
      at = 10; l10 = K[4];
      at = 11; {
        const s11 = l10, c11 = Array.isArray(s11) ? s11.length : Number(rt.array_count(s11));
        if (c11 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i11 = 0; i11 < c11; i11++) {
          l11 = BigInt(i11); l12 = Array.isArray(s11) ? s11[i11] : rt.array_nth(s11, i11);
          at = 12; l13 = K[5];
          at = 13; l14 = rt.ge(l5, l13);
          at = 14; if (rt.truthy(l14)) {
            at = 15; l16 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 16; l15 = l16;
          } else {
            at = 17; l17 = K[6];
            at = 18; l15 = l17;
          }
          at = 19; l18 = K[7];
          at = 20; l19 = K[8];
          at = 21; l20 = rt.eq(l18, l19);
          at = 22; l21 = K[9];
          at = 23; l22 = rt.and(l21, l20);
          at = 24; l23 = K[10];
          at = 25; l24 = rt.eq(l5, l23);
          at = 26; l25 = rt.and(l22, l24);
          at = 27; l26 = K[11];
          at = 28; l27 = rt.or(l26, l25);
          at = 29; l28 = K[12];
          at = 30; l29 = K[13];
          at = 31; l30 = rt.eq(l28, l29);
          at = 32; l31 = K[14];
          at = 33; l32 = rt.and(l31, l30);
          at = 34; l33 = K[15];
          at = 35; l34 = rt.eq(l5, l33);
          at = 36; l35 = rt.and(l32, l34);
          at = 37; l36 = rt.or(l27, l35);
          at = 38; if (rt.truthy(l36)) {
            at = 39; l38 = K[16];
            at = 40; l37 = l38;
          } else {
            at = 41; l39 = K[17];
            at = 42; l40 = rt.add(l39, l12);
            at = 43; l41 = input.t;
            at = 44; l42 = rt.add(l40, l41);
            at = 45; store(rt, l9, l7, l42);
            at = 46; l43 = K[18];
            at = 47; l44 = rt.add(l7, l43);
            at = 48; l7 = l44;
            at = 49; l45 = K[19];
            at = 50; l37 = l45;
          }
          at = 51; l46 = K[20];
          at = 52; l47 = rt.add(l5, l46);
          at = 53; l5 = l47;
        }
      }
      at = 54; l48 = K[21];
      at = 55; l49 = rt.sequence_slice(l9, l48, l7);
      at = 56; l50 = rt.sequence_concat(l49);
      at = 57; l51 = K[22];
      at = 58; l52 = l51;
      at = 59; l53 = K[23];
      at = 60; l54 = l53;
      at = 61; l55 = K[24];
      at = 62; l56 = rt.sequence_build(l55);
      at = 63; l57 = K[25];
      at = 64; {
        const s64 = l57, c64 = Array.isArray(s64) ? s64.length : Number(rt.array_count(s64));
        if (c64 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i64 = 0; i64 < c64; i64++) {
          l58 = BigInt(i64); l59 = Array.isArray(s64) ? s64[i64] : rt.array_nth(s64, i64);
          at = 65; l60 = K[26];
          at = 66; l61 = rt.ge(l52, l60);
          at = 67; if (rt.truthy(l61)) {
            at = 68; l63 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 69; l62 = l63;
          } else {
            at = 70; l64 = K[27];
            at = 71; l62 = l64;
          }
          at = 72; l65 = K[28];
          at = 73; l66 = K[29];
          at = 74; l67 = rt.eq(l65, l66);
          at = 75; l68 = K[30];
          at = 76; l69 = rt.and(l68, l67);
          at = 77; l70 = K[31];
          at = 78; l71 = rt.eq(l52, l70);
          at = 79; l72 = rt.and(l69, l71);
          at = 80; l73 = K[32];
          at = 81; l74 = rt.or(l73, l72);
          at = 82; l75 = K[33];
          at = 83; l76 = K[34];
          at = 84; l77 = rt.eq(l75, l76);
          at = 85; l78 = K[35];
          at = 86; l79 = rt.and(l78, l77);
          at = 87; l80 = K[36];
          at = 88; l81 = rt.eq(l52, l80);
          at = 89; l82 = rt.and(l79, l81);
          at = 90; l83 = rt.or(l74, l82);
          at = 91; if (rt.truthy(l83)) {
            at = 92; l85 = K[37];
            at = 93; l84 = l85;
          } else {
            at = 94; l86 = K[38];
            at = 95; l87 = rt.add(l86, l59);
            at = 96; l88 = input.t;
            at = 97; l89 = rt.add(l87, l88);
            at = 98; store(rt, l56, l54, l89);
            at = 99; l90 = K[39];
            at = 100; l91 = rt.add(l54, l90);
            at = 101; l54 = l91;
            at = 102; l92 = K[40];
            at = 103; l84 = l92;
          }
          at = 104; l93 = K[41];
          at = 105; l94 = rt.add(l52, l93);
          at = 106; l52 = l94;
        }
      }
      at = 107; l95 = K[42];
      at = 108; l96 = rt.sequence_slice(l56, l95, l54);
      at = 109; l97 = rt.sequence_concat(l96);
      at = 110; l98 = K[43];
      at = 111; l99 = l98;
      at = 112; l100 = K[44];
      at = 113; l101 = l100;
      at = 114; l102 = K[45];
      at = 115; l103 = rt.sequence_build(l102);
      at = 116; l104 = K[46];
      at = 117; {
        const s117 = l104, c117 = Array.isArray(s117) ? s117.length : Number(rt.array_count(s117));
        if (c117 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i117 = 0; i117 < c117; i117++) {
          l105 = BigInt(i117); l106 = Array.isArray(s117) ? s117[i117] : rt.array_nth(s117, i117);
          at = 118; l107 = K[47];
          at = 119; l108 = rt.ge(l99, l107);
          at = 120; if (rt.truthy(l108)) {
            at = 121; l110 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 122; l109 = l110;
          } else {
            at = 123; l111 = K[48];
            at = 124; l109 = l111;
          }
          at = 125; l112 = K[49];
          at = 126; l113 = K[50];
          at = 127; l114 = rt.eq(l112, l113);
          at = 128; l115 = K[51];
          at = 129; l116 = rt.and(l115, l114);
          at = 130; l117 = K[52];
          at = 131; l118 = rt.eq(l99, l117);
          at = 132; l119 = rt.and(l116, l118);
          at = 133; l120 = K[53];
          at = 134; l121 = rt.or(l120, l119);
          at = 135; l122 = K[54];
          at = 136; l123 = K[55];
          at = 137; l124 = rt.eq(l122, l123);
          at = 138; l125 = K[56];
          at = 139; l126 = rt.and(l125, l124);
          at = 140; l127 = K[57];
          at = 141; l128 = rt.eq(l99, l127);
          at = 142; l129 = rt.and(l126, l128);
          at = 143; l130 = rt.or(l121, l129);
          at = 144; if (rt.truthy(l130)) {
            at = 145; l132 = K[58];
            at = 146; l131 = l132;
          } else {
            at = 147; l133 = K[59];
            at = 148; l134 = rt.add(l133, l106);
            at = 149; l135 = input.t;
            at = 150; l136 = rt.add(l134, l135);
            at = 151; store(rt, l103, l101, l136);
            at = 152; l137 = K[60];
            at = 153; l138 = rt.add(l101, l137);
            at = 154; l101 = l138;
            at = 155; l139 = K[61];
            at = 156; l131 = l139;
          }
          at = 157; l140 = K[62];
          at = 158; l141 = rt.add(l99, l140);
          at = 159; l99 = l141;
        }
      }
      at = 160; l142 = K[63];
      at = 161; l143 = rt.sequence_slice(l103, l142, l101);
      at = 162; l144 = rt.sequence_concat(l143);
      at = 163; l145 = rt.sequence_concat([l50], [l97], [l144]);
      at = 164; l3 = l145;
    } else {
      at = 165; l146 = K[64];
      at = 166; l147 = l146;
      at = 167; l148 = K[65];
      at = 168; l149 = l148;
      at = 169; l150 = K[66];
      at = 170; l151 = rt.sequence_build(l150);
      at = 171; l152 = K[67];
      at = 172; {
        const s172 = l152, c172 = Array.isArray(s172) ? s172.length : Number(rt.array_count(s172));
        if (c172 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i172 = 0; i172 < c172; i172++) {
          l153 = BigInt(i172); l154 = Array.isArray(s172) ? s172[i172] : rt.array_nth(s172, i172);
          at = 173; l155 = K[68];
          at = 174; l156 = rt.ge(l147, l155);
          at = 175; if (rt.truthy(l156)) {
            at = 176; l158 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 177; l157 = l158;
          } else {
            at = 178; l159 = K[69];
            at = 179; l157 = l159;
          }
          at = 180; l160 = K[70];
          at = 181; l161 = K[71];
          at = 182; l162 = rt.eq(l160, l161);
          at = 183; l163 = K[72];
          at = 184; l164 = rt.and(l163, l162);
          at = 185; l165 = K[73];
          at = 186; l166 = rt.eq(l147, l165);
          at = 187; l167 = rt.and(l164, l166);
          at = 188; l168 = K[74];
          at = 189; l169 = rt.or(l168, l167);
          at = 190; l170 = K[75];
          at = 191; l171 = K[76];
          at = 192; l172 = rt.eq(l170, l171);
          at = 193; l173 = K[77];
          at = 194; l174 = rt.and(l173, l172);
          at = 195; l175 = K[78];
          at = 196; l176 = rt.eq(l147, l175);
          at = 197; l177 = rt.and(l174, l176);
          at = 198; l178 = rt.or(l169, l177);
          at = 199; if (rt.truthy(l178)) {
            at = 200; l180 = K[79];
            at = 201; l179 = l180;
          } else {
            at = 202; l181 = K[80];
            at = 203; l182 = rt.add(l181, l154);
            at = 204; l183 = input.t;
            at = 205; l184 = rt.add(l182, l183);
            at = 206; store(rt, l151, l149, l184);
            at = 207; l185 = K[81];
            at = 208; l186 = rt.add(l149, l185);
            at = 209; l149 = l186;
            at = 210; l187 = K[82];
            at = 211; l179 = l187;
          }
          at = 212; l188 = K[83];
          at = 213; l189 = rt.add(l147, l188);
          at = 214; l147 = l189;
        }
      }
      at = 215; l190 = K[84];
      at = 216; l191 = rt.sequence_slice(l151, l190, l149);
      at = 217; l192 = rt.sequence_concat(l191);
      at = 218; l193 = K[85];
      at = 219; l194 = l193;
      at = 220; l195 = K[86];
      at = 221; l196 = l195;
      at = 222; l197 = K[87];
      at = 223; l198 = rt.sequence_build(l197);
      at = 224; l199 = K[88];
      at = 225; {
        const s225 = l199, c225 = Array.isArray(s225) ? s225.length : Number(rt.array_count(s225));
        if (c225 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i225 = 0; i225 < c225; i225++) {
          l200 = BigInt(i225); l201 = Array.isArray(s225) ? s225[i225] : rt.array_nth(s225, i225);
          at = 226; l202 = K[89];
          at = 227; l203 = rt.ge(l194, l202);
          at = 228; if (rt.truthy(l203)) {
            at = 229; l205 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 230; l204 = l205;
          } else {
            at = 231; l206 = K[90];
            at = 232; l204 = l206;
          }
          at = 233; l207 = K[91];
          at = 234; l208 = K[92];
          at = 235; l209 = rt.eq(l207, l208);
          at = 236; l210 = K[93];
          at = 237; l211 = rt.and(l210, l209);
          at = 238; l212 = K[94];
          at = 239; l213 = rt.eq(l194, l212);
          at = 240; l214 = rt.and(l211, l213);
          at = 241; l215 = K[95];
          at = 242; l216 = rt.or(l215, l214);
          at = 243; l217 = K[96];
          at = 244; l218 = K[97];
          at = 245; l219 = rt.eq(l217, l218);
          at = 246; l220 = K[98];
          at = 247; l221 = rt.and(l220, l219);
          at = 248; l222 = K[99];
          at = 249; l223 = rt.eq(l194, l222);
          at = 250; l224 = rt.and(l221, l223);
          at = 251; l225 = rt.or(l216, l224);
          at = 252; if (rt.truthy(l225)) {
            at = 253; l227 = K[100];
            at = 254; l226 = l227;
          } else {
            at = 255; l228 = K[101];
            at = 256; l229 = rt.add(l228, l201);
            at = 257; l230 = input.t;
            at = 258; l231 = rt.add(l229, l230);
            at = 259; store(rt, l198, l196, l231);
            at = 260; l232 = K[102];
            at = 261; l233 = rt.add(l196, l232);
            at = 262; l196 = l233;
            at = 263; l234 = K[103];
            at = 264; l226 = l234;
          }
          at = 265; l235 = K[104];
          at = 266; l236 = rt.add(l194, l235);
          at = 267; l194 = l236;
        }
      }
      at = 268; l237 = K[105];
      at = 269; l238 = rt.sequence_slice(l198, l237, l196);
      at = 270; l239 = rt.sequence_concat(l238);
      at = 271; l240 = K[106];
      at = 272; l241 = l240;
      at = 273; l242 = K[107];
      at = 274; l243 = l242;
      at = 275; l244 = K[108];
      at = 276; l245 = rt.sequence_build(l244);
      at = 277; l246 = K[109];
      at = 278; {
        const s278 = l246, c278 = Array.isArray(s278) ? s278.length : Number(rt.array_count(s278));
        if (c278 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i278 = 0; i278 < c278; i278++) {
          l247 = BigInt(i278); l248 = Array.isArray(s278) ? s278[i278] : rt.array_nth(s278, i278);
          at = 279; l249 = K[110];
          at = 280; l250 = rt.ge(l241, l249);
          at = 281; if (rt.truthy(l250)) {
            at = 282; l252 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 283; l251 = l252;
          } else {
            at = 284; l253 = K[111];
            at = 285; l251 = l253;
          }
          at = 286; l254 = K[112];
          at = 287; l255 = K[113];
          at = 288; l256 = rt.eq(l254, l255);
          at = 289; l257 = K[114];
          at = 290; l258 = rt.and(l257, l256);
          at = 291; l259 = K[115];
          at = 292; l260 = rt.eq(l241, l259);
          at = 293; l261 = rt.and(l258, l260);
          at = 294; l262 = K[116];
          at = 295; l263 = rt.or(l262, l261);
          at = 296; l264 = K[117];
          at = 297; l265 = K[118];
          at = 298; l266 = rt.eq(l264, l265);
          at = 299; l267 = K[119];
          at = 300; l268 = rt.and(l267, l266);
          at = 301; l269 = K[120];
          at = 302; l270 = rt.eq(l241, l269);
          at = 303; l271 = rt.and(l268, l270);
          at = 304; l272 = rt.or(l263, l271);
          at = 305; if (rt.truthy(l272)) {
            at = 306; l274 = K[121];
            at = 307; l273 = l274;
          } else {
            at = 308; l275 = K[122];
            at = 309; l276 = rt.add(l275, l248);
            at = 310; l277 = input.t;
            at = 311; l278 = rt.add(l276, l277);
            at = 312; store(rt, l245, l243, l278);
            at = 313; l279 = K[123];
            at = 314; l280 = rt.add(l243, l279);
            at = 315; l243 = l280;
            at = 316; l281 = K[124];
            at = 317; l273 = l281;
          }
          at = 318; l282 = K[125];
          at = 319; l283 = rt.add(l241, l282);
          at = 320; l241 = l283;
        }
      }
      at = 321; l284 = K[126];
      at = 322; l285 = rt.sequence_slice(l245, l284, l243);
      at = 323; l286 = rt.sequence_concat(l285);
      at = 324; l287 = rt.sequence_concat([l192], [l239], [l286]);
      at = 325; l3 = l287;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
