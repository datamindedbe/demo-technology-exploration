# Use the official lightweight MindsDB image as a base
FROM mindsdb/mindsdb:latest

# Install the required dependencies for the RAG engine and PostgreSQL handler
# This ensures that the RAG model can be created and can connect to our database.
RUN pip install .[rag,postgres] 