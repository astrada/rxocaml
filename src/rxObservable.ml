(* Internal module. (see Rx.Observable)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/Observable.java
 *)

let empty =
  (fun (on_completed, _, _) ->
    on_completed ();
    RxSubscription.empty
  )

let error e =
  (fun (_, on_error, _) ->
    on_error e;
    RxSubscription.empty
  )

let never =
  (fun (_, _, _) ->
    RxSubscription.empty
  )

let return v =
  (fun (on_completed, on_error, on_next) ->
    on_next v;
    on_completed ();
    RxSubscription.empty
  )

let materialize observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationMaterialize.java
   *)
  (fun (on_completed, on_error, on_next) ->
    let materialize_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          on_next RxCore.OnCompleted;
          on_completed ())
        ~on_error:(fun e ->
          on_next (RxCore.OnError e);
          on_completed ())
        (fun v -> on_next (RxCore.OnNext v))
    in
    observable materialize_observer
  )

let dematerialize observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationDematerialize.java
   *)
  (fun (on_completed, on_error, on_next) ->
    let materialize_observer =
      RxObserver.create
        ~on_completed:ignore
          ~on_error:ignore
          (function
            | RxCore.OnCompleted -> on_completed ()
            | RxCore.OnError e -> on_error e
            | RxCore.OnNext v -> on_next v
          )
      in
      observable materialize_observer
    )

let to_enum observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationToIterator.java
   *)
  let condition = Condition.create () in
  let mutex = Mutex.create () in
  let queue = Queue.create () in
  let observer =
    RxObserver.create
      ~on_completed:ignore
      ~on_error:ignore
      (fun n ->
        BatMutex.synchronize ~lock:mutex
          (fun () ->
            Queue.add n queue;
            Condition.signal condition) ()) in
  let _ = materialize observable observer in
  BatEnum.from
    (fun () ->
      BatMutex.synchronize ~lock:mutex
        (fun () ->
          if Queue.is_empty queue then Condition.wait condition mutex;
          let n = Queue.take queue in
          match n with
          | RxCore.OnCompleted -> raise BatEnum.No_more_elements
          | RxCore.OnError e -> raise e
          | RxCore.OnNext v -> v
        ) ()
    )

let length observable =
  (* Implementation based on:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Linq/Reactive/Linq/Observable/Count.cs
   *)
  (fun (on_completed, on_error, on_next) ->
    let counter = RxAtomicData.create 0 in
    let length_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          let v = RxAtomicData.unsafe_get counter in
          on_next v;
          on_completed ()
        )
        ~on_error
        (fun _ -> RxAtomicData.update succ counter)
    in
    observable length_observer)

let drop n observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationSkip.java
   *)
  (fun (on_completed, on_error, on_next) ->
    let counter = RxAtomicData.create 0 in
    let drop_observer =
      RxObserver.create
        ~on_completed
        ~on_error
        (fun v ->
          let count = RxAtomicData.update_and_get succ counter in
          if count > n then on_next v
        )
    in
    observable drop_observer)

let take n observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationTake.java
   *)
  (fun (on_completed, on_error, on_next) ->
    if n < 1 then begin
      let observer =
        RxObserver.create ~on_completed:ignore ~on_error:ignore ignore in
      let unsubscribe = observable observer in
      unsubscribe ();
      RxSubscription.empty;
    end else begin
      let counter = RxAtomicData.create 0 in
      let error = ref false in
      let (unsubscribe, subscription_state) =
        RxSubscription.SingleAssignment.create () in
      let take_observer =
        let on_completed_wrapper () =
          if not !error && RxAtomicData.get_and_set n counter < n then
            on_completed () in
        let on_error_wrapper e =
          if not !error && RxAtomicData.get_and_set n counter < n then
            on_error e
        in
        RxObserver.create
          ~on_completed:on_completed_wrapper
          ~on_error:on_error_wrapper
          (fun v ->
            if not !error then begin
              let count = RxAtomicData.update_and_get succ counter in
              if count <= n then begin
                begin try
                  on_next v;
                with e ->
                  error := true;
                  on_error e;
                  unsubscribe ()
                end;
                if not !error && count = n then on_completed ()
              end;
              if not !error && count >= n then unsubscribe ()
            end
          ) in
      let result = observable take_observer in
      RxSubscription.SingleAssignment.set subscription_state result;
      result
    end)

