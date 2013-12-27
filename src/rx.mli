(**
 * RxOCaml is an OCaml implementation of {{https://rx.codeplex.com/}Rx
 * Observables}.
 *)

type -'a observer =
  (* on_next: *) ('a -> unit) *
  (* on_error: *) (exn -> unit) *
  (* on_completed: *) (unit -> unit)
(**
 * Provides a mechanism for receiving push-based notifications.
 *
 * After an Observer calls an [observable]'s subscribe function, the
 * Observable calls the Observer's first closure (on_next) to provide
 * notifications. A well-behaved Observable will call an Observer's third
 * closure (on_completed) exactly once or the Observer's second closure
 * (on_error) exactly once.
 *
 * For more information see the
 * {{https://github.com/Netflix/RxJava/wiki/Observable}RxJava Wiki}
 *)

type subscription =
  (* unsubscribe: *) unit -> unit
(**
 * Subscription returns from {Observable.subscribe(Observer)} to allow
 * unsubscribing.
 *
 * This type is the RxOCaml equivalent of {IDisposable} in Microsoft's Rx
 * implementation.
 *)

type +'a observable =
  (* subscribe: *) 'a observer -> subscription
(**
 * The Observable type that implements the Reactive Pattern.
 *
 * This interface provides overloaded methods for subscribing as well as
 * delegate methods to the various operators.
 *
 * For more information see the
 * {{https://github.com/Netflix/RxJava/wiki/Observable}RxJava Wiki}
 *)

module Observer : sig
  val create :
    ?on_error:(exn -> unit) ->
    ?on_completed:(unit -> unit) ->
    ('a -> unit) ->
    'a observer

  val checked : 'a observer -> 'a observer

  val synchronize : 'a observer -> 'a observer

  val synchronize_async_lock : 'a observer -> 'a observer

end

