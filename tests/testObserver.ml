open OUnit2

let test_create_on_next _ =
  let next = ref false in
  let observer : int Rx.observer =
    Rx.Observer.create (fun x -> assert_equal 42 x; next := true) in
  let (on_next, _, on_completed) = observer in
  on_next 42;
  assert_equal true !next;
  on_completed ()

let test_create_on_next_has_errors _ =
  let failure = Failure "error" in
  let next = ref false in
  let observer : int Rx.observer =
    Rx.Observer.create (fun x -> assert_equal 42 x; next := true) in
  let (on_next, on_error, _) = observer in
  on_next 42;
  assert_equal true !next;
  try
    on_error failure;
    assert_failure "Should raise the exception"
  with e ->
    assert_equal failure e

let test_create_on_next_on_completed _ =
  let next = ref false in
  let completed = ref false in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, _, on_completed) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !completed;
  on_completed ();
  assert_equal true !completed

let test_create_on_next_on_completed_has_errors _ =
  let failure = Failure "error" in
  let next = ref false in
  let completed = ref false in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, on_error, on_completed) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !completed;
  begin try
    on_error failure;
    assert_failure "Should raise the exception"
  with e ->
    assert_equal failure e
  end;
  assert_equal false !completed

let test_create_on_next_on_error _ =
  let failure = Failure "error" in
  let next = ref false in
  let error = ref false in
  let observer = Rx.Observer.create
    ~on_error:(fun e -> assert_equal failure e; error := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, on_error, _) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !error;
  on_error failure;
  assert_equal true !error

let test_create_on_next_on_error_hit_completed _ =
  let failure = Failure "error" in
  let next = ref false in
  let error = ref false in
  let observer = Rx.Observer.create
    ~on_error:(fun e -> assert_equal failure e; error := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, _, on_completed) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !error;
  on_completed ();
  assert_equal false !error

let test_create_on_next_on_error_on_completed_1 _ =
  let failure = Failure "error" in
  let next = ref false in
  let error = ref false in
  let completed = ref false in
  let observer = Rx.Observer.create
    ~on_error:(fun e -> assert_equal failure e; error := true)
    ~on_completed:(fun () -> completed := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, _, on_completed) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !error;
  assert_equal false !completed;
  on_completed ();
  assert_equal true !completed;
  assert_equal false !error

let test_create_on_next_on_error_on_completed_2 _ =
  let failure = Failure "error" in
  let next = ref false in
  let error = ref false in
  let completed = ref false in
  let observer = Rx.Observer.create
    ~on_error:(fun e -> assert_equal failure e; error := true)
    ~on_completed:(fun () -> completed := true)
    (fun x -> assert_equal 42 x; next := true) in
  let (on_next, on_error, _) = observer in
  on_next 42;
  assert_equal true !next;
  assert_equal false !error;
  assert_equal false !completed;
  on_error failure;
  assert_equal true !error;
  assert_equal false !completed

let test_checked_observer_already_terminated_completed _ =
  let m = ref 0 in
  let n = ref 0 in
  let observer = Rx.Observer.create
      ~on_error:(fun _ -> assert_failure "Should not call on_error")
      ~on_completed:(fun () -> n := succ !n;)
      (fun _ -> m := succ !m)
    |> Rx.Observer.checked in
  let (on_next, on_error, on_completed) = observer in
  on_next 1;
  on_next 2;
  on_completed ();
  assert_raises
    (Failure "Observer has already terminated.")
    (fun () -> on_completed ());
  assert_raises
    (Failure "Observer has already terminated.")
    (fun () -> on_error (Failure "test"));
  assert_equal 2 !m;
  assert_equal 1 !n

let test_checked_observer_already_terminated_error _ =
  let m = ref 0 in
  let n = ref 0 in
  let observer = Rx.Observer.create
      ~on_error:(fun _ -> n := succ !n;)
      ~on_completed:(fun () -> assert_failure "Should not call on_completed")
      (fun _ -> m := succ !m)
    |> Rx.Observer.checked in
  let (on_next, on_error, on_completed) = observer in
  on_next 1;
  on_next 2;
  on_error (Failure "test");
  assert_raises
    (Failure "Observer has already terminated.")
    (fun () -> on_completed ());
  assert_raises
    (Failure "Observer has already terminated.")
    (fun () -> on_error (Failure "test2"));
  assert_equal 2 !m;
  assert_equal 1 !n

let test_checked_observer_reentrant_next _ =
  let n = ref 0 in
  let reentrant_thunk = ref (fun () -> ()) in
  let observer = Rx.Observer.create
      ~on_error:(fun _ -> assert_failure "Should not call on_error")
      ~on_completed:(fun () -> assert_failure "Should not call on_completed")
      (fun _ -> n := succ !n; !reentrant_thunk ())
    |> Rx.Observer.checked in
  let (on_next, on_error, on_completed) = observer in
  reentrant_thunk := (fun () ->
    assert_raises ~msg:"on_next"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_next 9);
    assert_raises ~msg:"on_error"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_error (Failure "test"));
    assert_raises ~msg:"on_completed"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_completed ())
  );
  on_next 1;
  assert_equal 1 !n

let test_checked_observer_reentrant_error _ =
  let n = ref 0 in
  let reentrant_thunk = ref (fun () -> ()) in
  let observer = Rx.Observer.create
      ~on_error:(fun _ -> n := succ !n; !reentrant_thunk ())
      ~on_completed:(fun () -> assert_failure "Should not call on_completed")
      (fun _ -> assert_failure "Should not call on_next")
    |> Rx.Observer.checked in
  let (on_next, on_error, on_completed) = observer in
  reentrant_thunk := (fun () ->
    assert_raises ~msg:"on_next"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_next 9);
    assert_raises ~msg:"on_error"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_error (Failure "test"));
    assert_raises ~msg:"on_completed"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_completed ())
  );
  on_error (Failure "test");
  assert_equal 1 !n

