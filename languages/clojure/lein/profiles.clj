{:user {:plugins [[lein-beanstalk "0.2.7"]
                  [lein-light "0.0.44"]
                  [lein-marginalia "0.7.1"]
                  [cider/cider-nrepl "0.7.0-SNAPSHOT"]
                  [lein-clojars "0.9.1"]
                  [lein-ancient  "0.5.5"]
                  [lein-depgraph "0.1.0"]
                  [lein-pprint "1.1.1"]
                  [lein-ring "0.8.10"]]
        :dependencies [[io.aviso/pretty "0.1.11"]
                       [alembic "0.2.1"]]
        :repl-options {:nrepl-middleware [io.aviso.nrepl/pretty-middleware]}
        :injections [#_(let [orig (ns-resolve (doto 'clojure.stacktrace require)
                                              'print-cause-trace)
                             new (ns-resolve (doto 'clj-stacktrace.repl require)
                                             'pst)]
                         (alter-var-root orig (constantly @new)))]}}
