import Foundation

// https://github.com/nsscreencast/469-swift-command-line-progress-bar
public struct ProgressBar {
    
    public let width: Int = 60
    private var output: OutputBuffer
    
    public init(output: OutputBuffer) {
        self.output = output
        self.output.write("")
    }
    
    public mutating func render(count: Int, total: Int) {
        let progress = Float(count) / Float(total)
        let numberOfBars = Int(floor(progress * Float(width)))
        let numberOfTicks = width - numberOfBars
        let bars = "🁢" * numberOfBars
        let ticks = "-" * numberOfTicks
        
        let percentage = Int(floor(progress * 100))
        output.clearLine()
        output.write("[\(bars)\(ticks)] \(percentage)%")
    }
}

extension String {
    static func *(char: String, count: Int) -> String {
        var s = ""
        for _ in 0..<count {
            s.append(char)
        }
        return s
    }
}

