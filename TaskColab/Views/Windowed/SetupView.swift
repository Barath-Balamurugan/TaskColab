import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) var appModel
    @AppStorage("setup.userId") private var userId: String = ""
    @AppStorage("setup.ipAddress") private var ipAddress: String = ""
    @AppStorage("setup.port") private var portString: String = "9000"
    @AppStorage("setup.slimeVRPort") private var slimeVRPortString: String = "9001"
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @FocusState private var focusedField: Field?
    enum Field: Hashable { case userId, ip, port, slimeVRPort }

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

                FieldRow(title: "OSC IP") {
                    TextField("e.g. 192.168.1.42", text: $ipAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .ip)
                        .onSubmit { focusedField = .port }
                }
                .validationMessage(unityIPValid ? nil : "Enter a valid IPv4 address.")

                FieldRow(title: "Unity Port") {
                    TextField("e.g. 9000", text: $portString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .port)
                        .onSubmit { focusedField = .slimeVRPort }
                }
                .validationMessage(unityPortValid ? nil : "Port must be 1-65535.")

                FieldRow(title: "SlimeVR Port") {
                    TextField("e.g. 9001", text: $slimeVRPortString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .slimeVRPort)
                        .onSubmit { attemptDone() }
                }
                .validationMessage(slimeVRPortValid ? nil : "Port must be 1-65535.")
            }
            .padding(24)
            .glassBackgroundEffect()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack {
                Spacer()
                Button("Done", action: attemptDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!formValid)
            }
        }
        .frame(maxWidth: 600)
        .padding(32)
        .onAppear {
            syncModelIfPossible()
        }
        .onChange(of: userId) { syncModelIfPossible() }
        .onChange(of: ipAddress) { syncModelIfPossible() }
        .onChange(of: portString) { syncModelIfPossible() }
        .onChange(of: slimeVRPortString) { syncModelIfPossible() }
    }

    // MARK: - Validation

    private var userIdValid: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var unityIPValid: Bool {
        // Strict IPv4 validation 0-255 per octet
        ipAddress.matches(#"^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"#)
    }

    private var unityPortValid: Bool {
        if let p = Int(portString), (1...65535).contains(p) { return true }
        return false
    }

    private var slimeVRPortValid: Bool {
        if let p = Int(slimeVRPortString), (1...65535).contains(p) { return true }
        return false
    }

    private var formValid: Bool {
        userIdValid && unityIPValid && unityPortValid && slimeVRPortValid
    }

    // MARK: - Actions

    private func attemptDone() {
        guard formValid else { return }
        focusedField = nil
        syncModelIfPossible()
//        openWindow(id: "content-view")
        dismissWindow(id: "setup-view")
    }

    private func syncModelIfPossible() {
        var unityPort: UInt16?
        if let p = Int(portString), (1...65535).contains(p) {
            unityPort = UInt16(p)
        }

        var slimePort: UInt16?
        if let p = Int(slimeVRPortString), (1...65535).contains(p) {
            slimePort = UInt16(p)
        }

        appModel.updateSetup(
            userID: userId,
            unityIPAddress: ipAddress,
            unityPort: unityPort,
            outputMode: .slimeVR,
            slimeVRIPAddress: ipAddress,
            slimeVRPort: slimePort
        )
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
    SetupView { user, ip, port in
//        print("User:", user, "IP:", ip, "Port:", port)
    }
    .frame(width: 800, height: 500)
}
