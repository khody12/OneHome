import SwiftUI

struct RegisterView: View {
    @State private var vm = AuthViewModel()
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Join OneHome 🏡")
                    .font(.title.bold())

                Group {
                    TextField("Name", text: $vm.name)
                    TextField("Username", text: $vm.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $vm.password)
                }
                .textFieldStyle(.roundedBorder)

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red).font(.caption)
                }

                Button {
                    Task { await vm.signUp(appState: appState) }
                } label: {
                    Group {
                        if vm.isLoading { ProgressView() }
                        else { Text("Create Account ✨") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
