import urllib.request

url = 'https://videos.pexels.com/video-files/3015510/3015510-uhd_2560_1440_24fps.mp4'
print(f"Downloading drone video from {url}...")
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
try:
    with urllib.request.urlopen(req) as response, open('public/background.mp4', 'wb') as out_file:
        data = response.read()
        out_file.write(data)
    print("Download complete. File size:")
except Exception as e:
    print(f"Error: {e}")
