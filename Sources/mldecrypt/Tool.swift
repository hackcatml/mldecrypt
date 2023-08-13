import Foundation
import os
import cdaswift
import opainject
import ZIPFoundation

let MACH_PORT_NULL: mach_port_name_t = 0
let MACH_PORT_DEAD: mach_port_name_t = ~mach_port_name_t(0)

var documentsPath: String = "/var/mobile/Documents/"

// Check if it's arm64e device
func isArm64eDevice() -> Bool {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }

    let components = identifier.split(separator: ",")
    let iPhoneNumberString = components.first?.replacingOccurrences(of: "iPhone", with: "")
    if let iPhoneNumber = Int(iPhoneNumberString ?? "") {
        return iPhoneNumber > 10
    }
    return false
}

// Check if it's rootless
func isRootless() -> Bool {
    let rootlessPath = "/var/jb/usr/bin/su"
    if access(rootlessPath, F_OK) == 0 {
        return true
    }
    return false
}

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

func cleanTempDir() -> Void {
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
}

func createIpa(bundleId: String) -> Int {
    let fileMgr = FileManager.default
    // Clean before
    cleanTempDir()
    
    // source path
    let src: String! = AppUtils.sharedInstance().searchAppBundleDir(bundleId)
    // Define real work path
    var workPath = URL(string: "com.hackcatml.mldecrypt.\(randomStringInLength(6))")!
    workPath = URL(string: NSTemporaryDirectory())!.appendingPathComponent(workPath.path)
    let bundleExecutable = AppUtils.sharedInstance().searchAppExecutable(bundleId)!
    
    do {
        let srcURL = URL(fileURLWithPath: src)
        let dstURL = URL(fileURLWithPath: workPath.appendingPathComponent("Payload").path)
        // Create real work path
        try fileMgr.createDirectory(atPath: workPath.path, withIntermediateDirectories: true, attributes: nil)
        // Do copy
        try fileMgr.copyItem(at: srcURL, to: dstURL)
        
        // Replace a original binary file with a dumped one
        let appResourceDir = (AppUtils.sharedInstance().searchAppResourceDir(bundleId)! as NSString).lastPathComponent
        let fileToReplace = workPath.appendingPathComponent("Payload").path + "/\(appResourceDir)/\(bundleExecutable)"
        let replacementFile = "\(documentsPath)\(bundleExecutable).decrypted"
        try fileMgr.removeItem(atPath: fileToReplace)
        try fileMgr.copyItem(atPath: replacementFile, toPath: fileToReplace)
        
        // Fakesigning with ldid
        var command = "/usr/bin/ldid"
        if isRootless() {
            command = "/var/jb" + command
        }
        let out = task(launchPath: command, arguments: "-e", "\(fileToReplace)")
        let entitlementsPath = "\(workPath)/ent.xml"
        let data = out.data(using: .utf8)
        fileMgr.createFile(atPath: entitlementsPath, contents: data)
        let _ = task(launchPath: command, arguments: "-S\(entitlementsPath)", "\(fileToReplace)")
        
        // Remove files in the Payload dir except for .app dir
        let directoryContents = try fileMgr.contentsOfDirectory(at: workPath.appendingPathComponent("Payload"), includingPropertiesForKeys: nil)
        for fileUrl in directoryContents {
            if !fileUrl.lastPathComponent.hasSuffix(".app") {
                try fileMgr.removeItem(at: fileUrl)
            }
        }
    }
    catch {
        print("Something went wrong while copying: \(error.localizedDescription)")
        // Clean temp dir
        cleanTempDir()
        return 1
    }
    
    // Zip
    do {
        // Clean ipa first if it's already there
        if let filesInDocumentsDir = try? fileMgr.contentsOfDirectory(atPath: "\(documentsPath)") {
            for file in filesInDocumentsDir {
                let filefullpath = "\(documentsPath)".appending((file as NSString).lastPathComponent)
                if file == "\(bundleExecutable).ipa" {
                    try? fileMgr.removeItem(atPath: filefullpath)
                }
            }
        }
        
        let buffer: StringBuffer = StringBuffer()
        var progressBar: ProgressBar = ProgressBar(output: buffer)
        
        let filePath = URL(fileURLWithPath: workPath.appendingPathComponent("Payload").path, isDirectory: true)
        let zipFilePath = URL(fileURLWithPath: "\(documentsPath)\(bundleExecutable).ipa", isDirectory: false)

        let zipProgress = Progress()
        let observation = zipProgress.observe(\.fractionCompleted) { progress, _ in
            progressBar.render(count: Int(progress.fractionCompleted * 100), total:100)
            progress.fractionCompleted == 1 ?
            { print("Zipping...\(buffer.string)"); fflush(stdout) }() :
            { print("Zipping...\(buffer.string)", terminator: "\r"); fflush(stdout) }()
        }
        try fileMgr.zipItem(at: filePath, to: zipFilePath, progress: zipProgress)
        observation.invalidate()
        // Clean after
        cleanTempDir()
        return 0
    }
    catch {
        print("Something went wrong while zipping: \(error.localizedDescription)")
        // Clean after
        cleanTempDir()
        return 1
    }
}

