(* Internal module (see Rx.Observer) *)

val create :
  ?on_completed:(unit -> unit) ->
  ?on_error:(exn -> unit) ->
  ('a -> unit) ->
  'a RxCore.observer

val checked : 'a RxCore.observer -> 'a RxCore.observer

val synchronize : 'a RxCore.observer -> 'a RxCore.observer

val synchronize_async_lock : 'a RxCore.observer -> 'a RxCore.observer

