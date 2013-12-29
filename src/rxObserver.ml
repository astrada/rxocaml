(* Internal module (see Rx.Observer)
 *
 * Implementation based on:
 * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Observer.Extensions.cs
 *)

type -'a observer = (unit -> unit) * (exn -> unit) * ('a -> unit)

let create
    ?(on_completed = fun () -> ())
    ?(on_error = fun e -> raise e)
    on_next = 
  (on_completed, on_error, on_next)

module ObserverBase = struct
  (* Original implementation:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/ObserverBase.cs
   *)
  type t = {
    mutable is_stopped: bool;
    mutex: Mutex.t
  }

  let create (on_completed, on_error, on_next) =
    let observer_state = {
      is_stopped = false;
      mutex = Mutex.create ();
    } in
    let synchronize thunk =
      BatMutex.synchronize ~lock:observer_state.mutex thunk () in
    let stop () =
      synchronize (
        fun () ->
          if not observer_state.is_stopped then begin
            observer_state.is_stopped <- true;
            true
          end else false
      ) in
    let on_completed' () =
      let was_running = stop () in
      if was_running then on_completed ()
    in
    let on_error' e =
      let was_running = stop () in
      if was_running then on_error e
    in
    let on_next' x =
      if not observer_state.is_stopped then on_next x
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
  type t = {
    mutable state: state;
    mutex: Mutex.t
  }

  let create (on_completed, on_error, on_next) =
    let observer_state = {
      state = Idle;
      mutex = Mutex.create ();
    } in
    let synchronize thunk =
      BatMutex.synchronize ~lock:observer_state.mutex thunk () in
    let check_access () =
      synchronize
        (fun () ->
          match observer_state.state with
          | Idle ->
              observer_state.state <- Busy
          | Busy ->
              failwith "Reentrancy has been detected."
          | Done ->
              failwith "Observer has already terminated."
        )
    in
    let wrap_action thunk new_state =
      check_access ();
      Utils.try_finally
        thunk
        (fun () ->
          synchronize (fun () -> observer_state.state <- new_state)
        )
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
    let mutex = BatRMutex.create () in
    let on_completed' () =
      BatRMutex.synchronize ~lock:mutex on_completed ()
    in
    let on_error' e = BatRMutex.synchronize ~lock:mutex on_error e in
    let on_next' x = BatRMutex.synchronize ~lock:mutex on_next x in
    (on_completed', on_error', on_next')

end

let synchronize observer = SynchronizedObserver.create observer

module AsyncLockObserver = struct
  (* Original implementation:
   * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Internal/AsyncLockObserver.cs
   *)
  let create (on_completed, on_error, on_next) =
    let async_lock = AsyncLock.create () in
    let wrap_action thunk = AsyncLock.wait async_lock thunk in
    let on_completed' () = wrap_action (fun () -> on_completed ()) in
    let on_error' e = wrap_action (fun () -> on_error e) in
    let on_next' x = wrap_action (fun () -> on_next x) in
    ObserverBase.create (on_completed', on_error', on_next')

end

let synchronize_async_lock observer = AsyncLockObserver.create observer

