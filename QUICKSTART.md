# Cloe Video AI - Quick Start Guide

Get up and running in 5 minutes! ⚡

---

## Prerequisites

### Required Software:
- **Node.js** 18+ ([Download](https://nodejs.org/))
- **Python** 3.9+ (usually pre-installed on macOS)
- **PostgreSQL** 14+ ([Install](https://postgresapp.com/))
- **Redis** 6+ (`brew install redis`)

### API Keys Needed:
- **OpenAI API Key** ([Get it here](https://platform.openai.com/api-keys))
- **Google OAuth Credentials** ([Get it here](https://console.cloud.google.com))

---

## Step 1: Clone & Setup

```bash
# Clone the repo (if not already done)
git clone <your-repo-url>
cd cloeai

# Run setup script (installs all dependencies)
./scripts/setup.sh
```

This will:
- Install Node.js dependencies for backend & frontend
- Setup Python virtual environment
- Create `.env` files from examples

---

## Step 2: Configure API Keys

Edit `backend/.env`:

```bash
nano backend/.env
```

**Required settings:**
```env
# OpenAI (Required for video analysis)
OPENAI_API_KEY=sk-your-openai-key-here

# Google OAuth (Required for login)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Database (auto-configured for local)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/cloe_video

# Redis (auto-configured for local)
REDIS_URL=redis://localhost:6379

# Session secret (change this!)
SESSION_SECRET=change-this-to-something-random
```

**Optional (for reference videos):**
```env
YOUTUBE_API_KEY=your-youtube-key
PEXELS_API_KEY=your-pexels-key
```

---

## Step 3: Setup Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project: "Cloe Video"
3. Enable **Google+ API**
4. Go to **Credentials** → **Create OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Authorized redirect URIs:
   ```
   http://localhost:3000/auth/google/callback
   ```
7. Copy **Client ID** and **Client Secret** to `.env`

---

## Step 4: Start Services

### Terminal 1 - Start PostgreSQL & Redis:
```bash
# Start PostgreSQL
brew services start postgresql@14

# Create database
createdb cloe_video

# Start Redis
brew services start redis
```

### Terminal 2 - Start Backend API:
```bash
cd backend
npm run dev
```

You should see:
```
✅ Database connected
✅ Redis connected
🚀 Cloe Video Backend running on port 3000
```

### Terminal 3 - Start Worker:
```bash
cd backend
npm run worker
```

You should see:
```
✅ Video Analysis Worker ready
   Listening for jobs...
```

### Terminal 4 - Start Frontend:
```bash
cd frontend
npm run dev
```

You should see:
```
VITE ready in 500ms
➜  Local: http://localhost:5173/
```

---

## Step 5: Test It! 🎉

1. **Open browser:** http://localhost:5173

2. **Login:**
   - Click "Continue with Google"
   - Authorize the app
   - You'll be redirected to dashboard

3. **Upload a video:**
   - Click "New Project"
   - Upload a SaaS product video
   - Wait ~2 minutes for analysis

4. **View results:**
   - See AI analysis (product type, style, colors)
   - See reference videos from YouTube/Pexels
   - Use insights to improve your video!

---

## Common Issues

### "Database connection failed"
```bash
# Check if PostgreSQL is running
brew services list

# Start it if not running
brew services start postgresql@14

# Create database if doesn't exist
createdb cloe_video
```

### "Redis connection failed"
```bash
# Check if Redis is running
brew services list

# Start it if not running
brew services start redis
```

### "OpenAI API error"
- Check your API key in `backend/.env`
- Verify you have credits: https://platform.openai.com/account/billing
- Make sure key starts with `sk-`

### "Google OAuth error"
- Verify redirect URI is exactly: `http://localhost:3000/auth/google/callback`
- Make sure you copied both Client ID and Secret
- Check there are no extra spaces in `.env`

### "Worker not processing jobs"
```bash
# Check worker is running
# You should see logs when uploading a video

# Check Redis queue
redis-cli
> KEYS bull:*
> QUIT
```

---

## What Happens When You Upload

```
1. Upload video.mp4
   ↓
2. Backend saves to uploads/videos/
   ↓
3. Job added to Redis queue
   ↓
4. Worker picks up job
   ↓
5. Python extracts 10 key frames
   ↓
6. Sends to GPT-4 Vision API
   ↓
7. AI analyzes:
   - Product type
   - Visual style
   - Color palette
   - Animation suggestions
   ↓
8. Searches YouTube & Pexels for references
   ↓
9. Status changes to "completed"
   ↓
10. You see results in dashboard! ✅
```

---

## Project Structure

```
cloeai/
├── backend/           # Node.js API
│   ├── src/
│   │   ├── api/      # Routes (video, user, projects)
│   │   ├── auth/     # OAuth (Google, Apple)
│   │   ├── models/   # Database schemas
│   │   ├── workers/  # Background jobs
│   │   └── index.js  # Main server
│   └── package.json
│
├── frontend/          # React app
│   ├── src/
│   │   ├── pages/    # Login, Dashboard, Upload, Project
│   │   └── App.jsx
│   └── package.json
│
├── video-analyzer/    # Python AI service
│   ├── analyzer.py           # GPT-4 Vision
│   ├── reference_finder.py   # YouTube/Pexels
│   └── requirements.txt
│
└── Cloe/             # macOS app (separate feature)
```

---

## Development Tips

### View Logs:
```bash
# Backend logs
cd backend && npm run dev

# Worker logs (more interesting - shows AI analysis)
cd backend && npm run worker

# Frontend logs
cd frontend && npm run dev
```

### Check Database:
```bash
psql cloe_video

# List tables
\dt

# View users
SELECT * FROM users;

# View projects
SELECT id, name, status, progress FROM projects;

# Exit
\q
```

### Check Redis Queue:
```bash
redis-cli

# View queue keys
KEYS bull:*

# Check queue length
LLEN bull:video-analysis:wait

# Exit
QUIT
```

### Reset Database:
```bash
# Drop and recreate
dropdb cloe_video
createdb cloe_video

# Restart backend (auto-syncs tables)
cd backend && npm run dev
```

---

## Costs

### Per Video Analysis:
- **OpenAI GPT-4 Vision:** ~$0.10-0.15
  - 10 frames @ ~$0.01/image
- **YouTube API:** Free (10,000 requests/day)
- **Pexels API:** Free (200 requests/hour)

**Total:** ~$0.15 per video

### Monthly Estimate:
- 100 videos/month = ~$15
- 1,000 videos/month = ~$150

---

## Next Steps

1. **Customize the UI** - Edit `frontend/src/pages/`
2. **Add more AI models** - Try Claude 3.5 Sonnet
3. **Deploy to production** - See `README_SAAS_VIDEO.md`
4. **Add payments** - Integrate Stripe for subscriptions

---

## Support

- 📖 Full docs: `README_SAAS_VIDEO.md`
- 🐛 Issues: GitHub Issues
- 💬 Questions: Ask in discussions

---

**Built with ❤️ - Happy analyzing!** 🎬
