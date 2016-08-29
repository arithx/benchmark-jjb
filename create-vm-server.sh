#!/bin/bash
name=$(uuidgen)
wget https://raw.github.com/arithx/shstack/master/user_data.yml

echo "Initial Name $name"

# Give RAX 3 tries to dodge build / cloud-init failures
while [[ "$count" -lt 3 ]] ; do
    ((++count))
    echo "Try #$count"

    # Create the server and wait until it's status is ACTIVE or ERROR
    rack servers instance create --name "$name" --flavor-id "performance1-8" --image-name "Ubuntu 14.04 LTS (Trusty Tahr) (PVHVM)" --keypair "devstack-ci" --user-data user_data.yml &> /dev/null
    time_determining_status=0
    status=""
    while [[ "$status" != "ACTIVE" && "$status" != "ERROR" ]]; do
        status="$(rack servers instance get --name "$name" | grep "Status.*" | awk '{print $2}')"
        ((++time_determining_status))
        sleep 1
        if ! ((time_determining_status % 60)); then
            echo "Server has been building for $(((time_determining_status / 60))) minutes."
        fi
        if [ "$time_determining_status" -gt 300 ] ; then
            break
        fi
    done

    echo "Status $status after $time_determining_status seconds."

    if [ "$status" = "ACTIVE" ] ; then
        # Give it 15 seconds after going active to make sure that the IPv4 is set
        sleep 15
        rack servers instance get --name "$name"
        SERVER=$(rack servers instance get --name "$name" | grep "PublicIPv4.*" | awk '{print $2}')

        # Check the cloud-init-output.log to make sure that it hasn't hung on a single action for 4 minutes (this will need testing)
        echo "Beggining cloud-init monitoring"
        same_count=0
        while :; do
            sleep 60
            tmp_last_line=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$SERVER tail -1 /var/log/cloud-init-output.log 2> /dev/null)
            if [ "$last_line" = "$tmp_last_line" ] ; then
                ((++same_count))
                echo "cloud-init log has been the same for $same_count minutes."
                if [ "$same_count" -ge 4 ] ; then
                    echo "cloud-init seems to have died."
                    echo "Last new cloud-init line $last_line"
                    break
                fi
            else
                # Break if Cloud-init & finished are in the last line received
                if [ ! -z  "$(echo $tmp_last_line | egrep "Cloud-init" | egrep "finished")" ] ; then
                    echo "Last cloud-init line detected $tmp_last_line"
                    break
                fi
                same_count=0
                last_line=$tmp_last_line
            fi
        done
    fi

    # Failure case (either an ERROR state or failed cloud-init), delete and try again
    rack servers instance delete --name "$name"
    name=$(uuidgen)
    echo "Deleting the server and trying again under name $name."
done

if [ "$count" -eq 3 ] ; then
    exit 1
fi

echo "name=$name
ip=$SERVER" > $JENKINS_HOME/rally_vm.sh
