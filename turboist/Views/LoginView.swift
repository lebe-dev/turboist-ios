import SwiftUI

struct LoginView: View {
    let authStore: AuthStore

    @State private var password = ""
    @FocusState private var passwordFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Turboist")
                    .font(.largeTitle.bold())
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .focused($passwordFieldFocused)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .disabled(authStore.isLoggingIn)

                if let error = authStore.loginError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack {
                        if authStore.isLoggingIn {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Sign in")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(password.isEmpty || authStore.isLoggingIn)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .onAppear {
            passwordFieldFocused = true
        }
    }

    private func submit() {
        let pwd = password
        Task {
            await authStore.login(password: pwd)
            if authStore.state == .authenticated {
                password = ""
            }
        }
    }
}

#Preview {
    LoginView(authStore: AuthStore(apiClient: APIClient(baseURL: "https://t.tinyops.ru")))
}
