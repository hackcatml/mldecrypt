import Foundation
import os
import Zip
import cdaswift

// Create temp path
func randomStringInLength(_ len: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var ret = ""
    for _ in 0..<len {
        let randomIndex = letters.index(letters.startIndex, offsetBy: Int(arc4random_uniform(UInt32(letters.count))))
        ret += String(letters[randomIndex])
    }
    return ret
}

func createIpa(bundleId: String) -> Int {
    // Clean before
    let fileMgr = FileManager.default
    if let filesInTemp = try? fileMgr.contentsOfDirectory(atPath: NSTemporaryDirectory()) {
        for file in filesInTemp {
            let filefullpath = (NSTemporaryDirectory() as NSString).appendingPathComponent((file as NSString).lastPathComponent)
            // print("file: \(URL(fileURLWithPath: filefullpath).lastPathComponent)")
            if URL(fileURLWithPath: filefullpath).lastPathComponent.hasPrefix("com.hackcatml.mldecrypt.") {
                try? fileMgr.removeItem(atPath: filefullpath)
            }
        }
    }
    
    // source path
    let src: String! = AppUtils.sharedInstance().searchAppBundleDir(bundleId)
    // Define temp dest path
    var tmpPath = URL(string: "com.hackcatml.mldecrypt.\(randomStringInLength(6))")!
    tmpPath = URL(string: NSTemporaryDirectory())!.appendingPathComponent(tmpPath.path)
    // Define real work path
    var workPath = URL(string: "com.hackcatml.mldecrypt.\(randomStringInLength(6))")!
    workPath = URL(string: NSTemporaryDirectory())!.appendingPathComponent(workPath.path)
    let bundleExecutable = AppUtils.sharedInstance().searchAppExecutable(bundleId)!
    
    do {
        // Do copy
        try Filesystem().copyDirectory(sourcePath: src, destinationPath: tmpPath.path, followSymlinks: false)
        // Create real work path
        try fileMgr.createDirectory(atPath: workPath.path, withIntermediateDirectories: true, attributes: nil)
        // Do copy again...
        try Filesystem().copyDirectory(sourcePath: tmpPath.path, destinationPath: workPath.appendingPathComponent("Payload").path, followSymlinks: false)
        
        // Replace a original binary file with a dumped one
        let appResourceDir = (AppUtils.sharedInstance().searchAppResourceDir(bundleId)! as NSString).lastPathComponent
        let fileToReplace = workPath.appendingPathComponent("Payload").path + "/\(appResourceDir)/\(bundleExecutable)"
        let replacementFile = "/var/mobile/Documents/\(bundleExecutable).decrypted"
        try fileMgr.removeItem(atPath: fileToReplace)
        try fileMgr.copyItem(atPath: replacementFile, toPath: fileToReplace)
        
        // Remove files in the Payload dir except for .app dir
        let directoryContents = try fileMgr.contentsOfDirectory(at: workPath.appendingPathComponent("Payload"), includingPropertiesForKeys: nil)
        for fileUrl in directoryContents {
            if !fileUrl.lastPathComponent.hasSuffix(".app") {
                try fileMgr.removeItem(at: fileUrl)
            }
        }

        // Remove the temp path
        try fileMgr.removeItem(atPath: tmpPath.path)
    }
    catch {
        print("Something went wrong while copying: \(error.localizedDescription)")
        return 1
    }
    
    // Zip
    do {
        let buffer: StringBuffer = StringBuffer()
        var progressBar: ProgressBar = ProgressBar(output: buffer)
        
        let filePath = URL(fileURLWithPath: workPath.appendingPathComponent("Payload").path, isDirectory: true)
        let zipFilePath = URL(fileURLWithPath: "/var/mobile/Documents/\(bundleExecutable).ipa", isDirectory: false)
        try Zip.zipFiles(paths: [filePath], zipFilePath: zipFilePath, password: nil, progress: { (progress) in
            progressBar.render(count: Int(progress * 100), total:100)
            progress == 1 ?
            { print("Zipping...\(buffer.string)"); fflush(stdout) }() :
            { print("Zipping...\(buffer.string)", terminator: "\r"); fflush(stdout) }()
        })
        // Remove the real work path
        try fileMgr.removeItem(atPath: workPath.path)
        return 0
    }
    catch {
        print("Something went wrong while zipping: \(error.localizedDescription)")
        return 1
    }
}

