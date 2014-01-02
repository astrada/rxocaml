(**
 RxOCaml is an OCaml implementation of {{:https://rx.codeplex.com/}Rx
 Observables}.
 *)

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
  (* subscribe: *) 'a RxCore.observer -> subscription

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
    'a RxCore.observer

  (**
   Checks access to the observer for grammar violations. This includes
   checking for multiple [on_error] or [on_completed] calls, as well as
   reentrancy in any of the observer closures.
   If a violation is detected, a [Failure] exception is raised from the
   offending observer call.
   *)
  val checked : 'a RxCore.observer -> 'a RxCore.observer

  (**
   Synchronizes access to the observer such that its callback functions
   cannot be called concurrently from multiple threads. This function is
   useful when coordinating access to an observer. Notice reentrant observer
   callbacks on the same thread are still possible.
   *)
  val synchronize : 'a RxCore.observer -> 'a RxCore.observer

  (**
   Synchronizes access to the observer such that its callback methods
   cannot be called concurrently, using an asynchronous lock to protect
   against concurrent and reentrant access.  This function is useful when
   coordinating access to an observer.
   *)
  val synchronize_async_lock : 'a RxCore.observer -> 'a RxCore.observer

end

(** Provides a set of functions for creating subscriptions. *)
module Subscription : sig

  (** A subscription that does nothing. *)
  val empty : subscription

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

  (**
   Subscription whose underlying subscription can be swapped for another
   subscription.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.multipleassignmentdisposable> Rx.Net equivalent MultipleAssignmentDisposable
   *)
  module MultipleAssignment : sig
    include BooleanSubscription

    val create : subscription -> (subscription * state)

    val set : state -> subscription -> unit

  end

  (**
   Subscription which only allows a single assignment of its underlying
   subscription. If an underlying subscription has already been
   set, future attempts to set the underlying disposable resource will raise
   [Failure "SingleAssignment"].

   @see <https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Disposables/SingleAssignmentDisposable.cs> Rx.Net equivalent SingleAssignmentDisposable
   *)
  module SingleAssignment : sig
    include BooleanSubscription

    val create : unit -> (subscription * state)

    val set : state -> subscription -> unit

  end

end

(** Represents an object that schedules units of work. *)
module Scheduler : sig

  module type Base = sig
    type t

    val schedule_absolute :
      ?due_time:float -> (unit -> subscription) -> subscription

    val schedule_relative :
      float -> (unit -> subscription) -> subscription

  end

  module type S = sig
    include Base

    val schedule_recursive :
      ((unit -> subscription) -> subscription) -> subscription

  end

  module MakeScheduler :
    functor (BaseScheduler : Base) -> S

  (**
   Schedules work on the current thread but does not execute immediately.
   Work is put in a queue and executed after the current unit of work is
   completed.
   *)
  module CurrentThread : S

end

module Observable : sig
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
    functor(Scheduler : Scheduler.S) -> O

  module CurrentThread : O

end

