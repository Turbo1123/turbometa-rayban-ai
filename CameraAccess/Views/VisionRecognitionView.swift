/*
 * Vision Recognition View
 * UI for analyzing captured photos using AI vision model
 */

import SwiftUI

struct VisionRecognitionView: View {
    @StateObject private var viewModel: VisionRecognitionViewModel
    @Environment(\.dismiss) private var dismiss

    let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self._viewModel = StateObject(wrappedValue: VisionRecognitionViewModel(photo: photo, apiKey: apiKey))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo preview
                    photoSection

                    // Prompt input section
                    promptSection

                    // Quick prompt buttons
                    quickPromptsSection

                    // Analyze button
                    analyzeButton

                    // Result section
                    resultSection
                }
                .padding()
            }
            .navigationTitle("AI 视觉识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var photoSection: some View {
        Image(uiImage: photo)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 300)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提问内容")
                .font(.headline)
                .foregroundColor(.primary)

            TextField("输入你的问题...", text: $viewModel.customPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .disabled(viewModel.isAnalyzing)
        }
    }

    private var quickPromptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷提问")
                .font(.headline)
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VisionRecognitionViewModel.quickPrompts, id: \.self) { prompt in
                        Button {
                            viewModel.customPrompt = prompt
                        } label: {
                            Text(prompt)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.customPrompt == prompt
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    viewModel.customPrompt == prompt
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(16)
                        }
                        .disabled(viewModel.isAnalyzing)
                    }
                }
            }
        }
    }

    private var analyzeButton: some View {
        Button {
            Task {
                await viewModel.analyzeImage()
            }
        } label: {
            HStack {
                if viewModel.isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(viewModel.isAnalyzing ? "分析中..." : "开始分析")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isAnalyzing ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isAnalyzing || viewModel.customPrompt.isEmpty)
    }

    private var resultSection: some View {
        Group {
            if let result = viewModel.recognitionResult {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("识别结果")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Button {
                            viewModel.clearResult()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }

                    Text(result)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)

                    Button {
                        UIPasteboard.general.string = result
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制结果")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("错误")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)

                    Button {
                        Task {
                            await viewModel.retryAnalysis()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VisionRecognitionView(
        photo: UIImage(systemName: "photo")!,
        apiKey: "sk-demo"
    )
}
