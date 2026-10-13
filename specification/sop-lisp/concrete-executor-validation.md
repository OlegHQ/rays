# Concrete executor validation and Points measurements

The two one-point named-group Points rows first failed the unchanged2× gate.
Source tracing found that Executor.force prepared dynamic packed/Core/fallback
execution closures and an evaluator state for already-concrete records. Eval
then immediately returned those same records through its existing !is_live rule.

Executor now uses that same rule before dynamic setup. Compile qualification
still runs; Source/residual/nested live values retain their original execution
path. Common profile recording retains root/site/tier and two clock samples.
The added small check covers exact returned-object identity, nested signed-zero/
raw text values, unused resolver, unchanged supplied state, strict/reference
modes and the existing concrete invalid-frame boundary. All dynamic execution,
Core, Flow, SOP/graph/web/GPU, worker/CLI and API/dependency checks pass.

Request83851 EXIT0: /tmp/rays-concrete-executor-focused3-20261013.log.
Earlier55226/43666 EXIT1 retain only Line's intended CLI/catalog snapshot
differences; their functional checks passed. API snapshot remains unchanged.
Native integration request83712 also EXIT0:
 /tmp/rays-line-production-native-20261013.log.

## Fixed benchmark protocol

Apple M1 Macmini9,1,16GiB,arm64,macOS27.0.1 build26A434,OCaml5.3.0,
Dune dev,grain4096,domains1/4,median3 fresh cold-session samples.
All three agents acknowledged pause before each timing window and were released
after terminal results; desktop/VM background processes remained running.
Whole Context creation and cook are timed; session creation/close and major GC
are outside the clock. Byte-exact native/reference/domain preflights run first.
Allocation/promoted/major counters measure the initial domain.

Native points has a hard maximum50. Aggregate means20,000 independent50-point
cold cooks (1M total), never a single1M geometry. The complementary small-count
table uses1/7/50 points and1000 cold sessions. No count limit, row set, threshold
or body callback changed. Original failures remain in the complete tables.

Before aggregate97105 EXIT0 and micro16504 EXIT2:
 /tmp/rays-points-aggregate-before-20261013.log
 /tmp/rays-points-micro-before-20261013.log
After aggregate80848 EXIT0 and micro91572 EXIT0:
 /tmp/rays-points-aggregate-concrete-after-20261013.log
 /tmp/rays-points-micro-concrete-after-20261013.log

All12 aggregate and36 small-count rows now pass. Concrete-path allocation drops
1536 bytes/cook for empty/blank-group recipes and2048 for named-group recipes.
Wall-time changes are modest; maximum after ratios are1.8258339810115973 and
1.9819395082323927. Raw logs retain batch seconds and promoted/major words;
ratios below use the unrounded timing predicate, with no failed-row filtering.

## All12 aggregate rows

| Case | Domains | Native seconds/cook before | Lisp seconds/cook before | Ratio before | Native seconds/cook after | Lisp seconds/cook after | Ratio after | Lisp bytes/cook before → after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| count=50/empty/default | 1 | 0.000003679204 | 0.000005991256 | 1.628410998140192 | 0.000003701949 | 0.000005909693 | 1.5963734374094325 PASS | 23440.018 → 21904.018 |
| count=50/empty/default | 4 | 0.000003903794 | 0.000006358302 | 1.6287491526044815 | 0.000003919303 | 0.000006224108 | 1.5880647859478367 PASS | 23672.018 → 22136.018 |
| count=50/empty/custom | 1 | 0.000003686500 | 0.000006320798 | 1.7145799783990738 | 0.000003694248 | 0.000006078553 | 1.6454100730567673 PASS | 23448.018 → 21912.018 |
| count=50/empty/custom | 4 | 0.000004028451 | 0.000006437850 | 1.5980954691934153 | 0.000004032803 | 0.000006248498 | 1.5494182609312555 PASS | 23680.018 → 22144.018 |
| count=50/blank/default | 1 | 0.000003641307 | 0.000006399858 | 1.7575714917090897 | 0.000003595757 | 0.000006060195 | 1.6853736647725388 PASS | 23464.018 → 21928.018 |
| count=50/blank/default | 4 | 0.000003992045 | 0.000006490254 | 1.6257969343968084 | 0.000003931546 | 0.000006232893 | 1.5853542428487395 PASS | 23696.018 → 22160.018 |
| count=50/blank/custom | 1 | 0.000003727150 | 0.000006384897 | 1.7130776316462821 | 0.000003634441 | 0.000006114697 | 1.6824313908140607 PASS | 23472.018 → 21936.018 |
| count=50/blank/custom | 4 | 0.000004065406 | 0.000006538653 | 1.6083640490160718 | 0.000003999102 | 0.000006253600 | 1.5637510470416045 PASS | 23704.018 → 22168.018 |
| count=50/trim_named/default | 1 | 0.000003960359 | 0.000007559252 | 1.9087288806480063 | 0.000003911197 | 0.000007141197 | 1.8258339810115973 PASS | 26808.018 → 24760.018 |
| count=50/trim_named/default | 4 | 0.000004364693 | 0.000007611096 | 1.7437871616362182 | 0.000004269600 | 0.000007238257 | 1.6953009828009828 PASS | 27040.018 → 24992.018 |
| count=50/trim_named/custom | 1 | 0.000004083657 | 0.000007528102 | 1.8434706710026214 | 0.000004019904 | 0.000007218802 | 1.7957647072778711 PASS | 26816.018 → 24768.018 |
| count=50/trim_named/custom | 4 | 0.000004432309 | 0.000007615554 | 1.7181913294191373 | 0.000004324007 | 0.000007346010 | 1.6988895137900994 PASS | 27048.018 → 25000.018 |

