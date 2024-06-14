#!/bin/bash

# List of GOOS and GOARCH combinations
declare -a GOOS_LIST=("linux" "darwin")
declare -a GOARCH_LIST=("amd64" "arm64")

# Output directory for binaries
OUTPUT_DIR="build"

# Create the output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Iterate over each combination of GOOS and GOARCH
for GOOS in "${GOOS_LIST[@]}"; do
  for GOARCH in "${GOARCH_LIST[@]}"; do
    # Set the output file name
    OUTPUT_FILE="$OUTPUT_DIR/doppelganger_assistant_${GOOS}_${GOARCH}"
    if [ "$GOOS" == "windows" ]; then
      OUTPUT_FILE+=".exe"
    fi

    # Build the application
    echo "Building for $GOOS/$GOARCH..."
    env GOOS=$GOOS GOARCH=$GOARCH go build -o $OUTPUT_FILE *.go

    # Check if the build was successful
    if [ $? -ne 0 ]; then
      echo "Failed to build for $GOOS/$GOARCH"
    else
      echo "Successfully built for $GOOS/$GOARCH"
    fi
  done
done

echo "Build process completed."
