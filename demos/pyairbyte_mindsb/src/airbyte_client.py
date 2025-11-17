import os
import json
import hashlib
import airbyte as ab
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

def sync_google_drive_to_postgres(cache):
    """
    Syncs Google Drive files to PostgreSQL using Airbyte.
    """
    # Configure Google Drive source
    source = ab.get_source(
        "source-google-drive",
        install_if_missing=True,
        config={
            "folder_url": os.environ.get("GOOGLE_DRIVE_FOLDER_URL"),
            "credentials": {
                "auth_type": "Service",
                "service_account_info": json.dumps(json.loads(open(os.environ.get("GOOGLE_JSON_PATH")).read()))
            },
            "streams": [
                {
                    "name": "files_metadata",
                    "globs": ["**"],
                    "format": {"filetype": "unstructured", "skip_unstructured_parsing": False},
                    "validation_policy": "Emit Record"
                }
            ]
        }
    )

    # Check connection and read data
    source.check()
    source.select_all_streams()
    
    print("📚 Reading data from Google Drive...")
    result = source.read(cache=cache)
    
    # Convert to DataFrame
    df = result.cache["files_metadata"].to_pandas()
    
    # Extract metadata from _airbyte_data if present
    if '_airbyte_data' in df.columns:
        metadata_df = df['_airbyte_data'].apply(
            lambda x: json.loads(x) if isinstance(x, str) else x
        ).apply(pd.Series)
        df = df.combine_first(metadata_df)
    
    # Rename columns to match database schema
    df = df.rename(columns={
        'mimeType': 'mime_type',
        'modifiedTime': 'modified_time',
        'webViewLink': 'web_view_link'
    })
    
    # Select only the columns we need
    columns = ['id', 'name', 'mime_type', 'modified_time', 'web_view_link', 'description', 'content']
    df = df[[col for col in columns if col in df.columns]]
    
    # Generate ID from content if missing
    if 'id' not in df.columns and 'content' in df.columns:
        df['id'] = df['content'].apply(
            lambda x: hashlib.sha256(x.encode('utf-8')).hexdigest() if x else None
        )
    
    # Generate name from content if missing
    if 'name' not in df.columns and 'content' in df.columns:
        df['name'] = df['content'].apply(
            lambda x: x[:30].split('\n')[0] + "..." if x else "Unnamed Document"
        )
    
    # Clean data (only if 'id' column exists)
    if 'id' in df.columns:
        df = df.dropna(subset=['id'])
        df = df.drop_duplicates(subset=['id'], keep='last')
    
    # Convert dict/list columns to JSON strings to avoid database errors
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].apply(
            lambda x: json.dumps(x) if isinstance(x, (dict, list)) else x
        )
    
    # Connect to PostgreSQL
    db_host = os.environ.get("DB_HOST")
    if not db_host:
        # In docker-compose, use service name; otherwise use localhost
        db_host = "postgres-inv" if os.path.exists("/.dockerenv") else "localhost"
    db_port = os.environ.get("DB_PORT", "5432")
    engine = create_engine(f'postgresql://postgres:inventory@{db_host}:{db_port}/postgres')
    
    # Upsert to database
    with engine.connect() as conn:
        with conn.begin():
            df.to_sql('google_drive_files_staging', con=conn, if_exists='replace', index=False)
            
            cols = df.columns.tolist()
            update_cols = [c for c in cols if c != 'id']
            update_clause = ", ".join([f'"{col}" = EXCLUDED."{col}"' for col in update_cols])
            
            upsert_sql = f"""
                CREATE TABLE IF NOT EXISTS google_drive_files (
                    id VARCHAR(255) PRIMARY KEY,
                    name VARCHAR(255),
                    mime_type VARCHAR(255),
                    modified_time VARCHAR(255),
                    web_view_link VARCHAR(255),
                    description VARCHAR(255),
                    content TEXT
                );
                INSERT INTO google_drive_files ({", ".join([f'"{c}"' for c in cols])})
                SELECT {", ".join([f'"{c}"' for c in cols])} FROM google_drive_files_staging
                ON CONFLICT (id) DO UPDATE SET {update_clause};
            """
            conn.execute(text(upsert_sql))
    
    print(f"✅ Successfully synced {len(df)} records to database")
    engine.dispose()
    
    return len(df)

if __name__ == '__main__':
    num_records = sync_google_drive_to_postgres(cache=ab.get_default_cache())
    print(f"Synced {num_records} records") 