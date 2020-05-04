if [ -n ${WSL_DISTRO_NAME:-} ] || grep -sqi microsoft /proc/sys/kernel/osrelease; then
    # # Talk to Windows' SSH-Agent when under WSL, using https://github.com/rupor-github/wsl-ssh-agent
    # # wsl-ssh-agent started with:
    # #
    # #    wsl-ssh-agent-gui.exe -setenv -envname=WSL_AUTH_SOCK -lemonade=2489;127.0.0.1/24
    # #
    # [ -n ${WSL_AUTH_SOCK} ] && export SSH_AUTH_SOCK=${WSL_AUTH_SOCK}

    # Above does not work currently due to WSL1 -> WSL2 turbulence. Workaround below.
    # Based on: https://github.com/rupor-github/wsl-ssh-agent/tree/4e08e3fa84380f4d62bfdf607ae6b2c680e1ff3e#wsl-2-compatibility

    # where I installed it (must be on Windows' filesystem)
    NPIPERELAY_DIR="/mnt/c/Program Files/WSL-SSH-Agent"

    export SSH_AUTH_SOCK=$HOME/.ssh/agent.sock

    ss -a | grep -q $SSH_AUTH_SOCK

    if [ $? -ne 0 ]; then
        rm -f $SSH_AUTH_SOCK
        ( 
            PATH="$NPIPERELAY_DIR:$PATH"
            setsid socat \
                UNIX-LISTEN:$SSH_AUTH_SOCK,fork \
                EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork & 
        ) >/dev/null 2>&1
    fi

    # https://github.com/microsoft/WSL/issues/4166#issuecomment-618159162
    [ -z "$(ps -ef | grep cron | grep -v grep)" ] && sudo /etc/init.d/cron start &>/dev/null
fi