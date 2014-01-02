type 'a t = {
  mutable data : 'a;
  mutex : Mutex.t;
}

let with_lock ad f =
  BatMutex.synchronize ~lock:ad.mutex f ()

let create initial_value = {
  data = initial_value;
  mutex = Mutex.create ();
}

let get ad =
  with_lock ad (fun () -> ad.data)

let unsafe_get ad = ad.data

let set value ad =
  with_lock ad (fun () -> ad.data <- value)

let unsafe_set value ad = ad.data <- value

let get_and_set value ad =
  with_lock ad
    (fun () ->
      let result = ad.data in
      ad.data <- value;
      result)

let update f ad =
  with_lock ad (fun () -> ad.data <- f ad.data)

let update_and_get f ad =
  with_lock ad
    (fun () ->
      let result = f ad.data in
      ad.data <- result;
      result
    )

let compare_and_set compare_value set_value ad =
  with_lock ad
    (fun () ->
      let result = ad.data in
      if ad.data = compare_value then ad.data <- set_value;
      result
    )

let update_if predicate update ad =
  with_lock ad
    (fun () ->
      let result = ad.data in
      if predicate ad.data then ad.data <- update result;
      result
    )

let synchronize f ad =
  with_lock ad (fun () -> f ad.data)

