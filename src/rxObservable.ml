(* Internal module. (see Rx.Observable)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/Observable.java
 *)

type +'a observable = 'a RxObserver.observer -> RxSubscription.subscription

let empty =
  (fun (on_completed, _, _) ->
    RxScheduler.CurrentThread.schedule_absolute
      (fun () ->
        on_completed ();
        RxSubscription.empty
      )
  )

let from_enum enum =
  (fun (on_completed, on_error, on_next) ->
    RxScheduler.CurrentThread.schedule_recursive
      (fun self ->
        try
          let elem = BatEnum.get enum in
          match elem with
            None ->
              on_completed ();
              RxSubscription.empty
          | Some x ->
              on_next x;
              self ()
        with e ->
          on_error e;
          RxSubscription.empty
      )
  )

let count observable =
  let counter = RxAtomicData.create 0 in
  let create_observer on_next on_completed =
    let on_completed () =
      let v = RxAtomicData.unsafe_get counter in
      on_next v;
      on_completed ()
    in
    RxObserver.create
    ~on_completed
    (fun _ -> RxAtomicData.update succ counter)
  in
  (fun (on_completed, _, on_next) ->
    observable (create_observer on_next on_completed))

