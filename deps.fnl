{:project-name "metabuffer"
 :project-version "0.1.0"

 :deps {"io.gitlab.andreyorst/fennel-cljlib"
        {:type :git :sha "256d59ef6efd0f39ca35bb6815e9c29bc8b8584a"}
        "io.gitlab.andreyorst/async.fnl"
        {:type "git" :sha "a83b13b397fdfab3ebf7f17a16d21a7ec2674ceb"}
        "io.gitlab.andreyorst/reader.fnl"
        {:type "git" :sha "3ff2bc790c8b7922267af5712a64a14572a172cf"}
        
}
; ["luasocket"
;    {:type "rock" :version "3.0rc1-2"}]
;

 :paths {:fennel ["fnl/?.fnl" "fnl/?/?.fnl" "deps/?/?.fnl"]
         :macro ["deps/nfnl/fnl/nfnl/macros/?.fnlm" "deps/nfnl/fnl/nfnl/macros.fnlm" "src/?.fnlm" "src/?/?.fnlm"]
         :lua ["lua/?.lua" "plugin/?.lua"]}

 :profiles
 {:dev
  {:deps {:ht.sr.technomancy/faith
          {:type :git :sha "89f7a6677821cfd6a0702cf22725dccbde1eb08c"
           :paths {:fennel ["?.fnl"]}}}
   :paths {:fennel ["test/?.fnl"]
           :macro ["test/?.fnlm"]
           :lua ["test/?.lua"]}}
  :aot
  {:deps {"fennel" {:type :rock :version "1.5.3"}}}}}
