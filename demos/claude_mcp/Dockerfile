# Use the official Python image
FROM python:3.13-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install the project into /app
COPY . /app
WORKDIR /app

# Allow statements and log messages to immediately appear in the logs
ENV PYTHONUNBUFFERED=1

# Install dependencies
RUN rm -rf .venv
RUN uv sync

# Cloud Run sets PORT automatically, but we expose 8080 as default
# Note: EXPOSE is just documentation - the actual port is configured in main.py
EXPOSE 8080

# Run the FastMCP server
CMD ["uv", "run", "python","main.py", "http"]