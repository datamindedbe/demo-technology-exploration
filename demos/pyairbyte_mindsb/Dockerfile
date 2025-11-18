# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Install curl for debugging network issues
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Install uv for fast package installation
RUN pip install uv

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN uv pip install --system --no-cache -r requirements.txt

# Set NLTK_DATA to /airbyte/nltk_data
ENV NLTK_DATA=/airbyte/nltk_data

# Prepare NLTK data directory
RUN rm -rf $NLTK_DATA && mkdir -p $NLTK_DATA

RUN rm -rf /app/.cache/default_cache/default_cache.duckdb
# Download NLTK data required by Airbyte Google Drive connector
RUN python - <<'PY'
import nltk, os, sys
download_dir = os.environ.get('NLTK_DATA', '/usr/share/nltk_data')
pkgs = [
    'punkt', 'punkt_tab',
    'averaged_perceptron_tagger', 'averaged_perceptron_tagger_eng',
    'maxent_ne_chunker',
    'words', 'stopwords', 'wordnet', 'omw-1.4'
]
for p in pkgs:
    try:
        nltk.download(p, download_dir=download_dir, quiet=True)
    except Exception as e:
        print(f'Failed to download {p}: {e}', file=sys.stderr)
PY

# Copy the rest of the application's code into the container
COPY . .

# Command to run the application
CMD ["python", "demo.py"]