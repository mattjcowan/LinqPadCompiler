#!/bin/bash

# Quick script to verify command-line arguments work

echo "Testing CommandLineArgs program with arguments..."
cd tests/output/CommandLineArgs_CompiledFolder/dist/CommandLineArgs
./CommandLineArgs hello world test 123
echo ""
echo "Exit code: $?"