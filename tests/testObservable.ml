open OUnit2

let test_from_list _ =
  let completed = ref false in
  let error = ref false in
  let counter = ref 0 in
  let items = ["one"; "two"; "three"] in
  let observable = Rx.Observable.from_enum (BatList.enum items) in
  let observer = Rx.Observer.create
    ~on_completed:(fun () -> completed := true)
    ~on_error:(fun _ -> error := true)
    (fun _ -> incr counter) in
  let _ = observable observer in
  assert_equal 3 !counter;
  assert_equal true !completed;
  assert_equal false !error

let test_count _ =
  let result = ref 0 in
  let observable =
    (fun (on_completed, _, on_next) ->
      on_next "a";
      on_next "b";
      on_next "c";
      on_completed ();
      Rx.Subscription.empty;
    ) in
  let count_observable = Rx.Observable.count observable in
  let observer = Rx.Observer.create (fun v -> result := v) in
  let _ = count_observable observer in
  assert_equal 3 !result

let suite = "Observable tests" >:::
  ["test_from_list" >:: test_from_list;
   "test_count" >:: test_count;
  ]

