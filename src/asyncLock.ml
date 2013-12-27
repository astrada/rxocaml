type t = {
  queue: (unit -> unit) Queue.t;
  mutable is_acquired: bool;
  mutable has_faulted: bool;
  mutex: Mutex.t;
}

let create () = {
  queue = Queue.create ();
  is_acquired = false;
  has_faulted = false;
  mutex = Mutex.create ();
}

let dispose l =
  BatMutex.synchronize ~lock:l.mutex
    (fun () ->
      Queue.clear l.queue;
      l.has_faulted <- true
    ) ()

let wait l action =
  let is_owner =
    BatMutex.synchronize ~lock:l.mutex
      (fun () ->
        if not l.has_faulted then begin
          Queue.add action l.queue;
          let result = not l.is_acquired in
          l.is_acquired <- true;
          result
        end else false
      ) () in

  if is_owner then begin
    let rec loop () =
      let work =
        BatMutex.synchronize ~lock:l.mutex
          (fun () ->
             try
               Some (Queue.take l.queue)
             with Queue.Empty ->
               l.is_acquired <- false;
               None
          ) ()
      in

      match work with
        None -> ()
      | Some w ->
        begin try
          w ()
        with e ->
          dispose l;
          raise e
        end;
        loop ()

    in
    loop ()
  end

