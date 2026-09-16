#!/usr/bin/env bash
set -euo pipefail

docker ps -a --filter name=pg- --format '{{.Names}} {{.Status}}'

down=""
for node in pg-master pg-slave; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$node"; then
    down="$node"
  fi
done

if [[ -z "$down" ]]; then
  echo "Both nodes are UP. Run ./scripts/failover-test.sh first"
  exit 1
fi

echo "Writing while $down is down..."
docker run --rm --network host postgres:15 \
  bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "
INSERT INTO lab_demo(note) VALUES ('\''written while peer was down'\'');
SELECT * FROM lab_demo ORDER BY id;
"'

echo "Starting $down..."
docker start "$down"
sleep 20

echo "=== After rejoin ==="
./scripts/status.sh || true

echo "=== Data on rejoined node ==="
docker exec "$down" bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d postgres -c "SELECT * FROM lab_demo ORDER BY id; SELECT pg_is_in_recovery() AS is_replica;"'
