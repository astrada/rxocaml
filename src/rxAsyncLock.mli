(** Asynchronous lock.
 *
 * https://rx.codeplex.com/SourceControl/latest#Rx.NET/Source/System.Reactive.Core/Reactive/Concurrency/AsyncLock.cs
 *)

type t

val create : unit -> t

val wait : t -> (unit -> unit) -> unit
(**
 * Queues the action for execution. If the caller acquires the lock and
 * becomes the owner, the queue is processed. If the lock is already owned,
 * the action is queued and will get processed by the owner.
 *)

val dispose : t -> unit
(**
 * Clears the work items in the queue and drops further work being queued.
 *)

