open OUnit2

let test_create_subject _ =
  let c1 = ref 0 in
  let c2 = ref 0 in
  let (subject, _) = Rx.Subject.create () in
  let ((_, _, on_next), observable) = subject in
  let observer1 = Rx.Observer.create (fun _ -> incr c1) in
  let unsubscribe1 = observable observer1 in
  let observer2 = Rx.Observer.create (fun _ -> incr c2) in
  let unsubscribe2 = observable observer2 in
  on_next 1;
  on_next 2;
  assert_equal 2 !c1;
  assert_equal 2 !c2;
  unsubscribe2 ();
  on_next 3;
  assert_equal 3 !c1;
  assert_equal 2 !c2;
  unsubscribe1 ();
  on_next 4;
  assert_equal 3 !c1;
  assert_equal 2 !c2

let test_subject_unsubscribe _ =
  let c1 = ref 0 in
  let c2 = ref 0 in
  let (subject, unsubscribe) = Rx.Subject.create () in
  let ((_, _, on_next), observable) = subject in
  let observer1 = Rx.Observer.create (fun _ -> incr c1) in
  let _ = observable observer1 in
  let observer2 = Rx.Observer.create (fun _ -> incr c2) in
  let _ = observable observer2 in
  on_next 1;
  on_next 2;
  assert_equal 2 !c1;
  assert_equal 2 !c2;
  unsubscribe ();
  on_next 3;
  assert_equal 2 !c1;
  assert_equal 2 !c2

let test_subject_on_completed _ =
  let on_completed1 = ref false in
  let on_completed2 = ref false in
  let (subject, _) = Rx.Subject.create () in
  let ((on_completed, _, _), observable) = subject in
  let observer1 =
    Rx.Observer.create
      ~on_completed:(fun () -> on_completed1 := true)
      (fun _ -> ()) in
  let _ = observable observer1 in
  let observer2 =
    Rx.Observer.create
      ~on_completed:(fun () -> on_completed2 := true)
      (fun _ -> ()) in
  let _ = observable observer2 in
  on_completed ();
  assert_equal true !on_completed1;
  assert_equal true !on_completed2

let test_subject_on_error _ =
  let on_error1 = ref false in
  let on_error2 = ref false in
  let (subject, _) = Rx.Subject.create () in
  let ((_, on_error, _), observable) = subject in
  let observer1 =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; on_error1 := true)
      (fun _ -> ()) in
  let _ = observable observer1 in
  let observer2 =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; on_error2 := true)
      (fun _ -> ()) in
  let _ = observable observer2 in
  on_error (Failure "test");
  assert_equal true !on_error1;
  assert_equal true !on_error2

let test_create_replay_subject _ =
  let c1 = ref 0 in
  let c2 = ref 0 in
  let (subject, unsubscribe) = Rx.Subject.Replay.create () in
  let ((_, _, on_next), observable) = subject in
  on_next 1;
  on_next 2;
  let observer1 = Rx.Observer.create (fun _ -> incr c1) in
  let _ = observable observer1 in
  let observer2 = Rx.Observer.create (fun _ -> incr c2) in
  let _ = observable observer2 in
  assert_equal 2 !c1;
  assert_equal 2 !c2;
  on_next 3;
  assert_equal 3 !c1;
  assert_equal 3 !c2;
  unsubscribe ();
  on_next 4;
  assert_equal 3 !c1;
  assert_equal 3 !c2

