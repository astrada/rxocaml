open OUnit2

let test_from_enum _ =
  let completed = ref false in
  let error = ref false in
  let counter = ref 0 in
  let items = ["one"; "two"; "three"] in
  let observable = Rx.Observable.CurrentThread.from_enum (BatList.enum items) in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (fun _ -> incr counter) in
  let _ = observable observer in
  assert_equal 3 !counter;
  assert_equal true !completed;
  assert_equal false !error

let test_count _ =
  let result = ref None in
  let completed = ref false in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let count_observable = Rx.Observable.CurrentThread.count observable in
  let observer =
    Rx.Observer.create
      ~on_completed:(fun () ->
        assert_equal false !completed; completed := true
      )
      (fun v -> assert_equal None !result; result := Some v) in
  let _ = count_observable observer in
  assert_equal (Some 3) !result

let test_drop _ =
  let result = ref "" in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_next "d";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let drop_2_observable = Rx.Observable.CurrentThread.drop 2 observable in
  let observer = Rx.Observer.create (fun v -> result := !result ^ v) in
  let _ = drop_2_observable observer in
  assert_equal "cd" !result

let test_take _ =
  let result = ref "" in
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
  let observer = Rx.Observer.create (fun v -> result := !result ^ v) in
  let _ = take_2_observable observer in
  assert_equal "ab" !result

let test_take_last _ =
  let result = ref "" in
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
  let observer = Rx.Observer.create (fun v -> result := !result ^ v) in
  let _ = take_last_2_observable observer in
  assert_equal "cd" !result

let test_materialize _ =
  let result = ref "" in
  let completed = ref false in
  let error = ref false in
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
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (function
      | `OnCompleted -> result := !result ^ "."
      | `OnError _ -> result := !result ^ "?"
      | `OnNext v -> result := !result ^ v
    ) in
  let _ = materialized_observable observer in
  assert_equal "abcd." !result;
  assert_equal true !completed;
  assert_equal false !error

let test_materialize_error _ =
  let result = ref "" in
  let completed = ref false in
  let error = ref false in
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
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (function
      | `OnCompleted -> result := !result ^ "."
      | `OnError _ -> result := !result ^ "?"
      | `OnNext v -> result := !result ^ v
    ) in
  let _ = materialized_observable observer in
  assert_equal "abcd?" !result;
  assert_equal true !completed;
  assert_equal false !error

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
  let completed = ref false in
  let error = ref false in
  let counter = ref 0 in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (fun _ -> incr counter) in
  let _ = single_observable observer in
  assert_equal 1 !counter;
  assert_equal true !completed;
  assert_equal false !error

let test_single_too_many_elements _ =
  let completed = ref false in
  let error = ref false in
  let counter = ref 0 in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next 1;
      on_next 2;
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (fun _ -> incr counter) in
  let _ = single_observable observer in
  assert_equal 0 !counter;
  assert_equal false !completed;
  assert_equal true !error

let test_single_empty _ =
  let completed = ref false in
  let error = ref false in
  let counter = ref 0 in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let single_observable = Rx.Observable.CurrentThread.single observable in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (fun _ -> incr counter) in
  let _ = single_observable observer in
  assert_equal 0 !counter;
  assert_equal false !completed;
  assert_equal true !error

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
  let from_list xs = Rx.Observable.CurrentThread.from_enum @@ BatList.enum xs in
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

