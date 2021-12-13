#!/usr/bin/env bash
cd %PROJECT_ROOT%

# Load environment
source cfg/environment.env

# Launch trace recipe for this member
make test_${MEMBER}
