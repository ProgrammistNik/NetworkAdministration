#!/usr/bin/env bash
set -euo pipefail

echo "=== Patroni: pg-master ==="
curl -s http://127.0.0.1:5433/patroni 2>/dev/null || \
  docker exec pg-master curl -s http://pg-master:8008/patroni
echo
echo

echo "=== Patroni: pg-slave ==="
docker exec pg-slave curl -s http://pg-slave:8008/patroni
echo
echo

echo "=== Cluster members ==="
docker exec pg-master curl -s http://pg-master:8008/cluster
echo
echo

echo "=== HAProxy stats ==="
curl -s http://127.0.0.1:7001/ | head -n 40 || true
echo
echo "http://127.0.0.1:7001/"
