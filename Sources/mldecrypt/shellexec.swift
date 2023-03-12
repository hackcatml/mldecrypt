//
//  shellexec.swift
//
//
//  Created by hackcatml on 2023/02/20.
//

import shellexec

// https://stackoverflow.com/questions/46194704/i-cant-use-process-in-a-function
func task(launchPath: String, arguments: String...) -> String {
    let task = NSTask.init()
    task?.setLaunchPath(launchPath)
    task?.arguments = arguments
    
    // Create a Pipe and make the task
    // put all the output there
    let pipe = Pipe()
    task?.standardOutput = pipe

    // Launch the task
    task?.launch()

    // Get the data
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    // trim ouput
    let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)?.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return output!
}
