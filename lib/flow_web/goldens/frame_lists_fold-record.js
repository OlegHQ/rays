// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, 0, 1, 0n, 0n, [0n, 1n, 2n, 3n], 4096n, 0n, 1n, 1n, 0, 1, 0n, 0n, [0n, 1n, 2n, 3n], 4096n, 0n, 1n, 1n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61, l62, l63;
  let l64, l65, l66, l67, l68, l69, l70, l71, l72, l73, l74, l75, l76, l77, l78, l79;
  let l80, l81, l82, l83, l84, l85, l86, l87, l88, l89, l90, l91, l92, l93;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l3 = K[1];
      at = 5; l4 = l3;
      at = 6; l5 = K[2];
      at = 7; l6 = l5;
      at = 8; l7 = K[3];
      at = 9; l8 = l7;
      at = 10; l9 = K[4];
      at = 11; l10 = l9;
      at = 12; l11 = K[5];
      at = 13; {
        const s13 = l11, c13 = Array.isArray(s13) ? s13.length : Number(rt.array_count(s13));
        if (c13 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i13 = 0; i13 < c13; i13++) {
          l12 = BigInt(i13); l13 = Array.isArray(s13) ? s13[i13] : rt.array_nth(s13, i13);
          at = 14; l14 = K[6];
          at = 15; l15 = rt.ge(l8, l14);
          at = 16; if (rt.truthy(l15)) {
            at = 17; l17 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 18; l16 = l17;
          } else {
            at = 19; l18 = K[7];
            at = 20; l16 = l18;
          }
          at = 21; l19 = input.t;
          at = 22; l20 = rt.add(l4, l19);
          at = 23; l21 = rt.coerce("float", l4);
          at = 24; l22 = rt.equal(l4, l21);
          at = 25; if (rt.truthy(l22)) {
            at = 26; l24 = rt.coerce("float", l20);
            at = 27; l23 = l24;
          } else {
            at = 28; l25 = rt.coerce("int", l20);
            at = 29; l23 = l25;
          }
          at = 30; l26 = rt.coerce("float", l6);
          at = 31; l27 = rt.equal(l6, l26);
          at = 32; if (rt.truthy(l27)) {
            at = 33; l29 = rt.coerce("float", l4);
            at = 34; l28 = l29;
          } else {
            at = 35; l30 = rt.coerce("int", l4);
            at = 36; l28 = l30;
          }
          at = 37; l31 = rt.coerce("float", l4);
          at = 38; l32 = rt.equal(l4, l31);
          at = 39; if (rt.truthy(l32)) {
            at = 40; l34 = rt.coerce("float", l23);
            at = 41; l33 = l34;
          } else {
            at = 42; l35 = rt.coerce("int", l23);
            at = 43; l33 = l35;
          }
          at = 44; l36 = rt.coerce("float", l6);
          at = 45; l37 = rt.equal(l6, l36);
          at = 46; if (rt.truthy(l37)) {
            at = 47; l39 = rt.coerce("float", l28);
            at = 48; l38 = l39;
          } else {
            at = 49; l40 = rt.coerce("int", l28);
            at = 50; l38 = l40;
          }
          at = 51; l41 = l33;
          at = 52; l42 = l38;
          at = 53; l4 = l41;
          at = 54; l6 = l42;
          at = 55; l43 = K[8];
          at = 56; l44 = rt.add(l10, l43);
          at = 57; l10 = l44;
          at = 58; l45 = K[9];
          at = 59; l46 = rt.add(l8, l45);
          at = 60; l8 = l46;
        }
      }
      at = 118; l91 = l4;
      at = 120; l92 = l6;
    } else {
      at = 61; l47 = K[10];
      at = 62; l48 = l47;
      at = 63; l49 = K[11];
      at = 64; l50 = l49;
      at = 65; l51 = K[12];
      at = 66; l52 = l51;
      at = 67; l53 = K[13];
      at = 68; l54 = l53;
      at = 69; l55 = K[14];
      at = 70; {
        const s70 = l55, c70 = Array.isArray(s70) ? s70.length : Number(rt.array_count(s70));
        if (c70 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i70 = 0; i70 < c70; i70++) {
          l56 = BigInt(i70); l57 = Array.isArray(s70) ? s70[i70] : rt.array_nth(s70, i70);
          at = 71; l58 = K[15];
          at = 72; l59 = rt.ge(l52, l58);
          at = 73; if (rt.truthy(l59)) {
            at = 74; l61 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 75; l60 = l61;
          } else {
            at = 76; l62 = K[16];
            at = 77; l60 = l62;
          }
          at = 78; l63 = input.t;
          at = 79; l64 = rt.add(l48, l63);
          at = 80; l65 = rt.coerce("float", l48);
          at = 81; l66 = rt.equal(l48, l65);
          at = 82; if (rt.truthy(l66)) {
            at = 83; l68 = rt.coerce("float", l64);
            at = 84; l67 = l68;
          } else {
            at = 85; l69 = rt.coerce("int", l64);
            at = 86; l67 = l69;
          }
          at = 87; l70 = rt.coerce("float", l50);
          at = 88; l71 = rt.equal(l50, l70);
          at = 89; if (rt.truthy(l71)) {
            at = 90; l73 = rt.coerce("float", l48);
            at = 91; l72 = l73;
          } else {
            at = 92; l74 = rt.coerce("int", l48);
            at = 93; l72 = l74;
          }
          at = 94; l75 = rt.coerce("float", l48);
          at = 95; l76 = rt.equal(l48, l75);
          at = 96; if (rt.truthy(l76)) {
            at = 97; l78 = rt.coerce("float", l67);
            at = 98; l77 = l78;
          } else {
            at = 99; l79 = rt.coerce("int", l67);
            at = 100; l77 = l79;
          }
          at = 101; l80 = rt.coerce("float", l50);
          at = 102; l81 = rt.equal(l50, l80);
          at = 103; if (rt.truthy(l81)) {
            at = 104; l83 = rt.coerce("float", l72);
            at = 105; l82 = l83;
          } else {
            at = 106; l84 = rt.coerce("int", l72);
            at = 107; l82 = l84;
          }
          at = 108; l85 = l77;
          at = 109; l86 = l82;
          at = 110; l48 = l85;
          at = 111; l50 = l86;
          at = 112; l87 = K[17];
          at = 113; l88 = rt.add(l54, l87);
          at = 114; l54 = l88;
          at = 115; l89 = K[18];
          at = 116; l90 = rt.add(l52, l89);
          at = 117; l52 = l90;
        }
      }
      at = 119; l91 = l48;
      at = 121; l92 = l50;
    }
    at = 122; l93 = new Map([["x", l91], ["y", l92]]);
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l93;
}
