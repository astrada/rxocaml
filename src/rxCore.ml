type -'a observer = (unit -> unit) * (exn -> unit) * ('a -> unit)

type subscription = unit -> unit

type +'a observable = 'a observer -> subscription

type 'a notification =
  | OnCompleted
  | OnError of exn
  | OnNext of 'a

module type MutableData = sig

  type 'a t

  val create : 'a -> 'a t

  val get : 'a t -> 'a

  val set : 'a -> 'a t -> unit

end

module DataRef = struct

  type 'a t = 'a ref

  let create v = ref v

  let get r = BatRef.get r

  let set v r = BatRef.set r v

end

