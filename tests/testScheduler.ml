open OUnit2

let test_current_thread_schedule_action _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let _ = Rx.Scheduler.CurrentThread.schedule_absolute
    (fun () ->
      assert_equal id (Utils.current_thread_id ());
      ran := true;
      Rx.Subscription.empty
    ) in
  assert_bool "ran should be true" !ran

let test_current_thread_schedule_action_error _ =
  let ex = Failure "test" in
  try
    let _ = Rx.Scheduler.CurrentThread.schedule_absolute
      (fun () -> raise ex) in
    assert_failure "Should raise an exception"
  with e ->
    assert_equal ex e

let test_current_thread_schedule_action_nested _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let _ = Rx.Scheduler.CurrentThread.schedule_absolute
    (fun () ->
      assert_equal id (Utils.current_thread_id ());
      Rx.Scheduler.CurrentThread.schedule_absolute
        (fun () ->
          ran := true;
          Rx.Subscription.empty
        )
    ) in
  assert_bool "ran should be true" !ran

let test_current_thread_schedule_relative_action_nested _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let _ = Rx.Scheduler.CurrentThread.schedule_absolute
    (fun () ->
      assert_equal id (Utils.current_thread_id ());
      Rx.Scheduler.CurrentThread.schedule_relative 0.1
        (fun () ->
          ran := true;
          Rx.Subscription.empty
        )
    ) in
  assert_bool "ran should be true" !ran

let test_current_thread_schedule_relative_action_due _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let start = Unix.gettimeofday () in
  let stop = ref 0.0 in
  let _ = Rx.Scheduler.CurrentThread.schedule_relative 0.1
    (fun () ->
      stop := Unix.gettimeofday ();
      assert_equal id (Utils.current_thread_id ());
      ran := true;
      Rx.Subscription.empty
    ) in
  assert_bool "ran should be true" !ran;
  let elapsed = !stop -. start in
  assert_bool "Elapsed time should be > 80ms" (elapsed > 0.08)

let test_current_thread_schedule_relative_action_due_nested _ =
  let ran = ref false in
  let start = Unix.gettimeofday () in
  let stop = ref 0.0 in
  let _ = Rx.Scheduler.CurrentThread.schedule_relative 0.1
    (fun () ->
      Rx.Scheduler.CurrentThread.schedule_relative 0.1
        (fun () ->
          stop := Unix.gettimeofday ();
          ran := true;
          Rx.Subscription.empty
        )
    ) in
  assert_bool "ran should be true" !ran;
  let elapsed = !stop -. start in
  assert_bool "Elapsed time should be > 180ms" (elapsed > 0.18)

let test_current_thread_cancel _ =
  let ran1 = ref false in
  let ran2 = ref false in
  let _ = Rx.Scheduler.CurrentThread.schedule_absolute
    (fun () ->
      RxScheduler.CurrentThread.schedule_absolute
        (fun () ->
          ran1 := true;
          let unsubscribe = Rx.Scheduler.CurrentThread.schedule_relative 1.0
            (fun () ->
              ran2 := true;
              Rx.Subscription.empty
            )
          in
          unsubscribe ();
          Rx.Subscription.empty
        );
    ) in
  assert_equal ~msg:"ran1" true !ran1;
  assert_equal ~msg:"ran2" false !ran2

let test_current_thread_schedule_nested_actions _ =
  let queue = Queue.create () in
  let first_step_start () = Queue.add "first_step_start" queue in
  let first_step_end () = Queue.add "first_step_end" queue in
  let second_step_start () = Queue.add "second_step_start" queue in
  let second_step_end () = Queue.add "second_step_end" queue in
  let third_step_start () = Queue.add "third_step_start" queue in
  let third_step_end () = Queue.add "third_step_end" queue in
  let first_action () =
    first_step_start ();
    first_step_end ();
    Rx.Subscription.empty;
  in
  let second_action () =
    second_step_start ();
    let s = Rx.Scheduler.CurrentThread.schedule_absolute first_action in
    second_step_end ();
    s
  in
  let third_action () =
    third_step_start ();
    let s = Rx.Scheduler.CurrentThread.schedule_absolute second_action in
    third_step_end ();
    s
  in
  let _ = Rx.Scheduler.CurrentThread.schedule_absolute third_action in
  let in_order = BatQueue.enum queue |> BatList.of_enum in
  assert_equal
    ~printer:(fun xs ->
      BatPrintf.sprintf2 "%a" (BatList.print BatString.print) xs)
    ["third_step_start";
     "third_step_end";
     "second_step_start";
     "second_step_end";
     "first_step_start";
     "first_step_end"]
    in_order

