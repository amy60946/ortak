#!/usr/bin/env bash
# Ortak şemanın tamamını yerel PostgreSQL'de dener. Her test dosyası kendi temiz veritabanında koşar:
# uygulanmış göçler + öneriler (her öneri iki kez: tekrar çalıştırmak zarar vermemeli) + test.
# Gerekenler: psql ve çalışan bir sunucu (PGHOST/PGPORT/PGUSER).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
for t in "$here"/test_*.sql; do
  db="ortak_$(basename "$t" .sql)"
  psql -q -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists $db" -c "create database $db"
  run() { psql -q -t -o /dev/null -v ON_ERROR_STOP=1 -d "$db" -f "$1"; }
  run "$here/supabase_stub.sql"
  for f in "$here"/../migrations/*.sql; do run "$f"; done
  for f in "$here"/../proposed/*.sql; do [ -e "$f" ] || continue; run "$f"; run "$f"; done
  run "$t"
  echo "geçti: $(basename "$t")"
done
echo "TAMAM: tüm testler geçti"
