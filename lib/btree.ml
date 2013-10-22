(* 
 * by Chris Greenhalgh <chris.greenhalgh@nottingham.ac.uk>
 *
 * Copyright (c) 2013, The University of Nottingham 
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * 
 *   Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * 
 *   Redistributions in binary form must reproduce the above copyright notice, this
 *   list of conditions and the following disclaimer in the documentation and/or
 *   other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)

open Lwt

module BS = Baardskeerder.Baardskeerder(Baardskeerder.Logs.Flog0)(Baardskeerder.Blkif.Store) 

(* persistent btree for mirage over OS.Devices.blkif *)
type t = {
  blkif : OS.Devices.blkif;
  bs : BS.t
}

type btree = <
  (* OS.Devices.kv_ro methods *)
  iter_s : (string -> unit Lwt.t) -> unit Lwt.t;
  read : string -> Cstruct.t Lwt_stream.t option Lwt.t;
  size : string -> int64 option Lwt.t;
  (* additional Btree methods *)
  get : string -> Cstruct.t option Lwt.t;
  set : string -> Cstruct.t -> unit Lwt.t;
  delete : string -> unit Lwt.t
  (* range, prefix, transaction... *)
>

let iter_s t (fn: string -> unit Lwt.t) = 
  (* no from, inc from, no to, inc to, no max *)
  lwt keys = BS.range_latest t.bs None true None true None in
  let rec callfn ks = match ks with 
  | [] -> return ()
  | k :: ks -> lwt _ = fn k in
    callfn ks in
  callfn keys

let read t (key:string) : Cstruct.t Lwt_stream.t option Lwt.t = 
  lwt res = BS.get_latest t.bs key in
  match res with 
  | Baardskeerder.NOK _ -> return None
  | Baardskeerder.OK v -> 
    Printf.printf "read %s -> %s\n%!" key v;
    let taken = ref false in
    let fn () = if !taken then return None
      else begin
        taken := true;
        return (Some (Cstruct.of_string v))
      end 
    in 
    return (Some (Lwt_stream.from fn))

let size t (key:string) : int64 option Lwt.t =
  lwt res = BS.get_latest t.bs key in
  match res with 
  | Baardskeerder.NOK _ -> return None
  | Baardskeerder.OK v -> 
    let size = String.length v in
    Printf.printf "size %s -> %s = %d\n%!" key v size;
    return (Some (Int64.of_int size))

let get t (key:string) : Cstruct.t option Lwt.t = 
  lwt res = BS.get_latest t.bs key in
  match res with 
  | Baardskeerder.NOK _ -> return None
  | Baardskeerder.OK v -> 
    Printf.printf "got %s -> %s\n%!" key v;
    return (Some (Cstruct.of_string v))

let set t (key:string) (value:Cstruct.t) =
  let svalue = Cstruct.to_string value in
  lwt _ = BS.with_tx t.bs (fun tx ->
    BS.set tx key svalue >>= fun () ->
    Printf.printf "set %s <- %s\n%!" key svalue;
    return (Baardskeerder.OK ())) in
  return ()

let delete t (key:string) = 
  lwt _ = BS.with_tx t.bs (fun tx ->
    lwt res = BS.delete tx key in
    begin
      match res with 
      | Baardskeerder.NOK _ -> Printf.printf "delete %s (not present)\n%!" key
      | Baardskeerder.OK _ -> Printf.printf "delete %s\n%!" key
    end;
    return res) in
  return ()

let create blkif : btree Lwt.t =
  (* TODO make over provided blkif! *)
  Lwt.catch (fun () -> BS.init "testfile") 
    (fun ex -> Printf.printf "Error init\n%!"; return ()) >>
  lwt bs = BS.make "testfile" in
  let t = { blkif; bs } in
  return (object
    method iter_s = iter_s t
    method read = read t
    method size = size t
    method get = get t
    method set = set t
    method delete = delete t
  end)

