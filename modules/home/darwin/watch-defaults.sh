function watch-defaults() {
    (
        pushd $(mktemp -d)
        echo "Loading current defaults"
        defaults read >defaults_before.txt
        while true; do
            defaults read >defaults_after.txt

            diff defaults_before.txt defaults_after.txt >diff.txt
            code=$?

            if [ $code -eq 0 ]; then
                sleep 1
            elif [ $code -eq 1 ]; then
                date
                cat diff.txt
                rm diff.txt
                mv defaults_after.txt defaults_before.txt
            else
                echo "There was something wrong with the diff command"
                return
            fi
        done
    )
}
