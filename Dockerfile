# Build Stage #
FROM python:3.12-slim AS builder

WORKDIR /app

# Create virtual environment to isolate dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Layer Caching: Install system dependencies and build tools
COPY app/requirements.txt .

# Install dependencies, then strip pip/build tools to minimize runtime footprint
RUN pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y pip setuptools wheel 2>/dev/null || true

# Production Stage #
FROM python:3.12-slim AS production

# Optimize python execution in container
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Create a non-root user and group to run the application
RUN groupadd --system --gid 10001 appgroup && \
    useradd --system --uid 10001 --gid appgroup --no-create-home appuser

# Copy the virtual environment from the builder stage
COPY --from=builder --chown=appuser:appgroup /opt/venv /opt/venv

# Copy application code to the production image
COPY --chown=appuser:appgroup app/ ./app/

# Set the user to the non-root user
USER appuser

# Expose the port that the application will run on
EXPOSE 8080

# The whole context was copied to /app, so the app package lives in /app/app.
CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]