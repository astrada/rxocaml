(* Internal module. (see Rx.Scheduler)
 *
 * Implementation based on:
 * https://github.com/Netflix/RxJava/blob/master/rxjava-core/src/main/java/rx/Scheduler.java
 *)

module type Base = sig
  type t

  val schedule_absolute :
    ?due_time:float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

  val schedule_relative :
    float -> (unit -> RxSubscription.subscription) ->
    RxSubscription.subscription

end

module type S = sig
  include Base

  val schedule_recursive :
    ((unit -> RxSubscription.subscription) -> RxSubscription.subscription) ->
    RxSubscription.subscription

end

module MakeScheduler(BaseScheduler : Base) = struct
  include BaseScheduler

  let schedule_recursive cont =
    let open RxSubscription in
    let (child_subscription, child_state) =
      MultipleAssignment.create empty in
    let (parent_subscription, parent_state) =
      Composite.create [child_subscription] in
    let rec schedule_k k =
      let k_subscription =
        if Composite.is_unsubscribed parent_state then empty
        else BaseScheduler.schedule_absolute
          (fun () -> k (fun () -> schedule_k k))
      in
      MultipleAssignment.set child_state k_subscription;
      child_subscription in
    let scheduled_subscription =
      BaseScheduler.schedule_absolute (fun () -> schedule_k cont)
    in
    Composite.add parent_state scheduled_subscription;
    parent_subscription

end

let now () = Unix.gettimeofday ()

(* val create_sleeping_action :
 *   (unit -> RxSubscription.subscription) -> float ->
 *   (unit -> RxSubscription.subscription)
 *)
let create_sleeping_action action exec_time =
  (fun () ->
    if exec_time > now () then begin
      let delay = exec_time -. (now ()) in
      if delay > 0.0 then Thread.delay delay;
    end;
    action ())

module DiscardableAction = struct
  type t = {
    ready: bool;
    unsubscribe: RxSubscription.subscription;
  }

  let create action =
    let state = RxAtomicData.create {
      ready = true;
      unsubscribe = (fun () -> ());
    } in
    RxAtomicData.update
      (fun s ->
        { s with
          unsubscribe =
            (fun () ->
              RxAtomicData.update (fun s' -> { s' with ready = false }) state)
        }) state;
    ((fun () ->
      let was_ready =
        let old_state =
          RxAtomicData.update_if
            (fun s -> s.ready = true)
            (fun s -> { s with ready = false })
            state
        in
        old_state.ready
      in
      if was_ready then begin
        let unsubscribe = action () in
        RxAtomicData.update
          (fun s -> { s with unsubscribe = unsubscribe }) state
      end), (RxAtomicData.unsafe_get state).unsubscribe)

end

module TimedAction = struct
  type t = {
    discardable_action : unit -> unit;
    exec_time : float;
    count : int;
  }

  let compare ta1 ta2 =
    let result = compare ta1.exec_time ta2.exec_time in
    if result = 0 then
      compare ta1.count ta2.count
    else result

end

module TimedActionPriorityQueue = BatHeap.Make(TimedAction)

module CurrentThreadBase = struct
  type t = {
    queue_table: (int, TimedActionPriorityQueue.t option) Hashtbl.t;
    counter: int;
  }

  let current_state = RxAtomicData.create {
    queue_table = Hashtbl.create 16;
    counter = 0;
  }

  let get_queue state =
    let tid = Utils.current_thread_id () in
    let queue_table = state.queue_table in
    try
      Hashtbl.find queue_table tid
    with Not_found ->
      let queue = None in
      Hashtbl.add queue_table tid queue;
      queue

  let set_queue queue state =
    let tid = Utils.current_thread_id () in
    Hashtbl.replace state.queue_table tid queue

  let enqueue action exec_time =
    let exec =
      RxAtomicData.synchronize
        (fun state ->
          let queue_option = get_queue state in
          let (exec, queue) =
            match queue_option with
              None ->
                (true, TimedActionPriorityQueue.empty)
            | Some q ->
                (false, q) in
          let queue' = TimedActionPriorityQueue.insert queue {
            TimedAction.discardable_action = action;
            exec_time;
            count = state.counter;
          } in
          RxAtomicData.unsafe_set
            { state with counter = succ state.counter}
            current_state;
          set_queue (Some queue') state;
          exec) current_state in
    let reset_queue () =
      RxAtomicData.synchronize
        (fun state -> set_queue None state)
        current_state in
    if exec then begin
      try
        while true do
          let action =
            RxAtomicData.synchronize
              (fun state ->
                let queue = BatOption.get (get_queue state) in
                let result = TimedActionPriorityQueue.find_min queue in
                let queue' = TimedActionPriorityQueue.del_min queue in
                set_queue (Some queue') state;
                result.TimedAction.discardable_action) current_state in
          action ()
        done
      with
      | Invalid_argument _ -> reset_queue ()
      | e -> reset_queue (); raise e
    end

  let schedule_absolute ?due_time action =
    let (exec_time, action') =
      match due_time with
      | None -> (now (), action)
      | Some dt -> (dt, create_sleeping_action action dt) in
    let (discardable_action, unsubscribe) = DiscardableAction.create action' in
    enqueue discardable_action exec_time;
    unsubscribe

  let schedule_relative delay action =
    let due_time = now () +. delay in
    schedule_absolute ~due_time action

end

module CurrentThread = MakeScheduler(CurrentThreadBase)

