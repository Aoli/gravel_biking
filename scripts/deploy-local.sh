#!/bin/bash

# Deploy to Firebase Hosting (Local Development)
# This script builds and deploys the Flutter web app to Firebase Hosting

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI is not installed. Please run: npm install -g firebase-tools"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi

print_status "Starting deployment process..."

# Get project root directory
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT"

print_status "Working in directory: $PROJECT_ROOT"

# Clean previous builds
print_status "Cleaning previous builds..."
flutter clean

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Run tests (optional - comment out if you want to skip)
print_status "Running tests..."
if flutter test; then
    print_success "All tests passed!"
else
    print_warning "Some tests failed, but continuing with deployment..."
fi

# Build for web
print_status "Building Flutter web app..."
flutter build web --release

# Deploy to Firebase
print_status "Deploying to Firebase Hosting..."
if firebase deploy --only hosting; then
    print_success "Deployment completed successfully!"
    print_status "Your app is now live at: https://gravel-biking.web.app"
else
    print_error "Deployment failed!"
    exit 1
fi

print_success "All done! 🚀"
