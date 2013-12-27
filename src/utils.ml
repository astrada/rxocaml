let try_finally thunk finally =
  try
    let result = thunk () in
    finally ();
    result
  with e ->
    finally ();
    raise e

let with_lock mutex thunk =
  try
    Mutex.lock mutex;
    let result = thunk () in
    Mutex.unlock mutex;
    result
  with e ->
    Mutex.unlock mutex;
    raise e

