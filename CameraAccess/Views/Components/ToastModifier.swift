/*
 * Toast Modifier
 * 统一的Toast提示组件 - 用于显示临时消息和通知
 */

import SwiftUI

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let duration: TimeInterval
    let position: ToastPosition

    enum ToastPosition {
        case top
        case bottom
        case center
    }

    func body(content: Content) -> some View {
        ZStack(alignment: alignmentForPosition) {
            content

            if isPresented {
                toastView
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
            }
        }
    }

    private var alignmentForPosition: Alignment {
        switch position {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .center:
            return .center
        }
    }

    private var toastView: some View {
        Text(message)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(getPaddingForPosition)
    }

    private var getPaddingForPosition: CGFloat {
        switch position {
        case .top:
            return 60
        case .bottom:
            return 60
        case .center:
            return 0
        }
    }
}

// MARK: - View Extension

extension View {
    /// 显示Toast提示
    /// - Parameters:
    ///   - isPresented: 是否显示
    ///   - message: 消息内容
    ///   - duration: 显示时长（默认2秒）
    ///   - position: 显示位置（默认底部）
    /// - Returns: 应用了Toast修饰器的视图
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        duration: TimeInterval = 2.0,
        position: ToastModifier.ToastPosition = .bottom
    ) -> some View {
        self.modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            duration: duration,
            position: position
        ))
    }
}

// MARK: - Toast View Model

@MainActor
class ToastViewModel: ObservableObject {
    @Published var isShowing = false
    @Published var message = ""

    private var workItem: DispatchWorkItem?

    /// 显示Toast
    func show(_ message: String, duration: TimeInterval = 2.0) {
        // 取消之前的显示任务
        workItem?.cancel()

        self.message = message
        self.isShowing = true

        // 设置自动隐藏
        let newWorkItem = DispatchWorkItem { [weak self] in
            withAnimation {
                self?.isShowing = false
            }
        }
        workItem = newWorkItem

        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: newWorkItem)
    }

    /// 立即隐藏Toast
    func hide() {
        workItem?.cancel()
        withAnimation {
            isShowing = false
        }
    }
}

// MARK: - Usage Examples

/*
 单独使用Toast修饰器：
 ```
 struct ExampleView: View {
     @State private var showToast = false

     var body: some View {
         VStack {
             Button("Show Toast") {
                 showToast = true
             }
         }
         .toast(isPresented: $showToast, message: "操作成功")
     }
 }
 ```

 使用ToastViewModel：
 ```
 struct ExampleView2: View {
     @StateObject private var toast = ToastViewModel()

     var body: some View {
         VStack {
             Button("Show Toast") {
                 toast.show("操作成功")
             }
         }
         .toast(isPresented: $toast.isShowing, message: toast.message)
     }
 }
 ```
 */
