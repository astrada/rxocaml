(* Internal module. (see Rx.Subscription)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subscriptions/Subscriptions.java
 *)

type subscription = unit -> unit

let create_empty () = (fun () -> ())

let create unsubscribe =
  (* Wrap the unsubscribe function in a lazy value, to get idempotency. *)
  let idempotent_thunk = lazy (unsubscribe ()) in
  (fun () -> Lazy.force idempotent_thunk)

let from_task task =
  (fun () -> Lwt.cancel task)

module type BooleanSubscription = sig
  type state

  val is_unsubscribed : state -> bool

end

module Boolean = struct
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subscriptions/BooleanSubscription.java
   *)
  type state = {
    mutable is_unsubscribed: bool;
    mutex: Mutex.t;
  }

  let create unsubscribe =
    let state = {
      is_unsubscribed = false;
      mutex = Mutex.create ();
    } in
    let unsubscribe_wrapper () =
      let set_unsubscribed () =
        BatMutex.synchronize ~lock:state.mutex
          (fun () ->
            if not state.is_unsubscribed then begin
              state.is_unsubscribed <- true;
              false
            end else true
          ) ()
      in
      let is_unsubscribed = set_unsubscribed () in
      if not is_unsubscribed then unsubscribe ()
    in
    (unsubscribe_wrapper, state)

  let is_unsubscribed state = state.is_unsubscribed

end

module Composite = struct
  (* Implementation based on:
   * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subscriptions/CompositeSubscription.java
   *)
  exception CompositeException of exn list

  module State = struct
    type t = {
      is_unsubscribed: bool;
      subscriptions: subscription list;
    }

    let unsubscribe state = {
      is_unsubscribed = true;
      subscriptions = state.subscriptions;
    }

    let add state subscription = {
      is_unsubscribed = state.is_unsubscribed;
      subscriptions = state.subscriptions @ [subscription];
    }

    let remove state subscription = {
      is_unsubscribed = state.is_unsubscribed;
      subscriptions =
        List.filter (fun s -> s != subscription) state.subscriptions;
    }

    let clear state = {
      is_unsubscribed = state.is_unsubscribed;
      subscriptions = [];
    }

  end

  type state = {
    mutable state: State.t;
    mutex: Mutex.t;
  }

  let unsubscribe_from_all subscriptions =
    let exceptions =
      List.fold_left
        (fun exns unsubscribe ->
          try
            unsubscribe ();
            exns
          with e ->
            e :: exns)
        []
        subscriptions
    in
    if List.length exceptions > 0 then
      raise (CompositeException exceptions)

  let create subscriptions =
    let state = {
      state = {
        State.is_unsubscribed = false;
        State.subscriptions = subscriptions;
      };
      mutex = Mutex.create ();
    } in
    let unsubscribe_wrapper () =
      let set_unsubscribed () =
        BatMutex.synchronize ~lock:state.mutex
          (fun () ->
            if not state.state.State.is_unsubscribed then begin
              let subscriptions = state.state.State.subscriptions in
              state.state <- State.unsubscribe state.state;
              (false, subscriptions)
            end else (true, [])
          ) ()
      in
      let (is_unsubscribed, subscriptions) = set_unsubscribed () in
      if not is_unsubscribed then
        unsubscribe_from_all subscriptions
    in
    (unsubscribe_wrapper, state)

  let is_unsubscribed state = state.state.State.is_unsubscribed

  let add state subscription =
    let is_unsubscribed =
      BatMutex.synchronize ~lock:state.mutex
        (fun () ->
          if not state.state.State.is_unsubscribed then begin
            state.state <- State.add state.state subscription;
            false
          end else true
        ) ()
    in
    if is_unsubscribed then subscription ()

  let remove state subscription =
    let is_unsubscribed =
      BatMutex.synchronize ~lock:state.mutex
        (fun () ->
          if not state.state.State.is_unsubscribed then begin
            state.state <- State.remove state.state subscription;
            false
          end else true
        ) ()
    in
    if not is_unsubscribed then subscription ()

  let clear state =
    let (is_unsubscribed, subscriptions) =
      BatMutex.synchronize ~lock:state.mutex
        (fun () ->
          if not state.state.State.is_unsubscribed then begin
            let subscriptions = state.state.State.subscriptions in
            state.state <- State.clear state.state;
            (false, subscriptions)
          end else (true, [])
        ) ()
    in
    if not is_unsubscribed then
      unsubscribe_from_all subscriptions

end

