# Setting up and building an MCP server with Claude Desktop
**What you’ll learn:** 
How to get started building an MCP server from scratch
How to integrate an MCP server with Claude Desktop

## Video
📺 [Watch the webinar/demo](https://www.youtube.com/watch?v=fIr55-koOJQ)

## Author
- Name: [Pierre Crochelet](https://github.com/crocheletpierre)

## Stack
- Languages/Frameworks/Tools: Python / Claude Desktop
- Cloud/Services: None needed for a local run, but you'll need somewhere to host your MCP server if you want remote connections.
- Estimated run time: <10min

## Prereqs
- Claude desktop (Pro Plan if you want a remote server)
- Python with the `mcp[cli]` dependency
- [uv](https://docs.astral.sh/uv/getting-started/installation/)

## Quick start - Inspector
```bash
git clone https://github.com/datamindedbe/demo-technology-exploration
cd demos/claude_mcp
uv sync
uv run mcp dev main.py # For inspector which opens at http://localhost:6274/
```

If you open the inspector, make sure you set transport type to "STDIO" for this demo to work.


## Using Claude Desktop
To have it working with Claude, [download Claude Desktop](https://claude.ai/download)

Then go to `settings > developer` and `Edit Config` with the following, replacing values in angle brackets with your own:
```json
{
  "mcpServers": {
    "<server_name>": {
      "command": "<absolute_path_to_uv>",
      "args": [
        "--directory",
        "<absolute_path_to_code_repository>",
        "run",
        "main.py"
      ]
    }
  }
}
```

Note: you can retrieve your uv path with `which uv`, and your code repository path with `pwd`.

You can then shut down and restart Claude Desktop.
In the chat interface, make sure the "Demo" server toggle is set to "active".
You can now ask questions like:
- "list the files in the Demo environment", and
- "I want to know about the staff" as a follow-up question.

## Resources
The official spec can be found [here](https://modelcontextprotocol.io/docs/getting-started/intro)
You can find a variety of servers [here](https://github.com/modelcontextprotocol/servers) and [here](https://mcp.so)