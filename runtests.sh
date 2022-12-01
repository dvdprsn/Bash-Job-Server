#! /bin/bash

CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
USER=dpears04
FILE=/tmp/server-$USER-inputfifo

# Give worker 1 a single task - Test that tasks are sent to a worker
testSingle() {

    echo "Starting Test Single"
    ./submitJob.sh ./timedCountdown.sh 2
    sleep 3
    #This should have 1 additional line not in log 2
    LINEW1=$(wc -l </tmp/worker-${USER}.1.log)
    #Should have 1 less line
    LINEW2=$(wc -l </tmp/worker-${USER}.2.log)
    if [ $((LINEW1 - LINEW2)) -eq 2 ]; then
        echo "Test Single Success - ${LINEW1} lines found in worker 1 - ${LINEW2} lines found in worker 2"
    else
        echo "Test Single Failed - Mismatch in expected line count"
    fi
}

# Give worker 1 and 2 a task - Test round robin works on small scale
testDouble() {
    echo "Starting Test Double"
    # Give to worker 1
    ./submitJob.sh ./timedCountdown.sh 2
    # Give to worker 2
    ./submitJob.sh ./timedCountdown.sh 1
    sleep 3
    LINEW1=$(wc -l </tmp/worker-${USER}.1.log)
    LINEW2=$(wc -l </tmp/worker-${USER}.2.log)

    if [ $((LINEW1 - LINEW2)) -eq 1 ]; then
        echo "Test Double Success - ${LINEW1} lines found in worker 1 - ${LINEW2} lines found in worker 2"
    else
        echo "Test Double Failed - Mismatch in expected line count"
    fi

    sleep 3
}

# Give each worker 1 task - Test that taks can be sent to all workers
testAllRun1() {
    echo "Starting All Run 1 Test"
    START=1
    END=$((CORES))
    for ((c = $START; c <= $END; c++)); do
        ./submitJob.sh ./timedCountdown.sh 1
    done

    sleep 2
    LINES=$(wc -l </tmp/worker-${USER}.1.log)
    LINES2=$(wc -l </tmp/worker-${USER}.${CORES}.log)

    # We expect every worker to be allocated a task 3 times
    if [ $LINES -eq $LINES2 ]; then
        echo "1 Task Test Success - ${LINES} lines found in worker 1 and worker ${CORES}"
    else
        echo "1 Task Test Failed - ${LINES} lines found"
    fi

}

# Give each worker 3 tasks - tests that round robin works
testAllRun3() {
    echo "Starting All Run 3 Test"
    START=1
    END=$((3 * CORES))
    for ((c = $START; c <= $END; c++)); do
        ./submitJob.sh ./timedCountdown.sh 1
    done

    sleep 4
    LINES=$(wc -l </tmp/worker-${USER}.1.log)
    LINES2=$(wc -l </tmp/worker-${USER}.${CORES}.log)

    # We expect every worker to be allocated a task 3 times
    if [ $LINES -eq $LINES2 ]; then
        echo "Test 3 Tasks Success - ${LINES} lines found in worker 1 and worker ${CORES}"
    else
        echo "Test 3 Tasks Failed - ${LINES} lines found"
    fi

}

# Bombard the server with 10 requests for each worker running
testBombard() {
    echo "Starting Bombard Test"
    START=1
    END=$((10 * CORES))
    for ((c = $START; c <= $END; c++)); do
        ./submitJob.sh ./timedCountdown.sh 5
    done
    echo "Test Successful if Exit test is Successful"
}
# Test CTRL-C - Not sure this is even possible based on job control documentation
#
testSIGINT() {
    echo "Starting SIGINT Test"

    ./server.sh >server.log &
    PID=$!
    sleep 1
    kill -SIGINT $PID
    sleep 1
    if [ -p "${FILE}" ]; then

        echo "Test Exit Failed, did not close server FIFO ${FILE}"
        echo "Running exit with submitJob.sh -x"
        testExit

    else
        echo "Test Exit success, cleaned up ${FILE}"
    fi
}

#Tests that exit cleans up files
testExit() {
    echo "Running Exit Test"
    ./submitJob.sh -x
    sleep 6
    if [ -p "${FILE}" ]; then
        echo "Test Exit Failed, did not close server FIFO ${FILE}"
    else
        echo "Test Exit success, cleaned up ${FILE}"
    fi
}

# Cleanly executes each test individually
runTest() {
    # Start the server output to log
    ./server.sh >server.log &
    # Wait for startup to finish
    sleep 1
    #Execute the test
    ${*}
    # Give it some space
    sleep 1
    # Get status
    ./submitJob.sh -s
    # Give some space
    sleep 2
    # Read tasks processed from server output
    sed -n '5p' server.log
    # Test that exit is successful
    testExit
    echo ""
    sleep 1
}

# Test executions
runTest testSingle
runTest testDouble
runTest testAllRun1
runTest testAllRun3
runTest testBombard
testSIGINT
