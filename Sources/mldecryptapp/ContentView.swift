//
//  ContentView.swift
//  swiftuiapp
//
//  Created by hackcatml on 12/3/23.
//

import SwiftUI
import UIKit
import os
import uiimage
import lsap
import shellexec
import ZIPFoundation

class ApplicationManager {
    static let shared = ApplicationManager()
    func installedApplications() -> [LSApplicationProxy] {
        
        let workspace = LSApplicationWorkspace.default()
        let allApps = workspace?.allInstalledApplications() as? [LSApplicationProxy] ?? []
        
        // Filter out system apps. This is a basic filter and might need adjustments.
        return allApps.filter { app in
            guard let bundleID = app.applicationIdentifier else { return false }
            // Exclude system apps based on common bundle ID prefixes
            if bundleID.hasPrefix("com.apple.") || bundleID.hasPrefix("com.hackcatml.") {
                return false
            } else {
                return true
            }
        }
    }
}

struct PressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
            .opacity(configuration.isPressed ? 0.0 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

// MARK: ContentView
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    private let apps = ApplicationManager.shared.installedApplications()
    private var documentsPath: String {
        isRootless() ? "/var/jb/var/mobile/Documents/" : "/var/mobile/Documents/"
    }
    
    @State private var showDumpAlert = false
    @State private var setTarget = false
    @State private var selectedApp: LSApplicationProxy?
    @State private var isForeground = false
    
    @State private var ipaName: String?
    @State private var isCreatingIpa = false
    @State private var createIpaDone = false
    
    @State private var dumpFileSigPath: String?
    @State private var workPathURL: URL?
    
    var body: some View {
        NavigationView {
            List(apps, id: \.applicationIdentifier) { app in
                Button(action: {
                    
                }, label: {
                    HStack {
                        // Display the app icon
                        if let icon = iconForApp(app) {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            // Display the app's localized name
                            Text(app.localizedName ?? "Unknown App")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .font(.system(size: 17)) // Adjust the font size as needed
                            HStack {
                                Text(app.shortVersionString ?? "1.0.0")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                // Display the app's identifier below the name
                                Text(app.applicationIdentifier ?? "Unknown Identifier")
                                    .font(.system(size: 14)) // Smaller font size
                                    .foregroundColor(.gray) // Optional: Change the color to distinguish it
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        DispatchQueue.global().async {
                            self.selectedApp = app
                            self.ipaName = "\(app.bundleExecutable!)_\(app.shortVersionString!).ipa"
                            setDecryptTarget(set: true, app: app) { isSet in
                                self.showDumpAlert = isSet
                                self.setTarget = true
                            }
                        }
                    }
                })
                .buttonStyle(PressEffectButtonStyle())
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Apps")
                        .font(.system(size: 20)) // Adjust the size as needed
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(PlainListStyle())
            .alert(isPresented: $showDumpAlert) {
                Alert(
                    title: Text(""),
                    message: Text("Dump & backup ipa for\n\(self.selectedApp!.localizedName)??"),
                    primaryButton: .default(Text("OK")) {
                        // clean first
                        cleanSigFiles()
                        // make dump start signal file so that mldecryptor tweak can open this app later again
                        self.dumpFileSigPath =  self.documentsPath + "." + self.selectedApp!.applicationIdentifier + "_decrypt_start"
                        let fileMgr = FileManager.default
                        if fileMgr.createFile(atPath: self.dumpFileSigPath!, contents: "//dummy".data(using: .utf8)) {
//                            os_log("[hackcatml] file made at %{public}s", self.dumpFileSigPath!)
                            launchApp(app: self.selectedApp!)
                        }
                    },
                    secondaryButton: .cancel() {
                        self.selectedApp = nil
                    }
                )
            }
        }
        // App will enter foreground from mldecryptor tweak
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            isForeground = true
            if let app = self.selectedApp {
                if let appDataPath = app.dataContainerURL?.path {
//                    os_log("[hackcatml] app data path: %{public}s", appDataPath)
                    if FileManager.default.fileExists(atPath: documentsPath + ipaName!), !self.setTarget {
                        os_log("[hackcatml] dumped ipa already exists: %{public}s", documentsPath + ipaName!)
                        return
                    }
                    
                    if self.isCreatingIpa || self.showDumpAlert {
                        return
                    }
                    
                    // Set progress hud
                    ProgressHUD.animate("Creating IPA", .circleStrokeSpin, interaction: false)
                    ProgressHUD.colorHUD = .tertiarySystemBackground
                    if #available(iOS 15, *) {
                        ProgressHUD.colorAnimation = .systemCyan
                        ProgressHUD.colorProgress = .systemCyan
                    } else {
                        ProgressHUD.colorAnimation = .blue
                        ProgressHUD.colorProgress = .blue
                    }
                    
                    // rootless
                    if isRootless() {
                        // Copy dumped binary to the documents dir
                        let decryptedFile = app.bundleExecutable + ".decrypted"
                        let decryptedFilePath = appDataPath + "/Documents/" + decryptedFile
                        let dstPath = documentsPath + decryptedFile
//                        os_log("[hackcatml] decryptedFilePath: %{public}s, dstPath: %{public}s", decryptedFilePath, dstPath)
                        callMldecryptWithOptions(options: ["copy", decryptedFilePath, dstPath, "ext"])
                        // after copying dumped binary, mldecrypt creates a file
                        let copyFileSigPath = documentsPath + ".mldecrypt_copy_done"
                        checkFileExistenceAndThen(path: copyFileSigPath, interval: 0.01) {
                            unlink(self.dumpFileSigPath!)
                            unlink(copyFileSigPath)
                            
                            copyTargetDir(app: app) {
//                                os_log("[hackcatml] rootless copy dir, ldid done!")
                                createIpa(app: app)
                            }
                        }
                    } else {
                        // rootful
                        copyTargetDir(app: app) {
//                            os_log("[hackcatml] rootful copy dir, ldid done!")
                            createIpa(app: app)
                        }
                    }
                } else {
//                    os_log("[hackcatml] app is foreground, but data container URL is nil")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            isForeground = false
        }
        .alert(isPresented: $createIpaDone) {
            Alert(
                title: Text("Done"),
                message: Text(documentsPath + ipaName!),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: Set decrypt target
    func setDecryptTarget(set: Bool, app: LSApplicationProxy, completion: @escaping (Bool) -> Void) {
        let bundleId = app.applicationIdentifier
        var prefPath = "/Library/MobileSubstrate/DynamicLibraries/mldecryptor.plist"
        
        if isRootless() {
            prefPath = "/var/jb" + prefPath
        }
        
        if set {
            callMldecryptWithOptions(options: ["set", "true", bundleId!, "ext"])
        } else {
            callMldecryptWithOptions(options: ["set", "false", bundleId!, "ext"])
        }
        let setSigPath = documentsPath + ".mldecrypt_set_done"
        checkFileExistenceAndThen(path: setSigPath, interval: 0.01) {
            unlink(setSigPath)
            
            // Check if it's been set properly
            let prefs = NSMutableDictionary(contentsOfFile: prefPath)!
            if let FilterPrefs = prefs.value(forKey: "Filter") as? NSMutableDictionary,
               let bundlesArray = FilterPrefs["Bundles"] as? [String] {
                if bundleId == bundlesArray.first {
                    completion(true)
                } else {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
    
    // MARK: Copy target app dir
    func copyTargetDir(app: LSApplicationProxy, completion: @escaping () -> Void) {
        // source path
        let fileMgr = FileManager.default
        let src: String! = app.bundleContainerURL.path
        // Define the app documents path to work
        let appDocumentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let randomWorkPathURL = URL(string: "com.hackcatml.mldecrypt.\(randomStringInLength(6))")!
        workPathURL = appDocumentsPathURL.appendingPathComponent(randomWorkPathURL.path)
        try? fileMgr.createDirectory(atPath: workPathURL!.path, withIntermediateDirectories: true, attributes: nil)
        callMldecryptWithOptions(options: ["copydir", src, workPathURL!.appendingPathComponent("Payload").path, "ext"])
        
        let copyDirSigPath = documentsPath + ".mldecrypt_copydir_done"
        checkFileExistenceAndThen(path: copyDirSigPath, interval: 0.01) {
            unlink(copyDirSigPath)
            
            // MARK: ldid
            let bundleExecutable = app.bundleExecutable!
            let appResourceDir = app.bundleURL.lastPathComponent
            let fileToReplace = workPathURL!.appendingPathComponent("Payload").path + "/\(appResourceDir)/\(bundleExecutable)"
            let replacementFile = "\(documentsPath)\(bundleExecutable).decrypted"
//            os_log("[hackcatml] fileToReplace: %{public}s, replacementFile: %{public}s", fileToReplace, replacementFile)
            
            let command = isRootless() ? "/var/jb/usr/bin/ldid" : "/usr/bin/ldid"
            let out = task(launchPath: command, arguments: "-e", replacementFile)
            let entitlementsPath = workPathURL!.path + "/ent.xml"
            let data = out.data(using: .utf8)
            fileMgr.createFile(atPath: entitlementsPath, contents: data)
            
            // Replace the original binary file with a dumped one
            let copyFileSigPath = documentsPath + ".mldecrypt_copy_done"
            callMldecryptWithOptions(options: ["copy", replacementFile, fileToReplace, "ext"])
            checkFileExistenceAndThen(path: copyFileSigPath, interval: 0.01) {
                unlink(copyFileSigPath)
                // signing with ldid
                let _ = task(launchPath: command, arguments: "-S\(entitlementsPath)", "\(fileToReplace)")
                completion()
            }
        }
    }
    
    // MARK: Zip
    func createIpa(app: LSApplicationProxy) {
        self.isCreatingIpa = true
        
        // Clean ipa first if it's already there
        let fileMgr = FileManager.default
        let bundleExecutable = app.bundleExecutable!
        if let filesInDocumentsDir = try? fileMgr.contentsOfDirectory(atPath:"\(documentsPath)") {
            for file in filesInDocumentsDir {
                let filefullpath = "\(documentsPath)".appending((file as NSString).lastPathComponent)
                if file == ipaName {
                    try? fileMgr.removeItem(atPath: filefullpath)
                }
            }
        }
        
        do {
            let filePath = URL(fileURLWithPath: workPathURL!.appendingPathComponent("Payload").path, isDirectory: true)
            let zipFilePath = URL(fileURLWithPath: documentsPath + ipaName!, isDirectory: false)
//            os_log("[hackcatml] try to zip %{public}s to %{public}s", filePath.path, zipFilePath.path)
            
            let zipProgress = Progress()
            let observation = zipProgress.observe(\.fractionCompleted) { progress, _ in
                ProgressHUD.progress(progress.fractionCompleted)
                if progress.fractionCompleted == 1 {
                    ProgressHUD.liveIcon(icon: .succeed, delay: 1.5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                        self.createIpaDone = true
                    })
                }
            }
            try FileManager.default.zipItem(at: filePath, to: zipFilePath, progress: zipProgress)
            observation.invalidate()
        } catch {
            os_log("[hackcatml] Something went wrong while zipping: \(error.localizedDescription)")
            self.isCreatingIpa = false
            return
        }
        
        let appDocumentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cleanDirSigPath = documentsPath + ".mldecrypt_cleandir_done"
        callMldecryptWithOptions(options: ["cleandir", appDocumentsPathURL.path, "ext"])
        checkFileExistenceAndThen(path: appDocumentsPathURL.path, interval: 0.01, completion: {
            unlink(cleanDirSigPath)
            cleanSigFiles()
            
            setDecryptTarget(set: false, app: self.selectedApp!, completion: { _ in
                self.setTarget = false
            })
            
            self.isCreatingIpa = false
        })
    }
    
    func iconForApp(_ app: LSApplicationProxy) -> UIImage? {
        guard let bundleIdentifier = app.applicationIdentifier else {
            return nil
        }
        let appIcon = UIImage._applicationIconImage(forBundleIdentifier: bundleIdentifier, format: MIIconVariant.default, scale: 0)
        
        return appIcon
    }
    
    func isRootless() -> Bool {
        let rootlessPath = "/var/jb/usr/bin/su"
        if access(rootlessPath, F_OK) == 0 {
            return true
        }
        return false
    }
    
    func launchApp(app: LSApplicationProxy) {
        let workspace = LSApplicationWorkspace.default()!
        workspace.perform(#selector(LSApplicationWorkspace.openApplication(withBundleID:)), with: app.applicationIdentifier)
    }
    
    func checkFileExistenceAndThen(path: String, interval: TimeInterval, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            while true {
                if fileManager.fileExists(atPath: path) {
                    completion()
                    break
                }
                Thread.sleep(forTimeInterval: interval)
            }
        }
    }
    
    func callMldecryptWithOptions(options: [String]) -> Void {
        var mldecryptPath = "/usr/local/bin/mldecrypt"
        
        if isRootless() {
            mldecryptPath = "/var/jb/usr/bin/mldecrypt"
        }
        
        var pid: pid_t = 0
        var status: Int32 = 0
        var cStrings: [UnsafeMutablePointer<CChar>?] = []
        cStrings.append(strdup(mldecryptPath))
        for option in options {
            cStrings.append(strdup(option))
        }
        cStrings.append(nil)
        
        let posixSpawnResult = posix_spawn(&pid, mldecryptPath, nil, nil, &cStrings, nil)
        let waitPidRResult = waitpid(pid, &status, 0)
//        if cStrings[3] != nil {
//            os_log("[hackcatml] posix_spawn return: %{public}d, waitpid return: %{public}d, option1: %{public}s, option2: %{public}s, options3: %{public}s", posixSpawnResult, waitPidRResult, String(cString: cStrings[1]!), String(cString: cStrings[2]!), String(cString: cStrings[3]!))
//        } else {
//            os_log("[hackcatml] posix_spawn return: %{public}d, waitpid return: %{public}d, option1: %{public}s, option2: %{public}s", posixSpawnResult, waitPidRResult, String(cString: cStrings[1]!), String(cString: cStrings[2]!))
//        }
        
        // Free the C strings
        for cString in cStrings {
            free(cString)
        }
    }
    
    func randomStringInLength(_ len: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var ret = ""
        for _ in 0..<len {
            let randomIndex = letters.index(letters.startIndex, offsetBy: Int(arc4random_uniform(UInt32(letters.count))))
            ret += String(letters[randomIndex])
        }
        return ret
    }
    
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
    
    func cleanSigFiles() {
        DispatchQueue.global().async {
            let fileMgr = FileManager.default
            if let filesInDocuments = try? fileMgr.contentsOfDirectory(atPath: documentsPath) {
                for file in filesInDocuments {
//                    os_log("[hackcatml] file: %{public}s", file)
                    let filefullpath = URL(fileURLWithPath: documentsPath).appendingPathComponent(file).path
//                    os_log("[hackcatml] filefullpath %{public}s", filefullpath)
                    if file.hasPrefix(".mldecrypt_") || file.hasSuffix("_decrypt_start") {
                        do {
                            try fileMgr.removeItem(atPath: filefullpath)
                        } catch {
                            os_log("\(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

// #Preview {
//     ContentView()
// }
