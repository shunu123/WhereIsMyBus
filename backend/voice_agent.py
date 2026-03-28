import os
import json
import google.generativeai as genai

SYSTEM_INSTRUCTION = """
You are a smart voice assistant for the 'Where Is My Bus' campus bus navigation app.
Your job is to read the user's audio transcript and parse their INTENT into a Structured JSON action that the app can execute.

Available Commands:
1. SEARCH: User wants to find a route from point A to point B.
   Args: 'from_stop' (string), 'to_stop' (string)
2. TRACK: User wants to track a specific bus number.
   Args: 'bus_number' (string)
4. NAVIGATE: User wants to open a specific utility screen.
   Args: 'screen' (Available screens: "HELP", "REPORT", "ABOUT", "LOGOUT", "HISTORY", "SAVED_ROUTES", "FLEET_MAP", "ALL_ROUTES", "SETTINGS")

JSON Response Format:
{
  "command": "SEARCH" | "TRACK" | "NAVIGATE" | "STATUS",
  "from_stop": "..." (Optional),
  "to_stop": "..." (Optional),
  "bus_number": "..." (Optional),
  "screen": "..." (Optional),
  "speech_response": "Short vocal feedback to speak back to the user",
  "language_code": "hi-IN" | "ta-IN" | "te-IN" | "en-US"
}

Language Behavior:
- Detect the language of the transcript (English, Hindi, Tamil, or Telugu).
- Provide the `speech_response` strictly in that detected language's script.
- Provide the exact BCP 47 `language_code` for front-end parsing (e.g., "hi-IN" for Hindi, "ta-IN" for Tamil, "te-IN" for Telugu, "en-US" for English).

Example 1: "Find a bus from Saveetha to Koyambedu"
{
  "command": "SEARCH",
  "from_stop": "Saveetha University",
  "to_stop": "Koyambedu",
  "speech_response": "Searching for buses to Koyambedu. One moment."
}

Example 2: "Where is bus 1?"
{
  "command": "TRACK",
  "bus_number": "1",
  "speech_response": "Let me find the live location for Bus 1."
}
"""

def parse_voice_intent(transcript: str) -> dict:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        try:
            env_path = os.path.join(os.path.dirname(__file__), ".env")
            if os.path.exists(env_path):
                with open(env_path, "r") as f:
                    for line in f:
                        if "GEMINI_API_KEY" in line and "=" in line:
                            api_key = line.split("=")[1].strip()
                            os.environ["GEMINI_API_KEY"] = api_key
        except Exception:
            pass

    if not api_key:
        return {
            "command": "STATUS",
            "speech_response": "The backend Gemini API key is missing. Please configure GEMINI_API_KEY in environment."
        }
        
    genai.configure(api_key=api_key)
    # Using lightweight and fast flash model for voice responses
    model = genai.GenerativeModel(
        model_name="gemini-1.5-flash",
        system_instruction=SYSTEM_INSTRUCTION
    )
    
    prompt = f"User said: '{transcript}'\nOutput JSON only:"
    try:
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        data = json.loads(text)
        return data
    except Exception as e:
        print(f"Gemini voice intent error: {e}")
        return {
            "command": "STATUS",
            "speech_response": f"Sorry, I had trouble parsing that. (Error: {str(e)})"
        }
