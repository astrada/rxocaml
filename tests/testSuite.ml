open OUnit2

let tests =
  [TestObserver.suite;
  ]

let build_suite () =
  "RxOCaml test suite" >::: tests

let _ =
  let ounit_specs =
    ["-verbose",
       Arg.Unit (fun _ -> ()),
       "See oUnit doc";
     "-only-test",
       Arg.String (fun _ -> ()),
       "See oUnit doc";
     "-list-test",
       Arg.String (fun _ -> ()),
       "See oUnit doc"] in
  let _ =
    Arg.parse
      (ounit_specs)
      (fun _ -> ())
      ("Usage: " ^ Sys.argv.(0) ^ " [oUnit arguments]") in
  let _ =
    (* Reset argument counter, to let OUnit reparse arguments *)
    Arg.current := 0 in
  let suite = build_suite () in
    run_test_tt_main suite

