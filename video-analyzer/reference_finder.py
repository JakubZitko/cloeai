"""
Reference Video Finder
Searches YouTube and stock video sites for similar content
"""

import os
import requests
import json
from pathlib import Path
from dotenv import load_dotenv
import yt_dlp

load_dotenv()

YOUTUBE_API_KEY = os.getenv('YOUTUBE_API_KEY')
PEXELS_API_KEY = os.getenv('PEXELS_API_KEY')

def search_youtube(keywords, max_results=10):
    """Search YouTube for reference videos"""

    if not YOUTUBE_API_KEY:
        print("⚠️  YouTube API key not found")
        return []

    print(f"🔍 Searching YouTube for: {keywords}")

    url = "https://www.googleapis.com/youtube/v3/search"

    params = {
        'part': 'snippet',
        'q': ' '.join(keywords) if isinstance(keywords, list) else keywords,
        'type': 'video',
        'videoDuration': 'short',  # <4 minutes
        'videoDefinition': 'high',
        'key': YOUTUBE_API_KEY,
        'maxResults': max_results,
        'order': 'relevance'
    }

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()

        data = response.json()
        results = []

        for item in data.get('items', []):
            video_id = item['id']['videoId']
            snippet = item['snippet']

            results.append({
                'id': video_id,
                'title': snippet['title'],
                'description': snippet['description'],
                'thumbnail': snippet['thumbnails']['high']['url'],
                'url': f"https://www.youtube.com/watch?v={video_id}",
                'channel': snippet['channelTitle'],
                'published_at': snippet['publishedAt'],
                'source': 'youtube'
            })

        print(f"✅ Found {len(results)} YouTube videos")

        return results

    except Exception as e:
        print(f"❌ YouTube search error: {e}")
        return []

def search_pexels_videos(keywords, max_results=10):
    """Search Pexels for stock videos"""

    if not PEXELS_API_KEY:
        print("⚠️  Pexels API key not found")
        return []

    print(f"🔍 Searching Pexels for: {keywords}")

    url = "https://api.pexels.com/videos/search"

    headers = {
        'Authorization': PEXELS_API_KEY
    }

    params = {
        'query': ' '.join(keywords) if isinstance(keywords, list) else keywords,
        'per_page': max_results,
        'orientation': 'landscape'
    }

    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()

        data = response.json()
        results = []

        for video in data.get('videos', []):
            # Get the highest quality file
            video_files = sorted(
                video['video_files'],
                key=lambda x: x.get('width', 0),
                reverse=True
            )

            best_file = video_files[0] if video_files else None

            results.append({
                'id': video['id'],
                'title': f"Pexels Video {video['id']}",
                'description': '',
                'thumbnail': video['image'],
                'url': video['url'],
                'download_url': best_file['link'] if best_file else None,
                'duration': video.get('duration', 0),
                'width': video.get('width', 0),
                'height': video.get('height', 0),
                'source': 'pexels'
            })

        print(f"✅ Found {len(results)} Pexels videos")

        return results

    except Exception as e:
        print(f"❌ Pexels search error: {e}")
        return []

def download_youtube_video(video_url, output_dir='downloads'):
    """Download YouTube video"""

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"📥 Downloading: {video_url}")

    ydl_opts = {
        'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
        'outtmpl': str(output_dir / '%(id)s.%(ext)s'),
        'quiet': True,
        'no_warnings': True
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=True)
            filename = ydl.prepare_filename(info)

            print(f"✅ Downloaded: {filename}")

            return filename

    except Exception as e:
        print(f"❌ Download error: {e}")
        return None

def download_pexels_video(download_url, output_dir='downloads', video_id='video'):
    """Download Pexels video"""

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    output_path = output_dir / f"{video_id}.mp4"

    print(f"📥 Downloading Pexels video: {video_id}")

    try:
        response = requests.get(download_url, stream=True)
        response.raise_for_status()

        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        print(f"✅ Downloaded: {output_path}")

        return str(output_path)

    except Exception as e:
        print(f"❌ Download error: {e}")
        return None

def find_references(analysis, max_per_source=5):
    """Find reference videos based on analysis"""

    print("\n🔎 Finding reference videos...")

    # Extract search keywords from analysis
    keywords = analysis.get('suggestions', {}).get('reference_search_keywords', [])

    if not keywords:
        keywords = [analysis.get('product_type', 'saas video')]

    print(f"🔑 Keywords: {keywords}")

    # Search both sources
    youtube_results = search_youtube(keywords, max_results=max_per_source)
    pexels_results = search_pexels_videos(keywords, max_results=max_per_source)

    references = {
        'youtube': youtube_results,
        'pexels': pexels_results,
        'total_count': len(youtube_results) + len(pexels_results)
    }

    print(f"\n✅ Found {references['total_count']} reference videos total")

    return references

def save_references(references, output_path):
    """Save references to JSON file"""

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        json.dump(references, f, indent=2)

    print(f"💾 References saved to: {output_path}")

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python reference_finder.py <analysis_json_path> [output_path]")
        sys.exit(1)

    analysis_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "references.json"

    # Load analysis
    with open(analysis_path, 'r') as f:
        analysis = json.load(f)

    # Find references
    references = find_references(analysis)

    # Save results
    save_references(references, output_path)

    print("\n📊 Reference Results:")
    print(f"YouTube: {len(references['youtube'])} videos")
    print(f"Pexels: {len(references['pexels'])} videos")
