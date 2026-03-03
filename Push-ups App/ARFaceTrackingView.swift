//
//  ARFaceTrackingView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI
import ARKit

/// SwiftUI обертка для AR камеры с отслеживанием лица
struct ARFaceTrackingView: UIViewRepresentable {
    
    @ObservedObject var detector: PushUpDetector
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        
        // Настройка конфигурации для отслеживания лица
        let configuration = ARFaceTrackingConfiguration()
        
        // Проверяем поддержку TrueDepth камеры
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ Face tracking не поддерживается на этом устройстве")
            return arView
        }
        
        // Запускаем сессию
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Обновления UI при необходимости
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detector: detector)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        
        let detector: PushUpDetector
        
        init(detector: PushUpDetector) {
            self.detector = detector
        }
        
        // MARK: - ARSessionDelegate
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // Находим anchor лица
            guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
                return
            }
            
            // Получаем позицию лица в мировых координатах
            let transform = faceAnchor.transform
            
            // Извлекаем позицию (translation) из матрицы трансформации
            let position = simd_float3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            
            // Вычисляем евклидово расстояние от камеры (0,0,0) до лица
            // Это работает независимо от ориентации устройства
            let distance = simd_length(position)
            
            // Отправляем расстояние в детектор
            Task { @MainActor in
                detector.processDistance(distance)
            }
            
            // Отладочная информация
            #if DEBUG
            if Int.random(in: 0...30) == 0 { // Каждый ~30-й кадр
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
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }
}
