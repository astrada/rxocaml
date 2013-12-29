(* Internal module (see Rx.Observer) *)

type -'a observer = (unit -> unit) * (exn -> unit) * ('a -> unit)

val create :
  ?on_completed:(unit -> unit) ->
  ?on_error:(exn -> unit) ->
  ('a -> unit) ->
  'a observer

val checked : 'a observer -> 'a observer

val synchronize : 'a observer -> 'a observer

val synchronize_async_lock : 'a observer -> 'a observer

