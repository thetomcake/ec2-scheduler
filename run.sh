#!/bin/bash

# DOW 1 = Monday
# DOW 7 = Sunday
# ACTION[STOP/START] DOW[1-7 or *] HOUR[00:23] MINUTE[00:59]

run_schedule() {
    while read -r ITEM; do
	debug "ITEM: $ITEM"
        read -r -a ITEM_PARTS <<< "${ITEM}"

        debug "ACTION: ${ITEM_PARTS[0]}"
	debug "DOW: ${ITEM_PARTS[1]}"
	debug "HOUR: ${ITEM_PARTS[2]}"
	debug "MINUTE: ${ITEM_PARTS[3]}"

        if [ "${ITEM_PARTS[1]}" != "$(date +%u)" ] && [ "${ITEM_PARTS[1]}" != "*" ]; then
            debug "SKIP: Wrong day of week"
            continue # wrong day of week
        fi
        if [ "${ITEM_PARTS[2]}" != "$(date +%H)" ]; then
            debug "SKIP: Wrong hour, got ${ITEM_PARTS[2]}, expected $(date +%H)"
            continue # wrong hour
        fi
        if [ "${ITEM_PARTS[3]}" != "$(date +%M)" ]; then
            debug "SKIP: Wrong minute, got ${ITEM_PARTS[3]}, expected $(date +%M)"
            continue # wrong minute
        fi

        if [ "${ITEM_PARTS[0]}" == "START" ]; then
            run_start &
        fi
        if [ "${ITEM_PARTS[0]}" == "STOP" ]; then
            run_stop &
        fi

    done <<< "${1}"
}

run_start() {
    debug "Running start on {$INSTANCES}"
    ATTEMPTS=0
    LIMIT=30
    while [ ${ATTEMPTS} -lt ${LIMIT} ]; do
        aws ec2 start-instances --instance-ids="${INSTANCES}"
        if [ $? -eq 0 ]; then
            debug "Start successful"
            break 2
        fi
        ((ATTEMPTS++))
        debug "Start failed, attempts: ${ATTEMPTS}"
        sleep 5
    done
}

run_stop() {
    debug "Running stop on ${INSTANCES}"
    ATTEMPTS=0
    LIMIT=30
    while [ ${ATTEMPTS} -lt ${LIMIT} ]; do
        aws ec2 stop-instances --instance-ids="${INSTANCES}"
        if [ $? -eq 0 ]; then
            debug "Stop successful"
            break 2
        fi
        ((ATTEMPTS++))
        debug "Stop failed, attempts: ${ATTEMPTS}"
        sleep 5
    done
}

debug() {
    if [ "${DEBUG}" == "1" ]; then
        echo "DEBUG: ${1}"
    fi
}

setup_aws() {
    debug "Setting up AWS"
    mkdir ~/.aws
    echo "[default]" > ~/.aws/config
    echo "aws_access_key_id=${AWS_ACCESS_KEY_ID}" >> ~/.aws/config
    echo "aws_secret_access_key=${AWS_ACCESS_KEY_ID}" >> ~/.aws/config
    echo "region=${AWS_REGION}" >> ~/.aws/config
}

setup_aws
debug "Starting, sleeping for $((60 - $(date +%s) % 60)) until next minute"
sleep $((60 - $(date +%s) % 60))

SCHEDULE_ITEMS=$(echo "${SCHEDULE}" | tr "," "\n")

while [ true ]; do
    run_schedule "${SCHEDULE_ITEMS}"
    debug "Finished loop, sleeping for $((60 - $(date +%s) % 60)) until next run"

    sleep $((60 - $(date +%s) % 60))
done
