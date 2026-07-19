//
//  SettingsView.swift
//  LimesTV
//
//  User preferences: playback quality and channel-change animation.
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(settings: AppSettings) {
        _viewModel = State(initialValue: SettingsViewModel(settings: settings))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section {
                    Picker("Video quality", selection: $viewModel.videoQuality) {
                        ForEach(viewModel.qualityOptions) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    Text("Lower quality reduces network and battery use. Auto always streams the best available quality.")
                }

                Section {
                    Toggle("Channel change animation", isOn: $viewModel.isChannelTransitionEnabled)
                } footer: {
                    Text("Slide transition when zapping between channels.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}
