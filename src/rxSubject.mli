val create : unit -> 'a RxCore.subject * RxCore.subscription

module Replay : sig
  val create : unit -> 'a RxCore.subject * RxCore.subscription

end

module Behavior : sig
  val create : 'a -> 'a RxCore.subject * RxCore.subscription

end

module Async : sig
  val create : unit -> 'a RxCore.subject * RxCore.subscription

end

