(* Internal module (see Rx.Observable) *)

module type O = sig
  val empty : 'a RxCore.observable

  val materialize :
    'a RxCore.observable -> 'a RxCore.notification RxCore.observable

  val from_enum : 'a BatEnum.t -> 'a RxCore.observable

  val to_enum : 'a RxCore.observable -> 'a BatEnum.t

  val count : 'a RxCore.observable -> int RxCore.observable

  val drop : int -> 'a RxCore.observable -> 'a RxCore.observable

  val take : int -> 'a RxCore.observable -> 'a RxCore.observable
  
  val take_last : int -> 'a RxCore.observable -> 'a RxCore.observable
  
  val single : 'a RxCore.observable -> 'a RxCore.observable

  module Blocking : sig
    val single : 'a RxCore.observable -> 'a

  end

end

module MakeObservable :
  functor(Scheduler : RxScheduler.S) -> O

module CurrentThread : O

