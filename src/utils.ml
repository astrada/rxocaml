let try_finally thunk finally =
  try
    let result = thunk () in
    finally ();
    result
  with e ->
    finally ();
    raise e

let current_thread_id () =
  Thread.self () |> Thread.id

