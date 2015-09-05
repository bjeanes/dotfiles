{:user {:plugins [;[lein-beanstalk "0.2.7"]
                  ;[lein-marginalia "0.7.1"]
                  [cider/cider-nrepl "0.9.1"]
                  [refactor-nrepl "1.1.0"]
                  [lein-clojars "0.9.1"]
                  [lein-ancient  "0.6.7"]
                  [lein-depgraph "0.1.0"]
                  [lein-pprint "1.1.2"]
                  [lein-ring "0.9.6"]]
        :dependencies [[io.aviso/pretty "0.1.18"]
                       [alembic "0.3.2"]
                       [org.clojure/tools.nrepl "0.2.10"]
                       [clj-stacktrace "0.2.8"]]
        :repl-options {:skip-default-intro true}
        :global-vars {*print-length* 103
                      *print-level* 15}
        :injections [(require 'io.aviso.repl)
                     (io.aviso.repl/install-pretty-exceptions)]}}
