(* Internal module (see Rx.Observer) *)

val create :
  ?on_completed:(unit -> unit) ->
  ?on_error:(exn -> unit) ->
  ('a -> unit) ->
  'a RxCore.observer

module type ObserverState = sig

  type 'a state

  val initial_state : unit -> 'a state

  val on_completed : 'a state -> 'a state

  val on_error : exn -> 'a state -> 'a state

  val on_next : 'a -> 'a state -> 'a state

end

module MakeObserverWithState :
    functor (O : ObserverState) ->
    functor (D : RxCore.MutableData) -> sig

  val create : unit -> ('a RxCore.observer * 'a O.state D.t)

end

val checked : 'a RxCore.observer -> 'a RxCore.observer

val synchronize : 'a RxCore.observer -> 'a RxCore.observer

val synchronize_async_lock : 'a RxCore.observer -> 'a RxCore.observer

