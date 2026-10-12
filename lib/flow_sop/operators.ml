let attr : Flow.Op.t = {
  name = "sop/attr"; ctx = Flow.Context.sop;
  signature = {pos = ["geometry", Flow.Ty.geometry; "attribute", Flow.Ty.Text];
    opt = []; rest = None; kw = []};
  out = (fun _ -> Flow.Ty.Array Flow.Ty.Vec3); any_num = false; choices = [];
  shape = Flow.Op.Struct {splice = false}; live = false; category = "Attributes";
  arithmetic = None; packed_extension = None;
  check = (fun args -> match List.assoc "attribute" args with
    | Flow.Value.Text name when String.trim name <> "" -> ()
    | _ -> Flow.Value.fail "E_ATTR_NAME" "A point attribute needs a nonblank name.");
  body = (fun ~live:_ ~node:_ args -> Flow.Value.Struct ("sop/attr", Flow.Ty.Array Flow.Ty.Vec3, args));
}
let with_attr : Flow.Op.t = {
  attr with name = "sop/with_attr";
  signature = {attr.signature with pos = attr.signature.pos @ ["values", Flow.Ty.Array Flow.Ty.Vec3]};
  out = (fun _ -> Flow.Ty.geometry); shape = Flow.Op.Scalar;
  body = (fun ~live:_ ~node args -> node "sop/with_attr" args);
}
let delete_attr : Flow.Op.t = {
  attr with name="sop/delete_attr";
  signature={attr.signature with kw=["owner",Flow.Ty.Text]};
  out=(fun _ -> Flow.Ty.geometry); shape=Flow.Op.Scalar;
  choices=["owner",["point";"vertex";"primitive";"detail"]];
  check=(fun args ->
    (match List.assoc "attribute" args with
     | Flow.Value.Text pattern when String.trim pattern<>"" ->
         (match Rdk.Attribute_pattern.compile pattern with Ok _ -> ()
          | Error message -> Flow.Value.fail "E_ATTR_PATTERN" message)
     | _ -> Flow.Value.fail "E_ATTR_NAME" "An attribute pattern must be nonblank.");
    Option.iter (function Flow.Value.Text owner when List.mem owner ["point";"vertex";"primitive";"detail"] -> ()
      | _ -> Flow.Value.fail "E_ATTR_OWNER" "Attribute owner is point, vertex, primitive or detail.")
      (List.assoc_opt "owner" args));
  body=(fun ~live:_ ~node args -> node "sop/delete_attr" args);
}

let context_seed : Flow.Op.t = {
  attr with name="sop/context_seed";ctx=Flow.Context.value;category="Random";
  signature={pos=["namespace",Flow.Ty.Text];opt=[];rest=None;kw=[]};
  out=(fun _ -> Flow.Ty.Int);shape=Flow.Op.Scalar;
  check=(fun args -> match List.assoc "namespace" args with
    | Flow.Value.Text namespace when String.trim namespace<>"" -> ()
    | _ -> Flow.Value.fail "E_SEED_NAMESPACE" "A context seed namespace must be nonblank.");
  body=(fun ~live:_ ~node:_ _ -> Flow.Value.fail "E_NODE_CONTEXT" "Context seed is available inside a defnode body.");
}

let seed_for ~seed ~namespace ~label =
  let identity=ref 0xcbf29ce484222325L in
  String.iter (fun c -> identity:=Int64.mul (Int64.logxor !identity (Int64.of_int (Char.code c)))
    0x100000001b3L) (namespace^":"^label);
  let mixed=Int64.logxor seed (Int64.mul !identity 0x9e3779b97f4a7c15L) in
  Int64.to_int (Int64.logxor mixed (Int64.shift_right_logical mixed 32))

let all = Flow_ir.Operators.all @ [attr; with_attr; delete_attr; context_seed]
