#!/bin/bash
# This script attempts to autodetect the maximum MTU value that allows throughput from the device to my.autopi.io.
#
# Process:
# Start executing pings so that you find the first low enough MTU to allow pings to go through without fragmentation ( -10 as recommended)
# Then, when this is found, start incrementing the MTU until you find the last MTU that works (+1 as recommended)
# Display calculated MTU value

if [ -z $1 ]; then
    echo -e "You need to provide a URL to ping. Usage:\n"
    echo -e "$0 <url_to_ping>"
    echo -e "Example: $0 my.autopi.io"
    exit 1
fi

HOST_TO_HIT=$1
PING_HEADER_SIZE=28
MTU=$((1500 - $PING_HEADER_SIZE))
#MTU=1528

DECREMENT_AMOUNT=10
INCREMENT_AMOUNT=1

autodetect() {
    # Start by checking if default MTU is good to go
    echo -e "\n---[ Start MTU detection procedure ]---"
    test_mtu "$MTU"
    if [ $? -eq 0 ]; then
        # MTU is good
        echo "MTU is good, skipping detection"
        show_calculated_mtu
        return 0
    else
        echo "MTU is bad, proceeding with detection"
    fi

    # First decrement until we're able to ping (find min)
    echo -e "\n---[ Start decrementing MTU until we find first successful ping ]---"
    decrement_until_successful

    # Next increment until we're unable to ping (find max)
    echo -e "\n---[ Start incrementing MTU until we find first failing ping ]---"
    increment_until_fail

    # Display MTU
    echo -e "\n---[ MTU FOUND ]---"
    show_calculated_mtu
}

test_mtu() {
    MTU_TO_TEST=$1
    bash -c "ping -I wwan0 -M do $HOST_TO_HIT -s $MTU_TO_TEST -c 1 2>&1" | egrep --ignore-case --quiet "(local error: message too long)|(frag needed and df set)"
    #bash -c "ping -M do my.autopi.io -s $MTU_TO_TEST -c 1 2>&1" | egrep -q "local error: message too long"

    if [ $? -eq 0 ]; then
        # MTU failed
        echo "Ping with MTU $MTU_TO_TEST failed"
        return 1
    else
        # MTU succeeded
        echo "Ping with MTU $MTU_TO_TEST succeeded"
        return 0
    fi
}

show_calculated_mtu() {
    echo "MTU: $(($MTU + $PING_HEADER_SIZE))"
}

decrement_until_successful() {
    min_mtu_found="false"
    while [ $min_mtu_found = "false" ]
    do
        # Decrement MTU
        MTU=$(($MTU - $DECREMENT_AMOUNT))

        # Check if we're at 0 or below
        if [ $MTU -le 0 ]; then
            echo "Couldn't find a valid MTU value before hitting 0!"
            return 1
        fi

        # Test new MTU
        test_mtu "$MTU"
        if [ $? -eq 0 ]; then
            # MTU is now good
            min_mtu_found="true"
        fi
    done
}

increment_until_fail() {
    max_mtu_found="false"
    while [ $max_mtu_found = "false" ]
    do
        TEST_MTU=$(($MTU + $INCREMENT_AMOUNT)) # unsure if this will work yet

        # Check if we're at 1500 or above
        if [ $MTU -ge 1500 ]; then
            echo "Couldn't find a max valid MTU value before hitting 1500!"
            return 1
        fi

        # Test new MTU
        test_mtu "$TEST_MTU"
        if [ $? -eq 0 ]; then
            # MTU is still good, maybe we can go higher
            MTU=$TEST_MTU
        else
            # MTU is no longer good, use last value
            # Don't assign TEST_MTU as it didn't succeed, get out of this loop
            break
        fi
    done
}

# Ensure that we've stopped qmi-manager (we don't want it interfering with the process we're making here)
echo "---[ Setup ]---"
echo "Stopping qmi-manager service"
systemctl stop qmi-manager
output=$(qmi-manager down) # in case it was up from a command

# Start the qmi-manager network (qmi-manager up)
echo "Bringing LTE connection up"
CONNECTED_TO_LTE="false"
while [ $CONNECTED_TO_LTE = "false" ]
do
    output=$(bash -c "qmi-manager up 2>&1")
    if [ $? -eq 0 ]; then # conn is up
        CONNECTED_TO_LTE="true"
    else
        # Check if SIM is connected
        echo $output | egrep -q "No SIM card present"
        if [ $? -eq 0 ]; then # SIM card not inserted
            echo "No SIM card present, breaking MTU detection"
            exit 1
        fi
        sleep 3
    fi
done
echo "LTE connection is up"

autodetect

# Stop the qmi-manager network
echo -e "\n---[ Cleanup ]---"
echo "Bringing LTE connection down"
output=$(qmi-manager down)

# Restart the qmi-manager
echo "Restarting qmi-manager service"
output=$(systemctl restart qmi-manager)
echo "Done"
