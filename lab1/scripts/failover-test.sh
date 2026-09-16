#!/usr/bin/env bash
set -euo pipefail

echo "=== Before failover ==="
./scripts/status.sh || true

leader=""
for node in pg-master pg-slave; do
  role=$(docker exec "$node" curl -s "http://${node}:8008/patroni" | grep -o '"role": "[^"]*"' | head -1 | cut -d'"' -f4 || true)
  echo "$node => $role"
  if [[ "$role" == "master" || "$role" == "primary" || "$role" == "leader" ]]; then
    leader="$node"
  fi
done

if [[ -z "$leader" ]]; then
  echo "Leader not found"
  exit 1
fi

echo
echo "Stopping leader: $leader"
docker stop "$leader"

echo "Waiting for election..."
for i in $(seq 1 20); do
  sleep 2
  other="pg-slave"
  [[ "$leader" == "pg-slave" ]] && other="pg-master"
  if docker exec "$other" curl -sf "http://${other}:8008/patroni" 2>/dev/null | grep -Eq '"role": "(master|primary|leader)"'; then
    echo "New leader: $other (try $i)"
    break
  fi
  echo "  waiting ($i)"
done

echo
echo "=== After failover (HAProxy :5432) ==="
docker run --rm --network host postgres:15 \
  bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "
INSERT INTO lab_demo(note) VALUES ('\''after failover'\'');
SELECT * FROM lab_demo ORDER BY id;
SELECT pg_is_in_recovery() AS connected_to_replica_should_be_false;
"'

echo
echo "Survivor logs:"
other="pg-slave"
[[ "$leader" == "pg-slave" ]] && other="pg-master"
docker logs --tail 40 "$other"

echo
echo "Restore: docker start $leader && sleep 15 && ./scripts/status.sh"
