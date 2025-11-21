#!/bin/bash

# Cloe Video AI - Development Startup Script

echo "🚀 Starting Cloe Video AI in development mode..."
echo ""

# Check if .env exists in backend
if [ ! -f backend/.env ]; then
    echo "⚠️  Warning: backend/.env not found"
    echo "   Copy backend/.env.example to backend/.env and configure it"
    exit 1
fi

# Check if PostgreSQL is running
if ! command -v psql &> /dev/null; then
    echo "⚠️  Warning: PostgreSQL not found"
    echo "   Install PostgreSQL: brew install postgresql@14"
fi

# Check if Redis is running
if ! command -v redis-cli &> /dev/null; then
    echo "⚠️  Warning: Redis not found"
    echo "   Install Redis: brew install redis"
fi

echo "📋 Services to start:"
echo "   1. PostgreSQL (brew services start postgresql@14)"
echo "   2. Redis (brew services start redis)"
echo "   3. Backend API (Terminal 1)"
echo "   4. Worker (Terminal 2)"
echo "   5. Frontend (Terminal 3)"
echo ""
echo "To start backend: cd backend && npm run dev"
echo "To start worker: cd backend && npm run worker"
echo "To start frontend: cd frontend && npm run dev"
echo ""
echo "Then open: http://localhost:5173"
