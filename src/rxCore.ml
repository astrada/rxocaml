type -'a observer = (unit -> unit) * (exn -> unit) * ('a -> unit)

type subscription = unit -> unit

type +'a observable = 'a observer -> subscription

module type MutableState = sig

  type 'a t

  val create : 'a -> 'a t

  val get : 'a t -> 'a

  val set : 'a t -> 'a -> unit

end

type 'a notification =
  | OnCompleted
  | OnError of exn
  | OnNext of 'a

