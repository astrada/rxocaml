(**
 RxOCaml is an OCaml implementation of {{:https://rx.codeplex.com/}Rx
 Observables}.
 *)

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
  val empty : RxCore.subscription

  (** A subscription which invokes the given closure when unsubscribed. *)
  val create : (unit -> unit) -> RxCore.subscription

  (** A subscription that wraps a task (Lwt cancelable thread) and cancels it
   when unsubscribed. *)
  val from_task : 'a Lwt.t -> RxCore.subscription

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

    val create : (unit -> unit) -> (RxCore.subscription * state)

  end

  (**
   Subscription that represents a group of subscriptions that are unsubscribed
   together.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.compositedisposable.aspx> Rx.Net equivalent CompositeDisposable
   *)
  module Composite : sig
    exception CompositeException of exn list

    include BooleanSubscription

    val create : RxCore.subscription list -> (RxCore.subscription * state)

    val add : state -> RxCore.subscription -> unit

    val remove : state -> RxCore.subscription -> unit

    val clear : state -> unit

  end

  (**
   Subscription whose underlying subscription can be swapped for another
   subscription.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.multipleassignmentdisposable> Rx.Net equivalent MultipleAssignmentDisposable
   *)
  module MultipleAssignment : sig
    include BooleanSubscription

    val create : RxCore.subscription -> (RxCore.subscription * state)

    val set : state -> RxCore.subscription -> unit

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

    val create : unit -> (RxCore.subscription * state)

    val set : state -> RxCore.subscription -> unit

  end

end

(** Represents an object that schedules units of work. *)
module Scheduler : sig

  module type Base = sig
    type t

    val now : unit -> float

    val schedule_absolute :
      ?due_time:float -> (unit -> RxCore.subscription) -> RxCore.subscription

  end

  module type S = sig
    include Base

    val schedule_relative :
      float -> (unit -> RxCore.subscription) -> RxCore.subscription

    val schedule_recursive :
      ((unit -> RxCore.subscription) -> RxCore.subscription) ->
      RxCore.subscription

  end

  module MakeScheduler :
    functor (BaseScheduler : Base) -> S

  (**
   Schedules work on the current thread but does not execute immediately.
   Work is put in a queue and executed after the current unit of work is
   completed.
   *)
  module CurrentThread : S

  (**
   Executes work immediately on the current thread.
   *)
  module Immediate : S

  (**
   Schedules work on a new thread.
   *)
  module NewThread : S

end

module Observable : sig

  val empty : 'a RxCore.observable

  val error : exn -> 'a RxCore.observable

  val never : 'a RxCore.observable

  val return : 'a -> 'a RxCore.observable

  val materialize :
    'a RxCore.observable -> 'a RxCore.notification RxCore.observable

  val dematerialize :
    'a RxCore.notification RxCore.observable -> 'a RxCore.observable

  val to_enum : 'a RxCore.observable -> 'a BatEnum.t

  val length : 'a RxCore.observable -> int RxCore.observable

  val drop : int -> 'a RxCore.observable -> 'a RxCore.observable

  val take : int -> 'a RxCore.observable -> 'a RxCore.observable

  val take_last : int -> 'a RxCore.observable -> 'a RxCore.observable

  val single : 'a RxCore.observable -> 'a RxCore.observable

  val append :
    'a RxCore.observable -> 'a RxCore.observable -> 'a RxCore.observable

  val merge : 'a RxCore.observable RxCore.observable -> 'a RxCore.observable

  val map : ('a -> 'b) -> 'a RxCore.observable -> 'b RxCore.observable

  val bind :
    'a RxCore.observable -> ('a -> 'b RxCore.observable) ->
    'b RxCore.observable

  module Blocking : sig
    val single : 'a RxCore.observable -> 'a

  end

  module type Scheduled = sig
    val subscribe_on_this : 'a RxCore.observable -> 'a RxCore.observable

    val from_enum : 'a BatEnum.t -> 'a RxCore.observable

  end

  module MakeScheduled :
    functor(Scheduler : Scheduler.S) -> Scheduled

  module CurrentThread : Scheduled

  module Immediate : Scheduled

  module NewThread : Scheduled

end

