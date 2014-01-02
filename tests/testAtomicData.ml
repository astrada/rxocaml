open OUnit2

let test_unsafe_get _ =
  let v = RxAtomicData.create 0 in
  assert_equal 0 (RxAtomicData.unsafe_get v)

let test_get _ =
  let v = RxAtomicData.create 0 in
  assert_equal 0 (RxAtomicData.get v)

let test_set _ =
  let v = RxAtomicData.create 0 in
  RxAtomicData.set 1 v;
  assert_equal 1 (RxAtomicData.get v)

let test_get_and_set _ =
  let v = RxAtomicData.create 0 in
  let v' = RxAtomicData.get_and_set 1 v in
  assert_equal 1 (RxAtomicData.get v);
  assert_equal 0 v'

let test_update _ =
  let v = RxAtomicData.create 0 in
  RxAtomicData.update succ v;
  assert_equal 1 (RxAtomicData.get v)

let test_update_and_get _ =
  let v = RxAtomicData.create 0 in
  let v' = RxAtomicData.update_and_get succ v in
  assert_equal 1 v'

let test_compare_and_set _ =
  let v = RxAtomicData.create 0 in
  let old_content = RxAtomicData.compare_and_set 0 1 v in
  assert_equal 0 old_content;
  assert_equal 1 (RxAtomicData.get v)

let test_concurrent_update _ =
  let v = RxAtomicData.create 0 in
  let count = 10 in
  let start = Condition.create () in
  let lock = Mutex.create () in
  let f () =
    BatMutex.synchronize ~lock
      (fun () -> Condition.wait start lock) ();
    RxAtomicData.update
      (fun value ->
        let value' = succ value in
        Thread.delay (Random.float 0.1);
        value'
      ) v;
  in
  let threads =
    BatEnum.range 1 ~until:count
      |> BatEnum.fold
        (fun ts _ ->
          let thread = Thread.create f () in
          thread :: ts
        )
        []
  in
  (* Wait for all the threads to start *)
  Thread.delay 0.1;
  Condition.broadcast start;
  List.iter (fun thread -> Thread.join thread) threads;
  assert_equal count (RxAtomicData.get v)

let suite = "Atomic data tests" >:::
  ["test_unsafe_get" >:: test_unsafe_get;
   "test_get" >:: test_get;
   "test_set" >:: test_set;
   "test_get_and_set" >:: test_get_and_set;
   "test_update" >:: test_update;
   "test_update_and_get" >:: test_update_and_get;
   "test_compare_and_set" >:: test_compare_and_set;
   "test_concurrent_update" >:: test_concurrent_update;
  ]

