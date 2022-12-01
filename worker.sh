#! /bin/bash
umask 0077
USER=dpears04
SERVER_FIFO=/tmp/server-$USER-inputfifo
ID=$1
LOG=/tmp/worker-$USER.${ID}.log
MY_FIFO=/tmp/worker-$USER.${ID}-inputfifo

terminate=1
if [ ! -p /tmp/worker-$USER.${ID}-inputfifo ]; then
    mkfifo /tmp/worker-$USER.${ID}-inputfifo
fi

#Clear log file on startup
>$LOG

while [ $terminate != 0 ]; do
    if read line; then

        ACTION=$(echo ${line} | head -n1 | awk '{print $1;}')

        if [ "$ACTION" = "MSG" ]; then
            if [ $(echo $line | cut -d " " -f2-) = "quit" ]; then
                terminate=0
                #Clean up the FIFO
                rm $MY_FIFO
                exit 0
                break
            fi
        fi

        if [ "$ACTION" = "CMD" ]; then
            #Send waiting status back to server
            echo "WS ${ID} wait" >$SERVER_FIFO
            #Gets everything in the string after the first word (remove CMD)
            RUN=$(echo $line | cut -d " " -f2-)
            #Append to LOG
            $RUN >>$LOG
            #Alert server that worker is ready again
            echo "WS ${ID} ready" >$SERVER_FIFO
        fi
    fi
done </tmp/worker-$USER.${ID}-inputfifo
