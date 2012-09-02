{:user {:plugins [[lein-beanstalk "0.2.2"]
                  [lein-light "0.0.4"]
                  [lein-marginalia "0.7.1"]
                  [lein-clojars "0.9.0"]
                  [lein-tarsier "0.9.1"]
                  ;[lein-pedantic "0.0.2"]
                  [lein-outdated "0.1.0"]
                  [lein-ring "0.7.1"]
                  [lein-swank "1.4.0"]]
        :dependencies [[clj-stacktrace "0.2.4"]]
        :injections [(let [orig (ns-resolve (doto 'clojure.stacktrace require)
                                            'print-cause-trace)
                           new (ns-resolve (doto 'clj-stacktrace.repl require)
                                           'pst)]
                       (alter-var-root orig (constantly @new)))]
        :vimclojure-opts {:repl true}}}
