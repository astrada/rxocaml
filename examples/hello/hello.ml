let _ =
  let enum = BatList.enum ["Hello"; ","; " "; "world"; "!"; "\n"] in
  let observable = Rx.Observable.CurrentThread.of_enum enum in
  let observer = Rx.Observer.create (fun s -> print_string s) in
  observable observer

