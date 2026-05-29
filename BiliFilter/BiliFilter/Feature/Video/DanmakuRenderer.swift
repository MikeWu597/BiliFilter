import SwiftUI

// MARK: - 弹幕数据模型
struct DanmakuItem: Identifiable {
    let id = UUID()
    let time: Double
    let content: String
    let color: Color
    let mode: Int
    let userHash: String
}

// MARK: - 解析器
enum DanmakuParser {
    static func parse(xml: String) -> [DanmakuItem] {
        var items: [DanmakuItem] = []
        let pattern = #"<d p="([^"]*)">([^<]*)</d>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return items }
        regex.enumerateMatches(in: xml, range: NSRange(xml.startIndex..., in: xml)) { m, _, _ in
            guard let m, m.numberOfRanges == 3,
                  let a = Range(m.range(at: 1), in: xml),
                  let c = Range(m.range(at: 2), in: xml) else { return }
            let attrs = String(xml[a]).components(separatedBy: ",")
            guard attrs.count >= 5 else { return }
            let t = Double(attrs[0]) ?? 0 // XML弹幕的time字段已经是秒
            let ci = Int(attrs[3]) ?? 0xFFFFFF
            let uh = attrs.count > 6 ? attrs[6] : ""
            items.append(DanmakuItem(time: t, content: String(xml[c]),
                color: Color(red: Double((ci>>16)&0xFF)/255, green: Double((ci>>8)&0xFF)/255, blue: Double(ci&0xFF)/255),
                mode: Int(attrs[1]) ?? 1, userHash: uh))
        }
        return items.sorted { $0.time < $1.time }
    }
    static func parseProto(data: Data) -> [DanmakuItem] {
        var items: [DanmakuItem] = []
        let bytes = [UInt8](data); var pos = 0
        while pos < bytes.count - 2 {
            let tag = readVarint(bytes, pos: &pos)
            guard Int(tag>>3)==1, Int(tag&0x7)==2 else { let len=readVarint(bytes,pos:&pos); pos+=Int(len); continue }
            let msgLen=Int(readVarint(bytes,pos:&pos)); let end=pos+msgLen
            var progress:Int32=0,mode:Int32=1,color:Int32=0xFFFFFF,content=""
            while pos<end,pos<bytes.count {
                let it=readVarint(bytes,pos:&pos)
                switch (Int(it>>3),Int(it&0x7)) {
                case (2,0): progress=Int32(readVarint(bytes,pos:&pos))
                case (3,0): mode=Int32(readVarint(bytes,pos:&pos))
                case (5,0): color=Int32(readVarint(bytes,pos:&pos))
                case (7,2): let len=Int(readVarint(bytes,pos:&pos)); if pos+len<=bytes.count { content=String(bytes:bytes[pos..<pos+len],encoding:.utf8) ?? ""; pos+=len }
                default: if Int(it&0x7)==0 { _=readVarint(bytes,pos:&pos) } else if Int(it&0x7)==2 { let l=Int(readVarint(bytes,pos:&pos)); pos+=l } else { break }
                }
            }
            if !content.isEmpty,progress>=0 { let t=Double(progress)/1000
                items.append(DanmakuItem(time:t,content:content,color:Color(red:Double((color>>16)&0xFF)/255,green:Double((color>>8)&0xFF)/255,blue:Double(color&0xFF)/255),mode:Int(mode),userHash:"")) }
            pos=end
        }
        return items.sorted { $0.time < $1.time }
    }
    private static func readVarint(_ b:[UInt8],pos:inout Int)->UInt64 { var r:UInt64=0,s=0; while pos<b.count { let v=b[pos]; pos+=1; r|=UInt64(v&0x7F)<<s; if v&0x80==0 {break}; s+=7 }; return r }
}

// MARK: - Canvas渲染 (极简:每帧取playerTime外挂,画可见弹幕)
struct DanmakuRenderer: UIViewRepresentable {
    let items: [DanmakuItem]
    let currentTime: Double
    let alpha: Double
    let fontScale: Double
    let isEnabled: Bool
    let isPlaying: Bool
    var onTapDanmaku: ((DanmakuItem) -> Void)?

    func makeUIView(context: Context) -> DanmakuCanvas { DanmakuCanvas() }
    func updateUIView(_ v: DanmakuCanvas, context: Context) {
        v.playerTime = currentTime
        v.playerPlaying = isPlaying
        v.danmakuAlpha = CGFloat(alpha)
        v.fontScale = CGFloat(fontScale)
        v.isEnabled = isEnabled
        v.onTapDanmaku = onTapDanmaku
        if v.loadedItems.count != items.count { v.setItems(items) }
    }
}

final class DanmakuCanvas: UIView {
    var danmakuAlpha: CGFloat = 0.8
    var fontScale: CGFloat = 1.0
    var isEnabled = true
    var playerPlaying = false
    var onTapDanmaku: ((DanmakuItem) -> Void)?

    private var itemsByTime: [DanmakuItem] = []
    private var displayLink: CADisplayLink?
    private let scrollSec: Double = 7.0
    // 记录当前帧弹幕位置用于点击检测
    private var hitRects: [(item: DanmakuItem, rect: CGRect)] = []

    // 独立时钟: tick()里自增, playerTime来同步时校准
    private var engineTime: Double = 0
    private var lastTickTime: CFTimeInterval = 0
    var playerTime: Double = 0 {
        didSet {
            let delta = abs(playerTime - engineTime)
            // 仅在大幅跳转(seek)时修正引擎时钟，正常播放期间让引擎自由运行
            if delta > 2.0 {
                engineTime = playerTime
                lastTickTime = CACurrentMediaTime()
            }
        }
    }

