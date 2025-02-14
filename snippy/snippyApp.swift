import SwiftUI
import Foundation

// MARK: - Models
struct Snippet: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var category: String
    var commands: [String]
    var tags: [String]
    var dateCreated: Date
    var lastModified: Date
    
    init(name: String, description: String, category: String, commands: [String], tags: [String] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.commands = commands
        self.tags = tags
        self.dateCreated = Date()
        self.lastModified = Date()
    }
}

// MARK: - View Models
class SnippetStore: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var categories: Set<String> = []
    private let saveKey = "savedSnippets"
    
    init() {
        loadSnippets()
    }
    
    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        categories.insert(snippet.category)
        saveSnippets()
    }
    
    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        updateCategories()
        saveSnippets()
    }
    
    private func updateCategories() {
        categories = Set(snippets.map { $0.category })
    }
    
    private func loadSnippets() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
                snippets = decoded
                updateCategories()
            }
        }
    }
    
    private func saveSnippets() {
        if let encoded = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var snippetStore = SnippetStore()
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    var filteredSnippets: [Snippet] {
        snippetStore.snippets.filter { snippet in
            let matchesSearch = searchText.isEmpty ||
                snippet.name.localizedCaseInsensitiveContains(searchText) ||
                snippet.description.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || snippet.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Categories")) {
                    HStack {
                        Text("All")
                            .font(.headline)
                        Spacer()
                        Text("\(snippetStore.snippets.count)")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCategory = nil
                    }
                    
                    ForEach(Array(snippetStore.categories), id: \.self) { category in
                        HStack {
                            Text(category)
                                .font(.headline)
                            Spacer()
                            Text("\(snippetStore.snippets.filter { $0.category == category }.count)")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                        }
                    }
                }
                
                Section(header: Text("Snippets")) {
                    ForEach(filteredSnippets) { snippet in
                        NavigationLink(destination: SnippetDetailView(snippet: snippet)) {
                            SnippetRowView(snippet: snippet)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            snippetStore.deleteSnippet(filteredSnippets[index])
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Snippet Manager")
            .searchable(text: $searchText, prompt: "Search snippets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Snippet", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSnippetView(snippetStore: snippetStore)
            }
        }
    }
}

struct SnippetRowView: View {
    let snippet: Snippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet.name)
                .font(.headline)
            Text(snippet.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Text(snippet.category)
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                ForEach(snippet.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SnippetDetailView: View {
    let snippet: Snippet
    @State private var showingCopiedAlert = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(snippet.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands")
                        .font(.headline)
                    
                    ForEach(snippet.commands.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                Text(snippet.commands[index])
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            
                            HStack {
                                Button(action: {
                                    copyToClipboard(snippet.commands[index])
                                    showingCopiedAlert = true
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                
                                Button(action: {
                                    runInTerminal(snippet.commands[index])
                                }) {
                                    Label("Run", systemImage: "terminal")
                                }
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading, 8)
                        }
                    }
                    
                    Button(action: {
                        copyToClipboard(snippet.commands.joined(separator: "\n"))
                        showingCopiedAlert = true
                    }) {
                        Label("Copy All Commands", systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle(snippet.name)
        .alert("Copied to Clipboard", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func runInTerminal(_ command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error executing AppleScript: \(error)")
            }
        }
    }
}


struct AddSnippetView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var snippetStore: SnippetStore
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = ""
    @State private var commandsText = ""
    @State private var tagsText = ""
    @State private var selectedTemplate: ScriptTemplate?
    @State private var showingTemplateSheet = false
    @State private var variables: [String: String] = [:]
    
    enum ScriptTemplate: String, CaseIterable {
        case kubernetes = "Kubernetes Deployment"
        case docker = "Docker Build & Push"
        case git = "Git Operations"
        case aws = "AWS CLI"
        case custom = "Custom Script"
        
        var placeholder: String {
            switch self {
            case .kubernetes:
                return """
                kubectl apply -f deployment.yaml
                kubectl get pods
                kubectl get services
                """
            case .docker:
                return """
                docker build -t {image_name}:{tag} .
                docker push {image_name}:{tag}
                """
            case .git:
                return """
                git checkout -b {branch_name}
                git add .
                git commit -m "{commit_message}"
                git push origin {branch_name}
                """
            case .aws:
                return """
                aws s3 cp {local_path} s3://{bucket_name}/
                aws ec2 describe-instances
                """
            case .custom:
                return "Enter your custom commands here..."
            }
        }
        
        var variables: [String] {
            switch self {
            case .kubernetes:
                return []
            case .docker:
                return ["image_name", "tag"]
            case .git:
                return ["branch_name", "commit_message"]
            case .aws:
                return ["local_path", "bucket_name"]
            case .custom:
                return []
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Details Section
                    GroupBox(label: Text("Details").bold()) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name").foregroundColor(.secondary)
                                TextField("Snippet name", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description").foregroundColor(.secondary)
                                TextField("Brief description", text: $description)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category").foregroundColor(.secondary)
                                HStack {
                                    TextField("Category", text: $category)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Menu {
                                        ForEach(snippetStore.categories.sorted(), id: \.self) { existingCategory in
                                            Button(existingCategory) {
                                                category = existingCategory
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .menuStyle(BorderlessButtonMenuStyle())
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tags").foregroundColor(.secondary)
                                TextField("Comma-separated tags", text: $tagsText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding()
                    }
                    
                    // Commands Section
                    GroupBox(label: Text("Commands").bold()) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Picker("Template", selection: $selectedTemplate) {
                                    Text("Select a template").tag(Optional<ScriptTemplate>.none)
                                    ForEach(ScriptTemplate.allCases, id: \.self) { template in
                                        Text(template.rawValue).tag(Optional<ScriptTemplate>.some(template))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                
                                Spacer()
                                
                                Button("Build Script") {
                                    showingTemplateSheet = true
                                }
                                .disabled(selectedTemplate == nil)
                            }
                            
                            TextEditor(text: $commandsText)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 200)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
            .navigationTitle("Add Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSnippet()
                    }
                    .disabled(name.isEmpty || commandsText.isEmpty)
                }
            }
            
            .sheet(isPresented: $showingTemplateSheet) {
                buildScriptSheet
            }
        }
    }
    
    private var buildScriptSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let template = selectedTemplate {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Template Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Template:")
                                    .font(.headline)
                                Text(template.rawValue)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Variables Section
                            if !template.variables.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Variables")
                                        .font(.headline)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(template.variables, id: \.self) { variable in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(variable.replacingOccurrences(of: "_", with: " ").capitalized)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                TextField("Enter \(variable)",
                                                          text: Binding(
                                                            get: { variables[variable] ?? "" },
                                                            set: { variables[variable] = $0 }
                                                          )
                                                )
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Preview Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Preview")
                                    .font(.headline)
                                
                                let previewText = template.placeholder
                                Text(previewText)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    Text("Please select a template")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Build Script")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTemplateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyTemplate()
                        showingTemplateSheet = false
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
        }
        .frame(width: 600, height: 600)
    }
    
    
    private func applyTemplate() {
        guard let template = selectedTemplate else { return }
        var scriptText = template.placeholder
        
        for variable in template.variables {
            if let value = variables[variable] {
                scriptText = scriptText.replacingOccurrences(of: "{\(variable)}", with: value)
            }
        }
        
        commandsText = scriptText
    }
    
    private func saveSnippet() {
        let commands = commandsText
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        let tags = tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let snippet = Snippet(
            name: name,
            description: description,
            category: category,
            commands: commands,
            tags: tags
        )
        
        snippetStore.addSnippet(snippet)
        dismiss()
    }
}


// MARK: - Menu Bar Views

// MARK: - Menu Bar Views
struct MenuBarView: View {
    @ObservedObject var snippetStore: SnippetStore
    @State private var searchText = ""
    
    var filteredSnippets: [Snippet] {
        if searchText.isEmpty {
            return snippetStore.snippets
        }
        return snippetStore.snippets.filter { snippet in
            snippet.name.localizedCaseInsensitiveContains(searchText) ||
            snippet.description.localizedCaseInsensitiveContains(searchText) ||
            snippet.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and settings bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                TextField("Search snippets...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(height: 24)
                Button(action: openMainWindow) {
                    Image(systemName: "gear")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            if filteredSnippets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No snippets added yet" : "No matching snippets")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Button("Add Snippet", action: openMainWindow)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSnippets) { snippet in
                            MenuBarSnippetView(snippet: snippet)
                            if snippet.id != filteredSnippets.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .frame(minHeight: 100, maxHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Snippet Manager"
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


struct MenuBarSnippetView: View {
    let snippet: Snippet
    @State private var isHovered = false
    @State private var showingCommands = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Snippet header
            Button(action: { withAnimation { showingCommands.toggle() }}) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Text(snippet.category)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Quick action buttons
                    HStack(spacing: 12) {
                        Button(action: { copyAllCommands() }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy all commands")
                        
                        Image(systemName: showingCommands ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .onHover { hover in
                isHovered = hover
            }
            
            // Commands list
            if showingCommands {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snippet.commands.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(snippet.commands[index])
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    copyToClipboard(snippet.commands[index])
                                    showCopied = true
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Copy command")
                                
                                Button(action: {
                                    runInTerminal(snippet.commands[index])
                                }) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Run in Terminal")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.05))
                        .overlay(
                            showCopied ? Color.blue.opacity(0.1) : Color.clear
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: showCopied) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showCopied = false
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func runInTerminal(_ command: String) {
         DispatchQueue.global(qos: .userInitiated).async {
             let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
             let script = """
             tell application "Terminal"
                 activate
                 if (count of windows) is 0 then
                     do script ""
                 end if
                 do script "\(escapedCommand)" in front window
             end tell
             """
             
             var error: NSDictionary?
             if let scriptObject = NSAppleScript(source: script) {
                 DispatchQueue.main.async {
                     NSApp.activate(ignoringOtherApps: true)
                 }
                 scriptObject.executeAndReturnError(&error)
                 if let error = error {
                     DispatchQueue.main.async {
                         print("Error executing AppleScript: \(error)")
                     }
                 }
             }
         }
     }
    
    private func copyAllCommands() {
        let allCommands = snippet.commands.joined(separator: "\n")
        copyToClipboard(allCommands)
        showCopied = true
    }
    
}

// Event monitor for handling clicks outside the popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var snippetStore: SnippetStore!
    var eventMonitor: EventMonitor?
    var accessibilityManager: AccessibilityManager!
    var settingsWindow: NSWindow?

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        snippetStore = SnippetStore()
        accessibilityManager = AccessibilityManager()

        
           setupMenuBar()

        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(snippetStore: snippetStore)
        )
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
             if event.modifierFlags.contains(.command) {
                 switch event.charactersIgnoringModifiers {
                 case "r":  // Run command
                     // Handle run command
                     return nil
                 case "c":  // Copy command
                     // Handle copy command
                     return nil
                 case ".":  // Stop process
                     // Handle stop process
                     return nil
                 default:
                     break
                 }
             }
             return event
         }
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "terminal.fill",
                accessibilityDescription: "Snippet Manager"
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(scale: .medium)
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create event monitor to detect clicks outside the popover
         eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
             if let strongSelf = self, strongSelf.popover.isShown {
                 strongSelf.closePopover(event)
             }
         }
         eventMonitor?.start()
    }
    
    func setupMenuBar() {
        let mainMenu = NSMenu()
        
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        appMenu.addItem(settingsItem)
        
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.title = "Settings"
            
            let settingsView = AccessibilitySettingsView()
                .environmentObject(accessibilityManager)
            
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                closePopover(sender)
            } else {
                showPopover(button)
            }
        }
    }
    
    func showPopover(_ sender: NSView) {
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        eventMonitor?.start()
    }
    
    func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    deinit {
        eventMonitor?.stop()
    }
}


// MARK: - App
@main
struct SnippetManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class TerminalManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentOutput: String = ""
    private var currentProcess: Process?
    
    func runCommand(_ command: String) {
        isRunning = true
        currentOutput = ""
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
        
        currentProcess = task
        
        let outputHandle = pipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.currentOutput += output
                    }
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            currentOutput = "Error: \(error.localizedDescription)"
            isRunning = false
        }
    }
    
    func stopCurrentProcess() {
        currentProcess?.terminate()
        isRunning = false
    }
}

struct TerminalView: View {
    @StateObject private var terminalManager = TerminalManager()
    let commands: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Terminal output area
            ScrollView {
                Text(terminalManager.currentOutput)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(height: 200)
            
            // Command controls
            VStack(spacing: 8) {
                ForEach(commands.indices, id: \.self) { index in
                    HStack {
                        Text(commands[index])
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            terminalManager.runCommand(commands[index])
                        }) {
                            Label("Run", systemImage: "play.fill")
                        }
                        .disabled(terminalManager.isRunning)
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            if terminalManager.isRunning {
                Button("Stop Current Process") {
                    terminalManager.stopCurrentProcess()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terminal Output and Controls")
    }
}

class AccessibilityManager: ObservableObject {
    @Published var isVoiceOverRunning = false
    @Published var fontScale: CGFloat = 1.0
    @Published var highContrastEnabled = false
    @Published var reduceMotionEnabled = false
    
    init() {
        // Check initial VoiceOver status
        isVoiceOverRunning = NSWorkspace.shared.isVoiceOverEnabled
        
        // Monitor system appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessibilityStatusChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAccessibilityStatusChange() {
        DispatchQueue.main.async {
            self.isVoiceOverRunning = NSWorkspace.shared.isVoiceOverEnabled
            // Update other accessibility settings as needed
        }
    }
}

struct AccessibleSnippetRowView: View {
    let snippet: Snippet
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: accessibilityManager.fontScale * 4) {
            Text(snippet.name)
                .font(.system(size: 16 * accessibilityManager.fontScale, weight: .medium))
                .foregroundColor(accessibilityManager.highContrastEnabled ? .white : .primary)
            
            Text(snippet.description)
                .font(.system(size: 14 * accessibilityManager.fontScale))
                .foregroundColor(accessibilityManager.highContrastEnabled ? .white : .secondary)
            
            HStack {
                AccessibleCategoryTag(text: snippet.category)
                ForEach(snippet.tags, id: \.self) { tag in
                    AccessibleCategoryTag(text: tag)
                }
            }
        }
        .padding(.vertical, 8 * accessibilityManager.fontScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snippet.name), \(snippet.description)")
        .accessibilityHint("Category: \(snippet.category), Tags: \(snippet.tags.joined(separator: ", "))")
    }
}

struct AccessibleCategoryTag: View {
    let text: String
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    var body: some View {
        Text(text)
            .font(.system(size: 12 * accessibilityManager.fontScale))
            .padding(4 * accessibilityManager.fontScale)
            .background(accessibilityManager.highContrastEnabled ? Color.white : Color.blue.opacity(0.2))
            .foregroundColor(accessibilityManager.highContrastEnabled ? .black : .blue)
            .cornerRadius(4)
            .accessibilityLabel(text)
    }
}

struct AccessibilitySettingsView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Display Settings")) {
                VStack(alignment: .leading, spacing: 16) {
                    // Font Size Slider
                    VStack(alignment: .leading) {
                        Text("Text Size")
                            .font(.headline)
                        Slider(
                            value: $accessibilityManager.fontScale,
                            in: 0.8...1.5,
                            step: 0.1
                        ) {
                            Text("Font Size")
                        } minimumValueLabel: {
                            Text("A").font(.system(size: 12))
                        } maximumValueLabel: {
                            Text("A").font(.system(size: 20))
                        }
                    }
                    
                    // High Contrast Toggle
                    Toggle("High Contrast Mode", isOn: $accessibilityManager.highContrastEnabled)
                        .toggleStyle(SwitchToggleStyle())
                    
                    // Reduce Motion Toggle
                    Toggle("Reduce Motion", isOn: $accessibilityManager.reduceMotionEnabled)
                        .toggleStyle(SwitchToggleStyle())
                }
            }
            
            Section(header: Text("Terminal Settings")) {
                VStack(alignment: .leading, spacing: 16) {
                    // Font Settings
                    Picker("Terminal Font Size", selection: .constant(14)) {
                        Text("Small (12pt)").tag(12)
                        Text("Medium (14pt)").tag(14)
                        Text("Large (16pt)").tag(16)
                    }
                    
                    // Color Scheme
                    Picker("Terminal Theme", selection: .constant(colorScheme)) {
                        Text("System").tag(colorScheme)
                        Text("Light").tag(ColorScheme.light)
                        Text("Dark").tag(ColorScheme.dark)
                    }
                }
            }
            
            Section(header: Text("Keyboard Shortcuts")) {
                VStack(alignment: .leading, spacing: 8) {
                    KeyboardShortcutRow(action: "Run Selected Command", shortcut: "⌘ + R")
                    KeyboardShortcutRow(action: "Copy Command", shortcut: "⌘ + C")
                    KeyboardShortcutRow(action: "Stop Process", shortcut: "⌘ + .")
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct KeyboardShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
                .foregroundColor(.primary)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action), keyboard shortcut \(shortcut)")
    }
}
