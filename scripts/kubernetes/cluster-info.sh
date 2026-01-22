#!/bin/bash
# cluster-info.sh
# Display comprehensive Kubernetes cluster information
# Run this from the k8s-master node

echo "====================================="
echo "Kubernetes Cluster Information"
echo "====================================="
echo ""

# Cluster info
echo "Cluster Info:"
echo "-------------"
kubectl cluster-info

echo ""
echo "Nodes:"
echo "------"
kubectl get nodes -o wide

echo ""
echo "System Pods:"
echo "------------"
kubectl get pods -n kube-system

echo ""
echo "Namespaces:"
echo "-----------"
kubectl get namespaces

echo ""
echo "Cluster Resources:"
echo "------------------"
kubectl get all --all-namespaces

echo ""
echo "====================================="
