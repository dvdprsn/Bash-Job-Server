#!/bin/bash
numSec=$1

while [ ${numSec} -ne 0 ]; do
    echo "${numSec} seconds remaining"
    sleep 1
    numSec=$((${numSec} - 1))
done
