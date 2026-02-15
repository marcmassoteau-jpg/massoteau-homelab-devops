FROM python:3.11-slim

WORKDIR /app

COPY app.py /app/

# Run as non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["python3", "app.py"]
