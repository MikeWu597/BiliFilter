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

    /// 基于自困惑度分析：困惑度越低 = 越可预测 = 越像AI生成
    private func analyze() {
        let text = transcribedText
        guard text.count > 50 else {
            aigcLabel = "文本不足"
            return
        }

        let words = segmentWords(text)
        wordCount = words.count
        guard words.count > 20 else {
            aigcLabel = "词数不足"
            return
        }

        // 计算 unigram 困惑度
        var wordFreq: [String: Int] = [:]
        for w in words { wordFreq[w, default: 0] += 1 }
        let n = Double(words.count)
        var logSum: Double = 0
        for w in words {
            let prob = Double(wordFreq[w]!) / n
            logSum += log(prob)
        }
        let perplexity = exp(-logSum / n)

        // 额外指标：唯一词比例
        let uniqueRatio = Double(wordFreq.count) / n

        // 综合评分：困惑度 + 重复度 映射到 0~1
        // perplexity 1~5 → high AI; 20+ → very human
        // uniqueRatio 低 → 重复 → AI
        let pScore = max(0, min(1, 1.0 - (perplexity - 1) / 30))
        let uScore = 1.0 - uniqueRatio
        let rawScore = (pScore * 0.6 + uScore * 0.4)
        aigcScore = min(1, max(0, rawScore))

        if aigcScore < 0.15 {
            aigcLabel = "疑似真人"
        } else if aigcScore < 0.40 {
            aigcLabel = "AI概率较低"
        } else if aigcScore < 0.65 {
            aigcLabel = "可能含AI"
        } else {
            aigcLabel = "疑似AI生成"
        }

        print("[AIGC] words=\(words.count) unique=\(wordFreq.count) perplexity=\(String(format:"%.2f",perplexity)) score=\(String(format:"%.2f",aigcScore)) label=\(aigcLabel)")
    }

    private func segmentWords(_ text: String) -> [String] {
        // 简单分词：按标点、空格切分，取长度≥2的中文词或英文词
        let cleaned = text.replacingOccurrences(of: "[，。！？、；：\"\"''（）【】《》\\[\\]\\.,!?;:\\s]+", with: " ", options: .regularExpression)
        let tokens = cleaned.components(separatedBy: .whitespaces).filter { $0.count >= 2 }
        // 对中文做2-gram切分（简单分词）
        var result: [String] = []
        for token in tokens {
            if token.range(of: "\\p{Han}", options: .regularExpression) != nil {
                // 中文按字符切bigram
                let chars = Array(token)
                if chars.count >= 2 {
                    for i in 0..<(chars.count - 1) {
                        result.append(String(chars[i...i+1]))
                    }
                }
            } else {
                result.append(token.lowercased())
            }
        }
        return result
    }
}
