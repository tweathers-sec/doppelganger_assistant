# Use Ubuntu as the base image
FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    wget \
    apt-utils \
    curl \
    git \
    make \
    xz-utils \
    gcc \
    g++ \
    libgl1 \
    xterm \
    libreadline-dev \
    gcc-arm-none-eabi \
    libnewlib-dev \
    qtbase5-dev \
    libbz2-dev \
    liblz4-dev \
    libbluetooth-dev \
    libpython3-dev \
    libssl-dev \
    libgd-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the installation script
COPY doppelganger_install_linux.sh /tmp/doppelganger_install_linux.sh

# Make the script executable
RUN chmod +x /tmp/doppelganger_install_linux.sh

# Run the installation script
RUN /tmp/doppelganger_install_linux.sh

# Set the working directory
WORKDIR /root

# Command to run when starting the container
CMD ["/bin/bash"]