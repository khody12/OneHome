import SwiftUI
import PhotosUI

struct CreatePostView: View {
    let home: Home
    @State private var vm = PostViewModel()
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            Form {
                Section("What'd you do? 💪") {
                    Picker("Category", selection: $vm.selectedCategory) {
                        ForEach(PostCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.label)").tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $vm.text)
                        .frame(minHeight: 80)
                }

                Section("Photo 📸") {
                    PhotosPicker(selection: $vm.selectedPhoto, matching: .images) {
                        Label(vm.uploadedImageURL == nil ? "Add a photo" : "Change photo", systemImage: "camera")
                    }
                }

                if let err = vm.errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Post 🚀") {
                        Task { await vm.publish(homeID: home.id, userID: appState.currentUser!.id) }
                    }
                    .disabled(vm.isLoading || vm.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                if let userID = appState.currentUser?.id {
                    await vm.startDraft(homeID: home.id, userID: userID)
                }
            }
            .onChange(of: vm.isPosted) {
                if vm.isPosted { vm.reset() }
            }
        }
    }
}
