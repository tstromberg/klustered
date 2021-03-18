#!/bin/sh
# Break a cluster in a way that requires the following debugging skills:
#
# * Knowledge of taints (noexecute)
# * Knowledge of eviction reasons (inodes)
# * Knowledge of CoreDNS
# * Knowledge of kill signals or process SIGSTOP/SIGCONT

kubectl get po -A --watch &

######################################
# Part 0: Launch innocuous "honk" pods
######################################
# honk
# honkhonk
# honkhonkhonk ...
perl -e '@a = (1..12); for $i (@a){ $name="honk" x $i; system("sed s/X/$name/ < honk.yaml | kubectl apply -f -")}'

###########################
# Part 1: Taint the workers
###########################
# a. Make only the master schedulable (to block future deployments)
kubectl get node --selector='!node-role.kubernetes.io/master' --no-headers \
    | awk '{ print $1 }' \
    | xargs -I{} kubectl taint nodes {} locked=true:NoExecute  

####################
# Part 2: DNS games!
####################
# a. Scale down DNS to make life easier
kubectl scale deployments.apps -n kube-system coredns --replicas=1

# b. Cause a real DNS loop between coredns and itself
kubectl apply -f coredns-loop-configmap.yaml

# c. Point the host DNS to coredns to make life even worse
scp resolver.crontab bighonk:/etc/cron.d/resolver

############################################################################
# Part 3: etcd sleepytime: pause/resume etcd in a loop via namespace sharing
############################################################################
kubectl apply -f etcd-sleepytime-pod.yaml

##########################
# Part 4: inode exhaustion
##########################
# Use up every inode on / - causing mass eviction and blocking deployments
ssh bighonk "while true; do mktemp; done"


echo "Done, watching the cluster burn (press Ctrl-C when bored)"
wait
