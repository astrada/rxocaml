type -'a observer = 'a RxObserver.observer

type subscription = RxSubscription.subscription

type +'a observable =
  (* subscribe: *) 'a observer -> subscription

module Observer = RxObserver

module Subscription = RxSubscription

