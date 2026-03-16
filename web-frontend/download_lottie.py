import requests
import re
import json

url = "https://lottiefiles.com/free-animation/animation-1716415932015-qf3NhLNj3L"
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
}

try:
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    
    # Simple regex to try and find the animation URL within NextJS data or script tags
    matches = re.findall(r'https://[^\"]*?\.json', response.text)
    
    # Filter for likely animation URLs (often hosted on lottie.host or similar)
    lottie_urls = [m for m in matches if 'lottie' in m.lower() or 'animation' in m.lower()]
    
    if lottie_urls:
        target_url = lottie_urls[0]
        print(f"Found URL: {target_url}")
        
        json_resp = requests.get(target_url)
        json_resp.raise_for_status()
        
        with open("public/bus-loading.json", "w") as f:
            f.write(json_resp.text)
        print("Success")
    else:
        print("Could not find JSON URL in HTML.")
        
except Exception as e:
    print(f"Error: {e}")
