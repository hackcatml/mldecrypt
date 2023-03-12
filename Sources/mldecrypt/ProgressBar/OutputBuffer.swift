//
//  OutputBuffer.swift
//  SwiftProgressBar
//
//  Created by Ben Scheirman on 12/4/20.
//

import Foundation

public protocol OutputBuffer {
    mutating func write(_ text: String)
    mutating func clearLine()
}

public class StringBuffer: OutputBuffer {
    public private(set) var string: String = ""
    
    public func write(_ text: String) {
        string.append(text)
    }
    
    public func clearLine() {
        string = ""
    }
}

extension FileHandle: OutputBuffer {
    public func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        write(data)
    }
    
    public func clearLine() {
        write("\r")
    }
}
