#!/bin/bash
# k8s-tunnel.sh
# Manage SSH tunnel for local kubectl access to the Kubernetes cluster

PROXMOX_HOST="192.168.1.222"
K8S_MASTER="192.168.1.240"
SSH_KEY="$HOME/.ssh/proxmox_key"
LOCAL_PORT="6443"

case "$1" in
    start)
        echo "Starting SSH tunnel to Kubernetes API..."
        ssh -f -N -L ${LOCAL_PORT}:localhost:${LOCAL_PORT} \
            -i ${SSH_KEY} \
            -o ProxyCommand="ssh -W %h:%p -i ${SSH_KEY} root@${PROXMOX_HOST}" \
            ubuntu@${K8S_MASTER}

        if [ $? -eq 0 ]; then
            echo "✓ SSH tunnel started successfully"
            echo "  Local port ${LOCAL_PORT} → k8s-master:${LOCAL_PORT}"
        else
            echo "✗ Failed to start SSH tunnel"
            exit 1
        fi
        ;;

    stop)
        echo "Stopping SSH tunnel..."
        pkill -f "ssh.*${LOCAL_PORT}.*${K8S_MASTER}"
        echo "✓ SSH tunnel stopped"
        ;;

    status)
        if pgrep -f "ssh.*${LOCAL_PORT}.*${K8S_MASTER}" > /dev/null; then
            echo "✓ SSH tunnel is running"
            echo ""
            lsof -i :${LOCAL_PORT} | grep ssh
        else
            echo "✗ SSH tunnel is not running"
            exit 1
        fi
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        ;;

    *)
        echo "Usage: $0 {start|stop|status|restart}"
        echo ""
        echo "Manage SSH tunnel for local kubectl access to Kubernetes cluster"
        echo ""
        echo "Commands:"
        echo "  start   - Start the SSH tunnel"
        echo "  stop    - Stop the SSH tunnel"
        echo "  status  - Check tunnel status"
        echo "  restart - Restart the tunnel"
        exit 1
        ;;
esac
