# Cloe SaaS Video Creator - Complete Platform

**AI-powered SaaS video creation with After Effects automation**

This is a complete full-stack application that analyzes videos, finds references, and generates After Effects animations automatically.

---

## 🎯 What It Does

### The Complete Flow:

```
1. User uploads video (React frontend)
   ↓
2. Backend processes video (Node.js + Bull queue)
   ↓
3. Python AI analyzes video with GPT-4 Vision
   - Extracts product type, visual style, animations needed
   - Identifies color palette, pacing, mood
   ↓
4. Python finds reference videos
   - Searches YouTube for similar content
   - Finds stock footage on Pexels
   ↓
5. After Effects automation creates animations
   - Generates ExtendScript from AI analysis
   - Creates logo reveals, text animations, transitions
   - Applies color grading
   ↓
6. Renders final video (aerender)
   ↓
7. User downloads completed video
```

---

## 🏗️ Architecture

### Backend (Node.js + Express)
- **Authentication**: Google OAuth + Apple Sign In
- **API**: Video upload, project management, user profiles
- **Job Queue**: Bull + Redis for async processing
- **Database**: PostgreSQL with Sequelize ORM

### Video Analysis Service (Python)
- **GPT-4 Vision**: Analyzes video frames
- **OpenCV**: Extracts key frames
- **Reference Finder**: YouTube + Pexels APIs

### After Effects Automation (ExtendScript)
- **Automated Project Creation**: Generates .aep files
- **Animation System**: Logo reveals, text animations, transitions
- **Color Grading**: Applies AI-suggested color palettes

### Frontend (React + Vite)
- **Login**: OAuth flow with Google/Apple
- **Upload**: Drag-and-drop video upload
- **Dashboard**: Project list with real-time status
- **Project View**: Analysis results, progress tracking

### macOS Cloe App (Swift)
- **Context Engine**: Screen monitoring for local assistance
- **Voice Input**: Speech recognition
- **Tool Integration**: File system, calendar, email

---

## 📋 Prerequisites

### Required:
- **macOS** 12.0+ (for After Effects automation)
- **Node.js** 18+
- **Python** 3.9+
- **PostgreSQL** 14+
- **Redis** 6+
- **After Effects** 2023+ (optional, for actual rendering)

### API Keys:
- OpenAI API key (for GPT-4 Vision)
- Google OAuth credentials
- Apple Sign In credentials (optional)
- YouTube Data API key (optional)
- Pexels API key (optional)

---

## 🚀 Setup Guide

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/cloeai.git
cd cloeai
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your credentials
nano .env

# Setup database
createdb cloe_video  # PostgreSQL

# Start Redis
redis-server  # Or: brew services start redis

# Run migrations (auto-syncs in dev mode)
npm run dev
```

**Required .env variables:**
```
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-secret
OPENAI_API_KEY=sk-your-key
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/cloe_video
REDIS_URL=redis://localhost:6379
```

### 3. Python Analysis Service

```bash
cd ../video-analyzer

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Test analyzer
python analyzer.py path/to/test-video.mp4
```

### 4. Frontend Setup

```bash
cd ../frontend

# Install dependencies
npm install

# Create .env
echo "VITE_API_URL=http://localhost:3000" > .env.local

# Start dev server
npm run dev
```

### 5. Start Worker Process

```bash
cd ../backend

# In a separate terminal
npm run worker
```

---

## 🔑 OAuth Setup

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URI: `http://localhost:3000/auth/google/callback`
6. Copy Client ID and Secret to `.env`

### Apple Sign In