func setDecryptTarget(set: Bool, bundleId: String) -> Void {
    let filename = "/Library/MobileSubstrate/DynamicLibraries/mldecryptor.plist"
    let prefs = NSMutableDictionary(contentsOfFile: filename)!
    let FilterPrefs = prefs.value(forKey: "Filter") as! NSMutableDictionary
    let bundleExecutable = AppUtils.sharedInstance().searchAppExecutable(bundleId)
    if bundleExecutable == "Nope" {
        print("There's no bundleId like that")
        exit(1)
    }
    let appResourceDir = AppUtils.sharedInstance().searchAppResourceDir(bundleId)
    if appResourceDir == "Nope" {
        print("There's no app resource dir")
        exit(1)
    }
    if set {
        // set decrypt target
        let target = [bundleId]
        FilterPrefs.setValue(target, forKey: "Bundles")
        prefs.write(toFile: filename, atomically: true)
        return
    } else {
        // unset
        let emptyTarget = [""]
        FilterPrefs.setValue(emptyTarget, forKey: "Bundles")
        prefs.write(toFile: filename, atomically: true)
        return
    }
}

let helpString: String = """
\nUsage:
\tmldecrypt list, -l\t\tList installed applications
\tmldecrypt <bundleId>\t\tOnly decrypt binary
\tmldecrypt -b <bundleId>\t\tDecrypt binary & backup ipa
\tmldecrypt help, -h\t\tShow help\n
"""

@main
public struct mldecrypt {
    public static func main() {
        let arguments = CommandLine.arguments
        
        guard arguments.count >= 2 else {
            print(helpString)
            exit(1)
        }
        
        if arguments[1].contains("list") || arguments[1].contains("-l") {
            let searchTerm = "list"
            AppUtils.sharedInstance().searchApp(searchTerm)
            exit(0)
        } else if arguments[1].contains("help") || arguments[1].contains("-h") {
            print(helpString)
            exit(0)
        } else if arguments.count == 2 || (arguments.count == 3 && arguments[1].contains("-b")) {
            let bundleId = arguments.count == 2 ? arguments[1] : arguments[2]
            
            setDecryptTarget(set: true, bundleId: bundleId)
            
            print("\nOkay. It's ready to decrypt \"\(bundleId)\"'s binary")
            print("Launching the app...\n")
            
            sleep(1)
            // open the target app
            let workspace = LSApplicationWorkspace.defaultWorkspace() as! NSObject
            workspace.perform(Selector(("openApplicationWithBundleID:")), with: bundleId)
            
            sleep(3)
            let documentsURL = URL(string: "/var/mobile/Documents")!
            let filelist = try! FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
            let bundleExecutable = AppUtils.sharedInstance().searchAppExecutable(bundleId)!
            for file in filelist {
                if file == bundleExecutable + ".decrypted" {
                    if arguments.count == 3 && arguments[1].contains("-b") {
                        if createIpa(bundleId: bundleId) != 0 {
                            print("Something went wrong while create ipa. retry")
                            exit(1)
                        }
                    }
                    print("Done!")
                    print("Decrypted at \(documentsURL.appendingPathComponent(bundleExecutable +  ".decrypted").path)")
                    if arguments.count == 3 && arguments[1].contains("-b") {
                        print("ipa created at \(documentsURL.appendingPathComponent(bundleExecutable + ".ipa").path)\n")
                    }
                    setDecryptTarget(set: false, bundleId: bundleId)
                    exit(0)
                }
            }
            // Kill the failed app process
            print("Something went wrong. retry\n")
            print("\(task(launchPath: "/usr/bin/killall", arguments: "-QUIT", "\(bundleExecutable)"))")
            exit(1)
        } else {
            print(helpString)
            exit(1)
        }
    }
}
