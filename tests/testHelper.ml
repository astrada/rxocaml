module Observer = struct
  type 'a state = {
    mutable completed: bool;
    mutable error: exn option;
    mutable on_next_queue: 'a Queue.t;
  }

  let create () =
    let state = {
      completed = false;
      error = None;
      on_next_queue = Queue.create ();
    } in
    let observer =
      Rx.Observer.create
        ~on_completed:(fun () ->
          OUnit2.assert_equal
            ~msg:"on_completed should be called only once"
            false state.completed;
          OUnit2.assert_equal
            ~msg:"on_completed should not be called after on_error"
            None state.error;
          state.completed <- true
        )
        ~on_error:(fun e ->
          OUnit2.assert_equal
            ~msg:"on_error should not be called after on_completed"
            false state.completed;
          OUnit2.assert_equal
            ~msg:"on_error should be called only once"
            None state.error;
          state.error <- Some e
        )
        (fun v ->
          OUnit2.assert_equal
            ~msg:"on_next should not be called after on_completed"
            false state.completed;
          OUnit2.assert_equal
            ~msg:"on_next should not be called after on_error"
            None state.error;
          Queue.add v state.on_next_queue
        )
    in
    (observer, state)

  let is_completed state = state.completed

  let is_on_error state = BatOption.is_some state.error

  let get_error state = state.error

  let on_next_values state =
    BatList.of_enum @@ BatQueue.enum state.on_next_queue

end

