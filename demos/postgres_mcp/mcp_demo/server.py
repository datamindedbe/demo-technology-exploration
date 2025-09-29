#!/usr/bin/env python3
import os
import asyncio
import asyncpg
import logging
import sys
from typing import Any, Dict, List, Optional
from fastmcp import FastMCP

# Set up logging with less verbose output for production
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create MCP server with proper configuration
mcp = FastMCP("Postgres Database Server")

# Database configuration - you can set these as environment variables
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

async def get_db_connection(database_name: str = None):
    """Get a database connection with proper error handling"""
    db_name = database_name or DB_NAME
    try:
        return await asyncpg.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=db_name,
            user=DB_USER,
            password=DB_PASSWORD,
            timeout=30.0,  # Increased timeout
            command_timeout=60.0,  # Command timeout
            server_settings={
                'application_name': 'mcp_postgres_server',
                'tcp_keepalives_idle': '600',
                'tcp_keepalives_interval': '30',
                'tcp_keepalives_count': '3'
            }
        )
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise

# Test database connection on startup
async def test_db_connection():
    """Test database connection during startup"""
    try:
        logger.info(f"Testing connection to {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
        conn = await get_db_connection()
        
        # Test with a simple query
        result = await conn.fetchval("SELECT 1")
        await conn.close()
        
        logger.info(f"Database connection successful: {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
        return True
    except Exception as e:
        logger.error(f"Database connection test failed: {e}")
        logger.error(f"Connection details: {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
        return False

@mcp.tool
async def list_tables(random_string: str = "dummy") -> Dict[str, Any]:
    """List all tables in the database from all schemas"""
    conn = None
    try:
        conn = await get_db_connection()
        
        query = """
        SELECT 
            table_schema,
            table_name,
            table_schema || '.' || table_name as full_name
        FROM information_schema.tables 
        WHERE table_type = 'BASE TABLE'
        AND table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        ORDER BY table_schema, table_name
        """
        
        rows = await conn.fetch(query)
        
        tables = []
        schemas = {}
        for row in rows:
            table_info = {
                "schema": row['table_schema'],
                "name": row['table_name'],
                "full_name": row['full_name']
            }
            tables.append(table_info)
            
            # Group by schema
            schema = row['table_schema']
            if schema not in schemas:
                schemas[schema] = []
            schemas[schema].append(row['table_name'])
        
        return {
            "tables": tables,
            "schemas": schemas,
            "total_count": len(tables),
            "schema_count": len(schemas),
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"Error in list_tables: {str(e)}")
        return {
            "tables": [],
            "schemas": {},
            "total_count": 0,
            "schema_count": 0,
            "status": "error",
            "error": str(e)
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def describe_table(table_name: str, schema_name: str = None) -> Dict[str, Any]:
    """Get the schema information for a specific table. If schema_name is not provided, searches all schemas."""
    conn = None
    try:
        conn = await get_db_connection()
        
        if schema_name:
            query = """
            SELECT 
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                table_schema
            FROM information_schema.columns 
            WHERE table_name = $1 AND table_schema = $2
            ORDER BY ordinal_position
            """
            rows = await conn.fetch(query, table_name, schema_name)
        else:
            query = """
            SELECT 
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                table_schema
            FROM information_schema.columns 
            WHERE table_name = $1 
            AND table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            ORDER BY table_schema, ordinal_position
            """
            rows = await conn.fetch(query, table_name)
        
        columns = [dict(row) for row in rows]
        schemas_found = list(set(row['table_schema'] for row in rows)) if rows else []
        
        return {
            "table_name": table_name,
            "schema_name": schema_name,
            "schemas_found": schemas_found,
            "columns": columns,
            "column_count": len(columns),
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"Error in describe_table: {str(e)}")
        return {
            "table_name": table_name,
            "schema_name": schema_name,
            "schemas_found": [],
            "columns": [],
            "column_count": 0,
            "status": "error",
            "error": str(e)
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def execute_query(query: str, limit: int = 100) -> Dict[str, Any]:
    """Execute a SQL query on the database (SELECT statements only for safety)"""
    # Basic safety check - only allow SELECT statements
    query_stripped = query.strip().upper()
    if not query_stripped.startswith('SELECT'):
        return {"error": "Only SELECT statements are allowed for safety"}
    
    conn = None
    try:
        conn = await get_db_connection()
        
        # Add LIMIT clause if not present
        if 'LIMIT' not in query_stripped:
            query = f"{query.rstrip(';')} LIMIT {limit}"
        
        # Add timeout for query execution
        rows = await asyncio.wait_for(conn.fetch(query), timeout=60.0)
        
        # Convert rows to list of dictionaries
        result_data = [dict(row) for row in rows]
        
        result = {
            "rows": result_data,
            "row_count": len(result_data),
            "query": query
        }
        logger.info(f"Query executed successfully: {len(result_data)} rows returned")
        return result
    except asyncio.TimeoutError:
        error_msg = "Query execution timed out"
        logger.error(f"Query execution timed out: {query}")
        return {"error": error_msg, "query": query}
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Query execution failed: {error_msg}")
        return {"error": error_msg, "query": query}
    finally:
        if conn:
            try:
                await conn.close()
            except Exception:
                pass  # Ignore close errors

@mcp.tool
async def get_table_sample(table_name: str, limit: int = 5) -> Dict[str, Any]:
    """Get a sample of rows from a specific table"""
    conn = None
    try:
        conn = await get_db_connection()
        query = f"SELECT * FROM {table_name} LIMIT {limit}"
        rows = await conn.fetch(query)
        
        result_data = [dict(row) for row in rows]
        
        return {
            "rows": result_data,
            "row_count": len(result_data),
            "query": query,
            "table_name": table_name
        }
    except Exception as e:
        logger.error(f"Error getting sample from table {table_name}: {str(e)}")
        return {"error": str(e), "table_name": table_name, "query": f"SELECT * FROM {table_name} LIMIT {limit}"}
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def search_table(table_name: str, column_name: str, search_term: str, limit: int = 50) -> Dict[str, Any]:
    """Search for records in a table where a column contains the search term"""
    conn = None
    try:
        conn = await get_db_connection()
        query = f"SELECT * FROM {table_name} WHERE {column_name}::text ILIKE $1 LIMIT {limit}"
        rows = await conn.fetch(query, f"%{search_term}%")
        
        result_data = [dict(row) for row in rows]
        
        return {
            "rows": result_data,
            "row_count": len(result_data),
            "query": query,
            "search_term": search_term
        }
    except Exception as e:
        logger.error(f"Search failed: {str(e)}")
        return {"error": str(e), "table": table_name, "column": column_name, "search_term": search_term}
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def list_databases(random_string: str = "dummy") -> List[Dict[str, Any]]:
    """List all databases that the user has access to"""
    conn = None
    try:
        conn = await get_db_connection()
        query = """
        SELECT 
            datname as database_name,
            pg_encoding_to_char(encoding) as encoding,
            datcollate as collation,
            pg_size_pretty(pg_database_size(datname)) as size
        FROM pg_database 
        WHERE datistemplate = false
        ORDER BY datname;
        """
        rows = await conn.fetch(query)
        return [dict(row) for row in rows]
    except Exception as e:
        logger.error(f"Error listing databases: {e}")
        return []
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def list_schemas(database_name: Optional[str] = None) -> List[Dict[str, Any]]:
    """List all schemas in the current database or a specified database"""
    conn = None
    try:
        conn = await get_db_connection()
        query = """
        SELECT 
            schema_name,
            schema_owner,
            CASE 
                WHEN schema_name IN ('information_schema', 'pg_catalog', 'pg_toast') 
                THEN 'system'
                ELSE 'user'
            END as schema_type
        FROM information_schema.schemata
        ORDER BY 
            CASE WHEN schema_name = 'public' THEN 1 ELSE 2 END,
            schema_name;
        """
        rows = await conn.fetch(query)
        return [dict(row) for row in rows]
    except Exception as e:
        logger.error(f"Error listing schemas: {e}")
        return []
    finally:
        if conn:
            await conn.close()


@mcp.tool
async def get_database_info(random_string: str = "dummy") -> Dict[str, Any]:
    """Get information about the current database"""
    conn = None
    try:
        conn = await get_db_connection()
        query = """
        SELECT 
            current_database() as database_name,
            current_user as current_user,
            session_user as session_user,
            version() as postgresql_version,
            current_setting('server_version') as server_version,
            pg_size_pretty(pg_database_size(current_database())) as database_size;
        """
        row = await conn.fetchrow(query)
        return dict(row) if row else {}
    except Exception as e:
        logger.error(f"Error getting database info: {e}")
        return {}
    finally:
        if conn:
            await conn.close()


@mcp.tool
async def get_table_info(table_name: str, schema_name: str = 'public') -> Dict[str, Any]:
    """Get detailed information about a specific table including size, row count, and indexes"""
    conn = None
    try:
        conn = await get_db_connection()
        
        table_info_query = """
        SELECT 
            schemaname as schema_name,
            tablename as table_name,
            tableowner as table_owner,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size
        FROM pg_tables 
        WHERE tablename = $1 AND schemaname = $2;
        """
        
        row_count_query = """
        SELECT reltuples::bigint as estimated_row_count
        FROM pg_class 
        WHERE relname = $1 
        AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = $2);
        """
        
        indexes_query = """
        SELECT 
            indexname as index_name,
            indexdef as index_definition
        FROM pg_indexes 
        WHERE tablename = $1 AND schemaname = $2
        ORDER BY indexname;
        """
        
        table_info = await conn.fetchrow(table_info_query, table_name, schema_name)
        row_count = await conn.fetchrow(row_count_query, table_name, schema_name)
        indexes = await conn.fetch(indexes_query, table_name, schema_name)
        
        result = {}
        if table_info:
            result.update(dict(table_info))
        if row_count:
            result['estimated_row_count'] = row_count['estimated_row_count']
        
        result['indexes'] = [dict(idx) for idx in indexes]
        
        return result
    except Exception as e:
        logger.error(f"Error getting table info for {schema_name}.{table_name}: {e}")
        return {}
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def test_connection(random_string: str = "dummy") -> Dict[str, Any]:
    """Test database connection and return connection status"""
    conn = None
    try:
        conn = await get_db_connection()
        result = await conn.fetchval("SELECT 1")
        
        return {
            "status": "success",
            "message": "Database connection successful",
            "test_query_result": result,
            "database": DB_NAME,
            "host": DB_HOST,
            "port": DB_PORT,
            "user": DB_USER
        }
        
    except Exception as e:
        logger.error(f"Database connection test failed: {e}")
        return {
            "status": "error",
            "message": f"Database connection failed: {str(e)}",
            "database": DB_NAME,
            "host": DB_HOST,
            "port": DB_PORT,
            "user": DB_USER
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def switch_database(database_name: str) -> Dict[str, Any]:
    """Switch to a different database"""
    global DB_NAME
    old_db = DB_NAME
    DB_NAME = database_name
    
    # Test the new connection
    conn = None
    try:
        conn = await get_db_connection()
        result = await conn.fetchval("SELECT current_database()")
        
        return {
            "status": "success",
            "message": f"Successfully switched to database: {database_name}",
            "previous_database": old_db,
            "current_database": result
        }
    except Exception as e:
        # Revert on failure
        DB_NAME = old_db
        logger.error(f"Failed to switch to database {database_name}: {e}")
        return {
            "status": "error",
            "message": f"Failed to switch to database {database_name}: {str(e)}",
            "current_database": old_db
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def query_database(database_name: str, query: str, limit: int = 100) -> Dict[str, Any]:
    """Execute a query on a specific database without switching context"""
    # Basic safety check - only allow SELECT statements
    query_stripped = query.strip().upper()
    if not query_stripped.startswith('SELECT'):
        return {"error": "Only SELECT statements are allowed for safety"}
    
    conn = None
    try:
        conn = await get_db_connection(database_name)
        
        # Add LIMIT clause if not present
        if 'LIMIT' not in query_stripped:
            query = f"{query.rstrip(';')} LIMIT {limit}"
        
        # Add timeout for query execution
        rows = await asyncio.wait_for(conn.fetch(query), timeout=60.0)
        
        # Convert rows to list of dictionaries
        result_data = [dict(row) for row in rows]
        
        result = {
            "rows": result_data,
            "row_count": len(result_data),
            "query": query,
            "database": database_name
        }
        logger.info(f"Query executed successfully on {database_name}: {len(result_data)} rows returned")
        return result
    except asyncio.TimeoutError:
        error_msg = "Query execution timed out"
        logger.error(f"Query execution timed out on {database_name}: {query}")
        return {"error": error_msg, "query": query, "database": database_name}
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Query execution failed on {database_name}: {error_msg}")
        return {"error": error_msg, "query": query, "database": database_name}
    finally:
        if conn:
            try:
                await conn.close()
            except Exception:
                pass  # Ignore close errors

@mcp.tool
async def get_table_statistics(table_name: str, schema_name: str = 'public', database_name: str = None) -> Dict[str, Any]:
    """Get comprehensive statistics for a table including count, min, max, avg, median"""
    conn = None
    try:
        conn = await get_db_connection(database_name)
        
        # Get table structure to identify numeric columns
        columns_query = """
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = $1 AND table_schema = $2
        AND data_type IN ('integer', 'bigint', 'numeric', 'decimal', 'real', 'double precision')
        ORDER BY ordinal_position
        """
        numeric_columns = await conn.fetch(columns_query, table_name, schema_name)
        
        if not numeric_columns:
            return {
                "table_name": f"{schema_name}.{table_name}",
                "message": "No numeric columns found for statistics",
                "columns": []
            }
        
        # Get basic count
        count_query = f"SELECT COUNT(*) as total_rows FROM {schema_name}.{table_name}"
        total_rows = await conn.fetchval(count_query)
        
        statistics = {
            "table_name": f"{schema_name}.{table_name}",
            "total_rows": total_rows,
            "numeric_columns": []
        }
        
        # Get statistics for each numeric column
        for col in numeric_columns:
            col_name = col['column_name']
            col_type = col['data_type']
            
            # Get min, max, avg
            stats_query = f"""
            SELECT 
                MIN({col_name}) as min_value,
                MAX({col_name}) as max_value,
                AVG({col_name}) as avg_value,
                COUNT({col_name}) as non_null_count
            FROM {schema_name}.{table_name}
            WHERE {col_name} IS NOT NULL
            """
            stats = await conn.fetchrow(stats_query)
            
            # Get median using a more robust approach
            median_query = f"""
            SELECT {col_name} as median_value
            FROM {schema_name}.{table_name}
            WHERE {col_name} IS NOT NULL
            ORDER BY {col_name}
            LIMIT 1 OFFSET (
                SELECT COUNT(*) / 2 
                FROM {schema_name}.{table_name} 
                WHERE {col_name} IS NOT NULL
            )
            """
            median_result = await conn.fetchrow(median_query)
            median_value = median_result['median_value'] if median_result else None
            
            column_stats = {
                "column_name": col_name,
                "data_type": col_type,
                "min_value": stats['min_value'],
                "max_value": stats['max_value'],
                "avg_value": float(stats['avg_value']) if stats['avg_value'] else None,
                "median_value": median_value,
                "non_null_count": stats['non_null_count']
            }
            statistics["numeric_columns"].append(column_stats)
        
        return statistics
        
    except Exception as e:
        logger.error(f"Error getting table statistics for {schema_name}.{table_name}: {e}")
        return {
            "table_name": f"{schema_name}.{table_name}",
            "error": str(e)
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def get_foreign_keys(table_name: str, schema_name: str = 'public', database_name: str = None) -> Dict[str, Any]:
    """Get foreign key relationships for a table"""
    conn = None
    try:
        conn = await get_db_connection(database_name)
        
        query = """
        SELECT
            tc.constraint_name,
            tc.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_name = $1
        AND tc.table_schema = $2
        ORDER BY tc.constraint_name, kcu.ordinal_position
        """
        
        rows = await conn.fetch(query, table_name, schema_name)
        foreign_keys = [dict(row) for row in rows]
        
        return {
            "table_name": f"{schema_name}.{table_name}",
            "foreign_keys": foreign_keys,
            "foreign_key_count": len(foreign_keys)
        }
        
    except Exception as e:
        logger.error(f"Error getting foreign keys for {schema_name}.{table_name}: {e}")
        return {
            "table_name": f"{schema_name}.{table_name}",
            "error": str(e)
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
async def explain_query(query: str, database_name: str = None) -> Dict[str, Any]:
    """Get query execution plan for performance analysis"""
    # Basic safety check - only allow SELECT statements
    query_stripped = query.strip().upper()
    if not query_stripped.startswith('SELECT'):
        return {"error": "Only SELECT statements are allowed for safety"}
    
    conn = None
    try:
        conn = await get_db_connection(database_name)
        
        # Get execution plan
        explain_query_sql = f"EXPLAIN (FORMAT JSON) {query}"
        result = await conn.fetch(explain_query_sql)
        
        return {
            "query": query,
            "execution_plan": result[0]['QUERY PLAN'] if result else None,
            "database": database_name or DB_NAME
        }
        
    except Exception as e:
        logger.error(f"Error explaining query: {e}")
        return {
            "query": query,
            "error": str(e),
            "database": database_name or DB_NAME
        }
    finally:
        if conn:
            await conn.close()

@mcp.tool
def get_server_status(random_string: str = "dummy") -> Dict[str, Any]:
    """Simple diagnostic tool to test MCP server functionality"""
    return {
        "status": "running",
        "message": "MCP server is working correctly",
        "database_config": {
            "host": DB_HOST,
            "port": DB_PORT,
            "database": DB_NAME,
            "user": DB_USER
        }
    }

if __name__ == "__main__":
    try:
        logger.info("Starting Postgres Database MCP Server...")
        
        # Test database connection before starting server (but don't fail startup)
        async def startup_check():
            try:
                if await test_db_connection():
                    logger.info("Database connection verified. Starting MCP server...")
                else:
                    logger.warning("Database connection test failed, but continuing to start server. Use test_connection tool to debug.")
            except Exception as e:
                logger.warning(f"Startup database check failed: {e}. Server will start anyway.")
        
        # Run startup check
        asyncio.run(startup_check())
        
        # Start the MCP server
        logger.info("Starting MCP server...")
        mcp.run()
        
    except KeyboardInterrupt:
        logger.info("Server shutdown requested")
    except Exception as e:
        logger.error(f"Server startup failed: {e}")
        sys.exit(1)