(* Internal module. (see Rx.Scheduler) *)

module type Scheduler = sig
  type t

  val schedule_absolute :
    ?due_time:float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

  val schedule_relative :
    float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

  val schedule_recursive :
    ((unit -> RxSubscription.subscription) -> RxSubscription.subscription) ->
    RxSubscription.subscription

end

module CurrentThread : Scheduler

