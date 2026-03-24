#!/bin/bash

# HOApp Test Runner Script
# This script installs dependencies, generates mocks, and runs all tests

set -e  # Exit on error

echo "========================================="
echo "HOApp Test Suite"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Install dependencies
echo -e "\n${YELLOW}Step 1: Installing dependencies...${NC}"
cd packages/core_domain && flutter pub get
cd ../core_data && flutter pub get
cd ../core_ui && flutter pub get
cd ../../apps/web_portal && flutter pub get

# Step 2: Build models (required for tests)
echo -e "\n${YELLOW}Step 2: Building domain models...${NC}"
cd ../../packages/core_domain
flutter pub run build_runner build --delete-conflicting-outputs

# Step 3: Generate test mocks
echo -e "\n${YELLOW}Step 3: Generating test mocks...${NC}"
cd ../core_data
flutter pub run build_runner build --delete-conflicting-outputs

cd ../core_ui
flutter pub run build_runner build --delete-conflicting-outputs

# Step 4: Run unit tests
echo -e "\n${YELLOW}Step 4: Running unit tests...${NC}"

echo -e "\n${GREEN}Testing core_data package...${NC}"
cd ../core_data
flutter test || echo -e "${RED}Some core_data tests failed${NC}"

echo -e "\n${GREEN}Testing core_ui package...${NC}"
cd ../core_ui
flutter test || echo -e "${RED}Some core_ui tests failed${NC}"

# Step 5: Run integration tests
echo -e "\n${YELLOW}Step 5: Running integration tests...${NC}"
cd ../../apps/web_portal
flutter test integration_test || echo -e "${RED}Some integration tests failed${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Test suite completed!${NC}"
echo -e "${GREEN}=========================================${NC}"
