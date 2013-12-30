(* Internal module. (see Rx.Subscription)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/subscriptions/Subscriptions.java
 *)

type subscription = unit -> unit

let empty = (fun () -> ())

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
  type state = bool RxAtomicData.t

  let create unsubscribe =
    let is_unsubscribed = RxAtomicData.create false in
    let unsubscribe_wrapper () =
      let was_unsubscribed =
        RxAtomicData.compare_and_set false true is_unsubscribed in
      if not was_unsubscribed then unsubscribe ()
    in
    (unsubscribe_wrapper, is_unsubscribed)

  let is_unsubscribed state = RxAtomicData.unsafe_get state

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

  type state = State.t RxAtomicData.t

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
    let state = RxAtomicData.create {
      State.is_unsubscribed = false;
      subscriptions = subscriptions;
    } in
    let unsubscribe_wrapper () =
      let old_state =
        RxAtomicData.update_if
          (fun s -> not s.State.is_unsubscribed)
          (fun s -> State.unsubscribe s)
          state
      in
      let was_unsubscribed = old_state.State.is_unsubscribed in
      let subscriptions = old_state.State.subscriptions in
      if not was_unsubscribed then unsubscribe_from_all subscriptions
    in
    (unsubscribe_wrapper, state)

  let is_unsubscribed state =
    (RxAtomicData.unsafe_get state).State.is_unsubscribed

  let add state subscription =
    let old_state =
      RxAtomicData.update_if
        (fun s -> not s.State.is_unsubscribed)
        (fun s -> State.add s subscription)
        state
    in
    if old_state.State.is_unsubscribed then subscription ()

  let remove state subscription =
    let old_state =
      RxAtomicData.update_if
        (fun s -> not s.State.is_unsubscribed)
        (fun s -> State.remove s subscription)
        state
    in
    if not old_state.State.is_unsubscribed then subscription ()

  let clear state =
    let old_state =
      RxAtomicData.update_if
        (fun s -> not s.State.is_unsubscribed)
        (fun s -> State.clear s)
        state
    in
    let was_unsubscribed = old_state.State.is_unsubscribed in
    let subscriptions = old_state.State.subscriptions in
    if not was_unsubscribed then unsubscribe_from_all subscriptions

end

module MultipleAssignment = struct
  module State = struct
    type t = {
      is_unsubscribed: bool;
      subscription: subscription;
    }

    let unsubscribe state = {
      is_unsubscribed = true;
      subscription = state.subscription;
    }

    let set state subscription = {
      is_unsubscribed = state.is_unsubscribed;
      subscription = subscription;
    }

  end

  type state = State.t RxAtomicData.t

  let create subscription =
    let state = RxAtomicData.create {
      State.is_unsubscribed = false;
      State.subscription = subscription;
    } in
    let unsubscribe_wrapper () =
      let old_state =
        RxAtomicData.update_if
          (fun s -> not s.State.is_unsubscribed)
          (fun s -> State.unsubscribe s)
          state
      in
      let was_unsubscribed = old_state.State.is_unsubscribed in
      let subscription = old_state.State.subscription in
      if not was_unsubscribed then subscription ()
    in
    (unsubscribe_wrapper, state)

  let is_unsubscribed state =
    (RxAtomicData.unsafe_get state).State.is_unsubscribed

  let set state subscription =
    let old_state =
      RxAtomicData.update_if
        (fun s -> not s.State.is_unsubscribed)
        (fun s -> State.set s subscription)
        state
    in
    let was_unsubscribed = old_state.State.is_unsubscribed in
    if was_unsubscribed then subscription ()

end