func setDecryptTarget(set: Bool, bundleId: String) -> Void {
    var filename = "/Library/MobileSubstrate/DynamicLibraries/mldecryptor.plist"
    if isRootless() {
        filename = "/var/jb" + filename
    }
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

func backup(arguments: [String], bundleId: String) -> Void {
    if isRootless() {
        let decryptedFile = AppUtils.sharedInstance().searchAppExecutable(bundleId) + ".decrypted"
        let appDocumentsPath = AppUtils.sharedInstance().searchAppDataDir(bundleId) + "/Documents/"
        let decryptedFilePath = appDocumentsPath + decryptedFile
        let srcURL = URL(fileURLWithPath: decryptedFilePath)
        let dstURL = URL(fileURLWithPath: documentsPath + decryptedFile)
        do {
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            try FileManager.default.removeItem(at: srcURL)
        }
        catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    let documentsURL = URL(string: documentsPath)!
    let filelist = try! FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
    let bundleExecutable = AppUtils.sharedInstance().searchAppExecutable(bundleId)!
    for file in filelist {
        if file == bundleExecutable + ".decrypted" {
            if arguments.count == 3 && arguments[1].contains("-b") || arguments.contains("-b") {
                if createIpa(bundleId: bundleId) != 0 {
                    print("Something went wrong while creating ipa. retry")
                    exit(1)
                }
            }
            print("Done!")
            print("Decrypted at \(documentsURL.appendingPathComponent(bundleExecutable +  ".decrypted").path)")
            if arguments.count == 3 && arguments[1].contains("-b") || arguments.contains("-b") {
                print("ipa created at \(documentsURL.appendingPathComponent(bundleExecutable + ".ipa").path)\n")
            }
            setDecryptTarget(set: false, bundleId: bundleId)
            exit(0)
        }
    }
    // Kill the failed app process
    print("Something went wrong while decrypting binary. retry\n")
    var command = "/usr/bin/killall"
    if isRootless() {
        command = "/var/jb" + command
    }
    print("\(task(launchPath: command, arguments: "-QUIT", "\(bundleExecutable)"))")
    exit(1)
}

func opainject(arguments: [String]) -> Void {
    guard let index = arguments.firstIndex(where: { $0 != "-r" && $0 != "-b" && $0 != arguments[0]}) else {
        print(helpString)
        exit(1)
    }
    
    var targetPid: Int32 = 0
    let bundleId = arguments[index]
    if isArm64eDevice(), CommandLine.argc >= 5 {
        let index = arguments.firstIndex(where: {
            $0.allSatisfy({ $0.isNumber })
        })
        targetPid = Int32(arguments[index!])!
    } else {
        let processList = Getpid()
        guard let processes = processList.processes else {
            print("Failed to retrieve process list.")
            exit(1)
        }
        for process in processes {
            let pid = process.kp_proc.p_pid
            let name = withUnsafePointer(to: process.kp_proc.p_comm) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            if name.contains(AppUtils.sharedInstance().searchAppExecutable(bundleId)!) {
                targetPid = Int32(pid)
                break
            }
        }
        guard targetPid != 0 else {
            print("Cannot find pid for \(bundleId)")
            exit(1)
        }
    }
    
    if isArm64eDevice() {
        var pacArg: UnsafeMutablePointer<Int8>? = nil
        if CommandLine.argc >= 5 {
            pacArg = CommandLine.unsafeArgv[Int(CommandLine.argc) - 1]
        }
        if pacArg == nil || String(cString: pacArg!) != "pac" {
            let pidString = String(targetPid)
            let pidPtr = strdup(pidString)

            CommandLine.unsafeArgv[Int(CommandLine.argc)] = pidPtr
            spawnPacChild(CommandLine.argc + 1, CommandLine.unsafeArgv)
            exit(0)
        }
    }
    
    print("OPAINJECT HERE WE ARE")
    print("RUNNING AS \(getuid())")
    
    var dylibPath = "/Library/MobileSubstrate/DynamicLibraries/mldecryptor.dylib"
    if isRootless() {
        dylibPath = "/var/jb" + dylibPath
    }
    guard access(dylibPath, R_OK) >= 0 else {
        print("ERROR: Can't access passed dylib at \(dylibPath)")
        exit(-4)
    }
    
    setDecryptTarget(set: true, bundleId: bundleId)
    
    var procTask: task_t = 0
    let kret = task_for_pid(mach_task_self_, targetPid, &procTask)
    guard kret == KERN_SUCCESS else {
        print("ERROR: task_for_pid failed with error code \(kret) (\(String(cString: mach_error_string(kret))))")
        exit(-2)
    }
    guard procTask != MACH_PORT_DEAD && procTask != MACH_PORT_NULL else {
        print("ERROR: Got invalid task port (\(procTask))")
        exit(-3)
    }

    print("Got task port \(procTask) for pid \(targetPid)!")

    var dyldInfo = task_dyld_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_dyld_info_data_t>.size / MemoryLayout<natural_t>.size)
    let _ = withUnsafeMutablePointer(to: &dyldInfo) { dyldInfoPtr in
        task_info(procTask, task_flavor_t(TASK_DYLD_INFO), dyldInfoPtr.withMemoryRebound(to: Int32.self, capacity: MemoryLayout<task_dyld_info_data_t>.size) { return $0 }, &count)
    }

    injectDylibViaRop(procTask, targetPid, dylibPath, vm_address_t(dyldInfo.all_image_info_addr))

    mach_port_deallocate(mach_task_self_, procTask)
    
    if arguments.contains("-b") {
        sleep(4)
        backup(arguments: arguments, bundleId: bundleId)
    } else {
        sleep(1)
        backup(arguments: arguments, bundleId: bundleId)
    }
    
    exit(0)
}

let helpString: String = """
\nUsage:
\tmldecrypt list, -l\t\tList installed applications
\tmldecrypt <bundleId>\t\tOnly dump binary
\tmldecrypt -r <bundleId>\t\tOnly dump binary during runtime
\tmldecrypt -b <bundleId>\t\tDump binary & backup ipa
\tmldecrypt -r -b <bundleId>\tDump binary & backup ipa during runtime
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
        
        if isRootless() {
            // create rooltess documents path if it's not exists
            documentsPath = "/var/jb" + documentsPath
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: documentsPath) {
                do {
                    try fileManager.createDirectory(atPath: documentsPath, withIntermediateDirectories: true, attributes: nil)
                    var command = "/usr/bin/chown"
                    if isRootless() {
                        command = "/var/jb" + command
                    }
                    let _ = task(launchPath: command, arguments: "mobile:", "\(documentsPath)")
                } catch {
                    print("\(error.localizedDescription)")
                }
            }
        }
        
        if arguments[1].contains("list") || arguments[1].contains("-l") {
            let searchTerm = "list"
            AppUtils.sharedInstance().searchApp(searchTerm)
            exit(0)
        } else if arguments[1].contains("help") || arguments[1].contains("-h") {
            print(helpString)
            exit(0)
        } else if arguments.contains("-r") {
            var index = arguments.firstIndex(of: "-r")
            if index != 1 {
                print("\nUsage: mldecrypt -r <bundleId> || mldecrypt -r -b <bundleId>")
                exit(1)
            } else if arguments.contains("-b") {
                index = arguments.firstIndex(of: "-b")
                if index != 2 {
                    print("\nUsage: mldecrypt -r <bundleId> || mldecrypt -r -b <bundleId>")
                    exit(1)
                }
            }
            opainject(arguments: arguments)
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
            backup(arguments: arguments, bundleId: bundleId)
        } else {
            print(helpString)
            exit(1)
        }
    }
}
