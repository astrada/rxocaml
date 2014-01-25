(* Internal module. (see Rx.Subject)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subjects/Subject.java
 *)

let unsubscribe_observer observer observers =
  List.filter (fun o -> o != observer) observers

let create () =
  (* Implementation based on:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Linq/Reactive/Subjects/Subject.cs
   *)
  let observers = RxAtomicData.create [] in
  let update f = RxAtomicData.update f observers in
  let sync f = RxAtomicData.synchronize f observers in
  let iter f = sync (fun os -> List.iter f os) in
  let observable =
    (fun observer ->
      let _ = update (fun os -> observer :: os) in
      (fun () -> update (unsubscribe_observer observer))
    ) in
  let observer =
    RxObserver.create
      ~on_completed:(fun () ->
        iter (fun (on_completed, _, _) -> on_completed ())
      )
      ~on_error:(fun e ->
        iter (fun (_, on_error, _) -> on_error e)
      )
      (fun v ->
        iter (fun (_, _, on_next) -> on_next v)
      ) in
  let unsubscribe () = RxAtomicData.set [] observers in
  ((observer, observable), unsubscribe)

module Replay = struct
  type 'a t = {
    queue: 'a RxCore.notification Queue.t;
    is_stopped: bool;
    observers: 'a RxCore.observer list;
  }

  let create () =
    (* Implementation based on:
     * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Linq/Reactive/Subjects/ReplaySubject.cs
     * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subjects/ReplaySubject.java
     *)
    let state = RxAtomicData.create {
      queue = Queue.create ();
      is_stopped = false;
      observers = [];
    } in
    let update f = RxAtomicData.update f state in
    let sync f = RxAtomicData.synchronize f state in
    let if_not_stopped f = sync (fun s -> if not s.is_stopped then f s) in
    let observable =
      (fun ((on_completed, on_error, on_next) as observer) ->
        let _ =
          sync
            (fun s ->
              let observers = observer :: s.observers in
              RxAtomicData.unsafe_set { s with observers } state;
              Queue.iter
                (function
                 | RxCore.OnCompleted -> on_completed ()
                 | RxCore.OnError e -> on_error e
                 | RxCore.OnNext v -> on_next v)
                s.queue
            )
        in
          (fun () ->
            update
              (fun s ->
                { s with observers = unsubscribe_observer observer s.observers }
              )
          )
      ) in
    let observer =
      RxObserver.create
        ~on_completed:(fun () ->
          if_not_stopped
            (fun s ->
              RxAtomicData.unsafe_set { s with is_stopped = true } state;
              Queue.add RxCore.OnCompleted s.queue;
              List.iter
                (fun (on_completed, _, _) -> on_completed ())
                s.observers
            )
        )
        ~on_error:(fun e ->
          if_not_stopped
            (fun s ->
              RxAtomicData.unsafe_set { s with is_stopped = true } state;
              Queue.add (RxCore.OnError e) s.queue;
              List.iter
                (fun (_, on_error, _) -> on_error e)
                s.observers
            )
        )
        (fun v ->
          if_not_stopped
            (fun s ->
              Queue.add (RxCore.OnNext v) s.queue;
              List.iter
                (fun (_, _, on_next) -> on_next v)
                s.observers
            )
        ) in
    let unsubscribe () = update (fun s -> { s with observers = [] }) in
    ((observer, observable), unsubscribe)

end

