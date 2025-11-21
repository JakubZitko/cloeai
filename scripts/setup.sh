#!/bin/bash

# Cloe Video AI - Setup Script

echo "🔧 Setting up Cloe Video AI..."
echo ""

# Backend
echo "📦 Installing backend dependencies..."
cd backend
npm install
cd ..

# Frontend
echo "📦 Installing frontend dependencies..."
cd frontend
npm install
cd ..

# Python
echo "🐍 Setting up Python virtual environment..."
cd video-analyzer
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate
cd ..

# Environment files
echo "📝 Creating environment files..."

if [ ! -f backend/.env ]; then
    cp backend/.env.example backend/.env
    echo "✅ Created backend/.env (configure your API keys)"
else
    echo "✅ backend/.env already exists"
fi

if [ ! -f frontend/.env.local ]; then
    echo "VITE_API_URL=http://localhost:3000" > frontend/.env.local
    echo "✅ Created frontend/.env.local"
else
    echo "✅ frontend/.env.local already exists"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure backend/.env with your API keys:"
echo "   - GOOGLE_CLIENT_ID"
echo "   - GOOGLE_CLIENT_SECRET"
echo "   - OPENAI_API_KEY"
echo ""
echo "2. Start PostgreSQL: brew services start postgresql@14"
echo "3. Create database: createdb cloe_video"
echo "4. Start Redis: brew services start redis"
echo ""
echo "5. Start the app:"
echo "   Terminal 1: cd backend && npm run dev"
echo "   Terminal 2: cd backend && npm run worker"
echo "   Terminal 3: cd frontend && npm run dev"
echo ""
echo "6. Open: http://localhost:5173"
