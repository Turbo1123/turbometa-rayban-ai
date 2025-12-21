/*
 * Omni Realtime View
 * Real-time multimodal conversation interface
 */

import SwiftUI

struct OmniRealtimeView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: OmniRealtimeViewModel(apiKey: apiKey))
    }

    var body: some View {
        ZStack {
            // Video background from glasses
            if let videoFrame = streamViewModel.currentVideoFrame {
                Image(uiImage: videoFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.3)
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Header
                headerView

                // Conversation history
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.conversationHistory) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Current AI response (streaming)
                            if !viewModel.currentTranscript.isEmpty {
                                MessageBubble(
                                    message: ConversationMessage(
                                        role: .assistant,
                                        content: viewModel.currentTranscript
                                    )
                                )
                                .id("current")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.conversationHistory.count) { _ in
                        if let lastMessage = viewModel.conversationHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentTranscript) { _ in
                        withAnimation {
                            proxy.scrollTo("current", anchor: .bottom)
                        }
                    }
                }

                // Status and controls
                controlsView
            }
        }
        .onAppear {
            viewModel.connect()
            // Update video frames
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if let frame = streamViewModel.currentVideoFrame {
                    viewModel.updateVideoFrame(frame)
                }
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("AI 实时对话")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 12) {
            // Speaking indicator
            if viewModel.isSpeaking {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text("正在说话...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.2))
                .cornerRadius(20)
            }

            // Recording status
            HStack(spacing: 8) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("录音中")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text("未录音")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)

            // Control buttons
            HStack(spacing: 20) {
                // Start/Stop Recording
                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(.title)
                        Text(viewModel.isRecording ? "停止" : "开始")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(!viewModel.isConnected)
            }
            .padding()
        }
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(18)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Preview
// Preview requires real wearables instance