let test_current_thread_schedule_recursion _ =
  let counter = ref 0 in
  let count = 10 in
  let _ = Rx.Scheduler.CurrentThread.schedule_recursive
    (fun self ->
      incr counter;
      if !counter < count then self ()
      else Rx.Subscription.empty
    )
  in
  assert_equal count !counter

let test_immediate_schedule_action _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let _ = Rx.Scheduler.Immediate.schedule_absolute
    (fun () ->
      assert_equal id (Utils.current_thread_id ());
      ran := true;
      Rx.Subscription.empty
    ) in
  assert_bool "ran should be true" !ran

let test_immediate_schedule_nested_actions _ =
  let queue = Queue.create () in
  let first_step_start () = Queue.add "first_step_start" queue in
  let first_step_end () = Queue.add "first_step_end" queue in
  let second_step_start () = Queue.add "second_step_start" queue in
  let second_step_end () = Queue.add "second_step_end" queue in
  let third_step_start () = Queue.add "third_step_start" queue in
  let third_step_end () = Queue.add "third_step_end" queue in
  let first_action () =
    first_step_start ();
    first_step_end ();
    Rx.Subscription.empty;
  in
  let second_action () =
    second_step_start ();
    let s = Rx.Scheduler.Immediate.schedule_absolute first_action in
    second_step_end ();
    s
  in
  let third_action () =
    third_step_start ();
    let s = Rx.Scheduler.Immediate.schedule_absolute second_action in
    third_step_end ();
    s
  in
  let _ = Rx.Scheduler.Immediate.schedule_absolute third_action in
  let in_order = BatQueue.enum queue |> BatList.of_enum in
  assert_equal
    ~printer:(fun xs ->
      BatPrintf.sprintf2 "%a" (BatList.print BatString.print) xs)
    ["third_step_start";
     "second_step_start";
     "first_step_start";
     "first_step_end";
     "second_step_end";
     "third_step_end"]
    in_order

let test_new_thread_schedule_action _ =
  let id = Utils.current_thread_id () in
  let ran = ref false in
  let _ = Rx.Scheduler.NewThread.schedule_absolute
    (fun () ->
      assert_bool
        "New thread scheduler should create schedule work on a different thread"
        (id <> (Utils.current_thread_id ()));
      ran := true;
      Rx.Subscription.empty
    ) in
  (* Wait for the other thread to run *)
  Thread.delay 0.1;
  assert_bool "ran should be true" !ran

let test_new_thread_cancel_action _ =
  let unsubscribe = Rx.Scheduler.NewThread.schedule_absolute
    (fun () ->
      assert_failure "This action should not run"
    ) in
  unsubscribe ();
  (* Wait for the other thread *)
  Thread.delay 0.1

let suite = "Scheduler tests" >:::
  ["test_current_thread_schedule_action" >::
     test_current_thread_schedule_action;
   "test_current_thread_schedule_action_error" >::
     test_current_thread_schedule_action_error;
   "test_current_thread_schedule_action_nested" >::
     test_current_thread_schedule_action_nested;
   "test_current_thread_schedule_relative_action_nested" >::
     test_current_thread_schedule_relative_action_nested;
   "test_current_thread_schedule_relative_action_due" >::
     test_current_thread_schedule_relative_action_due;
   "test_current_thread_schedule_relative_action_due_nested" >::
     test_current_thread_schedule_relative_action_due_nested;
   "test_current_thread_cancel" >:: test_current_thread_cancel;
   "test_current_thread_schedule_nested_actions" >::
     test_current_thread_schedule_nested_actions;
   "test_current_thread_schedule_recursion" >::
     test_current_thread_schedule_recursion;
   "test_immediate_schedule_action" >::
     test_immediate_schedule_action;
   "test_immediate_schedule_nested_actions" >::
     test_immediate_schedule_nested_actions;
   "test_new_thread_schedule_action" >:: test_new_thread_schedule_action;
   "test_new_thread_cancel_action" >:: test_new_thread_cancel_action;
  ]

