FROM registry.redhat.io/ubi9/python-311:latest

LABEL maintainer="purefield"
LABEL description="process.py - Jinja2 template processor"

# Switch to root for package installation
USER 0

WORKDIR /app

# Copy requirements
COPY --chown=1001:0 requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

# Copy CLI processor code
COPY --chown=1001:0 process.py /app/process.py
COPY --chown=1001:0 lib/ /app/lib/
RUN chmod +x /app/process.py

# Switch back to non-root user for security
USER 1001

# Default to running against a mounted working tree
WORKDIR /work

# Exec-form entrypoint preserves argv so container args map directly to process.py
ENTRYPOINT ["python3", "/app/process.py"]
