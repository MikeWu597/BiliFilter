import Foundation
import Speech
import Combine

// MARK: - AIGC检测器：语音转文字 + 自困惑度分析
@MainActor
final class AIGCDetector: ObservableObject {
    @Published var transcribedText = ""
    @Published var aigcScore: Double = 0
    @Published var aigcLabel: String = "检测中..."
    @Published var isRunning = false
    @Published var wordCount = 0

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let analysisInterval: TimeInterval = 5.0
    private var lastAnalysisTime: TimeInterval = 0

    func start() {
        guard !isRunning else { return }
        isRunning = true
        aigcLabel = "检测中..."
        aigcScore = 0
        transcribedText = ""
        wordCount = 0
        lastAnalysisTime = CACurrentMediaTime()

        // 尝试创建离线语音识别器
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            aigcLabel = "语音识别不可用"
            isRunning = false
            return
        }
        recognizer.supportsOnDeviceRecognition = true
        recognizer.defaultTaskHint = .dictation

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            aigcLabel = "请求创建失败"
            isRunning = false
            return
        }
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                let now = CACurrentMediaTime()
                if now - self.lastAnalysisTime > self.analysisInterval {
                    self.lastAnalysisTime = now
                    self.analyze()
                }
            }
            if let error {
                print("[AIGC] recognition error: \(error)")
                if self.transcribedText.isEmpty {
                    self.aigcLabel = "识别失败"
                    self.isRunning = false
                }
            }
        }
    }

    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        if !transcribedText.isEmpty {
            analyze()
        }
        isRunning = false
    }

    /// 多维度分析：困惑度 + 重复度 + AI特征词
    private func analyze() {
        let text = transcribedText
        guard text.count > 30 else {
            aigcLabel = "文本不足"
            return
        }

        // 提取有效字符（中文+字母+数字）
        let chars = Array(text).filter { c in
            let s = String(c)
            return s.range(of: "\\p{Han}|[a-zA-Z0-9]", options: .regularExpression) != nil
        }
        guard chars.count > 20 else {
            aigcLabel = "文本不足"
            return
        }
        wordCount = chars.count

        // bigram 统计
        var bigramFreq: [String: Int] = [:]
        for i in 0..<(chars.count - 1) {
            let bg = String(chars[i...i+1])
            bigramFreq[bg, default: 0] += 1
        }
        let n = Double(chars.count - 1)

        // 1. 困惑度：越低（词分布集中）越像AI
        var logSum: Double = 0
        for i in 0..<(chars.count - 1) {
            let bg = String(chars[i...i+1])
            let prob = Double(bigramFreq[bg]!) / n
            logSum += log(max(prob, 1e-10))
        }
        let perplexity = exp(-logSum / n)
        // 映射：perplexity=1 → 1.0(AI), perplexity=30+ → 0(真人)
        let pScore = max(0, min(1, 1.0 - (perplexity - 1) / 30))

        // 2. 重复度：唯一bigram比例
        let uniqueRatio = Double(bigramFreq.count) / n
        let rScore = 1.0 - uniqueRatio

        // 3. AI特征词
        let aiMarkers = [
            "值得注意", "需要注意", "值得关注",
            "从这个角度", "从这个层面", "从这个意义",
            "总的来说", "综上所述", "总而言之", "总的来看",
            "首先", "其次", "最后", "第一", "第二", "第三",
            "不仅如此", "更重要的是", "更关键的是",
            "由此可见", "由此看来", "由此可知",
            "在这个基础", "在此基础上",
            "显而易见", "显然", "毫无疑问",
            "需要强调", "必须指出", "不得不提",
            "一般而言", "一般来说", "通常情况下",
            "换言之", "换句话说", "也就是说",
            "具体而言", "具体来说", "具体来看",
            "事实上", "实际上", "其实",
            "某种程度", "某种意义上",
            "不可否认", "毋庸置疑",
            "众所周知",
            "极大", "显著", "深远", "重大",
        ]
        var markerHits = 0
        for m in aiMarkers { if text.contains(m) { markerHits += 1 } }
        let mScore = min(1.0, Double(markerHits) / max(1.0, Double(text.count) / 80.0))

        // 综合：困惑度40% + 重复度30% + 特征词30%
        let rawScore = pScore * 0.4 + rScore * 0.3 + mScore * 0.3
        aigcScore = min(1, max(0, rawScore))

        if aigcScore < 0.12 {
            aigcLabel = "疑似真人"
        } else if aigcScore < 0.30 {
            aigcLabel = "AI概率较低"
        } else if aigcScore < 0.55 {
            aigcLabel = "可能含AI"
        } else {
            aigcLabel = "疑似AI生成"
        }

        print("[AIGC] chars=\(chars.count) perplexity=\(String(format:"%.2f",perplexity)) repeat=\(String(format:"%.2f",rScore)) markers=\(markerHits) score=\(String(format:"%.2f",aigcScore)) label=\(aigcLabel)")
    }
}
