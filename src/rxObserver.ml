(* Internal module (see Rx.Observer)
 *
 * Implementation based on:
 * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Observer.Extensions.cs
 *)

let create
    ?(on_completed = fun () -> ())
    ?(on_error = fun e -> raise e)
    on_next = 
  (on_completed, on_error, on_next)

module ObserverBase = struct
  (* Original implementation:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/ObserverBase.cs
   *)
  let create (on_completed, on_error, on_next) =
    let is_stopped = RxAtomicData.create false in
    let stop () =
      RxAtomicData.compare_and_set false true is_stopped in
    let on_completed' () =
      let was_stopped = stop () in
      if not was_stopped then on_completed ()
    in
    let on_error' e =
      let was_stopped = stop () in
      if not was_stopped then on_error e
    in
    let on_next' x =
      if not (RxAtomicData.unsafe_get is_stopped) then on_next x
    in
    (on_completed', on_error', on_next')

end

module CheckedObserver = struct
  (* In the original implementation, synchronization for the observer state
   * is obtained through CAS (compare-and-swap) primitives, but in OCaml we
   * don't have a standard/portable CAS primitive, so I'm using a mutex.
   * (see https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Internal/CheckedObserver.cs)
   *)
  type state = Idle | Busy | Done

  let create (on_completed, on_error, on_next) =
    let state = RxAtomicData.create Idle in
    let check_access () =
      RxAtomicData.update
        (fun s ->
          match s with
          | Idle ->
              Busy
          | Busy ->
              failwith "Reentrancy has been detected."
          | Done ->
              failwith "Observer has already terminated."
        ) state
    in
    let wrap_action thunk new_state =
      check_access ();
      Utils.try_finally
        thunk
        (fun () -> RxAtomicData.set new_state state)
    in
    let on_completed' () = wrap_action (fun () -> on_completed ()) Done in
    let on_error' e = wrap_action (fun () -> on_error e) Done in
    let on_next' x = wrap_action (fun () -> on_next x) Idle in
    (on_completed', on_error', on_next')

end

let checked observer = CheckedObserver.create observer

module SynchronizedObserver = struct
  (* Original implementation:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Internal/SynchronizedObserver.cs
   *)
  let create (on_completed, on_error, on_next) =
    let lock = BatRMutex.create () in
    let on_completed' () = BatRMutex.synchronize ~lock on_completed () in
    let on_error' e = BatRMutex.synchronize ~lock on_error e in
    let on_next' x = BatRMutex.synchronize ~lock on_next x in
    (on_completed', on_error', on_next')

end

let synchronize observer = SynchronizedObserver.create observer

module AsyncLockObserver = struct
  (* Original implementation:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Internal/AsyncLockObserver.cs
   *)
  let create (on_completed, on_error, on_next) =
    let async_lock = RxAsyncLock.create () in
    let wrap_action thunk = RxAsyncLock.wait async_lock thunk in
    let on_completed' () = wrap_action (fun () -> on_completed ()) in
    let on_error' e = wrap_action (fun () -> on_error e) in
    let on_next' x = wrap_action (fun () -> on_next x) in
    ObserverBase.create (on_completed', on_error', on_next')

end

let synchronize_async_lock observer = AsyncLockObserver.create observer

