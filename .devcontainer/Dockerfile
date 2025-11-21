# For more information, please refer to https://aka.ms/vscode-docker-python
# arm64v8/python:3.8
FROM arm64v8/python:3.14

RUN ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

# Creates a non-root user with an explicit UID and adds permission to access the /workspaces folder
# For more info, please refer to https://aka.ms/vscode-docker-python-configure-containers
# We create the /workspaces directory first, as it doesn't exist during the image build.
RUN mkdir -p /workspaces && \
    adduser -u 5678 --disabled-password --gecos "" appuser && \
    chown -R appuser:appuser /workspaces

WORKDIR /workspaces

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    curl https://packages.microsoft.com/keys/microsoft.asc > /etc/apt/trusted.gpg.d/microsoft.asc && \
    curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    unixodbc-dev \
    freetds-dev \
    chromium-driver \
    build-essential \
    libxml2-dev \
    libxslt1-dev \
    xsel && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip

# Install pip requirements
COPY requirements.txt .
RUN python -m pip install -r requirements.txt

USER appuser

# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
CMD ["python"]
