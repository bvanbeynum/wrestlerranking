# For more information, please refer to https://aka.ms/vscode-docker-python
# arm64v8/python:3.8
FROM arm64v8/python:3.10

RUN ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

RUN curl https://packages.microsoft.com/keys/microsoft.asc > /etc/apt/trusted.gpg.d/microsoft.asc
RUN curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list

# Update package lists and install all system dependencies in one go.
# This is more efficient and ensures all build tools are available.
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential for compiling C/C++ code (gcc, g++, make)
    build-essential \
    # Python development headers, crucial for building C extensions
    python3-dev \
    # System libraries required to build lxml
    libxml2-dev \
    libxslt1-dev \
    # System libraries for pyodbc
    unixodbc-dev \
    freetds-dev \
    # And finally, the Microsoft ODBC driver itself
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    # Clean up apt cache to keep the final image size smaller
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip

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
USER appuser

# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
CMD ["python"]
