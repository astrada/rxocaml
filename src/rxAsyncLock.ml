type state = {
  queue: (unit -> unit) Queue.t;
  is_acquired: bool;
  has_faulted: bool;
}

type t = state RxAtomicData.t

let create () = RxAtomicData.create {
  queue = Queue.create ();
  is_acquired = false;
  has_faulted = false;
}

let dispose lock =
  RxAtomicData.update
    (fun l ->
      Queue.clear l.queue;
      { l with has_faulted = true }
    ) lock

let wait lock action =
  let old_state =
    RxAtomicData.update_if
      (fun l -> not l.has_faulted)
      (fun l ->
        Queue.add action l.queue;
        { l with is_acquired = true }
      ) lock
  in
  let is_owner = not old_state.is_acquired in
  if is_owner then begin
    let rec loop () =
      let work =
        RxAtomicData.synchronize
          (fun l ->
             try
               Some (Queue.take l.queue)
             with Queue.Empty ->
               RxAtomicData.unsafe_set { l with is_acquired = false } lock;
               None
          ) lock
      in

      match work with
      | None -> ()
      | Some w ->
        begin try
          w ()
        with e ->
          dispose lock;
          raise e
        end;
        loop ()

    in
    loop ()
  end

