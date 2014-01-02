module Observer : sig
  type 'a state

  val create : unit -> 'a RxCore.observer * 'a state

  val is_completed : 'a state -> bool

  val is_on_error : 'a state -> bool

  val get_error : 'a state -> exn option

  val on_next_values : 'a state -> 'a list

end

