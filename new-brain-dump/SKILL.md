---
name: new-brain-dump
description: Create a new brain dump folder with an empty raw-dump.txt file for voice transcripts or unstructured notes.
---

# New Brain Dump

Create a new brain dump folder with an empty `raw-dump.txt` file.

```bash
# Get today's date in the format: month-day-year (e.g., dec-30-25)
DATE_PREFIX=$(date +"%b-%d-%y" | tr '[:upper:]' '[:lower:]')

# Find the next available number suffix
BRAIN_DUMPS_DIR="$HOME/repos/brain-dumps"
NUM=1
while [ -d "$BRAIN_DUMPS_DIR/${DATE_PREFIX}-$(printf '%02d' $NUM)" ]; do
    NUM=$((NUM + 1))
done

# Create the folder and empty file
FOLDER_NAME="${DATE_PREFIX}-$(printf '%02d' $NUM)"
mkdir -p "$BRAIN_DUMPS_DIR/$FOLDER_NAME"
touch "$BRAIN_DUMPS_DIR/$FOLDER_NAME/raw-dump.txt"

echo "Created: $BRAIN_DUMPS_DIR/$FOLDER_NAME/raw-dump.txt"
```
