FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Cloud Run will set PORT environment variable (typically 8080)
# Default to 8000 if not set
ENV PORT=8000
EXPOSE 8080

# Use shell form to allow environment variable expansion
CMD uvicorn main:app --host 0.0.0.0 --port $PORT
