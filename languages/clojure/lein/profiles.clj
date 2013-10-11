{:user {:plugins [[lein-beanstalk "0.2.7"]
                  [lein-light "0.0.27"]
                  [lein-marginalia "0.7.1"]
                  [lein-clojars "0.9.1"]
                  [lein-outdated "1.0.1"]
                  [lein-depgraph "0.1.0"]
                  [lein-pprint "1.1.1"]
                  [lein-ring "0.8.7"]]
        :dependencies [[clj-stacktrace "0.2.5"]]
        :injections [(let [orig (ns-resolve (doto 'clojure.stacktrace require)
                                            'print-cause-trace)
                           new (ns-resolve (doto 'clj-stacktrace.repl require)
                                           'pst)]
                       (alter-var-root orig (constantly @new)))]
        :vimclojure-opts {:repl true}}}
