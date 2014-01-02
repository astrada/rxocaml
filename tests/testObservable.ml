open OUnit2

let test_from_enum _ =
  let items = ["one"; "two"; "three"] in
  let observable =
    Rx.Observable.CurrentThread.from_enum @@ BatList.enum items in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = observable observer in
  assert_equal items @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_count _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let count_observable =
    Rx.Observable.CurrentThread.count observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = count_observable observer in
  assert_equal [3] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_drop _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let drop_2_observable =
    Rx.Observable.CurrentThread.drop 2 observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = drop_2_observable observer in
  assert_equal ["c"; "d"] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_take _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let take_2_observable = Rx.Observable.CurrentThread.take 2 observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = take_2_observable observer in
  assert_equal ["a"; "b"] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_take_last _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let take_last_2_observable =
    Rx.Observable.CurrentThread.take_last 2 observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = take_last_2_observable observer in
  assert_equal ["c"; "d"] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_materialize _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let materialized_observable =
    Rx.Observable.CurrentThread.materialize observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = materialized_observable observer in
  assert_equal [
    `OnNext "a";
    `OnNext "b";
    `OnNext "c";
    `OnNext "d";
    `OnCompleted] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_materialize_error _ =
  let observable =
    (fun (_, on_error, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_error (Failure "test");
      Rx.Subscription.empty;
    ) in
  let materialized_observable =
    Rx.Observable.CurrentThread.materialize observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = materialized_observable observer in
  assert_equal [
    `OnNext "a";
    `OnNext "b";
    `OnNext "c";
    `OnNext "d";
    `OnError (Failure "test")] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_to_enum _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_next 2;
      on_next 3;
      on_next 4;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let enum = Rx.Observable.CurrentThread.to_enum observable in
  let xs = BatList.of_enum enum in
  assert_equal [1;2;3;4] xs

let test_to_enum_error _ =
  let ex = Failure "test" in
  let observable =
    (fun (_, on_error, on_next) ->
      on_next 1;
      on_next 2;
      on_next 3;
      on_next 4;
      on_error ex;
      Rx.Subscription.empty;
    ) in
  try
    let enum = Rx.Observable.CurrentThread.to_enum observable in
    let _ = BatList.of_enum enum in
    assert_failure "Should raise an exception"
  with e ->
    assert_equal ex e

let test_single _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = single_observable observer in
  assert_equal [1] @@ TestHelper.Observer.on_next_values state;
  assert_equal true @@ TestHelper.Observer.is_completed state;
  assert_equal false @@ TestHelper.Observer.is_on_error state

let test_single_too_many_elements _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_next 2;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = single_observable observer in
  assert_equal [] @@ TestHelper.Observer.on_next_values state;
  assert_equal false @@ TestHelper.Observer.is_completed state;
  assert_equal true @@ TestHelper.Observer.is_on_error state

let test_single_empty _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let (observer, state) = TestHelper.Observer.create () in
  let _ = single_observable observer in
  assert_equal [] @@ TestHelper.Observer.on_next_values state;
  assert_equal false @@ TestHelper.Observer.is_completed state;
  assert_equal true @@ TestHelper.Observer.is_on_error state

let test_single_blocking _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let value = Rx.Observable.CurrentThread.Blocking.single observable in
  assert_equal 1 value

let test_single_blocking_empty _ =
  let observable =
    (fun (on_completed, _, on_next) ->
      on_completed ();
      Rx.Subscription.empty;
    ) in
  try
    let _ = Rx.Observable.CurrentThread.Blocking.single observable in
    assert_failure "Should raise an exception"
  with e ->
    assert_equal (Failure "Sequence contains no elements") e

let test_from_list _ =
  let items = ["one"; "two"; "three"] in
  let from_list xs =
    Rx.Observable.CurrentThread.from_enum @@ BatList.enum xs in
  assert_equal 3
    Rx.Observable.CurrentThread.(
      items |> from_list |> count |> Blocking.single
    );
  assert_equal "two"
    Rx.Observable.CurrentThread.(
      items |> from_list |> drop 1 |> take 1 |> Blocking.single
    );
  assert_equal "three"
    Rx.Observable.CurrentThread.(
      items |> from_list |> take_last 1 |> Blocking.single
    )

let suite = "Observable tests" >:::
  ["test_from_enum" >:: test_from_enum;
   "test_count" >:: test_count;
   "test_drop" >:: test_drop;
   "test_take" >:: test_take;
   "test_take_last" >:: test_take_last;
   "test_materialize" >:: test_materialize;
   "test_materialize_error" >:: test_materialize_error;
   "test_to_enum" >:: test_to_enum;
   "test_to_enum_error" >:: test_to_enum_error;
   "test_single" >:: test_single;
   "test_single_too_many_elements" >:: test_single_too_many_elements;
   "test_single_empty" >:: test_single_empty;
   "test_single_blocking" >:: test_single_blocking;
   "test_single_blocking_empty" >:: test_single_blocking_empty;
   "test_from_list" >:: test_from_list;
  ]

