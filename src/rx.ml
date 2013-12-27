type -'a observer =
  (* on_next: *) ('a -> unit) *
  (* on_error: *) (exn -> unit) *
  (* on_completed: *) (unit -> unit)

type subscription =
  (* unsubscribe: *) unit -> unit

type +'a observable =
  (* subscribe: *) 'a observer -> subscription

module Observer = struct
  let create
      ?(on_error = fun e -> raise e)
      ?(on_completed = fun () -> ())
      on_next = 
    (on_next, on_error, on_completed)

  module Checked = struct
    type state = Idle | Busy | Done
    type t = {
      mutable state: state;
      mutex: Mutex.t
    }

    let create (on_next, on_error, on_completed) =
      let observer_state = {
        state = Idle;
        mutex = Mutex.create();
      } in
      let with_lock thunk =
        Utils.with_lock observer_state.mutex thunk in
      let check_access () =
        with_lock
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
            with_lock (fun () -> observer_state.state <- new_state)
          )
      in
      let on_next' x = wrap_action (fun () -> on_next x) Idle in
      let on_error' e = wrap_action (fun () -> on_error e) Done in
      let on_completed' () = wrap_action (fun () -> on_completed ()) Done in
      (on_next', on_error', on_completed')

  end

  let checked observer = Checked.create observer

end

