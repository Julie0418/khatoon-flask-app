# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container
COPY . /app

# Install required packages
RUN pip install --no-cache-dir flask flask-cors

# Expose port 5000
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]