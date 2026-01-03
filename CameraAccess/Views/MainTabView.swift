/*
 * Main Tab View
 * 主 Tab 导航视图
 */

import SwiftUI

struct MainTabView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @State private var selectedTab = 0

    // Read API Keys from secure storage
    private var visionApiKey: String {
        VisionAPIConfig.apiKey(for: VisionAPIConfig.activeProvider)
    }

    private var realtimeApiKey: String {
        VisionAPIConfig.apiKey(for: VisionAPIConfig.activeRealtimeProvider)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - Feature entry
            TurboMetaHomeView(streamViewModel: streamViewModel, wearablesViewModel: wearablesViewModel, visionApiKey: visionApiKey, realtimeApiKey: realtimeApiKey)
                .tabItem {
                    Label("tab.home".localized, systemImage: "house.fill")
                }
                .tag(0)

            // Records
            RecordsView()
                .tabItem {
                    Label("tab.records".localized, systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            // Gallery
            GalleryView()
                .tabItem {
                    Label("tab.gallery".localized, systemImage: "photo.on.rectangle")
                }
                .tag(2)

            // Settings
            SettingsView(streamViewModel: streamViewModel, apiKey: visionApiKey)
                .tabItem {
                    Label("tab.settings".localized, systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(AppColors.primary)
    }
}