1. Go to [Apple Developer](https://developer.apple.com)
2. Create App ID with Sign in with Apple capability
3. Create Service ID
4. Generate private key (.p8 file)
5. Download key and save as `AuthKey_Apple.p8`
6. Add credentials to `.env`

---

## 📺 After Effects Setup (Optional)

For actual video rendering, you need After Effects installed.

### macOS:

```bash
# After Effects render command location:
/Applications/Adobe\ After\ Effects\ 2024/aerender

# The worker will automatically use aerender if available
# Otherwise it just copies the original video
```

### Configure in Worker:

Edit `backend/src/workers/render-worker.js`:

```javascript
// Update this path if your AE version is different
const AE_RENDER = '/Applications/Adobe After Effects 2024/aerender';
```

---

## 🎬 Usage

### 1. Start All Services

**Terminal 1 - Backend API:**
```bash
cd backend
npm run dev
```

**Terminal 2 - Worker:**
```bash
cd backend
npm run worker
```

**Terminal 3 - Frontend:**
```bash
cd frontend
npm run dev
```

**Terminal 4 - Redis (if not running as service):**
```bash
redis-server
```

### 2. Access the App

Open browser to: `http://localhost:5173`

### 3. Login

- Click "Continue with Google"
- Authorize the app
- You'll be redirected to dashboard

### 4. Create Project

1. Click "New Project"
2. Upload a SaaS product video
3. Enter project name
4. Click "Start Analysis"

### 5. Watch Progress

The system will:
1. Upload video (progress bar)
2. Analyze with AI (~1-2 min)
3. Find reference videos (~30 sec)
4. Generate After Effects project (~1 min)
5. Render video (if AE installed, ~5-10 min)

### 6. Download Result

Once status shows "completed", download your processed video!

---

## 🔧 Development

### Backend API Routes

```
POST   /auth/google                 # Google OAuth login
GET    /auth/google/callback        # OAuth callback
POST   /auth/logout                 # Logout
GET    /auth/me                     # Get current user

POST   /api/videos/upload           # Upload video
GET    /api/videos/project/:id      # Get project status
GET    /api/videos/projects         # List all projects
DELETE /api/videos/project/:id      # Delete project

GET    /api/user/profile            # Get user profile
PATCH  /api/user/profile            # Update profile
```

### Database Schema

**Users:**
```sql
id, googleId, appleId, email, name, avatar,
provider, subscription, creditsRemaining, lastLogin
```

**Projects:**
```sql
id, userId, name, description, status, originalVideoPath,
outputVideoPath, analysis (JSONB), references (JSONB),
aeProjectPath, progress, errorMessage
```

### Job Queue

**Analysis Queue:**
- Runs Python video analyzer
- Finds reference videos
- Updates project with results

**Render Queue:**
- Generates After Effects config
- Runs ExtendScript automation
- Executes aerender
- Saves output video

---

## 🧪 Testing

### Test Video Upload

```bash
# Upload a test video via curl
curl -X POST http://localhost:3000/api/videos/upload \
  -H "Cookie: your-session-cookie" \
  -F "video=@test-video.mp4" \
  -F "name=Test Project" \
  -F "description=Testing upload"
```

### Test Python Analyzer

```bash
cd video-analyzer
python analyzer.py ../test-videos/sample.mp4 output.json
cat output.json
```

### Test Reference Finder

```bash
python reference_finder.py output.json references.json
cat references.json
```

---

## 📊 AI Analysis Output Example

```json
{
  "product_type": "CRM Software",
  "target_audience": "Sales Teams, SMBs",
  "visual_style": {
    "overall": "Modern, Clean, Professional",
    "color_palette": ["#2563eb", "#1e40af", "#f3f4f6"],
    "typography": "Sans-serif, Bold headings",
    "mood": "Confident, Efficient"
  },
  "content_analysis": {
    "key_scenes": [
      "Dashboard overview with graphs",
      "Mobile app interface",
      "Team collaboration view"
    ],
    "transitions": "Quick cuts with subtle fades",
    "text_overlay": "Large bold headlines, minimal body text"
  },
  "animations_needed": [
    {
      "type": "Logo reveal",
      "description": "Fade in with scale animation",
      "duration": "3",
      "complexity": "Simple"
    },
    {
      "type": "Feature showcase",
      "description": "Slide-in panels with screenshots",
      "duration": "5",
      "complexity": "Medium"
    }
  ],
  "pacing": {
    "speed": "Medium-fast",
    "cuts_per_minute": "15",
    "energy_level": "High"
  },
  "suggestions": {
    "animation_style": "Modern motion graphics with smooth easing",
    "reference_search_keywords": ["saas demo", "crm software", "dashboard animation"],
    "improvements": [
      "Add call-to-action overlay",
      "Include testimonial section"
    ]
  }
}
```

---

## 🎨 After Effects Output

The system generates:

1. **Project File (.aep)**: Complete After Effects project
2. **Compositions**: One main comp with all layers
3. **Animations**:
   - Logo reveals with scale/opacity
   - Text animations with position keyframes
   - Color grading adjustment layers
4. **Render Settings**: H.264 MP4 output

---

## 💰 Pricing Tiers (Configured in Code)

```javascript
FREE:       10 videos/month
PRO:        $29/mo - 100 videos
ENTERPRISE: $99/mo - Unlimited
```

Credits are deducted on video upload.

---

## 🐛 Troubleshooting

### "Database connection failed"
```bash
# Start PostgreSQL
brew services start postgresql@14

# Create database
createdb cloe_video
```

### "Redis connection failed"
```bash
# Start Redis
brew services start redis

# Or manually:
redis-server
```

### "OpenAI API error"
- Check your API key in `.env`
- Verify you have credits: https://platform.openai.com/account/billing

### "Upload fails with 401"
- Make sure you're logged in
- Check session cookie in browser
- Try logging out and back in

### "Worker not processing jobs"
```bash
# Check worker logs
npm run worker

# Check Redis queue
redis-cli
> KEYS bull:*
```

### "After Effects not rendering"
- Verify AE is installed at the correct path
- Check worker logs for aerender output
- For development, worker will copy original video if AE unavailable

---

## 📚 API Documentation

Full API docs available at: `/api/docs` (coming soon)

For now, see routes in:
- `backend/src/auth/routes.js`
- `backend/src/api/video.js`
- `backend/src/api/user.js`

---

## 🔐 Security

### Implemented:
- ✅ OAuth 2.0 authentication
- ✅ Session-based auth with httpOnly cookies
- ✅ CORS protection
- ✅ SQL injection protection (Sequelize ORM)
- ✅ File upload validation
- ✅ Rate limiting (TODO)
- ✅ Encrypted database fields

### TODO:
- [ ] Rate limiting on API endpoints
- [ ] CSRF token protection
- [ ] Video malware scanning
- [ ] Content moderation

---

## 🚢 Deployment

### Production Checklist:

1. **Environment:**
   - Set `NODE_ENV=production`
   - Use strong `SESSION_SECRET`
   - Enable database SSL

2. **Database:**
   - Use managed PostgreSQL (AWS RDS, Digital Ocean)
   - Enable backups
   - Set connection pooling

3. **Redis:**
   - Use managed Redis (AWS ElastiCache, Redis Cloud)
   - Enable persistence

4. **After Effects:**
   - Dedicated render server with AE license
   - Queue system for concurrent renders

5. **File Storage:**
   - Use S3 for video storage
   - CloudFront CDN for delivery

6. **Monitoring:**
   - Set up error tracking (Sentry)
   - Performance monitoring (New Relic)
   - Uptime monitoring

---

## 📈 Scaling

### Current Limits:
- 1 worker process
- Local file storage
- Single AE render instance

### To Scale:
1. **Horizontal Worker Scaling:**
   - Run multiple worker processes
   - Use Redis queue for distribution

2. **Distributed Storage:**
   - Move to S3/GCS
   - Use CDN for delivery

3. **Render Farm:**
   - Multiple AE servers
   - Load balancer for render queue

4. **Database:**
   - Read replicas
   - Connection pooling
   - Query optimization

---

## 🤝 Contributing

See main [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

---

## 🙏 Credits

- **OpenAI GPT-4 Vision** - Video analysis
- **After Effects** - Animation platform
- **YouTube & Pexels** - Reference content
- **Bull Queue** - Job processing
- **Sequelize** - Database ORM
- **React** - Frontend framework

---

## 📞 Support

- GitHub Issues: [Report Bug](https://github.com/yourusername/cloeai/issues)
- Email: support@cloe.ai
- Discord: [Join Community](https://discord.gg/cloe)

---

**Built with ❤️ for video creators**
