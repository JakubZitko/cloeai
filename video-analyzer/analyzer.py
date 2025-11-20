"""
Video Analysis Service
Uses GPT-4 Vision to analyze SaaS videos
"""

import os
import cv2
import base64
import json
from pathlib import Path
from openai import OpenAI
from PIL import Image
import io
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

def extract_key_frames(video_path, num_frames=10):
    """Extract key frames from video for analysis"""

    cap = cv2.VideoCapture(str(video_path))

    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {video_path}")

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    duration = total_frames / fps if fps > 0 else 0

    print(f"📹 Video: {total_frames} frames, {fps} FPS, {duration:.2f}s")

    # Calculate frame indices to extract
    frame_indices = [int(i * total_frames / num_frames) for i in range(num_frames)]

    frames = []
    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()

        if ret:
            # Convert BGR to RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frames.append(frame_rgb)

    cap.release()

    print(f"✅ Extracted {len(frames)} key frames")

    return frames, {
        'total_frames': total_frames,
        'fps': fps,
        'duration': duration
    }

def frame_to_base64(frame, max_size=1024):
    """Convert frame to base64 string, resizing if needed"""

    # Convert to PIL Image
    img = Image.fromarray(frame)

    # Resize if too large
    if max(img.size) > max_size:
        ratio = max_size / max(img.size)
        new_size = tuple(int(dim * ratio) for dim in img.size)
        img = img.resize(new_size, Image.Resampling.LANCZOS)

    # Convert to base64
    buffer = io.BytesIO()
    img.save(buffer, format='JPEG', quality=85)
    buffer.seek(0)

    return base64.b64encode(buffer.read()).decode('utf-8')

def analyze_video(video_path, requirements=None):
    """Analyze video with GPT-4 Vision"""

    print(f"\n🔍 Analyzing video: {video_path}")

    # Extract frames
    frames, metadata = extract_key_frames(video_path, num_frames=10)

    # Convert frames to base64 (use first 6 frames to stay under token limit)
    frame_b64 = [frame_to_base64(f) for f in frames[:6]]

    # Build prompt
    requirements_text = ""
    if requirements:
        requirements_text = f"\nUSER REQUIREMENTS:\n{json.dumps(requirements, indent=2)}\n"

    prompt = f"""Analyze this SaaS product video and extract detailed information:

{requirements_text}

Please provide a JSON response with the following structure:
{{
  "product_type": "Type of product (CRM, Analytics, Project Management, etc.)",
  "target_audience": "Who is this for? (Developers, Marketers, Businesses, etc.)",
  "visual_style": {{
    "overall": "Modern, Corporate, Playful, Minimal, etc.",
    "color_palette": ["#hex1", "#hex2", "#hex3"],
    "typography": "Font style observations",
    "mood": "Professional, Energetic, Calm, etc."
  }},
  "content_analysis": {{
    "key_scenes": ["Scene 1 description", "Scene 2", ...],
    "transitions": "Type of transitions used",
    "text_overlay": "How text is displayed",
    "icons_graphics": "Style of icons and graphics used"
  }},
  "animations_needed": [
    {{
      "type": "Logo reveal, Feature showcase, etc.",
      "description": "Detailed description",
      "duration": "Estimated seconds",
      "complexity": "Simple, Medium, Complex"
    }}
  ],
  "pacing": {{
    "speed": "Fast, Medium, Slow",
    "cuts_per_minute": "Estimated number",
    "energy_level": "High, Medium, Low"
  }},
  "suggestions": {{
    "animation_style": "What kind of animations would work best",
    "reference_search_keywords": ["keyword1", "keyword2", ...],
    "improvements": ["Suggestion 1", "Suggestion 2", ...]
  }}
}}

Be specific and actionable. Focus on what would help recreate or improve this video.
"""

    # Call GPT-4 Vision
    try:
        response = client.chat.completions.create(
            model="gpt-4-vision-preview",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    *[{
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{img}",
                            "detail": "high"
                        }
                    } for img in frame_b64]
                ]
            }],
            max_tokens=2000,
            temperature=0.7
        )

        analysis_text = response.choices[0].message.content

        # Try to parse as JSON
        try:
            # Extract JSON from markdown code blocks if present
            if "```json" in analysis_text:
                json_start = analysis_text.find("```json") + 7
                json_end = analysis_text.find("```", json_start)
                analysis_text = analysis_text[json_start:json_end].strip()
            elif "```" in analysis_text:
                json_start = analysis_text.find("```") + 3
                json_end = analysis_text.find("```", json_start)
                analysis_text = analysis_text[json_start:json_end].strip()

            analysis_json = json.loads(analysis_text)
        except json.JSONDecodeError:
            # If not valid JSON, wrap the text response
            analysis_json = {
                "raw_analysis": analysis_text,
                "product_type": "Unknown",
                "suggestions": {
                    "reference_search_keywords": ["saas video", "product demo"]
                }
            }

        # Add metadata
        analysis_json['video_metadata'] = metadata

        print("✅ Analysis complete")

        return analysis_json

    except Exception as e:
        print(f"❌ Analysis error: {e}")
        raise

def save_analysis(analysis, output_path):
    """Save analysis to JSON file"""

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        json.dump(analysis, f, indent=2)

    print(f"💾 Analysis saved to: {output_path}")

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python analyzer.py <video_path> [output_json_path]")
        sys.exit(1)

    video_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "analysis.json"

    # Run analysis
    analysis = analyze_video(video_path)

    # Save results
    save_analysis(analysis, output_path)

    print("\n📊 Analysis Results:")
    print(json.dumps(analysis, indent=2))
