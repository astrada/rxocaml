(** Synchronized mutable data structure. *)

type 'a t

val create : 'a -> 'a t

(** Synchronized getter. *)
val get : 'a t -> 'a

(** Non-synchronized getter. *)
val unsafe_get : 'a t -> 'a

(** Synchronized setter. *)
val set : 'a -> 'a t -> unit

(** Non-synchronized setter. *)
val unsafe_set : 'a -> 'a t -> unit

(** Synchronized update. *)
val update : ('a -> 'a) -> 'a t -> unit

(**
 Synchronized compare and set (CAS).

 [compare_and_set compare_to new_value data] compares current value of [data]
 with [compare_to] value. If they are equal, set the current value to
 [new_value]. Returns the value before updating.
 *)
val compare_and_set : 'a -> 'a -> 'a t -> 'a

(**
 Synchronized update with precondition.

 [update_if predicate f data] checks [predicate] on the current value of
 [data]. If it is [true], update the current value applying [f]. Returns the
 value before updating.
 *)
val update_if : ('a -> bool) -> ('a -> 'a) -> 'a t -> 'a

(**
 Synchronized function application.

 [synchronize f data] applies [f] to the current value of [data] and returns
 the return value of [f].
 *)
val synchronize : ('a -> 'b) -> 'a t -> 'b

