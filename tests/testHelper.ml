module Observer = struct
  module ObserverState = struct
    type 'a state = {
      completed: bool;
      error: exn option;
      on_next_queue: 'a Queue.t;
    }

    let initial_state () = {
      completed = false;
      error = None;
      on_next_queue = Queue.create ();
    }

    let on_completed s =
      OUnit2.assert_equal
        ~msg:"on_completed should be called only once"
        false s.completed;
      OUnit2.assert_equal
        ~msg:"on_completed should not be called after on_error"
        None s.error;
      { s with completed = true }

    let on_error e s =
      OUnit2.assert_equal
        ~msg:"on_error should not be called after on_completed"
        false s.completed;
      OUnit2.assert_equal
        ~msg:"on_error should be called only once"
        None s.error;
      { s with error = Some e }

    let on_next v s =
      OUnit2.assert_equal
        ~msg:"on_next should not be called after on_completed"
        false s.completed;
      OUnit2.assert_equal
        ~msg:"on_next should not be called after on_error"
        None s.error;
      Queue.add v s.on_next_queue;
      s

  end

  module O = Rx.Observer.MakeObserverWithState(ObserverState)(RxCore.DataRef)

  type 'a state = 'a ObserverState.state RxCore.DataRef.t

  let create = O.create

  let is_completed state =
    let s = RxCore.DataRef.get state in
    s.ObserverState.completed

  let is_on_error state =
    let s = RxCore.DataRef.get state in
    BatOption.is_some s.ObserverState.error

  let get_error state =
    let s = RxCore.DataRef.get state in
    s.ObserverState.error

  let on_next_values state =
    let s = RxCore.DataRef.get state in
    BatList.of_enum @@ BatQueue.enum s.ObserverState.on_next_queue

end

