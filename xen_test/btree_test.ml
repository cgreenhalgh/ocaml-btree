let main () =
  OS.Console.log "hello" ;
  (* Blkfront will map xen block devs to Mirage blkif *)
  lwt () = Blkfront.register () in
  (* get unknown blkif id - current vid e.g. '2049' *)
  let namet,nameu = Lwt.task () in
  Lwt.async (fun () -> (OS.Devices.listen (fun id -> 
    OS.Console.log ("found " ^ id); Lwt.wakeup nameu id; Lwt.return ())));
  lwt name = namet in
  OS.Console.log("try to open "^name);
  lwt () = OS.Devices.with_blkif name (fun blkif ->
  try_lwt
    OS.Console.log("create "^name^"...");
    lwt btree = Btree.create blkif in
    OS.Console.log ("Created btree over "^ blkif#id);
    let key = "key_123" in
    let svalue = "value_123" in
    let value = Cstruct.of_string svalue in
    lwt _ = btree#set key value in
    OS.Console.log ("set "^key^"="^svalue); 
    lwt ovalue = btree#get key in
    begin match ovalue with 
      | None -> OS.Console.log ("get "^key^" -> None")
      | Some v -> OS.Console.log("get "^key^" -> "^(Cstruct.to_string v))
    end;
    Lwt.return ()
  with ex -> OS.Console.log ("Exception!");
    Lwt.return ()) in
  lwt () =OS.Time.sleep 2.0 in
  Lwt.return ()
