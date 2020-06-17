#! /bin/bash
# Author:  Gernot Seidler
# Query kube-state metrics pod for restarts and memory utilization
# Param: metricbeat pod collecting kube-state metrics
# e.g. metricbeat-57b7bd984-qrbpz
#set -x

Pod=$1

if [ -z "$Pod" ]
then
    echo "Specify the pod to monitor"
    exit 1
fi

if [ -z "$2" ]
then
    Pod_Mem_limit="1"
    echo "Using Default Pod Memory Limit: $Pod_Mem_limit Gi"
else
    Pod_Mem_limit=$2
fi

printf "%.2f" $Pod_Mem_limit > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "$Pod_Mem_limit is not a valid number"
	exit 1
fi

pod_limit=$(printf "%.2f" $Pod_Mem_limit)
declare -i max_alloc=0
declare -i cur_alloc=0

pod_limit_95_bytes=$(echo "scale=2; $pod_limit*1073741824*0.95" | bc)
pod_limit_95_bytes=$(printf "%.0f" $pod_limit_95_bytes)

kubectl -n kube-system get pod $Pod --no-headers=true > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "Pod $Pod not found"
	exit 1
fi

cur_pod_state=($(kubectl -n kube-system get pod $Pod --no-headers=true | awk '{print $3,$4}'))
if [ ${cur_pod_state[0]} != "Running" ]
then
	echo "Pod $Pod is not running"
	exit 1
fi

pod_restarts_init=${cur_pod_state[1]} 
prev_pod_running_state=${cur_pod_state[0]} 
echo "Pod Limit 95%: $pod_limit_95_bytes bytes, initial restarts: $pod_restarts_init"
echo "Start: $(date)"
while true
do
	cur_alloc=$(kubectl -n kube-system logs  $Pod --since=30s | grep  -Eo '\"memory_alloc\"\:[0-9]{1,}' | awk -F ':' '{ print $2 }')
	if [ $cur_alloc -gt $max_alloc ]
	then
		max_alloc=$cur_alloc
		tmp=$(echo "scale=4; $max_alloc/1048576.0" | bc)
		
		if [ $max_alloc -gt $pod_limit_95_bytes ]
		then
			echo "$(date): Max. memory allocation exeeded 95% of Pod limit: $max_alloc bytes ($pod_limit_95_bytes bytes)"
		else
			printf "$(date): Max: %.3f Mi (%d bytes)\n" $tmp $max_alloc
		fi
	fi

	cur_pod_state=($(kubectl -n kube-system get pod $Pod --no-headers=true | awk '{print $3,$4}'))
	if [ $prev_pod_running_state != ${cur_pod_state[0]} ]
	then
		echo "$(date): Pod state change: $prev_pod_running_state -> ${cur_pod_state[0]}"
		prev_pod_running_state=${cur_pod_state[0]} 
	fi

	if [ ${cur_pod_state[0]} != "Running" ] && [ $pod_restarts_init -ne ${cur_pod_state[1]} ]
	then
		echo "$(date): Pod state: ${cur_pod_state[0]}, restarts: ${cur_pod_state[1]}"
		pod_restarts_init=${cur_pod_state[1]} 
	fi

	sleep 10
done