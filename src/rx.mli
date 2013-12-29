(**
 RxOCaml is an OCaml implementation of {{:https://rx.codeplex.com/}Rx
 Observables}.
 *)

(**
 Provides a mechanism for receiving push-based notifications.
 
 An {i observer} is a triple of closures: [(on_completed, on_error, on_next)],
 where:
 - [on_completed: unit -> unit]
 - [on_error: exn -> unit]
 - [on_next: 'a -> unit]
 
 After an observer calls an observable's subscribe function, the
 observable calls the observer's third closure (on_next) to provide
 notifications. A well-behaved observable will call an observer's first
 closure (on_completed) exactly once or the observer's second closure
 (on_error) exactly once.
 
 The first closure ([on_completed]) notifies the observer that the provider
 has finished sending push-based notifications. 
 The observable will not call this closure if it calls [on_error].
 
 The second closure ([on_error]) notifies the observer that the provider has
 experienced an error condition.
 If the observable calls this closure, it will not thereafter call [on_next]
 or [on_completed].
 
 The third closure ([on_next]) provides the observer with new data. 
 The observable calls this closure 1 or more times, unless it calls
 [on_error] in which case this closure may never be called.
 The observable will not call this closure again after it calls either
 [on_completed] or [on_error].
 
 For more information see the
 {{:https://github.com/Netflix/RxJava/wiki/Observable}RxJava Wiki}
 *)
type -'a observer =
  (* on_completed: *) (unit -> unit) *
  (* on_error: *) (exn -> unit) *
  (* on_next: *) ('a -> unit)

(**
 Subscription returns from observable's subscribe function to allow
 unsubscribing.
 
 A {i subscription} is a closure: [unsubscribe: unit -> unit].

 The unsubscribe function stops the notifications on the observer that was
 registered when this Subscription was received.
 This allows unregistering an observer before it has finished receiving all
 events (ie. before [on_completed] is called).
 
 This type is the RxOCaml equivalent of [IDisposable] in Microsoft's Rx
 implementation.
 *)
type subscription =
  (* unsubscribe: *) unit -> unit

(**
 The observable type that implements the Reactive Pattern.

 An {i observable} is a closure: [subscribe: 'a observer -> subscription].
 
 An observer must call an observable's subscribe function in
 order to receive items and notifications from the observable.
 An observable is responsible for accepting all subscriptions and notifying
 all Observers. Unless the documentation for a particular observable
 implementation indicates otherwise, Observers should make no assumptions
 about the order in which multiple Observers will receive their
 notifications.
 
 For more information see the
 {{:https://github.com/Netflix/RxJava/wiki/Observable}RxJava Wiki}
 *)
type +'a observable =
  (* subscribe: *) 'a observer -> subscription

(** Provides a set of functions for creating observers. *)
module Observer : sig

  (**
   Creates an observer from the specified closures.
   
   [create on_next] create an observer from the [on_next] closure.
   
   @param on_completed The [on_completed] closure. The default
   implementation does nothing.
   @param on_error The [on_error] closure. The default implementation raises
   the received exception
   *)
  val create :
    ?on_completed:(unit -> unit) ->
    ?on_error:(exn -> unit) ->
    ('a -> unit) ->
    'a observer

  (**
   Checks access to the observer for grammar violations. This includes
   checking for multiple [on_error] or [on_completed] calls, as well as
   reentrancy in any of the observer closures.
   If a violation is detected, a [Failure] exception is raised from the
   offending observer call.
   *)
  val checked : 'a observer -> 'a observer

  (**
   Synchronizes access to the observer such that its callback functions
   cannot be called concurrently from multiple threads. This function is
   useful when coordinating access to an observer. Notice reentrant observer
   callbacks on the same thread are still possible.
   *)
  val synchronize : 'a observer -> 'a observer

  (**
   Synchronizes access to the observer such that its callback methods
   cannot be called concurrently, using an asynchronous lock to protect
   against concurrent and reentrant access.  This function is useful when
   coordinating access to an observer.
   *)
  val synchronize_async_lock : 'a observer -> 'a observer

end

(** Provides a set of functions for creating subscriptions. *)
module Subscription : sig

  (** A subscription that does nothing. *)
  val create_empty : unit -> subscription

  (** A subscription which invokes the given closure when unsubscribed. *)
  val create : (unit -> unit) -> subscription

  (** A subscription that wraps a task (Lwt cancelable thread) and cancels it
   when unsubscribed. *)
  val from_task : 'a Lwt.t -> subscription

  (**
   Subscription that can be checked for status such as in a loop inside an
   observable to exit the loop if unsubscribed.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.booleandisposable.aspx> Rx.Net equivalent BooleanDisposable
   *)
  module type BooleanSubscription = sig
    type state

    val is_unsubscribed : state -> bool

  end

  module Boolean : sig
    include BooleanSubscription

    val create : (unit -> unit) -> (subscription * state)

  end

  (**
   Subscription that represents a group of subscriptions that are unsubscribed
   together.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.compositedisposable.aspx> Rx.Net equivalent CompositeDisposable
   *)
  module Composite : sig
    exception CompositeException of exn list

    include BooleanSubscription

    val create : subscription list -> (subscription * state)

    val add : state -> subscription -> unit

    val remove : state -> subscription -> unit

    val clear : state -> unit

  end

end

