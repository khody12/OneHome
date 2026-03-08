import SwiftUI

struct LoginView: View {
    @State private var vm = AuthViewModel()
    @State private var showRegister = false
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("🏠 OneHome")
                    .font(.largeTitle.bold())
                Text("where roommates actually get stuff done\n(or get roasted 🔥)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    TextField("Email", text: $vm.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $vm.password)
                        .textFieldStyle(.roundedBorder)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task { await vm.signIn(appState: appState) }
                } label: {
                    Group {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In 🚪")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("New here? Make an account 👋") {
                    showRegister = true
                }
                .font(.footnote)

#if DEBUG
                Divider()

                Button {
                    appState.devLogin()
                } label: {
                    Text("🛠️ Dev Login (skip auth)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .font(.footnote)
#endif
            }
            .padding()
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}