let take_last n observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationTakeLast.java
   *)
  (fun (on_completed, on_error, on_next) ->
    let queue = Queue.create () in
    let (unsubscribe, subscription_state) =
      RxSubscription.SingleAssignment.create () in
    let take_last_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          try
            Queue.iter on_next queue;
            on_completed ()
          with e ->
            on_error e
        )
        ~on_error
        (fun v ->
          if n > 0 then begin
            try
              BatMutex.synchronize
                (fun () ->
                  Queue.add v queue;
                  if Queue.length queue > n then ignore (Queue.take queue)
                ) ()
            with e ->
              on_error e;
              unsubscribe ()
          end
        )
    in
    let result = observable take_last_observer in
    RxSubscription.SingleAssignment.set subscription_state result;
    result
  )

let single observable =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationSingle.java
   *)
  (fun (on_completed, on_error, on_next) ->
    let value = ref None in
    let has_too_many_elements = ref false in
    let (unsubscribe, subscription_state) =
      RxSubscription.SingleAssignment.create () in
    let single_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          if not !has_too_many_elements then begin
            match !value with
            | None ->
                on_error (Failure "Sequence contains no elements")
            | Some v ->
                on_next v;
                on_completed ()
          end
        )
        ~on_error
        (fun v ->
          match !value with
          | None -> value := Some v
          | Some _ ->
              has_too_many_elements := true;
              on_error (Failure "Sequence contains too many elements");
              unsubscribe ()
        )
    in
    let result = observable single_observer in
    RxSubscription.SingleAssignment.set subscription_state result;
    result
  )

let append o1 o2 =
  (fun ((on_completed, on_error, on_next) as o2_observer) ->
    let o1_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          ignore @@ o2 o2_observer
        )
        ~on_error
        on_next
    in
    o1 o1_observer
  )

let merge observables =
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationMerge.java
   *)
  (fun actual_observer ->
    let (on_completed, on_error, on_next) =
      RxObserver.synchronize actual_observer in
    let (unsubscribe, subscription_state) =
      RxSubscription.Composite.create [] in
    let is_stopped = RxAtomicData.create false in
    let child_counter = RxAtomicData.create 0 in
    let parent_completed = ref false in
    let stop () =
      let was_stopped =
        RxAtomicData.compare_and_set false true is_stopped in
      if not was_stopped then unsubscribe ();
      was_stopped in
    let stop_if_and_do cond thunk =
      if not (RxAtomicData.get is_stopped) && cond then begin
        let was_stopped = stop () in
        if not was_stopped then thunk ()
      end in
    let child_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          let count = RxAtomicData.update_and_get pred child_counter in
          stop_if_and_do (count = 0 && !parent_completed) on_completed
        )
        ~on_error:(fun e ->
          stop_if_and_do true (fun () -> on_error e)
        )
        (fun v ->
          if not (RxAtomicData.get is_stopped) then on_next v
        ) in
    let parent_observer =
      RxObserver.create
        ~on_completed:(fun () ->
          parent_completed := true;
          let count = RxAtomicData.get child_counter in
          stop_if_and_do (count = 0) on_completed
        )
        ~on_error
        (fun observable ->
          if not (RxAtomicData.get is_stopped) then begin
            RxAtomicData.update succ child_counter;
            let child_subscription = observable child_observer in
            RxSubscription.Composite.add
              subscription_state child_subscription
          end
        ) in
    let parent_subscription = observables parent_observer in
    let (subscription, _) =
      RxSubscription.Composite.create [parent_subscription; unsubscribe]
    in
    subscription
  )

let map f observable =
  (fun (on_completed, on_error, on_next) ->
    let map_observer =
      RxObserver.create
        ~on_completed
        ~on_error
        (fun v -> on_next @@ f v) 
    in
    observable map_observer
  )

let bind observable f =
  map f observable |> merge

module Blocking = struct
(* Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/observables/BlockingObservable.java
 *)

  let single observable =
    let enum = single observable |> to_enum in
    BatEnum.get_exn enum

end

module type Scheduled = sig
  val subscribe_on_this : 'a RxCore.observable -> 'a RxCore.observable

  val from_enum : 'a BatEnum.t -> 'a RxCore.observable

end

module MakeScheduled(Scheduler : RxScheduler.S) = struct
  let subscribe_on_this observable =
    (fun observer ->
      Scheduler.schedule_absolute
        (fun () ->
          let unsubscribe = observable observer in
          RxSubscription.create
            (fun () ->
              ignore @@ Scheduler.schedule_absolute
                (fun () ->
                  unsubscribe();
                  RxSubscription.empty
                )
            )
        )
    )

  let from_enum enum =
    (fun (on_completed, on_error, on_next) ->
      Scheduler.schedule_recursive
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

end

module CurrentThread = MakeScheduled(RxScheduler.CurrentThread)

module Immediate = MakeScheduled(RxScheduler.Immediate)

