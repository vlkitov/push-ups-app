//
//  PushUpDetector.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import Foundation
import ARKit
import Combine

/// Состояния отжимания
enum PushUpPhase {
    case up        // Верхняя позиция (руки выпрямлены)
    case down      // Нижняя позиция (руки согнуты, близко к полу)
    case transition // Промежуточное состояние
}

/// Основной класс для детектирования отжиманий через TrueDepth камеру
@MainActor
class PushUpDetector: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Текущее количество отжиманий
    @Published var pushUpCount: Int = 0
    
    /// Текущее расстояние до лица (в метрах)
    @Published var currentDistance: Float = 0.0
    
    /// Текущая фаза отжимания
    @Published var currentPhase: PushUpPhase = .transition
    
    /// Статус готовности к тренировке
    @Published var isCalibrated: Bool = false

    /// Активна ли тренировка (считаем повторения)
    @Published var isActive: Bool = false

    /// Сообщения для пользователя
    @Published var feedbackMessage: String = "Расположите телефон перед собой"
    
    // MARK: - Private Properties
    
    /// Базовое расстояние (верхняя точка отжимания)
    private var baselineDistance: Float = 0.0
    
    /// Порог для определения нижней точки (в метрах от baseline)
    private let downThreshold: Float = 0.20 // 20 см ближе к камере
    
    /// Порог для возврата в верхнюю точку
    private let upThreshold: Float = 0.08 // 8 см от baseline
    
    /// Минимальное время между повторениями (защита от дребезга)
    private var lastPushUpTime: Date = Date()
    private let minimumRepInterval: TimeInterval = 0.5 // 0.5 секунды
    
    /// История расстояний для сглаживания данных
    private var distanceHistory: [Float] = []
    private let smoothingWindowSize = 5
    
    // MARK: - Calibration
    
    /// Калибровка начального положения
    func calibrate(with distance: Float) {
        baselineDistance = distance
        isCalibrated = true
        currentPhase = .up
        feedbackMessage = "Калибровка завершена. Начинайте!"
        print("📏 Базовое расстояние установлено: \(distance)м")
    }
    
    /// Автоматическая калибровка (берет среднее за первые 2 секунды)
    func autoCalibrate() {
        guard !distanceHistory.isEmpty else { return }
        let average = distanceHistory.reduce(0, +) / Float(distanceHistory.count)
        calibrate(with: average)
    }
    
    /// Сброс калибровки
    func resetCalibration() {
        isActive = false
        isCalibrated = false
        baselineDistance = 0.0
        pushUpCount = 0
        currentPhase = .transition
        distanceHistory.removeAll()
        feedbackMessage = "Займите верхнюю позицию"
    }
    
    // MARK: - Distance Processing
    
    /// Обработка нового значения расстояния от камеры до лица
    func processDistance(_ distance: Float) {
        // Сглаживание данных
        let smoothedDistance = smoothDistance(distance)
        currentDistance = smoothedDistance
        
        // Если еще не откалиброваны, собираем данные
        guard isCalibrated else {
            distanceHistory.append(smoothedDistance)
            feedbackMessage = "Калибровка... \(distanceHistory.count)/30"
            if distanceHistory.count >= 30 { // ~1 секунда при 30 FPS
                autoCalibrate()
            }
            return
        }

        // Не считаем повторения пока тренировка не активна
        guard isActive else { return }

        // Определяем фазу отжимания
        detectPhase(smoothedDistance)
    }
    
    /// Сглаживание расстояния методом скользящего среднего
    private func smoothDistance(_ newDistance: Float) -> Float {
        distanceHistory.append(newDistance)
        
        // Ограничиваем размер истории
        if distanceHistory.count > smoothingWindowSize {
            distanceHistory.removeFirst()
        }
        
        // Возвращаем среднее
        return distanceHistory.reduce(0, +) / Float(distanceHistory.count)
    }
    
    // MARK: - Push-up Detection Logic
    
    /// Определение текущей фазы отжимания
    private func detectPhase(_ distance: Float) {
        // При отжимании вниз: расстояние УМЕНЬШАЕТСЯ (лицо приближается)
        // При подъеме вверх: расстояние УВЕЛИЧИВАЕТСЯ (лицо отдаляется)
        let distanceChange = baselineDistance - distance
        
        // Логика машины состояний
        switch currentPhase {
        case .up:
            // В верхней позиции, ждем движения вниз
            // Расстояние должно уменьшиться (distance < baseline)
            if distanceChange >= downThreshold {
                // Пользователь достиг нижней точки (достаточно близко)
                transitionToDown()
            }
            
        case .down:
            // В нижней позиции, ждем движения вверх
            // Расстояние должно увеличиться обратно (distance → baseline)
            if distanceChange <= upThreshold {
                // Пользователь вернулся в верхнюю точку
                transitionToUp()
            }
            
        case .transition:
            // Определяем начальную фазу
            if abs(distanceChange) <= upThreshold {
                currentPhase = .up
                feedbackMessage = "Готов! Начинайте отжиматься"
            }
        }
        
        // Обновляем сообщение для пользователя
        updateFeedback(distanceChange)
    }
    
    /// Переход в нижнюю фазу
    private func transitionToDown() {
        currentPhase = .down
        feedbackMessage = "Отлично! Теперь вверх"
        print("⬇️ Нижняя точка достигнута")
    }
    
    /// Переход в верхнюю фазу (завершение повторения)
    private func transitionToUp() {
        // Проверяем минимальный интервал между повторениями
        let now = Date()
        guard now.timeIntervalSince(lastPushUpTime) >= minimumRepInterval else {
            return
        }
        
        currentPhase = .up
        pushUpCount += 1
        lastPushUpTime = now
        feedbackMessage = "Отжимание #\(pushUpCount)! 💪"
        
        // Генерируем тактильную обратную связь
        generateHapticFeedback()
        
        print("✅ Отжимание засчитано! Всего: \(pushUpCount)")
    }
    
    // MARK: - Feedback
    
    /// Обновление сообщений для пользователя
    private func updateFeedback(_ distanceChange: Float) {
        guard currentPhase != .transition else { return }
        
        let percentage = min(100, max(0, (distanceChange / downThreshold) * 100))
        
        if currentPhase == .up {
            if percentage > 90 {
                feedbackMessage = "Почти на месте! Еще чуть-чуть"
            } else if percentage > 75 {
                feedbackMessage = "Отлично! Еще ниже"
            } else if percentage > 50 {
                feedbackMessage = "Продолжайте опускаться..."
            } else if percentage > 25 {
                feedbackMessage = "Готов к отжиманию"
            }
        } else if currentPhase == .down {
            feedbackMessage = "Выпрямляйте руки!"
        }
    }
    
    /// Генерация тактильной обратной связи
    private func generateHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Public Methods
    
    /// Сброс счетчика отжиманий
    func resetCount() {
        pushUpCount = 0
        feedbackMessage = "Счетчик сброшен"
    }
    
    /// Получение прогресса (0.0 - 1.0) текущего отжимания
    func getCurrentProgress() -> Float {
        guard isCalibrated else { return 0.0 }
        let distanceFromBaseline = baselineDistance - currentDistance
        let progress = distanceFromBaseline / downThreshold
        return min(1.0, max(0.0, progress))
    }
}
