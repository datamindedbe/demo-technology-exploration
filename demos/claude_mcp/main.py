from mcp.server.fastmcp import FastMCP
import os

mcp = FastMCP("demo_server")

@mcp.tool()
def read_file(filename: str) -> list[str]:
    """
    Reads the content of the file

    Args:
        filename: Name of the file to read from
    
    Returns:
        All the lines in the files, in a list format
    """
    with open(filename, "r") as f:
        lines = f.readlines()
    return lines

@mcp.tool()
def write_file(contents: list[str], filename: str):
    """
    Write the contents in a file

    Args:
        contents: Contents to write
        filename: Name of the file to write into
    """
    with open(filename, "w") as f:
        f.writelines(line + '\n' for line in contents)

@mcp.tool()
def list_files(directory: str) -> list[str]:
    """
    List all files under the directory
    """
    return os.listdir(directory)

@mcp.resource("store://staff")
def get_staff() -> str:
    """
    Reads the current staff personal where each line is the name of a staff member
    """
    with open("store/inventory_staff.txt") as f:
        return f.read()
    
@mcp.resource("store://stock")
def get_stock() -> str:
    """
    Reads the current stock where each line represents one item with its current stock
    """
    with open("store/inventory_items.txt") as f:
        return f.read()

@mcp.prompt(title="Items to restock")
def items_to_restock() -> str:
    return ("Please Find items to restock in the following."
        "These are items where current stock is lower than 5"
    )


if __name__ == "__main__":
    mcp.run() # default to transport=stdio switch to sse for remote