# <Demo Title>
**What you’ll learn:** 
You will learn how to query your postgres database using natural language.
You will see how it becomes even more powerful in combination with your dbt code.

## Video
📺 [Watch the webinar/demo](<YouTube link>)

## Author
- Name: Emil Krause, github: emil-k

## Stack
- Languages/Frameworks/Tools: fastmcp, postgres
- Cloud/Services: local
- Estimated run time: <5 min

## Prereqs
- uv
- postgres

## Quick start
```bash
git clone https://github.com/datamindedbe/demo-technology-exploration
cd demos/postgres_mcp/mcp_demo
make setup     
```
Create a config file with the settings for the mcp server. 

On Mac, the path is:
`/Users/yourusername/.cursor/mcp.json
`

With this structure:

``` 
{
  "mcpServers": {
    "postgres-db": {
      "command": "/Users/emilkrause/github/emil_mcp/venv/bin/python",
      "args": [
        "/Users/emilkrause/github/emil_mcp/server.py"
      ],
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "db",
        "DB_USER": "user",
        "DB_PASSWORD": "pass",
        "PYTHONUNBUFFERED": "1"
      }
    }
  }
}
```


## Resources
https://github.com/jlowin/fastmcp
