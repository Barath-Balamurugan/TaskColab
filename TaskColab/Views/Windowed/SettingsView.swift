import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) var appModel
    @AppStorage("setup.userId") private var userId: String = ""
    @AppStorage("setup.ipAddress") private var ipAddress: String = ""
    @AppStorage("setup.port") private var portString: String = ""
    @StateObject private var sharePlayManager = SharePlayManager()
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var goNext = false
    
    @FocusState private var focusedField: Field?
    enum Field: Hashable { case userId, ip, port }
    
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @Environment(\.dismiss) private var dismiss

    /// Called when the user taps Done and validation passes
    var onDone: ((String, String, Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("SETUP")
                .font(.largeTitle.weight(.bold))
                .tracking(1.2)
            
            VStack(spacing: 16) {
                FieldRow(title: "User ID") {
                    TextField("e.g. 3001", text: $userId)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .userId)
                        .onSubmit { focusedField = .ip }
                }
                .validationMessage(userIdValid ? nil : "Please enter a four digit number.")
                
                FieldRow(title: "IP Address") {
                    TextField("e.g. 192.168.1.42", text: $ipAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .ip)
                        .onSubmit { focusedField = .port }
                }
                .validationMessage(ipValid ? nil : "Enter a valid IPv4 address.")
                
                FieldRow(title: "Port Number") {
                    TextField("e.g. 3333", text: $portString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .port)
                        .onSubmit { attemptDone() }
                }
                .validationMessage(portValid ? nil : "Port must be 1–65535.")
            }
            .padding(24)
            .glassBackgroundEffect()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            HStack {
                Spacer()
                Button("Save", action: attemptDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!formValid)
            }
        }
        .frame(maxWidth: 600)
        .padding(32)
        .navigationTitle("Settings")
    }

    // MARK: - Validation

    private var userIdValid: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ipValid: Bool {
        // Strict IPv4 validation 0-255 per octet
        ipAddress.matches(#"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#)
    }

    private var portValid: Bool {
        if let p = Int(portString), (1...65535).contains(p) { return true }
        return false
    }

    private var formValid: Bool { userIdValid && ipValid && portValid }

    // MARK: - Actions

    private func attemptDone() {
        guard formValid, let p = Int(portString) else { return }
        focusedField = nil
        appModel.userID = userId
        appModel.ipAddress = ipAddress
        appModel.portNumber = UInt16(p)
        
        onDone?(userId, ipAddress, p)
        
        hasCompletedSetup = true
        dismiss()
    }
}

// MARK: - FieldRow helper

/// A labeled row with a fixed-width title on the leading side and the input on the trailing side.
private struct FieldRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    private var message: String?

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .frame(width: 160, alignment: .trailing)
                    .font(.title3.weight(.semibold))
                content
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.leading, 160 + 16)
            }
        }
    }

    /// Attach an inline validation message below the field.
    func validationMessage(_ message: String?) -> some View {
        var copy = self
        copy.message = message
        return copy
    }
}

// MARK: - Utilities

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    SettingsView { user, ip, port in
//        print("User:", user, "IP:", ip, "Port:", port)
    }
    .frame(width: 800, height: 500)
}