let test_replay_subject_on_completed _ =
  let on_completed1 = ref false in
  let on_completed2 = ref false in
  let (subject, _) = Rx.Subject.Replay.create () in
  let ((on_completed, _, on_next), observable) = subject in
  on_completed ();
  let observer1 =
    Rx.Observer.create
      ~on_completed:(fun () -> on_completed1 := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer1 in
  let observer2 =
    Rx.Observer.create
      ~on_completed:(fun () -> on_completed2 := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer2 in
  assert_equal true !on_completed1;
  assert_equal true !on_completed2;
  on_next 1

let test_replay_subject_on_error _ =
  let on_error1 = ref false in
  let on_error2 = ref false in
  let (subject, _) = Rx.Subject.Replay.create () in
  let ((_, on_error, on_next), observable) = subject in
  on_error (Failure "test");
  let observer1 =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; on_error1 := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer1 in
  let observer2 =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; on_error2 := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer2 in
  assert_equal true !on_error1;
  assert_equal true !on_error2;
  on_next 1

let test_create_behavior_subject _ =
  let v1 = ref "" in
  let v2 = ref "" in
  let (subject, unsubscribe) = Rx.Subject.Behavior.create "default" in
  let ((_, _, on_next), observable) = subject in
  let observer1 = Rx.Observer.create (fun v -> v1 := v) in
  let _ = observable observer1 in
  assert_equal "default" !v1;
  assert_equal "" !v2;
  on_next "one";
  assert_equal "one" !v1;
  assert_equal "" !v2;
  on_next "two";
  let observer2 = Rx.Observer.create (fun v -> v2 := v) in
  let _ = observable observer2 in
  assert_equal "two" !v1;
  assert_equal "two" !v2;
  unsubscribe ();
  on_next "three";
  assert_equal "two" !v1;
  assert_equal "two" !v2

let test_behavior_subject_on_completed _ =
  let completed = ref false in
  let (subject, _) = Rx.Subject.Behavior.create 0 in
  let ((on_completed, _, on_next), observable) = subject in
  on_next 1;
  on_completed ();
  let observer =
    Rx.Observer.create
      ~on_completed:(fun () -> completed := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer in
  assert_equal true !completed

let test_behavior_subject_on_error _ =
  let error = ref false in
  let (subject, _) = Rx.Subject.Behavior.create 0 in
  let ((_, on_error, on_next), observable) = subject in
  on_next 1;
  on_error (Failure "test");
  let observer =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; error := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer in
  assert_equal true !error

let test_create_async_subject _ =
  let v1 = ref "" in
  let v2 = ref "" in
  let (subject, _) = Rx.Subject.Async.create () in
  let ((on_completed, _, on_next), observable) = subject in
  let observer1 = Rx.Observer.create (fun v -> v1 := v) in
  let _ = observable observer1 in
  assert_equal "" !v1;
  assert_equal "" !v2;
  on_next "one";
  assert_equal "" !v1;
  assert_equal "" !v2;
  on_next "two";
  on_completed ();
  assert_equal "two" !v1;
  assert_equal "" !v2;
  let observer2 = Rx.Observer.create (fun v -> v2 := v) in
  let _ = observable observer2 in
  assert_equal "two" !v1;
  assert_equal "two" !v2

let test_async_subject_on_error _ =
  let error = ref false in
  let (subject, _) = Rx.Subject.Async.create () in
  let ((_, on_error, on_next), observable) = subject in
  let observer =
    Rx.Observer.create
      ~on_error:(fun e -> assert_equal (Failure "test") e; error := true)
      (fun _ -> assert_failure "on_next should not be called") in
  let _ = observable observer in
  on_next 1;
  on_error (Failure "test");
  assert_equal true !error

let suite = "Subjects tests" >:::
  ["test_create_subject" >:: test_create_subject;
   "test_subject_unsubscribe" >:: test_subject_unsubscribe;
   "test_subject_on_completed" >:: test_subject_on_completed;
   "test_subject_on_error" >:: test_subject_on_error;
   "test_create_replay_subject" >:: test_create_replay_subject;
   "test_replay_subject_on_completed" >:: test_replay_subject_on_completed;
   "test_replay_subject_on_error" >:: test_replay_subject_on_error;
   "test_create_behavior_subject" >:: test_create_behavior_subject;
   "test_behavior_subject_on_completed" >:: test_behavior_subject_on_completed;
   "test_behavior_subject_on_error" >:: test_behavior_subject_on_error;
   "test_create_async_subject" >:: test_create_async_subject;
   "test_async_subject_on_error" >:: test_async_subject_on_error;
  ]

