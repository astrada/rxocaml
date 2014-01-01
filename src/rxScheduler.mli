(* Internal module. (see Rx.Scheduler) *)

module type Base = sig
  type t

  val schedule_absolute :
    ?due_time:float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

  val schedule_relative :
    float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

end

module type S = sig
  include Base

  val schedule_recursive :
    ((unit -> RxSubscription.subscription) -> RxSubscription.subscription) ->
    RxSubscription.subscription

end

module MakeScheduler :
  functor (BaseScheduler : Base) -> S

module CurrentThread : S

