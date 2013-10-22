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

(* persistent btree for mirage over OS.Devices.blkif *)
open OUnit
open Lwt

let read_as_string btree key = 
  lwt cso = btree#read key in
  match cso with 
  | None -> return None
  | Some cs ->
    let rec rd cs res = 
      lwt co = Lwt_stream.get cs in
      match co with
      | None -> return (Some res)
      | Some c -> rd cs (res ^ (Cstruct.to_string c))
    in rd cs ""

let test() = 
  let fn() = 
    let fn = "testfile" in
    Printf.printf "Using blkdev %s\n%!" fn;
    lwt blkif = Blkdev.create fn fn in
    lwt btree = Btree.create blkif in
    let key = "key_123" in
    let svalue = "value_123" in
    let value = Cstruct.of_string svalue in
    lwt _ = btree#set key value in
    lwt ovalue = btree#get key in
    assert_equal ovalue (Some value);
    lwt oreadvalue = read_as_string btree key in
    assert_equal oreadvalue (Some svalue);
    lwt osize = btree#size key in
    assert_equal osize (Some (Int64.of_int (String.length svalue)));

    let keys = ref [] in
    let with_key k = 
      Printf.printf "Found key %s\n%!" k; 
      keys := k :: !keys; 
      return () in
    lwt _ = btree#iter_s with_key in 
    assert_equal !keys [ key ];

    btree#delete key >>
    lwt ovalue' = btree#get key in
    assert_equal ovalue' None;
    lwt oreadvalue' = read_as_string btree key in
    assert_equal oreadvalue' None;
    lwt osize' = btree#size key in
    assert_equal osize' None;
    keys := [];
    lwt _ = btree#iter_s with_key in 
    assert_equal !keys [];

    return ()
  in Lwt_main.run(fn())

let _ =
    let verbose = ref false in
      Arg.parse [
                  "-verbose", Arg.Unit (fun _ -> verbose := true), "Run in verbose mode";
  ] (fun x -> Printf.fprintf stderr "Ignoring argument: %s" x)
      "Test blkdev code";
  let suite = "blkdev" >:::
    [
            "test" >:: test;   
    ] in
  run_test_tt ~verbose:!verbose suite