    var loadedItems: NSArray = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        lastTickTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setItems(_ items: [DanmakuItem]) {
        itemsByTime = items
        loadedItems = items as NSArray
        engineTime = playerTime
        lastTickTime = CACurrentMediaTime()
        if let first = items.first, let last = items.last {
            print("[Danmaku] setItems count=\(items.count) firstTime=\(first.time) lastTime=\(last.time) engineTime=\(engineTime)")
        } else {
            print("[Danmaku] setItems count=\(items.count) (empty)")
        }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        if playerPlaying, isEnabled, !itemsByTime.isEmpty, bounds.width > 0 {
            let dt = now - lastTickTime
            if dt > 0, dt < 0.5 {
                engineTime += dt
            }
            setNeedsDisplay()
        } else if !playerPlaying {
            // 暂停时把引擎时钟校准到播放器时间
            engineTime = playerTime
        }
        lastTickTime = now
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard !playerPlaying else { return }
        let point = gesture.location(in: self)
        for h in hitRects.reversed() {
            if h.rect.contains(point) {
                onTapDanmaku?(h.item)
                break
            }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), isEnabled, playerPlaying else { return }

        let w = bounds.width, h = bounds.height, t = engineTime
        let font = UIFont.systemFont(ofSize: 20 * fontScale, weight: .medium)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = CGSize(width: 1, height: 1)
        shadow.shadowBlurRadius = 1

        // 二分查找可见范围 [t-scrollSec, t+0.5]
        let lo = t - scrollSec
        let hi = t + 0.5

        let startIdx = itemsByTime.binarySearchFirst { $0.time >= lo }
        let endIdx = itemsByTime.binarySearchFirst { $0.time > hi }
        guard startIdx < endIdx else { return }

        // 稳定行分配：基于时间的确定性hash(不用hashValue,每次进程启动随机)
        let rowCount = min(Int(h / (font.lineHeight + 4)), 15)
        guard rowCount > 0 else { return }
        var rowUsed = [Bool](repeating: false, count: rowCount)

        var drawnCount = 0
        hitRects.removeAll(keepingCapacity: true)
        for i in startIdx..<endIdx {
            let item = itemsByTime[i]
            let filtered = DanmakuFilterSettings.shared.shouldFilter(content: item.content)
            if filtered { FilteredLog.shared.logDanmaku(content: item.content, time: item.time, mode: item.mode, colorHex: "FFFFFF", userHash: item.userHash, reason: "关键词匹配") }
            let elapsed = t - item.time
            // 硬守卫：不在可见时间窗内直接跳过
            guard elapsed >= -0.5 && elapsed <= scrollSec else { continue }
            let progress = elapsed / scrollSec
            let x = w - CGFloat(progress) * (w + 400)
            if x < -400 || x > w + 50 { continue }

            // 确定性hash: 用time的bit pattern
            let bits = item.time.bitPattern
            var row = Int((bits ^ (bits >> 32)) & 0x7FFFFFFF) % rowCount
            if rowUsed[row] {
                let alt = (row + 7) % rowCount
                row = rowUsed[alt] ? row : alt
            }
            rowUsed[row] = true
            let y = CGFloat(row) * (font.lineHeight + 4) + font.lineHeight
            // 记录点击区域
            let fh = font.lineHeight
            hitRects.append((item, CGRect(x: x - 4, y: y - fh - 2, width: 600, height: fh + 4)))

            if filtered {
                let markColor = UIColor.gray.withAlphaComponent(CGFloat(danmakuAlpha))
                let r = font.lineHeight * 0.45
                ctx.saveGState()
                ctx.setStrokeColor(markColor.cgColor)
                ctx.setLineWidth(1.5)
                let cx = x, cy = y - font.lineHeight * 0.5
                ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                ctx.strokePath()
                ctx.move(to: CGPoint(x: cx - r * 0.5, y: cy - r * 0.5))
                ctx.addLine(to: CGPoint(x: cx + r * 0.5, y: cy + r * 0.5))
                ctx.move(to: CGPoint(x: cx + r * 0.5, y: cy - r * 0.5))
                ctx.addLine(to: CGPoint(x: cx - r * 0.5, y: cy + r * 0.5))
                ctx.strokePath()
                ctx.restoreGState()
                drawnCount += 1
            } else {
            let str = NSAttributedString(string: item.content, attributes: [
                .font: font,
                .foregroundColor: UIColor(item.color).withAlphaComponent(danmakuAlpha),
                .shadow: shadow,
            ])
            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.translateBy(x: x, y: y)
            ctx.scaleBy(x: 1, y: -1)
            CTLineDraw(CTLineCreateWithAttributedString(str), ctx)
            drawnCount += 1
            ctx.restoreGState()
            }
        }
        if drawnCount > 0 {
            print("[Danmaku] draw engineTime=\(String(format:"%.2f",t)) window=[\(String(format:"%.2f",lo)),\(String(format:"%.2f",hi))] startIdx=\(startIdx) endIdx=\(endIdx) drawn=\(drawnCount)")
        }
    }
}

extension Array {
    func binarySearchFirst(where predicate: (Element) -> Bool) -> Int {
        var lo = 0, hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            if predicate(self[mid]) { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }
}
