(* Internal module (see Rx.Observable) *)

val empty : 'a RxCore.observable

val error : exn -> 'a RxCore.observable

val never : 'a RxCore.observable

val materialize :
  'a RxCore.observable -> 'a RxCore.notification RxCore.observable

val dematerialize :
  'a RxCore.notification RxCore.observable -> 'a RxCore.observable

val to_enum : 'a RxCore.observable -> 'a BatEnum.t

val length : 'a RxCore.observable -> int RxCore.observable

val drop : int -> 'a RxCore.observable -> 'a RxCore.observable

val take : int -> 'a RxCore.observable -> 'a RxCore.observable

val take_last : int -> 'a RxCore.observable -> 'a RxCore.observable

val single : 'a RxCore.observable -> 'a RxCore.observable

val append :
  'a RxCore.observable -> 'a RxCore.observable -> 'a RxCore.observable

val merge : 'a RxCore.observable RxCore.observable -> 'a RxCore.observable

val map : ('a -> 'b) -> 'a RxCore.observable -> 'b RxCore.observable

val return : 'a -> 'a RxCore.observable

val bind :
  'a RxCore.observable -> ('a -> 'b RxCore.observable) ->
  'b RxCore.observable

module Blocking : sig
  val single : 'a RxCore.observable -> 'a

end

module type Scheduled = sig

  val empty : 'a RxCore.observable

  val error : exn -> 'a RxCore.observable

  val from_enum : 'a BatEnum.t -> 'a RxCore.observable

  val return : 'a -> 'a RxCore.observable

end

module MakeScheduled :
  functor(Scheduler : RxScheduler.S) -> Scheduled

module CurrentThread : Scheduled

