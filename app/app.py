from flask import Flask, request, jsonify
import plyvel
import os
import time
import psutil
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)
db = plyvel.DB(os.getenv('DB_PATH', '/data/leveldb'), create_if_missing=True)

# Prometheus metrics
REQUEST_COUNT = Counter('leveldb_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('leveldb_request_duration_seconds', 'Request latency')
DB_SIZE = Gauge('leveldb_database_size_bytes', 'Database size in bytes')
MEMORY_USAGE = Gauge('leveldb_memory_usage_bytes', 'Memory usage in bytes')

@app.route('/write', methods=['POST'])
def write():
    start_time = time.time()
    try:
        key = request.args.get('key')
        value = request.args.get('value')
        
        if not key or not value:
            return jsonify({'error': 'Missing key or value'}), 400
            
        db.put(key.encode(), value.encode())
        
        REQUEST_COUNT.labels(method='POST', endpoint='/write').inc()
        REQUEST_LATENCY.observe(time.time() - start_time)
        
        return jsonify({'status': 'OK', 'key': key})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/read')
def read():
    start_time = time.time()
    try:
        key = request.args.get('key')
        
        if not key:
            return jsonify({'error': 'Missing key'}), 400
            
        value = db.get(key.encode())
        
        REQUEST_COUNT.labels(method='GET', endpoint='/read').inc()
        REQUEST_LATENCY.observe(time.time() - start_time)
        
        if value:
            return jsonify({'key': key, 'value': value.decode()})
        else:
            return jsonify({'error': 'Key not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    try:
        # Basic health check
        db.get(b'health_check')
        return jsonify({'status': 'healthy', 'timestamp': time.time()})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

@app.route('/metrics')
def metrics():
    # Update metrics
    try:
        # Get database size (approximate)
        db_size = sum(len(key) + len(value) for key, value in db)
        DB_SIZE.set(db_size)
    except:
        DB_SIZE.set(0)
    
    # Get memory usage
    process = psutil.Process()
    memory_info = process.memory_info()
    MEMORY_USAGE.set(memory_info.rss)
    
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/stats')
def stats():
    try:
        # Get basic statistics
        key_count = sum(1 for _ in db)
        db_size = sum(len(key) + len(value) for key, value in db)
        
        return jsonify({
            'key_count': key_count,
            'database_size_bytes': db_size,
            'uptime_seconds': time.time() - psutil.Process().create_time()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
