FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install flask plyvel prometheus-client psutil && \
    mkdir -p /data/leveldb

WORKDIR /app
COPY app.py .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app /data

USER appuser
VOLUME ["/data/leveldb"]

ENV DB_PATH /data/leveldb

EXPOSE 8080
CMD ["python", "app.py"]
