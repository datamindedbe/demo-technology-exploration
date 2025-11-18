import os
import time
import mysql.connector
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def execute_mindsdb_sql(sql_statements):
    """Connects to MindsDB and executes a list of SQL statements with a retry mechanism."""
    
    max_retries = 5
    retry_delay = 10  # seconds
    
    for attempt in range(max_retries):
        try:
            # Connect to MindsDB using its service name from docker-compose
            print(f"Attempting to connect to MindsDB (Attempt {attempt + 1}/{max_retries})...")
            conn = mysql.connector.connect(
                host="mindsdb",
                port=47335,
                user="mindsdb",
                password="inventory", # Default password, can be changed
                connection_timeout=10
            )
            cursor = conn.cursor()
            print("✅ Successfully connected to MindsDB.")

            # Execute each statement
            for statement in sql_statements:
                try:
                    print(f"Executing: {statement[:100]}...") # Print snippet of statement
                    cursor.execute(statement)
                    print("   ...Done.")
                except mysql.connector.Error as err:
                    # Ignore errors if the object already exists (e.g., database or model)
                    if "already exists" in str(err):
                        print(f"   ...Warning: {err}. Skipping.")
                    else:
                        raise err

            conn.commit()
            cursor.close()
            conn.close()
            print("✅ MindsDB setup commands executed successfully.")
            return # Exit the function on success

        except mysql.connector.Error as err:
            print(f"   ...Connection failed: {err}")
            if attempt < max_retries - 1:
                print(f"   Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                print("❌ Max retries reached. Could not connect to MindsDB.")
                print("   Please ensure the MindsDB container is running and healthy.")
                return

def main():
    """Main function to define and run the setup SQL."""
    
    openai_api_key = os.getenv("OPENAI_API_KEY")
    if not openai_api_key:
        print("❌ OPENAI_API_KEY environment variable not found. Please set it in your .env file.")
        return

    # --- SQL Statements for Setup ---

    # 1. Create a database connection to pgvector
    create_database_sql = """
    CREATE DATABASE IF NOT EXISTS postgres_inv
    WITH
        ENGINE = 'pgvector',
        PARAMETERS = {
            "host": "postgres-inv",
            "port": 5432,
            "database": "postgres",
            "user": "postgres",
            "password": "inventory",
            "distance": "cosine"
        };
    """

    # 2. Create (or update) a Knowledge Base that will RE-EMBED the content column
    create_kb_sql = f"""
    CREATE KNOWLEDGE_BASE IF NOT EXISTS mindsdb.google_drive_kb
    USING
        embedding_model = {{
            "provider": "openai",
            "model_name": "text-embedding-3-large",
            "api_key": "{openai_api_key}"
        }},
        storage = postgres_inv.google_drive_kb_storage,
        metadata_columns = ['name', 'mime_type', 'modified_time', 'web_view_link', 'description'],
        content_columns  = ['content'],
        id_column       = 'id';
    """

    # 3. Populate / refresh the Knowledge Base (this triggers re-embedding)
    populate_kb_sql = """
    INSERT INTO mindsdb.google_drive_kb
    SELECT id, name, mime_type, modified_time, web_view_link, description, content
    FROM postgres_inv.google_drive_files
    WHERE content IS NOT NULL;
    """

    # --- Execute SQL ---
    execute_mindsdb_sql([
        create_database_sql,
        create_kb_sql,
        populate_kb_sql
    ])

if __name__ == "__main__":
    main() 