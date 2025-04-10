
from flask import Flask, jsonify
import socket

app = Flask(__name__)

# Get hostname and IP address
hostname = socket.gethostname()
ip_address = socket.gethostbyname(hostname)

# Main route modified as per assignment requirements
@app.route('/')
def home():
    return jsonify({"message": "Welcome to Khatoon Final Test API Server"})

# Host route
@app.route('/host')
def host_name():
    return jsonify({"hostname": hostname})

# IP route
@app.route('/ip')
def host_ip():
    return jsonify({"ip_address": ip_address})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)