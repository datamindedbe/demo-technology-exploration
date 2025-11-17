#!/usr/bin/env python3
"""
Minimal demo for the Knowledge Inventory playground.

The script performs three simple steps:
1. Drop the temporary Airbyte cache schema (to avoid leftover types).
2. Run the Google Drive → Postgres sync with pyairbyte.
3. Show a lightweight summary of the loaded files.

Usage:
    python demo.py
"""

import os
import sys
import psycopg2
from psycopg2.extras import RealDictCursor
from sqlalchemy import create_engine, text as sql_text
from airbyte.caches import PostgresCache

from src.airbyte_client import sync_google_drive_to_postgres


def _resolve_db_host() -> str:
    """Return the correct database host for local vs Docker environments."""
    db_host = os.environ.get("DB_HOST")
    if db_host:
        return db_host
    return "host.docker.internal" if os.path.exists("/.dockerenv") else "localhost"


def check_prerequisites() -> bool:
    """Ensure the environment contains the variables required by the demo."""
    creds_path = os.environ.get("GOOGLE_JSON_PATH")
    if not creds_path:
        print("❌ GOOGLE_JSON_PATH environment variable is not set.")
        return False

    # When the path points inside the container we can verify existence up-front.
    if "/app/secrets" in creds_path and not os.path.exists(creds_path):
        print(f"❌ Google OAuth JSON file not found inside the container at {creds_path}")
        return False

    if not os.environ.get("GOOGLE_DRIVE_FOLDER_URL"):
        print("❌ GOOGLE_DRIVE_FOLDER_URL environment variable is not set.")
        return False

    print("✅ Prerequisites met")
    return True


def run_drive_sync(cache: PostgresCache) -> int:
    """Run the Google Drive sync workflow and return the number of processed records."""
    print("\n🔄 Starting Google Drive sync with pyairbyte...")
    record_count = sync_google_drive_to_postgres(cache=cache)
    if record_count > 0:
        print(f"✅ Sync completed successfully! Synced {record_count} records.")
    else:
        print("✅ Sync completed, but no new records were found.")
    return record_count


def show_results(db_host: str, db_port: str) -> None:
    """Print a short overview of the files currently stored in Postgres."""
    print("\n📊 Results Summary:")
    try:
        conn = psycopg2.connect(
            host=db_host,
            port=db_port,
            user="postgres",
            password="inventory",
        )
    except psycopg2.OperationalError as exc:
        print(f"❌ Unable to connect to Postgres: {exc}")
        return

    with conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT COUNT(*) AS count FROM google_drive_files;")
        total_files = cur.fetchone()["count"]
        print(f"📁 Total files synced: {total_files}")

        if total_files:
            cur.execute(
                """
                SELECT name, modified_time
                FROM google_drive_files
                ORDER BY modified_time DESC NULLS LAST
                LIMIT 5;
                """
            )
            print("🪪 Latest files:")
            for row in cur.fetchall():
                name = (row["name"] or "Unnamed document").strip()
                print(f"  • {name[:70]}{'…' if len(name) > 70 else ''}")

    conn.close()


def main() -> None:
    print("🚀 Knowledge Inventory Demo")
    print("=" * 35)

    if not check_prerequisites():
        sys.exit(1)

    db_host = _resolve_db_host()
    db_port = os.environ.get("DB_PORT", "5432")

    # Drop the cache schema to avoid pyairbyte type conflicts between runs.
    cleanup_engine = create_engine(f"postgresql://postgres:inventory@{db_host}:{db_port}/postgres")
    with cleanup_engine.connect() as conn:
        conn.execute(sql_text("DROP SCHEMA IF EXISTS airbyte_cache CASCADE;"))
        conn.commit()
    cleanup_engine.dispose()

    # Create a shared Postgres cache for pyairbyte to avoid DuckDB temp files.
    print("📦 Creating shared Postgres cache...")
    cache = PostgresCache(
        host=db_host,
        port=int(db_port),
        username="postgres",
        password="inventory",
        database="postgres",
        schema_name="airbyte_cache",
    )

    run_drive_sync(cache)
    show_results(db_host, db_port)

    print("\n✅ Demo completed.")
    print("💡 Connect to the postgres-inv database to explore the synced files.")


if __name__ == "__main__":
    main()
