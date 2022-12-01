#! /bin/bash
#Set permissions for created files
umask 0077
USER=dpears04
#Server fifo path
fifo_name=/tmp/server-$USER-inputfifo
#Find number of system cores
CORES=$(cat /proc/cpuinfo | grep processor | wc -l)

#Create dictonary that tracks the status of workers
declare -A worker_status
#The initial creation of workers based on num cores
spawn_workers() {
    echo "Starting up $CORES processing units"
    #For each core in the system
    for i in $(seq $CORES); do
        #Worker starts as ready
        worker_status[$i]="ready"
        #Create the worker as background process
        #We pass the worker ID to it using $i
        ./worker.sh $i &
    done
}

#Make FIFO if it doesnt exist
if [ ! -p $fifo_name ]; then
    mkfifo $fifo_name
fi

spawn_workers
echo "Ready for processing: place tasks into $fifo_name"
#Init the variables that will be used
terminate=1
CUR_WORKER=1
RUNNING_WORK=0
TASK_PROC=0
exited=0
CMDQueue=()

# This function will kill all ready workers
killReady() {
    # Loop through and exit all workers that are not processing
    while [ ${worker_status[$CUR_WORKER]} = 'ready' ]; do
        
        # echo "Exiting worker [${CUR_WORKER}]"
        # Send exit cmd to worker
        echo 'MSG quit' >/tmp/worker-$USER.${CUR_WORKER}-inputfifo
        # We move to the next worker
        CUR_WORKER=$((CUR_WORKER + 1))
        # Once all are exited this will = #Cores
        exited=$((exited + 1))
        # Once we have exited the same # workers as cores
        if [ ${exited} = ${CORES} ]; then
            # Remove the server FIFO 
            rm ${fifo_name}
            # Exit the script
            exit 0
        fi
        # Loop cur_worker back to 1 
        if [ $CUR_WORKER -gt $CORES ]; then
            CUR_WORKER=1
        fi
    done
}
# Cleanup function 
newClean() {
    echo ""
    echo "Preparing to exit - Might be waiting on worker to finish!"
    # Start by killing all the workers who are ready to be killed
    killReady
    # While there exists a worker that is waiting (Executing)
    while [[ " ${worker_status[*]} " =~ "wait" ]]; do
        # Read from the FIFO
        if read line; then
            #Get Token
            TOKEN=$(echo ${line} | head -n1 | awk '{print $1;}')
            #UPDATE WORKER STATUS if alerted
            if [ "$TOKEN" = 'WS' ]; then
                STAT_ID=$(echo ${line} | head -n1 | awk '{print $2;}')
                worker_status[$STAT_ID]=$(echo $line | cut -d " " -f3-)
            fi
        fi
    done <$fifo_name
    # Once the while loop above terminates all workers are ready to be killed
    killReady
}

# trap cleanup SIGINT
trap newClean SIGINT
# Main logic loop
while [ $terminate != 0 ]; do
    # Loop current worker back to 1
    if [ $CUR_WORKER -gt $CORES ]; then
        CUR_WORKER=1
    fi
    # Read from FIFO
    if read line; then
        #Get Token
        TOKEN=$(echo ${line} | head -n1 | awk '{print $1;}')
        #For worker status (WS) updates
        if [ "$TOKEN" = 'WS' ]; then
            STAT_ID=$(echo ${line} | head -n1 | awk '{print $2;}')
            worker_status[$STAT_ID]=$(echo $line | cut -d " " -f3-)
            # Update stat variables for server status reports
            if [ $(echo $line | cut -d " " -f3-) = 'ready' ]; then
                # Tasks processed increases by 1
                TASK_PROC=$((TASK_PROC + 1))
                # Actively running workers decreases by 1
                RUNNING_WORK=$((RUNNING_WORK - 1))
            else
                # If returns wait status - running worker count increases
                RUNNING_WORK=$((RUNNING_WORK + 1))
            fi
            #Skip command executions
            continue
        fi
        # For communication messages
        if [ "$TOKEN" = 'MSG' ]; then
            # Get msg contents
            msgCont=$(echo ${line} | head -n1 | awk '{print $2;}')
            if [ "$msgCont" = 'shutdown' ]; then
                # cleanup
                newClean
            elif [ "$msgCont" = 'status' ]; then
                echo ""
                echo "There are currently ${RUNNING_WORK} workers running"
                echo "${TASK_PROC} tasks have been processed"
                echo "${CORES} total workers"
                echo "${#CMDQueue[@]} commands in the queue"
                echo ""
            fi
            # Since we processed a message we can skip command executions
            continue
        fi
        # Add the newly processed command to the queue
        CMDQueue+=("$line")
    fi
    # If the current worker is ready and there exists a command to be execd
    if [ ${worker_status[$CUR_WORKER]} = 'ready' ] && [ "${CMDQueue[0]}" != '' ]; then
        # Send the command to the current worker
        echo "CMD ${CMDQueue[0]}" >/tmp/worker-$USER.${CUR_WORKER}-inputfifo
        #Remove command just executed
        CMDQueue=("${CMDQueue[@]:1}")
        # Move the current worker pointer forward
        CUR_WORKER=$((CUR_WORKER + 1))
    fi

done <$fifo_name
