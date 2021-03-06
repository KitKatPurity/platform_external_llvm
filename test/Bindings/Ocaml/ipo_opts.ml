(* RUN: %ocamlopt -warn-error A llvm.cmxa llvm_ipo.cmxa llvm_target.cmxa %s -o %t
 * RUN: %t %t.bc
 * XFAIL: vg_leak
 *)

(* Note: It takes several seconds for ocamlopt to link an executable with
         libLLVMCore.a, so it's better to write a big test than a bunch of
         little ones. *)

open Llvm
open Llvm_ipo
open Llvm_target

let context = global_context ()
let void_type = Llvm.void_type context
let i8_type = Llvm.i8_type context

(* Tiny unit test framework - really just to help find which line is busted *)
let print_checkpoints = false

let suite name f =
  if print_checkpoints then
    prerr_endline (name ^ ":");
  f ()


(*===-- Fixture -----------------------------------------------------------===*)

let filename = Sys.argv.(1)
let m = create_module context filename


(*===-- Transforms --------------------------------------------------------===*)

let test_transforms () =
  let (++) x f = ignore (f x); x in

  let fty = function_type i8_type [| |] in
  let fn = define_function "fn" fty m in
  let fn2 = define_function "fn2" fty m in begin
      ignore (build_ret (const_int i8_type 4) (builder_at_end context (entry_block fn)));
      let b = builder_at_end context  (entry_block fn2) in
      ignore (build_ret (build_call fn [| |] "" b) b);
  end;

  let td = DataLayout.create (target_triple m) in
  
  ignore (PassManager.create ()
           ++ DataLayout.add td
           ++ add_argument_promotion
           ++ add_constant_merge
           ++ add_dead_arg_elimination
           ++ add_function_attrs
           ++ add_function_inlining
           ++ add_global_dce
           ++ add_global_optimizer
           ++ add_ipc_propagation
           ++ add_prune_eh
           ++ add_ipsccp
           ++ add_internalize
           ++ add_strip_dead_prototypes
           ++ add_strip_symbols
           ++ PassManager.run_module m
           ++ PassManager.dispose);

  DataLayout.dispose td


(*===-- Driver ------------------------------------------------------------===*)

let _ =
  suite "transforms" test_transforms;
  dispose_module m
