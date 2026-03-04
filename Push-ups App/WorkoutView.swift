//
//  WorkoutView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI
import ARKit

struct WorkoutView: View {
    
    @StateObject private var detector = PushUpDetector()
    @Environment(\.dismiss) private var dismiss
    
    @State private var isWorkoutActive = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        ZStack {
            // AR камера на заднем фоне
            if isWorkoutActive {
                ARFaceTrackingView(detector: detector)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // UI поверх камеры
            VStack {
                // Верхняя панель
                topBar
                
                Spacer()
                
                // Основной счетчик
                mainCounter
                
                Spacer()
                
                // Индикатор прогресса и подсказки
                feedbackSection
                
                // Кнопки управления
                controlButtons
            }
            .padding()
        }
        .navigationBarBackButtonHidden(isWorkoutActive)
        .onChange(of: isWorkoutActive) { _, active in
            UIApplication.shared.isIdleTimerDisabled = active
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onAppear {
            checkCameraPermission()
        }
        .alert("Требуется доступ к камере", isPresented: $showingPermissionAlert) {
            Button("Настройки", action: openSettings)
            Button("Отмена", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Для автоматического подсчета отжиманий необходим доступ к TrueDepth камере.")
        }
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            // Кнопка закрытия
            Button {
                if isWorkoutActive {
                    isWorkoutActive = false
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: isWorkoutActive ? "stop.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            
            Spacer()
            
            // Статус калибровки
            if isWorkoutActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(detector.isCalibrated ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(detector.isCalibrated ? "Готово" : "Калибровка...")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
    
    private var mainCounter: some View {
        VStack(spacing: 16) {
            // Большой счетчик
            Text("\(detector.pushUpCount)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .blue, radius: 20)
                .contentTransition(.numericText(value: Double(detector.pushUpCount)))
            
            Text("отжиманий")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
    
    private var feedbackSection: some View {
        VStack(spacing: 20) {
            // Индикатор прогресса текущего отжимания
            if detector.isCalibrated && isWorkoutActive {
                ProgressBar(progress: detector.getCurrentProgress())
                    .frame(height: 60)
                    .padding(.horizontal, 40)
            }
            
            // Текстовая подсказка
            Text(detector.feedbackMessage)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Информация для отладки
            if isWorkoutActive {
                VStack(spacing: 4) {
                    Text("Расстояние: \(String(format: "%.3f", detector.currentDistance))м")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if detector.isCalibrated {
                        let progress = detector.getCurrentProgress()
                        Text("Прогресс: \(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text("Фаза: \(phaseText)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(8)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var phaseText: String {
        switch detector.currentPhase {
        case .up: return "⬆️ Вверху"
        case .down: return "⬇️ Внизу"
        case .transition: return "🔄 Переход"
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Кнопка сброса
            Button {
                detector.resetCount()
            } label: {
                Label("Сброс", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isWorkoutActive)
            .opacity(isWorkoutActive ? 1 : 0.5)
            
            // Кнопка старт/пауза
            Button {
                isWorkoutActive.toggle()
                if !isWorkoutActive {
                    detector.resetCalibration()
                }
            } label: {
                Label(
                    isWorkoutActive ? "Пауза" : "Старт",
                    systemImage: isWorkoutActive ? "pause.fill" : "play.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isWorkoutActive ? .orange : .green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Methods
    
    private func checkCameraPermission() {
        // Проверяем поддержку Face Tracking
        guard ARFaceTrackingConfiguration.isSupported else {
            detector.feedbackMessage = "TrueDepth камера не поддерживается"
            return
        }
        
        // Можно добавить проверку разрешений камеры
        // AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Progress Bar Component

struct ProgressBar: View {
    let progress: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Фон
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.2))
                
                // Прогресс
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .animation(.spring(response: 0.3), value: progress)
                
                // Индикатор целевой позиции
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .offset(x: geometry.size.width - 3)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutView()
    }
}
