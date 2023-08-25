# ------------------------------- Base Image ---------------------------------
FROM python:3.11.0-slim AS base

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt
COPY app/ .

EXPOSE 8000
USER nobody

# --------------------------- Environments Images -----------------------------
FROM base AS development
CMD ["uvicorn", "hello:app", "--host", "0.0.0.0", "--reload"]

FROM base AS production
ENV PYTHONDEBUG=0
CMD ["uvicorn", "hello:app", "--host", "0.0.0.0"]
