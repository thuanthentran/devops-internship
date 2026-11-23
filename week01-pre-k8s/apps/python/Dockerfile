FROM python:3.13-slim
LABEL org.opencontainers.image.source="https://github.com/thuanthentran/devops-internship"
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
RUN useradd -m -u 1234 fastapi
USER fastapi
EXPOSE 8080
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
