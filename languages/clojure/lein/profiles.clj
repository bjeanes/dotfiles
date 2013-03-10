{:user {:plugins [[lein-beanstalk "0.2.6"]
                  [lein-light "0.0.16"]
                  [lein-marginalia "0.7.1"]
                  [lein-clojars "0.9.1"]
                  [lein-outdated "1.0.0"]
                  [lein-ring "0.8.2"]
                  [lein-swank "1.4.5"]]
        :dependencies [[clj-stacktrace "0.2.5"]]
        :injections [(let [orig (ns-resolve (doto 'clojure.stacktrace require)
                                            'print-cause-trace)
                           new (ns-resolve (doto 'clj-stacktrace.repl require)
                                           'pst)]
                       (alter-var-root orig (constantly @new)))]
        :vimclojure-opts {:repl true}}}
