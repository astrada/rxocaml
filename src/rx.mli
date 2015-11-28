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

  (** Specifies the state of a stateful observer. *)
  module type ObserverState = sig

    (** Observer's state type. *)
    type 'a state

    (** Observer's initial state. *)
    val initial_state : unit -> 'a state

    (** Observer's [on_completed] function that gets the current observer's
     state and returns the updated state. *)
    val on_completed : 'a state -> 'a state

    (** Observer's [on_error] function that gets an exception and the current
     observer's state and returns the updated state. *)
    val on_error : exn -> 'a state -> 'a state

    (** Observer's [on_next] function that gets a value and the current
     observer's state and returns the updated state. *)
    val on_next : 'a -> 'a state -> 'a state

  end

  (** Builds a stateful observer from a module that implements [ObserverState]
   and a module that implements the mutable state storage. *)
  module MakeObserverWithState :
      functor (O : ObserverState) ->
      functor (D : RxCore.MutableData) -> sig

    (** Creates a stateful observer. Returns the observer and its state. *)
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

    (** Subscription state. *)
    type state

    (** Checks if the current subscription has been unsubscribed. *)
    val is_unsubscribed : state -> bool

  end

  module Boolean : sig

    include BooleanSubscription

    (** Creates a boolean subscription. Returns the subscription and its
     state. *)
    val create : (unit -> unit) -> (RxCore.subscription * state)

  end

  (**
   Subscription that represents a group of subscriptions that are unsubscribed
   together.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.compositedisposable.aspx> Rx.Net equivalent CompositeDisposable
   *)
  module Composite : sig

    (** List of exceptions thrown by the subscriptions that failed. *)
    exception CompositeException of exn list

    include BooleanSubscription

    (** Creates a composite subscription from a list of subscriptions. Returns
     the subscription and its state. *)
    val create : RxCore.subscription list -> (RxCore.subscription * state)

    (** Adds a new subscription to the composite subscription. If the
     composite subscription is already unsubscribed, the added subscription
     will be unsubscribed too. *)
    val add : state -> RxCore.subscription -> unit

    (** Removes (and unsubscribes) an existing subscription from the composite
     subscription. *)
    val remove : state -> RxCore.subscription -> unit

    (** Clears the composite subscription and unsubscribes from all the
     subscriptions contained. *)
    val clear : state -> unit

  end

  (**
   Subscription whose underlying subscription can be swapped for another
   subscription.

   @see <http://msdn.microsoft.com/en-us/library/system.reactive.disposables.multipleassignmentdisposable> Rx.Net equivalent MultipleAssignmentDisposable
   *)
  module MultipleAssignment : sig
    include BooleanSubscription

    (** Creates a multiple assignment subscription from a subscription. Returns
     the subscription and its state. *)
    val create : RxCore.subscription -> (RxCore.subscription * state)

    (** Sets the underlying subscription. *)
    val set : state -> RxCore.subscription -> unit

  end

  (**
   Subscription which only allows a single assignment of its underlying
   subscription. If an underlying subscription has already been set, future
   attempts to set the underlying subscription will raise [Failure
   "SingleAssignment"].

   @see <https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Disposables/SingleAssignmentDisposable.cs> Rx.Net equivalent SingleAssignmentDisposable
   *)
  module SingleAssignment : sig
    include BooleanSubscription

    (** Creates a single assignment subscription from a subscription. Returns
     the subscription and its state. *)
    val create : unit -> (RxCore.subscription * state)

    (** Sets the underlying subscription. If an underlying
     subscription has already been set, the function will raise [Failure
     "SingleAssignment"]. *)
    val set : state -> RxCore.subscription -> unit

  end

end

(** Represents an object that schedules units of work. *)
module Scheduler : sig

  (** Basic scheduler implementation *)
  module type Base = sig
    
    (** Scheduler state. *)
    type t

    (** Returns the current timestamp. *)
    val now : unit -> float

    (** [schedule_absolute ?due_time action] schedules an [action] to be
     executed at [due_time]. If [due_time] is omitted, the action will be
     performed as soon as possible. *)
    val schedule_absolute :
      ?due_time:float -> (unit -> RxCore.subscription) -> RxCore.subscription

  end

  module type S = sig

    include Base

    (** [schedule_relative delay action] schedules an [action] to be
     executed after [delay] seconds from now. *)
    val schedule_relative :
      float -> (unit -> RxCore.subscription) -> RxCore.subscription

    (** [schedule_recursive action] schedules a recursive [action] to be
     executed as soon as possible. The [action] takes the next recursive step
     (continuation) as parameter. *)
    val schedule_recursive :
      ((unit -> RxCore.subscription) -> RxCore.subscription) ->
      RxCore.subscription

    val schedule_periodically :
      ?initial_delay:float -> float -> (unit -> RxCore.subscription) ->
      RxCore.subscription

  end

  (** Builds a scheduler from its core function implementation. *)
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

  (**
   Schedules work using Lwt.
   *)
  module Lwt : S

  (**
   Virtual time scheduler used for testing applications and libraries built
   using Reactive Extensions.
   *)
  module Test : sig
    include S

    (** Current timestamp in seconds. *)
    val now : unit -> float

    (**
     [trigger_actions target_time] triggers all scheduled actions until
     [target_time] seconds.
     *)
    val trigger_actions : float -> unit

    (**
     [trigger_actions_until_now ()] triggers all scheduled actions until
     [now].
     *)
    val trigger_actions_until_now : unit -> unit

    (**
     [advance_time_to target_time] sets the current timestamp to [target_time]
     and triggers all actions until that time.
     *)
    val advance_time_to : float -> unit

    (**
     [advance_time_by dealy] advances the current timestamp by [delay] seconds
     and triggers all actions until that time.
     *)
    val advance_time_by : float -> unit

  end

end

(** Observable combinators. *)
module Observable : sig

  (**
   Returns an observable that emits no items to the observer and
   immediately invokes its [on_completed] closure.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/empty.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#empty-error-and-never> RxJava Wiki: empty()
   @see <http://msdn.microsoft.com/en-us/library/hh229670.aspx> MSDN: Observable.Empty
   *)
  val empty : 'a RxCore.observable

  (**
   Returns an observable that invokes an observer's [on_error] closure when
   the observer subscribes to it.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/error.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#empty-error-and-never> RxJava Wiki: error()
   @see <http://msdn.microsoft.com/en-us/library/hh244299.aspx> MSDN: Observable.Throw
  *)
  val error : exn -> 'a RxCore.observable

  (**
   Returns an observable that never sends any items or notifications to an
   observer.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/never.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#empty-error-and-never> RxJava Wiki: never()
   *)
  val never : 'a RxCore.observable

  (**
   Returns an observable that emits a single item and then completes.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/just.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#just> RxJava Wiki: just()
   *)
  val return : 'a -> 'a RxCore.observable

  (**
   Turns all of the emissions and notifications from a source observable into
   emissions marked with their original types within ['a RxCore.notification]
   values.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/materialize.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Observable-Utility-Operators#materialize> RxJava Wiki: materialize()
   @see <http://msdn.microsoft.com/en-us/library/hh229453.aspx> MSDN: Observable.materialize
   *)
  val materialize :
    'a RxCore.observable -> 'a RxCore.notification RxCore.observable

  (**
   Returns an observable that reverses the effect of [materialize] by
   transforming the ['a RxCore.notification] values emitted by the source
   observable into the items or notifications they represent.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/dematerialize.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Observable-Utility-Operators#dematerialize> RxJava Wiki: dematerialize()
   @see <http://msdn.microsoft.com/en-us/library/hh229047.aspx> MSDN: Observable.dematerialize
   *)
  val dematerialize :
    'a RxCore.notification RxCore.observable -> 'a RxCore.observable

  (**
   Returns an observable emits the count of the total number of items
   emitted by the source observable.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/count.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Mathematical-and-Aggregate-Operators#count-and-longcount> RxJava Wiki: count()
   @see <http://msdn.microsoft.com/en-us/library/hh229470.aspx> MSDN: Observable.Count
   *)
  val length : 'a RxCore.observable -> int RxCore.observable

  (**
   Returns an observable that skips the first [n] items emitted by the source
   observable and emits the remainder.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/skip.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Filtering-Observables#skip> RxJava Wiki: skip()
   *)
  val drop : int -> 'a RxCore.observable -> 'a RxCore.observable

  (**
   Returns an observable that emits only the first [n] items emitted by the
   source observable.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/take.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Filtering-Observables#take> RxJava Wiki: take()
   *)
  val take : int -> 'a RxCore.observable -> 'a RxCore.observable

  (**
   Returns an observable that emits only the last [n] items emitted by the
   source observable.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/takeLast.n.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Filtering-Observables#takelast> RxJava Wiki: takeLast()
   *)
  val take_last : int -> 'a RxCore.observable -> 'a RxCore.observable

  (**
   If the observable completes after emitting a single item, return an
   observable containing that item. If it emits more than one item or no
   item, raise a [Failure] exception.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/single.png> Marble diagram
   
   @see <https://github.com/Netflix/RxJava/wiki/Observable-Utility-Operators#single-and-singleordefault> RxJava Wiki: single()
   @see <https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Linq/Reactive/Linq/Observable/SingleAsync.cs> SingleAsync.cs
   *)
  val single : 'a RxCore.observable -> 'a RxCore.observable

  (**
   Returns an observable that emits the items emitted by two observables, one
   after the other.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/concat.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Mathematical-and-Aggregate-Operators#concat> RxJava Wiki: concat()
   @see <http://msdn.microsoft.com/en-us/library/system.reactive.linq.observable.concat.aspx> MSDN: Observable.Concat
   *)
  val append :
    'a RxCore.observable -> 'a RxCore.observable -> 'a RxCore.observable

  (**
   Flattens a sequence of observables emitted by an observable into one
   observable, without any transformation.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/merge.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Combining-Observables#merge> RxJava Wiki: merge()
   @see <http://msdn.microsoft.com/en-us/library/hh229099.aspx> MSDN: Observable.Merge
   *)
  val merge : 'a RxCore.observable RxCore.observable -> 'a RxCore.observable

  (**
   Returns an observable that applies the given function to each item
   emitted by an observable and emits the results of these function
   applications.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/map.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Transforming-Observables#map> RxJava Wiki: map()
   @see <http://msdn.microsoft.com/en-us/library/hh244306.aspx> MSDN: Observable.Select
   *)
  val map : ('a -> 'b) -> 'a RxCore.observable -> 'b RxCore.observable

  (**
   Creates a new observable by applying a function that you supply to each
   item emitted by the source observable, where that function returns an
   observable, and then merging those resulting observables and emitting the
   results of this merger.

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/flatMap.png> Marble diagram
   @see <https://github.com/Netflix/RxJava/wiki/Transforming-Observables#mapmany-or-flatmap-and-mapmanydelayerror> RxJava Wiki: flatMap()
   *)
  val bind :
    'a RxCore.observable -> ('a -> 'b RxCore.observable) ->
    'b RxCore.observable

  (**
   Provides blocking combinators.
   
   @see <https://github.com/Netflix/RxJava/wiki/Blocking-Observable-Operators> Blocking Observable Operators
   *)
  module Blocking : sig

    (**
     Converts an observable into an enum.

     @see <https://github.com/Netflix/RxJava/wiki/images/rx-operators/B.toIterable.png> Marble diagram
     @see <https://github.com/Netflix/RxJava/wiki/Blocking-Observable-Operators#transformations-tofuture-toiterable-and-toiteratorgetiterator> RxJava Wiki: toIterable()
     *)
    val to_enum : 'a RxCore.observable -> 'a BatEnum.t

    (**
     If the observable completes after emitting a single item, return
     that item, otherwise raise a [Failure] exception.

     @see <https://github.com/Netflix/RxJava/wiki/images/rx-operators/B.single.png> Marble diagram
     @see <https://github.com/Netflix/RxJava/wiki/Blocking-Observable-Operators#single-and-singleordefault> RxJava Wiki: single()
     @see <http://msdn.microsoft.com/en-us/library/system.reactive.linq.observable.single.aspx> MSDN: Observable.Single
     *)
    val single : 'a RxCore.observable -> 'a

  end

  (**
   Specifies the basic functions to integrate a scheduler with the
   observable combinators.
   *)
  module type Scheduled = sig

    (**
     Asynchronously subscribes and unsubscribes observers on the current
     scheduler.

     @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/subscribeOn.png> Marble diagram
     @see <https://github.com/Netflix/RxJava/wiki/Observable-Utility-Operators#subscribeon> RxJava Wiki: subscribeOn()
     *)
    val subscribe_on_this : 'a RxCore.observable -> 'a RxCore.observable

    (**
     Converts a ['a BatEnum.t] sequence into an observable with the current
     scheduler.

     @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/from.s.png> Marble diagram
     @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#from> RxJava Wiki: from()
     @see <http://msdn.microsoft.com/en-us/library/hh212140.aspx> MSDN: Observable.ToObservable
     *)
    val of_enum : 'a BatEnum.t -> 'a RxCore.observable

    (**
     Returns an observable that emits an item each time interval, containing
     a sequential number.

     @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/interval.png> Marble diagram
     @see <https://github.com/Netflix/RxJava/wiki/Creating-Observables#interval> RxJava Wiki: interval()
     @see <http://msdn.microsoft.com/en-us/library/hh229027.aspx> MSDN: Observable.Interval
     *)
    val interval : float -> int RxCore.observable

  end

  (** Provides combinators on a specific scheduler. *)
  module MakeScheduled :
    functor(Scheduler : Scheduler.S) -> Scheduled

  (** Provides combinators on the current thread scheduler. *)
  module CurrentThread : Scheduled

  (** Provides combinators on the immediate scheduler. *)
  module Immediate : Scheduled

  (** Provides combinators on the new thread scheduler. *)
  module NewThread : Scheduled

  (** Provides combinators on the Lwt scheduler. *)
  module Lwt : Scheduled

  (** Provides combinators on the test scheduler. *)
  module Test : Scheduled

end

(** Provides a set of functions for creating subjects. *)
module Subject : sig

  (**
   Creates a subject that broadcasts each notification to all subscribed
   observers.
   *)
  val create : unit -> 'a RxCore.subject * RxCore.subscription

  (**
   Subject that retains all events and will replay them to an observer that
   subscribes.

   Example usage:
   {[
     let (subject, unsubscribe) = Rx.Subject.Replay.create () in
     let ((on_completed, _, on_next), observable) = subject in
     on_next "one";
     on_next "two";
     on_next "three";
     on_completed ();

     (* both of the following will get the on_next/on_completed calls from
      * above *)
     let _ = observable observer1 in
     let _ = observable observer2 in
   ]}

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/S.ReplaySubject.png> RxJava ReplaySubject
   *)
  module Replay : sig

    (**
     Creates a subject that broadcasts each notification to all subscribed
     and future observers.
     *)
    val create : unit -> 'a RxCore.subject * RxCore.subscription

  end

  (**
   Subject that publishes the most recent and all subsequent events to each
   subscribed observer.

   Example usage:
   {[
     (* observer will receive all events. *)
     let (subject, unsubscribe) = Rx.Subject.Behavior.create "default" in
     let ((_, _, on_next), observable) = subject in
     let _ = observable observer in
     on_next "one";
     on_next "two";
     on_next "three";
     
     (* observer will receive the "one", "two" and "three" events, but not
      * "zero" *)
     let (subject, unsubscribe) = Rx.Subject.Behavior.create "default" in
     let ((_, _, on_next), observable) = subject in
     on_next "zero";
     on_next "one";
     let _ = observable observer in
     on_next "two";
     on_next "three";
     
     (* observer will receive only on_completed *)
     let (subject, unsubscribe) = Rx.Subject.Behavior.create "default" in
     let ((on_completed, _, on_next), observable) = subject in
     on_next "zero";
     on_next "one";
     on_completed ();
     let _ = observable observer in
     
     (* observer will receive only on_error *)
     let (subject, unsubscribe) = Rx.Subject.Behavior.create "default" in
     let ((_, on_error, on_next), observable) = subject in
     on_next "zero";
     on_next "one";
     on_error (Failure "error");
     let _ = observable observer in
   ]}

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/S.BehaviorSubject.png> RxJava BehaviorSubject
   *)
  module Behavior : sig

    (**
      Creates a value that changes over time. Observers can subscribe to the
      subject to receive the last (or initial) value and all subsequent
      notifications.
     *)
    val create : 'a -> 'a RxCore.subject * RxCore.subscription

  end

  (**
   Subject that publishes only the last event to each observer that has
   subscribed when the sequence completes.

   Example usage:
   {[
     (* observer will receive no onNext events because the on_completed isn't
      * called. *)
     let (subject, unsubscribe) = Rx.Subject.Async.create () in
     let ((_, _, on_next), observable) = subject in
     let _ = observable observer in
     on_next "one";
     on_next "two";
     on_next "three";
     
     (* observer will receive "three" as the only on_next event. *)
     let (subject, unsubscribe) = Rx.Subject.Async.create () in
     let ((_, _, on_next), observable) = subject in
     let _ = observable observer in
     on_next "one";
     on_next "two";
     on_next "three";
     on_completed ();
   ]}

   @see <https://raw.github.com/wiki/Netflix/RxJava/images/rx-operators/S.AsyncSubject.png> RxJava AsyncSubject
   *)
  module Async : sig

    (**
      Creates a value that represents the result of an asynchronous operation.
      The last value before the on_completed notification, or the error
      received through on_error, is sent to all subscribed observers.
     *)
    val create : unit -> 'a RxCore.subject * RxCore.subscription

  end

end

