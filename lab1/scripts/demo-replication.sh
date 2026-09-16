#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

leader=""
for node in pg-master pg-slave; do
  role=$(docker exec "$node" curl -s "http://${node}:8008/patroni" | grep -o '"role": "[^"]*"' | head -1 | cut -d'"' -f4 || true)
  echo "$node role=$role"
  if [[ "$role" == "master" || "$role" == "primary" || "$role" == "leader" ]]; then
    leader="$node"
  fi
done

if [[ -z "$leader" ]]; then
  echo "Leader not found"
  exit 1
fi

echo "Leader: $leader"

docker exec -i "$leader" bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d postgres' <<'SQL'
DROP TABLE IF EXISTS lab_demo;
CREATE TABLE lab_demo (
  id   serial PRIMARY KEY,
  note text NOT NULL,
  created_at timestamptz DEFAULT now()
);
INSERT INTO lab_demo (note) VALUES
  ('hello from leader'),
  ('replication check');
SELECT * FROM lab_demo;
SQL

echo
for node in pg-master pg-slave; do
  echo "--- $node SELECT ---"
  docker exec "$node" bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d postgres -c "SELECT * FROM lab_demo; SELECT pg_is_in_recovery() AS is_replica;"'
done

echo
for node in pg-master pg-slave; do
  role=$(docker exec "$node" curl -s "http://${node}:8008/patroni" | grep -o '"role": "[^"]*"' | head -1 | cut -d'"' -f4 || true)
  if [[ "$role" == "replica" ]]; then
    docker exec "$node" bash -c 'PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d postgres -c "INSERT INTO lab_demo(note) VALUES ('\''should fail'\'');"' || true
  fi
done