## All36 small-count rows

| Case | Domains | Native seconds/cook before | Lisp seconds/cook before | Ratio before | Native seconds/cook after | Lisp seconds/cook after | Ratio after | Lisp bytes/cook before → after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| count=1/empty/default | 1 | 0.000003004074 | 0.000005424976 | 1.8058730158730159 | 0.000002985001 | 0.000005326033 | 1.7842651757188499 PASS | 21480.360 → 19944.360 |
| count=1/empty/default | 4 | 0.000003254175 | 0.000005703926 | 1.7528024031064546 | 0.000003262043 | 0.000005612135 | 1.7204356088291186 PASS | 21712.360 → 20176.360 |
| count=1/empty/custom | 1 | 0.000003010988 | 0.000005618095 | 1.8658642806239607 | 0.000002974033 | 0.000005499125 | 1.8490460157126825 PASS | 21488.360 → 19952.360 |
| count=1/empty/custom | 4 | 0.000003318071 | 0.000005735159 | 1.7284615937342818 | 0.000003309965 | 0.000005624056 | 1.6991284304545127 PASS | 21720.360 → 20184.360 |
| count=1/blank/default | 1 | 0.000002928972 | 0.000005627871 | 1.9214489214489214 | 0.000002912045 | 0.000005537033 | 1.901424594727362 PASS | 21496.360 → 19960.360 |
| count=1/blank/default | 4 | 0.000003246069 | 0.000005753040 | 1.7723099522585384 | 0.000003350019 | 0.000005527973 | 1.6501316632268166 PASS | 21728.360 → 20192.360 |
| count=1/blank/custom | 1 | 0.000002975941 | 0.000005625010 | 1.8901618330395771 | 0.000003001928 | 0.000005625010 | 1.8737987451354141 PASS | 21512.360 → 19976.360 |
| count=1/blank/custom | 4 | 0.000003341198 | 0.000005815029 | 1.7404024546881689 | 0.000003329039 | 0.000005624056 | 1.6893933968344912 PASS | 21744.360 → 20208.360 |
| count=1/trim_named/default | 1 | 0.000003194094 | 0.000006506205 | 2.0369485705755022 FAIL | 0.000003225088 | 0.000006307125 | 1.9556442670215126 PASS | 24832.360 → 22784.360 |
| count=1/trim_named/default | 4 | 0.000003501892 | 0.000006568193 | 1.8756127450980393 | 0.000003458977 | 0.000006426811 | 1.8580093741384065 PASS | 25064.360 → 23016.360 |
| count=1/trim_named/custom | 1 | 0.000003315926 | 0.000006636143 | 2.0012942191544436 FAIL | 0.000003287077 | 0.000006514788 | 1.9819395082323927 PASS | 24856.360 → 22808.360 |
| count=1/trim_named/custom | 4 | 0.000003525972 | 0.000006666183 | 1.8905943606734734 | 0.000003540039 | 0.000006729841 | 1.9010641163793103 PASS | 25088.360 → 23040.360 |
| count=7/empty/default | 1 | 0.000002939939 | 0.000005607128 | 1.9072256913470116 | 0.000002951145 | 0.000005545855 | 1.8792211989012764 PASS | 21720.360 → 20184.360 |
| count=7/empty/default | 4 | 0.000003267050 | 0.000005731106 | 1.7542144056046121 | 0.000003377914 | 0.000005650043 | 1.6726425748164879 PASS | 21952.360 → 20416.360 |
| count=7/empty/custom | 1 | 0.000003072023 | 0.000005707026 | 1.8577415599534342 | 0.000003013849 | 0.000005584002 | 1.8527806344434776 PASS | 21728.360 → 20192.360 |
| count=7/empty/custom | 4 | 0.000003362894 | 0.000005810022 | 1.7276852180077986 | 0.000003383875 | 0.000005604029 | 1.6560980765165927 PASS | 21960.360 → 20424.360 |
| count=7/blank/default | 1 | 0.000002985001 | 0.000005689144 | 1.9059105431309904 | 0.000002943039 | 0.000005533934 | 1.880346727154893 PASS | 21736.360 → 20200.360 |
| count=7/blank/default | 4 | 0.000003309011 | 0.000005800962 | 1.7530801930974853 | 0.000003310204 | 0.000005629063 | 1.7005185825410545 PASS | 21968.360 → 20432.360 |
| count=7/blank/custom | 1 | 0.000003026962 | 0.000005726099 | 1.8916981726528039 | 0.000003072023 | 0.000005518913 | 1.7965075669383004 PASS | 21752.360 → 20216.360 |
| count=7/blank/custom | 4 | 0.000003386974 | 0.000005821943 | 1.7189215824299591 | 0.000003409863 | 0.000005665064 | 1.6613760313242902 PASS | 21984.360 → 20448.360 |
| count=7/trim_named/default | 1 | 0.000003347874 | 0.000006616831 | 1.976427859279305 | 0.000003310919 | 0.000006346941 | 1.9169727082883272 PASS | 25072.360 → 23024.360 |
| count=7/trim_named/default | 4 | 0.000003521919 | 0.000006774187 | 1.9234362307067425 | 0.000003529787 | 0.000006520987 | 1.8474164133738602 PASS | 25304.360 → 23256.360 |
| count=7/trim_named/custom | 1 | 0.000003439188 | 0.000006700039 | 1.9481455805892547 | 0.000003351927 | 0.000006388903 | 1.9060388363325984 PASS | 25096.360 → 23048.360 |
| count=7/trim_named/custom | 4 | 0.000003594160 | 0.000006773949 | 1.884709784411277 | 0.000003609896 | 0.000006692886 | 1.8540387028597847 PASS | 25328.360 → 23280.360 |
| count=50/empty/default | 1 | 0.000003389835 | 0.000005922794 | 1.7472218314812209 | 0.000003326893 | 0.000005810976 | 1.7466676221871864 PASS | 23440.360 → 21904.360 |
| count=50/empty/default | 4 | 0.000003660202 | 0.000006048918 | 1.6526185513288172 | 0.000003705025 | 0.000005853176 | 1.5797940797940797 PASS | 23672.360 → 22136.360 |
| count=50/empty/custom | 1 | 0.000003427982 | 0.000005932093 | 1.7304910279593824 | 0.000003445864 | 0.000005787849 | 1.6796512834705597 PASS | 23448.360 → 21912.360 |
| count=50/empty/custom | 4 | 0.000003789902 | 0.000006057978 | 1.5984524408656267 | 0.000003821850 | 0.000005918980 | 1.5487211478477854 PASS | 23680.360 → 22144.360 |
| count=50/blank/default | 1 | 0.000003355980 | 0.000005918980 | 1.763711281614095 | 0.000003316879 | 0.000005773783 | 1.7407274295572168 PASS | 23464.360 → 21928.360 |
| count=50/blank/default | 4 | 0.000003691912 | 0.000005978107 | 1.6192444300936391 | 0.000003703833 | 0.000005905151 | 1.5943353717412294 PASS | 23696.360 → 22160.360 |
| count=50/blank/custom | 1 | 0.000003477097 | 0.000006015062 | 1.7299094898518925 | 0.000003432035 | 0.000006005049 | 1.7497047585967349 PASS | 23472.360 → 21936.360 |
| count=50/blank/custom | 4 | 0.000003749132 | 0.000006090879 | 1.624610492845787 | 0.000003802061 | 0.000005922079 | 1.557597040195648 PASS | 23704.360 → 22168.360 |
| count=50/trim_named/default | 1 | 0.000003746986 | 0.000007085085 | 1.890875540850089 | 0.000003662109 | 0.000006942987 | 1.8958984375000001 PASS | 26808.360 → 24760.360 |
| count=50/trim_named/default | 4 | 0.000004004955 | 0.000007091999 | 1.7708060483390879 | 0.000004060030 | 0.000006973982 | 1.7177168359856716 PASS | 27040.360 → 24992.360 |
| count=50/trim_named/custom | 1 | 0.000003872156 | 0.000007040977 | 1.8183609383658641 | 0.000003842115 | 0.000006899118 | 1.7956562209121936 PASS | 26816.360 → 24768.360 |
| count=50/trim_named/custom | 4 | 0.000004106998 | 0.000007193089 | 1.751422268663648 | 0.000004130125 | 0.000006950140 | 1.6827916642613865 PASS | 27048.360 → 25000.360 |

These measurements qualify the Points draft's recipe; it remains registered
natively until its separate whole-port production integration is accepted.
This shared executor change accepts no additional whole port or milestone.
