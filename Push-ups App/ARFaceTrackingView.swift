//
//  ARFaceTrackingView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI
import ARKit

/// SwiftUI обертка для AR-сессии без отображения камеры
struct ARFaceTrackingView: UIViewRepresentable {

    @ObservedObject var detector: PushUpDetector

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ Face tracking не поддерживается на этом устройстве")
            return view
        }

        let configuration = ARFaceTrackingConfiguration()
        context.coordinator.session.delegate = context.coordinator
        context.coordinator.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(detector: detector)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {

        let detector: PushUpDetector
        let session = ARSession()

        init(detector: PushUpDetector) {
            self.detector = detector
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
                return
            }

            let transform = faceAnchor.transform
            let position = simd_float3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            let distance = simd_length(position)

            Task { @MainActor in
                detector.processDistance(distance)
            }

            #if DEBUG
            if Int.random(in: 0...30) == 0 {
                print("📍 Позиция: x=\(String(format: "%.2f", position.x)), y=\(String(format: "%.2f", position.y)), z=\(String(format: "%.2f", position.z))")
                print("📏 Расстояние: \(String(format: "%.3f", distance))м")
            }
            #endif
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            print("❌ AR Session ошибка: \(error.localizedDescription)")
            Task { @MainActor in
                detector.feedbackMessage = "Ошибка камеры"
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("⏸️ AR Session прервана")
            Task { @MainActor in
                detector.feedbackMessage = "Сессия прервана"
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("▶️ AR Session возобновлена")
            Task { @MainActor in
                detector.feedbackMessage = "Продолжайте!"
            }
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session.pause()
    }
}
