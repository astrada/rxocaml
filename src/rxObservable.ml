(* Internal module. (see Rx.Observable)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/Observable.java
 *)

module type O = sig
  val empty : 'a RxCore.observable

  val materialize :
    'a RxCore.observable -> 'a RxCore.notification RxCore.observable

  val dematerialize :
    'a RxCore.notification RxCore.observable -> 'a RxCore.observable

  val from_enum : 'a BatEnum.t -> 'a RxCore.observable

  val to_enum : 'a RxCore.observable -> 'a BatEnum.t

  val length : 'a RxCore.observable -> int RxCore.observable

  val drop : int -> 'a RxCore.observable -> 'a RxCore.observable

  val take : int -> 'a RxCore.observable -> 'a RxCore.observable
  
  val take_last : int -> 'a RxCore.observable -> 'a RxCore.observable

  val single : 'a RxCore.observable -> 'a RxCore.observable

  module Blocking : sig
    val single : 'a RxCore.observable -> 'a

  end

end

module MakeObservable(Scheduler : RxScheduler.S) = struct

  let empty =
    (fun (on_completed, _, _) ->
      Scheduler.schedule_absolute
        (fun () ->
          on_completed ();
          RxSubscription.empty
        )
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
        let (subscription, state) =
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
                    subscription ()
                  end;
                  if not !error && count = n then on_completed ()
                end;
                if not !error && count >= n then subscription ()
              end
            ) in
        let result = observable take_observer in
        RxSubscription.SingleAssignment.set state result;
        result
      end)

  let take_last n observable =
    (* Implementation based on:
     * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationTakeLast.java
     *)
    (fun (on_completed, on_error, on_next) ->
      let queue = Queue.create () in
      let (unsubscribe, subscription) =
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
      RxSubscription.SingleAssignment.set subscription result;
      result
    )

  let single observable =
    (* Implementation based on:
     * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/operators/OperationSingle.java
     *)
    (fun (on_completed, on_error, on_next) ->
      let value = ref None in
      let has_too_many_elements = ref false in
      let (unsubscribe, subscription) =
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
      RxSubscription.SingleAssignment.set subscription result;
      result
    )

  module Blocking = struct
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/observables/BlockingObservable.java
   *)

    let single observable =
      let enum = single observable |> to_enum in
      BatEnum.get_exn enum

  end

end

module CurrentThread = MakeObservable(RxScheduler.CurrentThread)

