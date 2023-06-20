//
//  File.swift
//  
//
//  Created by hackcatml on 2023/03/25.
//

import Foundation

public struct Getpid {
    var processes: [kinfo_proc]?
    
    init() {
        processes = getProcessList()
    }
    
    private func getProcessList() -> [kinfo_proc]? {
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        let nameSize = name.count

        var size: Int = 0
        sysctl(&name, u_int(nameSize), nil, &size, nil, 0)

        let count = size / MemoryLayout<kinfo_proc>.size

        guard count > 0 else {
            return nil
        }

        var processes = [kinfo_proc](repeating: kinfo_proc(), count: count)
        let result = processes.withUnsafeMutableBufferPointer { buffer -> Int32 in
            sysctl(&name, u_int(nameSize), buffer.baseAddress, &size, nil, 0)
        }

        if result == 0 {
            return processes
        } else {
            return nil
        }
    }
}
