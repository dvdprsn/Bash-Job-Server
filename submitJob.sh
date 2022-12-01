#! /bin/bash
USER=dpears04
fifo_name=/tmp/server-$USER-inputfifo

if [ $1 = "-s" ]; then
    echo "MSG status" >$fifo_name
    exit 0
fi
if [ $1 = "-x" ]; then
    echo "MSG shutdown" >$fifo_name
    exit 0
fi

echo $* >$fifo_name
exit 0
