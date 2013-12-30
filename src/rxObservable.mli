(* Internal module (see Rx.Observable) *)

type +'a observable = 'a RxObserver.observer -> RxSubscription.subscription

val empty : 'a observable

val from_enum : 'a BatEnum.t -> 'a observable

val count : 'a observable -> int observable

