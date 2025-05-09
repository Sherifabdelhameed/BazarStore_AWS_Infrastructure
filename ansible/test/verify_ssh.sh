#!/bin/bash

# Function to wait for container to be healthy
wait_for_container() {
    local container=$1
    local max_attempts=30
    local attempt=1

    echo "------------------------"
    echo "Waiting for $container to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker inspect --format='{{.State.Health.Status}}' $container | grep -q "healthy"; then
            echo "✅ $container is ready"
            return 0
        fi
        echo "Waiting for $container to be ready..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ $container failed to become healthy after $max_attempts attempts"
    return 1
}

# Function to test SSH connection
test_ssh() {
    local port=$1
    local host=$2
    echo "Testing SSH connection to $host on port $port..."
    echo "Attempting SSH connection with verbose output..."
    
    # Test if port is open first
    if ! nc -z $host $port 2>/dev/null; then
        echo "❌ Port $port is not open on $host"
        return 1
    fi
    
    # Try SSH connection with verbose output
    if ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i test/ssh_keys/id_rsa -p $port root@$host "echo 'SSH connection successful'"; then
        echo "✅ SSH connection to $host on port $port successful"
        return 0
    else
        echo "❌ SSH connection to $host on port $port failed"
        return 1
    fi
}

# Main script
echo "Waiting for containers to be ready..."

# Wait for all containers to be healthy
wait_for_container "jenkins_server" || exit 1
wait_for_container "eks_node1" || exit 1
wait_for_container "eks_node2" || exit 1

echo "Testing SSH connections..."
echo "------------------------"

# Test SSH connections
test_ssh 2222 "localhost" || exit 1
test_ssh 2223 "localhost" || exit 1
test_ssh 2224 "localhost" || exit 1

echo "------------------------"
echo "✅ All SSH connections successful!" 