#!/bin/sh
set -e

# Substitute environment variables in the config template using Python
python3 -c "
import os
import sys

with open('/app/config/config.template.json', 'r') as f:
    content = f.read()

# Replace environment variables
for key, value in os.environ.items():
    content = content.replace(f'\${{{key}}}', value)

with open('/app/config/config.json', 'w') as f:
    f.write(content)
"

# Execute the original command
exec "$@"
