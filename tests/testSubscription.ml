open OUnit2

let test_unsubscribe_only_once _ =
  let counter = ref 0 in
  let unsubscribe = Rx.Subscription.create (fun () -> incr counter) in
  unsubscribe ();
  unsubscribe ();
  assert_equal 1 !counter

let test_boolean_subscription _ =
  let counter = ref 0 in
  let boolean_subscription, state =
    Rx.Subscription.Boolean.create (fun () -> incr counter) in
  assert_equal false (Rx.Subscription.Boolean.is_unsubscribed state);
  boolean_subscription ();
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state);
  boolean_subscription ();
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state);
  assert_equal 1 !counter

let test_composite_subscription_success _ =
  let counter = ref 0 in
  let (composite_subscription, state) = Rx.Subscription.Composite.create [] in
  Rx.Subscription.Composite.add state (fun () -> incr counter);
  Rx.Subscription.Composite.add state (fun () -> incr counter);
  composite_subscription ();
  assert_equal 2 !counter

let test_composite_subscription_unsubscribe_all _ =
  let counter = ref 0 in
  let (composite_subscription, state) = Rx.Subscription.Composite.create [] in
  let count = 10 in
  let start = Condition.create () in
  let mutex = Mutex.create () in
  BatEnum.range 1 ~until:count
    |> BatEnum.iter
      (fun _ -> Rx.Subscription.Composite.add state (fun () -> incr counter));
  let threads =
    BatEnum.range 1 ~until:count
      |> BatEnum.fold
        (fun ts _ ->
          let thread = Thread.create
            (fun () ->
              BatMutex.synchronize ~lock:mutex
                (fun () ->
                  Condition.wait start mutex;
                  composite_subscription ();
                ) ();
            ) ()
          in
          thread :: ts
        )
        []
  in
  (* Wait for all the threads to start *)
  Thread.delay 0.1;
  Condition.broadcast start;
  List.iter (fun thread -> Thread.join thread) threads;
  assert_equal count !counter

let test_composite_subscription_exception _ =
  let counter = ref 0 in
  let ex = Failure "failed on first one" in
  let (composite_subscription, state) = Rx.Subscription.Composite.create [] in
  Rx.Subscription.Composite.add state
    (fun () -> raise ex);
  Rx.Subscription.Composite.add state (fun () -> incr counter);
  begin try
    composite_subscription ();
    assert_failure "Expecting an exception"
  with Rx.Subscription.Composite.CompositeException es ->
    assert_equal ex (List.hd es)
  end;
  (* we should still have unsubscribed to the second one *)
  assert_equal 1 !counter

let test_composite_subscription_remove _ =
  let (s1, state1) = Rx.Subscription.Boolean.create (fun () -> ()) in
  let (s2, state2) = Rx.Subscription.Boolean.create (fun () -> ()) in
  let (s, state) = Rx.Subscription.Composite.create [] in
  Rx.Subscription.Composite.add state s1;
  Rx.Subscription.Composite.add state s2;
  Rx.Subscription.Composite.remove state s1;
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state1);
  assert_equal false (Rx.Subscription.Boolean.is_unsubscribed state2)

let test_composite_subscription_clear _ =
  let (s1, state1) = Rx.Subscription.Boolean.create (fun () -> ()) in
  let (s2, state2) = Rx.Subscription.Boolean.create (fun () -> ()) in
  let (s, state) = Rx.Subscription.Composite.create [] in
  Rx.Subscription.Composite.add state s1;
  Rx.Subscription.Composite.add state s2;
  assert_equal false (Rx.Subscription.Boolean.is_unsubscribed state1);
  assert_equal false (Rx.Subscription.Boolean.is_unsubscribed state2);
  Rx.Subscription.Composite.clear state;
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state1);
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state2);
  assert_equal false (Rx.Subscription.Composite.is_unsubscribed state);
  let (s3, state3) = Rx.Subscription.Boolean.create (fun () -> ()) in
  Rx.Subscription.Composite.add state s3;
  s ();
  assert_equal true (Rx.Subscription.Boolean.is_unsubscribed state3);
  assert_equal true (Rx.Subscription.Composite.is_unsubscribed state)

let test_composite_subscription_unsubscribe_idempotence _ =
  let counter = ref 0 in
  let (s, state) = Rx.Subscription.Composite.create [] in
  Rx.Subscription.Composite.add state (fun () -> incr counter);
  s ();
  s ();
  s ();
  (* We should have only unsubscribed once *)
  assert_equal 1 !counter

let test_composite_subscription_unsubscribe_idempotence_concurrently _ =
  let counter = ref 0 in
  let (s, state) = Rx.Subscription.Composite.create [] in
  let count = 10 in
  let start = Condition.create () in
  let mutex = Mutex.create () in
  Rx.Subscription.Composite.add state (fun () -> incr counter);
  let threads =
    BatEnum.range 1 ~until:count
      |> BatEnum.fold
        (fun ts _ ->
          let thread = Thread.create
            (fun () ->
              BatMutex.synchronize ~lock:mutex
                (fun () ->
                  Condition.wait start mutex;
                  s ();
                ) ();
            ) ()
          in
          thread :: ts
        )
        []
  in
  (* Wait for all the threads to start *)
  Thread.delay 0.1;
  Condition.broadcast start;
  List.iter (fun thread -> Thread.join thread) threads;
  (* We should have only unsubscribed once *)
  assert_equal 1 !counter

let suite = "Subscription tests" >:::
  ["test_unsubscribe_only_once" >:: test_unsubscribe_only_once;
   "test_boolean_subscription" >:: test_boolean_subscription;
   "test_composite_subscription_success" >::
     test_composite_subscription_success;
   "test_composite_subscription_unsubscribe_all" >::
     test_composite_subscription_unsubscribe_all;
   "test_composite_subscription_exception" >::
     test_composite_subscription_exception;
   "test_composite_subscription_remove" >:: test_composite_subscription_remove;
   "test_composite_subscription_clear" >:: test_composite_subscription_clear;
   "test_composite_subscription_unsubscribe_idempotence" >::
     test_composite_subscription_unsubscribe_idempotence;
   "test_composite_subscription_unsubscribe_idempotence_concurrently" >::
     test_composite_subscription_unsubscribe_idempotence_concurrently;
  ]

