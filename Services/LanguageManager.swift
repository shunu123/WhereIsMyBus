import Foundation
import Combine

@MainActor
final class LanguageManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
        }
    }
    
    let supportedLanguages = [
        ("English", "English"),
        ("Hindi", "हिन्दी"),
        ("Tamil", "தமிழ்"),
        ("Telugu", "తెలుగు"),
        ("Kannada", "ಕನ್ನಡ"),
        ("Malayalam", "മലയാളം"),
        ("Marathi", "मराठी"),
        ("Bengali", "বাংলা"),
        ("Gujarati", "ગુજરાતી")
    ]
    
    init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "English"
    }
    
    func setLanguage(_ language: String) {
        currentLanguage = language
    }
    
    // Simple localization dictionary
    private let translations: [String: [String: String]] = [
        "English": [
            "Where Is My Bus": "Where Is My Bus",
            "From": "From",
            "To": "To",
            "Search buses": "Search buses",
            "Available Buses": "Available Buses",
            "Settings": "Settings",
            "City": "City",
            "Language": "Language",
            "Theme": "Theme",
            "No direct buses found": "No direct buses found",
            "Search buses at": "Search buses at",
            "There are no buses connecting these stops directly. Try searching for all buses at either stop:": "There are no buses connecting these stops directly. Try searching for all buses at either stop:"
        ],
        "Hindi": [
            "Where Is My Bus": "बस कहाँ है",
            "From": "से",
            "To": "तक",
            "Search buses": "बसें खोजें",
            "Available Buses": "उपलब्ध बसें",
            "Settings": "सेटिंग्स",
            "City": "शहर",
            "Language": "भाषा",
            "Theme": "थीम",
            "No direct buses found": "कोई सीधी बस नहीं मिली",
            "Search buses at": "यहाँ बसें खोजें",
            "There are no buses connecting these stops directly. Try searching for all buses at either stop:": "इन स्टॉप्स को सीधे जोड़ने वाली कोई बस नहीं है। किसी भी स्टॉप पर सभी बसों के लिए खोजें:"
        ],
        "Tamil": [
            "Where Is My Bus?": "என் பேருந்து எங்கே?",
            "From": "இருந்து",
            "To": "இடத்திற்கு",
            "Search buses": "பேருந்துகளைத் தேடுக",
            "Available Buses": "கிடைக்கும் பேருந்துகள்",
            "Settings": "அமைப்புகள்",
            "City": "நகரம்",
            "Language": "மொழி",
            "Theme": "தீம்",
            "No direct buses found": "நேரடி பேருந்துகள் இல்லை",
            "Search buses at": "பேருந்துகளைத் தேடுக",
            "There are no buses connecting these stops directly. Try searching for all buses at either stop:": "இந்த நிறுத்தங்களை நேரடியாக இணைக்கும் பேருந்துகள் இல்லை."
        ],
        "Kannada": [
            "Where Is My Bus": "ನನ್ನ ಬಸ್ ಎಲ್ಲಿದೆ",
            "From": "ಇಂದ",
            "To": "ಗೆ",
            "Search buses": "ಬಸ್ ಹುಡುಕಿ",
            "Available Buses": "ಲಭ್ಯವಿರುವ ಬಸ್ಸುಗಳು",
            "Settings": "ಸೆಟ್ಟಿಂಗ್ಗಳು",
            "City": "ನಗರ",
            "Language": "ಭಾಷೆ",
            "Theme": "ಥೀಮ್",
            "No direct buses found": "ನೇರ ಬಸ್ಸುಗಳಿಲ್ಲ",
            "Search buses at": "ಬಸ್ ಹುಡುಕಿ",
            "There are no buses connecting these stops directly. Try searching for all buses at either stop:": "ಈ ನಿಲ್ದಾಣಗಳನ್ನು ನೇರವಾಗಿ ಸಂಪರ್ಕಿಸುವ ಯಾವುದೇ ಬಸ್ಸುಗಳಿಲ್ಲ."
        ]
    ]
    
    func localizedString(_ key: String) -> String {
        return translations[currentLanguage]?[key] ?? key
    }
}