let test_checked_observer_reentrant_completed _ =
  let n = ref 0 in
  let reentrant_thunk = ref (fun () -> ()) in
  let observer = Rx.Observer.create
      ~on_error:(fun _ -> assert_failure "Should not call on_error")
      ~on_completed:(fun () -> n := succ !n; !reentrant_thunk ())
      (fun _ -> assert_failure "Should not call on_next")
    |> Rx.Observer.checked in
  let (on_next, on_error, on_completed) = observer in
  reentrant_thunk := (fun () ->
    assert_raises ~msg:"on_next"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_next 9);
    assert_raises ~msg:"on_error"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_error (Failure "test"));
    assert_raises ~msg:"on_completed"
      (Failure "Reentrancy has been detected.")
      (fun () -> on_completed ())
  );
  on_completed ();
  assert_equal 1 !n

let test_observer_synchronize_monitor_reentrant _ =
  let res = ref false in
  let inOne = ref false in
  let on_next_ref : (int -> unit) ref = ref (fun x -> ()) in
  let o = Rx.Observer.create
      (fun x ->
         if x = 1 then begin
           inOne := true;
           !on_next_ref 2;
           inOne := false;
         end else if x = 2 then begin
           res := !inOne;
         end
      ) in
  let (on_next, _, _) = Rx.Observer.synchronize o in
  on_next_ref := on_next;
  on_next 1;
  assert_bool "res should be true" !res

let test_observer_synchronize_async_lock_non_reentrant _ =
  let res = ref false in
  let inOne = ref false in
  let on_next_ref : (int -> unit) ref = ref (fun x -> ()) in
  let o = Rx.Observer.create
      (fun x ->
         if x = 1 then begin
           inOne := true;
           !on_next_ref 2;
           inOne := false;
         end else if x = 2 then begin
           res := not !inOne;
         end
      ) in
  let (on_next, _, _) = Rx.Observer.synchronize_async_lock o in
  on_next_ref := on_next;
  on_next 1;
  assert_bool "res should be true" !res

let test_observer_synchronize_async_lock_on_next _ =
  let res = ref false in
  let o = Rx.Observer.create
    ~on_error:(fun _ -> assert_failure "Should not call on_error")
    ~on_completed:(fun () -> assert_failure "Should not call on_completed")
    (fun x -> res := x = 1) in
  let (on_next, _, _) = Rx.Observer.synchronize_async_lock o in
  on_next 1;
  assert_bool "res should be true" !res

let test_observer_synchronize_async_lock_on_error _ =
  let res = ref (Failure "") in
  let err = Failure "test" in
  let o = Rx.Observer.create
    ~on_error:(fun e -> res := e)
    ~on_completed:(fun () -> assert_failure "Should not call on_completed")
    (fun _ -> assert_failure "Should not call on_next") in
  let (_, on_error, _) = Rx.Observer.synchronize_async_lock o in
  on_error err;
  assert_equal err !res

let test_observer_synchronize_async_lock_on_completed _ =
  let res = ref false in
  let o = Rx.Observer.create
    ~on_error:(fun _ -> assert_failure "Should not call on_error")
    ~on_completed:(fun () -> res := true)
    (fun _ -> assert_failure "Should not call on_next") in
  let (_, _, on_completed) = Rx.Observer.synchronize_async_lock o in
  on_completed ();
  assert_bool "res should be true" !res

let suite = "Observer tests" >:::
  ["test_create_on_next" >:: test_create_on_next;
   "test_create_on_next_has_errors" >:: test_create_on_next_has_errors;
   "test_create_on_next_on_completed" >:: test_create_on_next_on_completed;
   "test_create_on_next_on_completed_has_errors" >::
     test_create_on_next_on_completed_has_errors;
   "test_create_on_next_on_error" >:: test_create_on_next_on_error;
   "test_create_on_next_on_error_hit_completed" >::
     test_create_on_next_on_error_hit_completed;
   "test_create_on_next_on_error_on_completed_1" >::
     test_create_on_next_on_error_on_completed_1;
   "test_create_on_next_on_error_on_completed_2" >::
     test_create_on_next_on_error_on_completed_2;
   "test_checked_observer_already_terminated_completed" >::
     test_checked_observer_already_terminated_completed;
   "test_checked_observer_already_terminated_error" >::
     test_checked_observer_already_terminated_error;
   "test_checked_observer_reentrant_next" >::
     test_checked_observer_reentrant_next;
   "test_checked_observer_reentrant_error" >::
     test_checked_observer_reentrant_error;
   "test_checked_observer_reentrant_completed" >::
     test_checked_observer_reentrant_completed;
   "test_observer_synchronize_monitor_reentrant" >::
     test_observer_synchronize_monitor_reentrant;
   "test_observer_synchronize_async_lock_non_reentrant" >::
     test_observer_synchronize_async_lock_non_reentrant;
   "test_observer_synchronize_async_lock_on_next" >::
     test_observer_synchronize_async_lock_on_next;
   "test_observer_synchronize_async_lock_on_error" >::
     test_observer_synchronize_async_lock_on_error;
   "test_observer_synchronize_async_lock_on_completed" >::
     test_observer_synchronize_async_lock_on_completed;
   ]

