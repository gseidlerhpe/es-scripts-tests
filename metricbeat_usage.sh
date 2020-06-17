#! /bin/bash
# Author:  Gernot Seidler
# Query total numbers of pods and metricbeat pod stats
# Param: metricbeat pod collecting kube-state metrics
# e.g. metricbeat-57b7bd984-qrbpz
#set -x

Pod=$1

if [ -z "$Pod" ]
then
    echo "Specify the pod to monitor"
    exit 1
fi

echo "Start: $(date)"
while true
do
	echo "$(date): Total number of pods - ALL namespaces:" $(kubectl get pods -A --no-headers=true | wc -l) 
	echo "Pod stats:"
	kubectl -n kube-system get pod $Pod 
	kubectl -n kube-system top pod $Pod
	kubectl -n kube-system describe pod $Pod | grep OOMKilled
done
