#!/bin/bash

# Simple Sync Script for WhereIsMyBus
# Use this to quickly push all local changes to GitHub

ROOT_DIR="/Users/bujjuu/Documents/WhereIsMyBus 2"
BACKEND_SRC="/Users/bujjuu/Documents/college_bus_api"

echo "🔄 Syncing backend files..."
cp "$BACKEND_SRC/main.py" "$ROOT_DIR/backend/"
cp "$BACKEND_SRC/requirements.txt" "$ROOT_DIR/backend/"

cd "$ROOT_DIR" || exit

echo "📦 Staging changes..."
git add .

echo "💾 Committing changes..."
git commit -m "Auto-sync: $(date)" || echo "No changes to commit"

echo "🚀 Pushing to GitHub..."
git push origin main

echo "✅ Sync complete!"
