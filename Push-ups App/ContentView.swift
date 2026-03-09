//
//  ContentView.swift
//  Push-ups App
//
//  Created by Vladislav Kitov on 02.03.2026.
//

import SwiftUI

enum WorkoutType: CaseIterable {
    case cardio
    case power

    var displayName: String {
        switch self {
        case .cardio: return "Cardio"
        case .power: return "Power"
        }
    }
}

enum AppPhase {
    case home, countdown, workout
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

struct ContentView: View {

    @StateObject private var detector = PushUpDetector()
    @State private var phase: AppPhase = .home
    @State private var countdownText: String = "3"
    @State private var isGo: Bool = false
    @State private var countdownTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let top = geo.safeAreaInsets.top
            let bot = geo.safeAreaInsets.bottom

            ZStack {
                // Always-on background
                Color(hex: "#191717")
                    .ignoresSafeArea()

                // AR session (invisible, runs during countdown + workout)
                if phase != .home {
                    ARFaceTrackingView(detector: detector)
                        .frame(width: 0, height: 0)
                }

                // Workout rep counter (top area)
                if phase == .workout {
                    workoutCounter(w: w, h: h, top: top, bot: bot)
                        .transition(.opacity)
                }

                // Countdown counter — behind the circle, starts from top
                if phase == .countdown && !countdownText.isEmpty {
                    countdownCounter(w: w, h: h, top: top, bot: bot)
                        .transition(.opacity)
                }

                // Bottom circle — always at same position, content switches inside
                bottomCircle(w: w)
                    .position(x: w / 2, y: h - bot - w / 2)

                // Stop button — workout only
                if phase == .workout {
                    stopOverlay
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: phase) { _, p in
            UIApplication.shared.isIdleTimerDisabled = (p == .workout)
        }
    }

    // MARK: - Counters

    private func workoutCounter(w: CGFloat, h: CGFloat, top: CGFloat, bot: CGFloat) -> some View {
        let availableHeight = h - top - bot - w
        return Text("\(detector.pushUpCount)")
            .font(.system(size: availableHeight, weight: .black, design: .default))
            .fontWidth(.compressed)
            .minimumScaleFactor(0.01)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(width: w, height: availableHeight, alignment: .center)
            .position(x: w / 2, y: top + availableHeight * 0.6)
            .contentTransition(.numericText(value: Double(detector.pushUpCount)))
            .animation(.easeInOut(duration: 0.2), value: detector.pushUpCount)
    }

    private func countdownCounter(w: CGFloat, h: CGFloat, top: CGFloat, bot: CGFloat) -> some View {
        let availableHeight = h - top - bot - w
        return Text(countdownText)
            .font(.system(size: availableHeight, weight: .black, design: .default))
            .fontWidth(.compressed)
            .minimumScaleFactor(0.01)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(width: w, height: availableHeight, alignment: .center)
            .position(x: w / 2, y: top + availableHeight * 0.6)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.2), value: countdownText)
    }

    // MARK: - Bottom circle

    private func bottomCircle(w: CGFloat) -> some View {
        ZStack {
            if phase == .home {
                Button {
                    startFlow()
                } label: {
                    Text("Start")
                        .font(.system(size: 40, weight: .black, design: .default))
                        .italic()
                        .foregroundStyle(Color(hex: "#191717"))
                        .frame(width: w, height: w)
                        .background(Color.white, in: Circle())
                        .glassEffect(in: Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .transition(.opacity)
            } else if phase == .countdown || phase == .workout {
                ZStack {
                    TempoVisualizerView(workoutType: .cardio, detector: detector)
                        .frame(width: w, height: w)
                    if phase == .countdown {
                        Text(isGo ? "Go!" : "Get ready")
                            .font(.system(size: 40, weight: .regular).italic())
                            .tracking(-0.8)
                            .foregroundStyle(Color(hex: "#191717"))
                            .animation(.easeInOut(duration: 0.2), value: isGo)
                            .transition(.opacity)
                    }
                }
                .clipShape(Circle())
                .background(Color.white, in: Circle())
                .glassEffect(in: Circle())
                .transition(.opacity)
            }
        }
        .frame(width: w, height: w)
    }

    // MARK: - Stop button overlay

    private var stopOverlay: some View {
        VStack {
            HStack {
                Button {
                    stopWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .padding(.leading, 24)
                .padding(.top, 60)
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func startFlow() {
        detector.resetCalibration()
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .countdown
        }
        countdownText = "3"
        isGo = false

        var tick = 0
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            tick += 1
            withAnimation(.easeInOut(duration: 0.2)) {
                if tick == 1 {
                    countdownText = "2"
                } else if tick == 2 {
                    countdownText = "1"
                } else if tick == 3 {
                    countdownText = ""
                    isGo = true
                    detector.isActive = true
                } else {
                    t.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            phase = .workout
                        }
                    }
                }
            }
        }
    }

    private func stopWorkout() {
        countdownTimer?.invalidate()
        detector.isActive = false
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .home
        }
    }
}

#Preview {
    ContentView()
}
