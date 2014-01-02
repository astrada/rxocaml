(* Internal module (see Rx.Subscription) *)

val empty : RxCore.subscription

val create : (unit -> unit) -> RxCore.subscription

val from_task : 'a Lwt.t -> RxCore.subscription

module type BooleanSubscription = sig
  type state

  val is_unsubscribed : state -> bool

end

module Boolean : sig
  include BooleanSubscription

  val create : (unit -> unit) -> (RxCore.subscription * state)

end

module Composite : sig
  exception CompositeException of exn list

  include BooleanSubscription

  val create : RxCore.subscription list -> (RxCore.subscription * state)

  val add : state -> RxCore.subscription -> unit

  val remove : state -> RxCore.subscription -> unit

  val clear : state -> unit

end

module MultipleAssignment : sig
  include BooleanSubscription

  val create : RxCore.subscription -> (RxCore.subscription * state)

  val set : state -> RxCore.subscription -> unit

end

module SingleAssignment : sig
  include BooleanSubscription

  val create : unit -> (RxCore.subscription * state)

  val set : state -> RxCore.subscription -> unit

end

