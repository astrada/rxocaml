(* Internal module (see Rx.Subscription) *)

type subscription = unit -> unit

val create_empty : unit -> subscription

val create : (unit -> unit) -> subscription

val from_task : 'a Lwt.t -> subscription

module type BooleanSubscription = sig
  type state

  val is_unsubscribed : state -> bool

end

module Boolean : sig
  include BooleanSubscription

  val create : (unit -> unit) -> (subscription * state)

end

module Composite : sig
  exception CompositeException of exn list

  include BooleanSubscription

  val create : subscription list -> (subscription * state)

  val add : state -> subscription -> unit

  val remove : state -> subscription -> unit

  val clear : state -> unit

end

