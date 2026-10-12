let checked = function Ok value->value|Error (d:Flow.Diagnostic.t)->Flow.Value.fail d.code d.message
let type_argument args = match List.find_opt (fun (name,_,_)->name="type") args with
  | None -> "vec3"
  | Some (_,_,Some(Param.Text_value kind)) -> ignore(checked(Attribute_kernel.value_type kind));kind
  | Some _ -> Flow.Value.fail "E_ATTR_TYPE" "Attribute type must be a literal storage type."
let attribute_type args = checked(Attribute_kernel.value_type (type_argument args))
let validate_args args =
  (match List.assoc "attribute" args with
   | Flow.Value.Text name when String.trim name<>""->()
   | _ -> Flow.Value.fail "E_ATTR_NAME" "An attribute needs a nonblank name.");
  Option.iter (function Flow.Value.Text owner->ignore(checked(Attribute_kernel.owner owner))
    | _->Flow.Value.fail "E_ATTR_OWNER" "Attribute owner must be text.") (List.assoc_opt "owner" args);
  Option.iter (function Flow.Value.Text kind->ignore(checked(Attribute_kernel.value_type kind))
    | _->Flow.Value.fail "E_ATTR_TYPE" "Attribute type must be text.") (List.assoc_opt "type" args)
let attr : Flow.Op.t = {
  name = "sop/attr"; ctx = Flow.Context.sop;
  signature = {pos = ["geometry", Flow.Ty.geometry; "attribute", Flow.Ty.Text];
    opt = []; rest = None; kw = ["owner",Flow.Ty.Text;"type",Flow.Ty.Text]};
  out = (fun _ -> Flow.Ty.Array Flow.Ty.Vec3); out_args=Some attribute_type; any_num = false; choices = [];
  shape = Flow.Op.Struct {splice = false}; live = false; category = "Attributes";
  arithmetic = None; packed_extension = None;
  check = validate_args;
  body = (fun ~live:_ ~node:_ args ->
    let named=List.map(fun(name,v)->name,Flow.Value.ty_of v,
      (match v with Flow.Value.Text text->Some(Param.Text_value text)|_->None))args in
    let ty=attribute_type named in
    match ty with
    | Flow.Ty.Record fields -> Flow.Value.Record (List.map(fun(name,ty)->
        name,Flow.Value.Struct("sop/attr",ty,args@["component",Flow.Value.Text name]))fields)
    | _ -> Flow.Value.Struct ("sop/attr",ty,args));
}
let with_attr : Flow.Op.t = {
  attr with name = "sop/with_attr";
  signature = {attr.signature with pos = attr.signature.pos @ ["values", Flow.Ty.Any]};
  out = (fun _ -> Flow.Ty.geometry); out_args=Some(fun args->
    let ty=attribute_type args in
    Option.iter(fun(_,actual,_)->if not(Flow.Ty.fits actual ty)then
      Flow.Value.fail "E_ATTR_TYPE" ("Attribute values require "^Flow.Ty.to_string ty^"."))
      (List.find_opt(fun(name,_,_)->name="values")args);
    Flow.Ty.geometry); shape = Flow.Op.Scalar;
  body = (fun ~live:_ ~node args -> node "sop/with_attr" args);
}
let has_attr : Flow.Op.t = {
  attr with name="sop/has_attr";out=(fun _->Flow.Ty.Bool);
  out_args=Some(fun args->
    if List.exists(fun(name,_,_)->name="type")args then ignore(attribute_type args);
    Flow.Ty.Bool);
  body=(fun ~live:_ ~node:_ args->Flow.Value.Source("sop/has_attr",Flow.Ty.Bool,args));
}
let delete_attr : Flow.Op.t = {
  attr with name="sop/delete_attr";
  signature={attr.signature with kw=["owner",Flow.Ty.Text]};
  out=(fun _ -> Flow.Ty.geometry); out_args=None; shape=Flow.Op.Scalar;
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
  out=(fun _ -> Flow.Ty.Int);out_args=None;shape=Flow.Op.Scalar;
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

let all = Flow_ir.Operators.all @ [attr; with_attr; has_attr; delete_attr; context_seed]
