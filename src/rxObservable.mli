(* Internal module (see Rx.Observable) *)

type +'a observable = 'a RxObserver.observer -> RxSubscription.subscription

module type O = sig
  val empty : 'a observable

  val materialize : 'a observable -> 'a RxCore.notification observable

  val from_enum : 'a BatEnum.t -> 'a observable

  val to_enum : 'a observable -> 'a BatEnum.t

  val count : 'a observable -> int observable

  val drop : int -> 'a observable -> 'a observable

  val take : int -> 'a observable -> 'a observable
  
  val take_last : int -> 'a observable -> 'a observable
  
  val single : 'a observable -> 'a observable

  module Blocking : sig
    val single : 'a observable -> 'a

  end

end

module MakeObservable :
  functor(Scheduler : RxScheduler.S) -> O

module CurrentThread : O

