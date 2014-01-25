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

(** Represents a notification to an observer. *)
type 'a notification =
  | OnCompleted
  (** Represents an [on_completed] notification to an observer. *)
  | OnError of exn
  (** Represents an [on_error] notification to an observer. *)
  | OnNext of 'a
  (** Represents an [on_next] notification to an observer. *)

(**
 Represents both an observable sequence as well as an observer. Each
 notification is broadcasted to all subscribed observers.
 *)
type 'a subject = 'a observer * 'a observable

module type MutableData = sig

  type 'a t

  val create : 'a -> 'a t

  val get : 'a t -> 'a

  val set : 'a -> 'a t -> unit

end

module DataRef : MutableData