module Behavior = struct
  type 'a t = {
    last_notification: 'a RxCore.notification;
    observers: 'a RxCore.observer list;
  }

  let create default_value =
    (* Implementation based on:
     * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subjects/BehaviorSubject.java
     *)
    let state = RxAtomicData.create {
      last_notification = RxCore.OnNext default_value;
      observers = [];
    } in
    let update f = RxAtomicData.update f state in
    let sync f = RxAtomicData.synchronize f state in
    let observable =
      (fun ((on_completed, on_error, on_next) as observer) ->
        let _ =
          sync
            (fun s ->
              let observers = observer :: s.observers in
              RxAtomicData.unsafe_set { s with observers } state;
              match s.last_notification with
              | RxCore.OnCompleted -> on_completed ()
              | RxCore.OnError e -> on_error e
              | RxCore.OnNext v -> on_next v
            )
        in
          (fun () ->
            update
              (fun s ->
                { s with observers = unsubscribe_observer observer s.observers }
              )
          )
      ) in
    let observer =
      RxObserver.create
        ~on_completed:(fun () ->
          sync
            (fun s ->
              RxAtomicData.unsafe_set
                { s with last_notification = RxCore.OnCompleted }
                state;
              List.iter
                (fun (on_completed, _, _) -> on_completed ())
                s.observers
            )
        )
        ~on_error:(fun e ->
          sync
            (fun s ->
              RxAtomicData.unsafe_set
                { s with last_notification = RxCore.OnError e }
                state;
              List.iter
                (fun (_, on_error, _) -> on_error e)
                s.observers
            )
        )
        (fun v ->
          sync
            (fun s ->
              match s.last_notification with
              | RxCore.OnNext _ ->
                  RxAtomicData.unsafe_set
                    { s with last_notification = RxCore.OnNext v }
                    state;
                  List.iter
                    (fun (_, _, on_next) -> on_next v)
                    s.observers
              | _ -> ()
            )
        ) in
    let unsubscribe () = update (fun s -> { s with observers = [] }) in
    ((observer, observable), unsubscribe)

end

module Async = struct
  type 'a t = {
    last_notification: 'a RxCore.notification option;
    is_stopped: bool;
    observers: 'a RxCore.observer list;
  }

  let emit_last_notification (on_completed, on_error, on_next) s =
    match s.last_notification with
    | Some RxCore.OnCompleted ->
        failwith "Bug in AsyncSubject: should not store \
                  RxCore.OnCompleted as last notificaition"
    | Some (RxCore.OnError e) ->
        on_error e
    | Some (RxCore.OnNext v) ->
        on_next v;
        on_completed ();
    | None -> ()

  let create () =
    (* Implementation based on:
     * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Linq/Reactive/Subjects/AsyncSubject.cs
     * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subjects/AsyncSubject.java
     *)
    let state = RxAtomicData.create {
      last_notification = None;
      is_stopped = false;
      observers = [];
    } in
    let update f = RxAtomicData.update f state in
    let sync f = RxAtomicData.synchronize f state in
    let if_not_stopped f = sync (fun s -> if not s.is_stopped then f s) in
    let observable =
      (fun observer ->
        let _ =
          sync
            (fun s ->
              let observers = observer :: s.observers in
              RxAtomicData.unsafe_set { s with observers } state;
              if s.is_stopped then begin
                emit_last_notification observer s
              end
            )
        in
          (fun () ->
            update
              (fun s ->
                { s with observers = unsubscribe_observer observer s.observers }
              )
          )
      ) in
    let observer =
      RxObserver.create
        ~on_completed:(fun () ->
          if_not_stopped
            (fun s ->
              RxAtomicData.unsafe_set { s with is_stopped = true } state;
              List.iter
                (fun observer -> emit_last_notification observer s)
                s.observers
            )
        )
        ~on_error:(fun e ->
          if_not_stopped
            (fun s ->
              RxAtomicData.unsafe_set
                { s with
                  is_stopped = true;
                  last_notification = Some (RxCore.OnError e);
                }
                state;
              List.iter
                (fun (_, on_error, _) -> on_error e)
                s.observers
            )
        )
        (fun v ->
          if_not_stopped
            (fun s ->
              RxAtomicData.unsafe_set
                { s with last_notification = Some (RxCore.OnNext v) }
                state;
            )
        ) in
    let unsubscribe () = update (fun s -> { s with observers = [] }) in
    ((observer, observable), unsubscribe)

end

