// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
const store = (rt, s, index, value) => {
  const i = Number(rt.coerce("int", index));
  if (s instanceof rt.PArray) {
    const n = s.data.length / s.width;
    if (i < 0 || i >= n) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
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
  K ??= [-1000, 12n, 12n, 12n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n, 11n], [1n, 2n, 4n, 8n, 16n, 32n, 64n, 128n, 256n, 512n, 1024n, 2048n], 12n, 2n, 12n, 1n, 0n, 12n, 12n, true, false, 1n, 0n, 1n, 0n, 0n, 0n, 12n, 0n, 12n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n, 11n], 12n, 12n, 12n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n, 11n], [1n, 2n, 4n, 8n, 16n, 32n, 64n, 128n, 256n, 512n, 1024n, 2048n], 12n, 2n, 12n, 1n, 0n, 12n, 12n, true, false, 1n, 0n, 1n, 0n, 0n, 0n, 12n, 0n, 12n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n, 8n, 9n, 10n, 11n]];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61, l62, l63;
  let l64, l65, l66, l67, l68, l69, l70, l71, l72, l73, l74, l75, l76, l77, l78, l79;
  let l80, l81, l82, l83, l84, l85, l86, l87, l88, l89, l90, l91, l92, l93, l94, l95;
  let l96, l97, l98, l99, l100, l101, l102, l103, l104, l105, l106, l107, l108, l109, l110, l111;
  let l112, l113, l114, l115, l116, l117, l118, l119, l120, l121, l122, l123, l124, l125, l126, l127;
  let l128, l129, l130, l131, l132, l133, l134, l135, l136, l137, l138, l139, l140, l141, l142, l143;
  let l144, l145, l146, l147, l148, l149, l150, l151, l152, l153, l154, l155, l156, l157;
  let at = 0;
  const calls = new Int32Array(2);
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; calls[0] = 0;
      at = 5; l4 = K[1];
      at = 6; l5 = rt.sequence_build(l4);
      at = 7; l6 = K[2];
      at = 8; l7 = rt.sequence_build(l6);
      at = 9; l8 = l7;
      at = 10; l9 = K[3];
      at = 11; l10 = rt.sequence_build(l9);
      at = 12; l11 = l10;
      at = 13; l12 = K[4];
      at = 14; {
        const s14 = l12, c14 = Array.isArray(s14) ? s14.length : Number(rt.array_count(s14));
        if (c14 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i14 = 0; i14 < c14; i14++) {
          l13 = BigInt(i14); l14 = Array.isArray(s14) ? s14[i14] : rt.array_nth(s14, i14);
          at = 15; l15 = BigInt(calls[0]++);
          at = 16; l16 = input.t;
          at = 17; l17 = rt.sub(l16, l14);
          at = 18; l18 = rt.float(l17);
          at = 19; store(rt, l5, l13, l18);
          at = 20; store(rt, l8, l13, l13);
        }
      }
      at = 21; l19 = K[5];
      at = 22; {
        const s22 = l19, c22 = Array.isArray(s22) ? s22.length : Number(rt.array_count(s22));
        if (c22 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i22 = 0; i22 < c22; i22++) {
          l20 = BigInt(i22); l21 = Array.isArray(s22) ? s22[i22] : rt.array_nth(s22, i22);
          at = 23; l22 = K[6];
          at = 24; l23 = rt.lt(l21, l22);
          at = 25; if (rt.truthy(l23)) {
            at = 26; l25 = K[7];
            at = 27; l26 = rt.mul(l21, l25);
            at = 28; l27 = K[8];
            at = 29; l28 = rt.add(l27, l26);
            at = 30; l29 = K[9];
            at = 31; l30 = rt.sub(l28, l29);
            at = 32; l31 = rt.int_div(l30, l26);
            at = 33; l32 = K[10];
            at = 34; {
              const f34 = rt.coerce("int", l32), e34 = rt.coerce("int", l31), n34 = e34 > f34 ? e34 - f34 : 0n;
              if (n34 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
              l33 = n34;
              for (let i34 = 0, c34 = Number(n34); i34 < c34; i34++) {
                const j34 = BigInt(i34); l34 = j34; l35 = f34 + j34;
                at = 35; l36 = rt.mul(l35, l26);
                at = 36; l37 = rt.add(l36, l21);
                at = 37; l38 = K[11];
                at = 38; l39 = rt.min(l37, l38);
                at = 39; l40 = rt.add(l36, l26);
                at = 40; l41 = K[12];
                at = 41; l42 = rt.min(l40, l41);
                at = 42; l43 = l36;
                at = 43; l44 = l39;
                at = 44; {
                  const f44 = rt.coerce("int", l36), e44 = rt.coerce("int", l42), n44 = e44 > f44 ? e44 - f44 : 0n;
                  if (n44 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
                  l45 = n44;
                  for (let i44 = 0, c44 = Number(n44); i44 < c44; i44++) {
                    const j44 = BigInt(i44); l46 = j44; l47 = f44 + j44;
                    at = 45; l48 = rt.lt(l43, l39);
                    at = 46; if (rt.truthy(l48)) {
                      at = 47; l50 = rt.lt(l44, l42);
                      at = 48; if (rt.truthy(l50)) {
                        at = 49; l52 = rt.sequence_get(l8, l43);
                        at = 50; l53 = rt.sequence_get(l8, l44);
                        at = 51; l54 = rt.sequence_get(l5, l52);
                        at = 52; l55 = rt.sequence_get(l5, l53);
                        at = 53; l56 = rt.le(l54, l55);
                        at = 54; l51 = l56;
                      } else {
                        at = 55; l57 = K[13];
                        at = 56; l51 = l57;
                      }
                      at = 57; l49 = l51;
                    } else {
                      at = 58; l58 = K[14];
                      at = 59; l49 = l58;
                    }
                    at = 60; if (rt.truthy(l49)) {
                      at = 61; l60 = rt.sequence_get(l8, l43);
                      at = 62; store(rt, l11, l47, l60);
                      at = 63; l61 = K[15];
                      at = 64; l62 = rt.add(l43, l61);
                      at = 65; l43 = l62;
                      at = 66; l63 = K[16];
                      at = 67; l59 = l63;
                    } else {
                      at = 68; l64 = rt.sequence_get(l8, l44);
                      at = 69; store(rt, l11, l47, l64);
                      at = 70; l65 = K[17];
                      at = 71; l66 = rt.add(l44, l65);
                      at = 72; l44 = l66;
                      at = 73; l67 = K[18];
                      at = 74; l59 = l67;
                    }
                  }
                }
              }
            }
            at = 75; l68 = l8;
            at = 76; l8 = l11;
            at = 77; l11 = l68;
            at = 78; l69 = K[19];
            at = 79; l24 = l69;
          } else {
            at = 80; l70 = K[20];
            at = 81; l24 = l70;
          }
        }
      }
      at = 82; l71 = K[21];
      at = 83; l72 = rt.sequence_build(l71);
      at = 84; l73 = K[22];
      at = 85; l74 = K[23];
      at = 86; {
        const f86 = rt.coerce("int", l73), e86 = rt.coerce("int", l74), n86 = e86 > f86 ? e86 - f86 : 0n;
        if (n86 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l75 = n86;
        for (let i86 = 0, c86 = Number(n86); i86 < c86; i86++) {
          const j86 = BigInt(i86); l76 = j86; l77 = f86 + j86;
          at = 87; l78 = rt.sequence_get(l8, l77);
          at = 88; l79 = K[24];
          at = 89; l80 = rt.sequence_get(l79, l78);
          at = 90; store(rt, l72, l77, l80);
        }
      }
      at = 91; l3 = l72;
    } else {
      at = 92; calls[1] = 0;
      at = 93; l81 = K[25];
      at = 94; l82 = rt.sequence_build(l81);
      at = 95; l83 = K[26];
      at = 96; l84 = rt.sequence_build(l83);
      at = 97; l85 = l84;
      at = 98; l86 = K[27];
      at = 99; l87 = rt.sequence_build(l86);
      at = 100; l88 = l87;
      at = 101; l89 = K[28];
      at = 102; {
        const s102 = l89, c102 = Array.isArray(s102) ? s102.length : Number(rt.array_count(s102));
        if (c102 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i102 = 0; i102 < c102; i102++) {
          l90 = BigInt(i102); l91 = Array.isArray(s102) ? s102[i102] : rt.array_nth(s102, i102);
          at = 103; l92 = BigInt(calls[1]++);
          at = 104; l93 = input.t;
          at = 105; l94 = rt.sub(l93, l91);
          at = 106; l95 = rt.float(l94);
          at = 107; store(rt, l82, l90, l95);
          at = 108; store(rt, l85, l90, l90);
        }
      }
      at = 109; l96 = K[29];
      at = 110; {
        const s110 = l96, c110 = Array.isArray(s110) ? s110.length : Number(rt.array_count(s110));
        if (c110 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i110 = 0; i110 < c110; i110++) {
          l97 = BigInt(i110); l98 = Array.isArray(s110) ? s110[i110] : rt.array_nth(s110, i110);
          at = 111; l99 = K[30];
          at = 112; l100 = rt.lt(l98, l99);
          at = 113; if (rt.truthy(l100)) {
            at = 114; l102 = K[31];
            at = 115; l103 = rt.mul(l98, l102);
            at = 116; l104 = K[32];
            at = 117; l105 = rt.add(l104, l103);
            at = 118; l106 = K[33];
            at = 119; l107 = rt.sub(l105, l106);
            at = 120; l108 = rt.int_div(l107, l103);
            at = 121; l109 = K[34];
            at = 122; {
              const f122 = rt.coerce("int", l109), e122 = rt.coerce("int", l108), n122 = e122 > f122 ? e122 - f122 : 0n;
              if (n122 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
              l110 = n122;
              for (let i122 = 0, c122 = Number(n122); i122 < c122; i122++) {
                const j122 = BigInt(i122); l111 = j122; l112 = f122 + j122;
                at = 123; l113 = rt.mul(l112, l103);
                at = 124; l114 = rt.add(l113, l98);
                at = 125; l115 = K[35];
                at = 126; l116 = rt.min(l114, l115);
                at = 127; l117 = rt.add(l113, l103);
                at = 128; l118 = K[36];
                at = 129; l119 = rt.min(l117, l118);
                at = 130; l120 = l113;
                at = 131; l121 = l116;
                at = 132; {
                  const f132 = rt.coerce("int", l113), e132 = rt.coerce("int", l119), n132 = e132 > f132 ? e132 - f132 : 0n;
                  if (n132 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
                  l122 = n132;
                  for (let i132 = 0, c132 = Number(n132); i132 < c132; i132++) {
                    const j132 = BigInt(i132); l123 = j132; l124 = f132 + j132;
                    at = 133; l125 = rt.lt(l120, l116);
                    at = 134; if (rt.truthy(l125)) {
                      at = 135; l127 = rt.lt(l121, l119);
                      at = 136; if (rt.truthy(l127)) {
                        at = 137; l129 = rt.sequence_get(l85, l120);
                        at = 138; l130 = rt.sequence_get(l85, l121);
                        at = 139; l131 = rt.sequence_get(l82, l129);
                        at = 140; l132 = rt.sequence_get(l82, l130);
                        at = 141; l133 = rt.le(l131, l132);
                        at = 142; l128 = l133;
                      } else {
                        at = 143; l134 = K[37];
                        at = 144; l128 = l134;
                      }
                      at = 145; l126 = l128;
                    } else {
                      at = 146; l135 = K[38];
                      at = 147; l126 = l135;
                    }
                    at = 148; if (rt.truthy(l126)) {
                      at = 149; l137 = rt.sequence_get(l85, l120);
                      at = 150; store(rt, l88, l124, l137);
                      at = 151; l138 = K[39];
                      at = 152; l139 = rt.add(l120, l138);
                      at = 153; l120 = l139;
                      at = 154; l140 = K[40];
                      at = 155; l136 = l140;
                    } else {
                      at = 156; l141 = rt.sequence_get(l85, l121);
                      at = 157; store(rt, l88, l124, l141);
                      at = 158; l142 = K[41];
                      at = 159; l143 = rt.add(l121, l142);
                      at = 160; l121 = l143;
                      at = 161; l144 = K[42];
                      at = 162; l136 = l144;
                    }
                  }
                }
              }
            }
            at = 163; l145 = l85;
            at = 164; l85 = l88;
            at = 165; l88 = l145;
            at = 166; l146 = K[43];
            at = 167; l101 = l146;
          } else {
            at = 168; l147 = K[44];
            at = 169; l101 = l147;
          }
        }
      }
      at = 170; l148 = K[45];
      at = 171; l149 = rt.sequence_build(l148);
      at = 172; l150 = K[46];
      at = 173; l151 = K[47];
      at = 174; {
        const f174 = rt.coerce("int", l150), e174 = rt.coerce("int", l151), n174 = e174 > f174 ? e174 - f174 : 0n;
        if (n174 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l152 = n174;
        for (let i174 = 0, c174 = Number(n174); i174 < c174; i174++) {
          const j174 = BigInt(i174); l153 = j174; l154 = f174 + j174;
          at = 175; l155 = rt.sequence_get(l85, l154);
          at = 176; l156 = K[48];
          at = 177; l157 = rt.sequence_get(l156, l155);
          at = 178; store(rt, l149, l154, l157);
        }
      }
      at = 179; l3 = l149;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
