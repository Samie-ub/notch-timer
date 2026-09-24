import SwiftUI
import TimerCore

private enum Style {
    static let green = Color(nsColor: .systemGreen)
    static let red = Color(nsColor: .systemRed)
}

private struct NotchButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(.plain)
    }
}

struct NotchView: View {
    @ObservedObject var model: TimerModel
    var openControls: () -> Void
    var closeControls: () -> Void
    var openBrowserFocus: () -> Void
    var hoverChanged: (Bool) -> Void
    var dragChanged: (CGPoint) -> Void
    var dragEnded: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftMinutes = 25
    @State private var draftSeconds = 0

    private var expanded: Bool { model.notchScreen != .compact }
    private var size: CGSize { NotchLayout.size(for: model.notchScreen, featureSize: model.featurePanelSize) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: model.notchScreen.isFeaturePanel ? 24 : size.height / 2)
    }

    var body: some View {
        ZStack {
            Group {
                switch model.notchScreen {
                case .compact: compact
                case .controls: controls
                case .duration: durationPresets
                case .customDuration: customDuration
                case .mode: modeSelection
                case .browserFocus:
                    NotchFeatureContainer(title: "Focus Mode", symbol: "scope", done: closeControls,
                                          dragChanged: dragChanged, dragEnded: dragEnded) {
                        BrowserFocusSettingsView(focus: model.browserFocus, model: model)
                    }
                }
            }
            .id(model.notchScreen)
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
        }
        .frame(width: size.width, height: size.height)
        .background {
            Color.black
            if !expanded {
                compactProgressBackground
                    .transition(.identity)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(expanded ? 0.16 : 0.08), lineWidth: 0.5))
        .animation(NotchLayout.animation(reduceMotion: reduceMotion), value: model.notchScreen)
        .contentShape(shape)
        .onHover(perform: hoverChanged)
        .highPriorityGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in dragChanged(NSEvent.mouseLocation) }
                .onEnded { _ in dragEnded() },
            including: model.notchScreen.isFeaturePanel ? .subviews : .all
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onExitCommand(perform: closeControls)
    }

    private var compactProgressBackground: some View {
        // A stopwatch has no target duration, so it uses a solid running tint.
        let fraction = model.engine.isRunning && model.engine.mode == .timer
            ? min(1, max(0, model.progress)) : 1
        let color = model.engine.isRunning ? Style.green : Style.red
        return GeometryReader { geometry in
            Rectangle()
                .fill(color.opacity(0.45))
                .frame(width: geometry.size.width * fraction)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: fraction)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: model.engine.isRunning)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var compact: some View {
        HStack(spacing: 0) {
            Button(action: openControls) {
                HStack(spacing: 5) {
                    Image(systemName: model.engine.mode == .timer ? "timer" : "stopwatch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(model.time)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle())
            .accessibilityLabel("\(model.engine.mode.rawValue), \(model.time). \(model.status)")
            .accessibilityHint("Open notch controls")
            .help("Notch controls")

            Button(action: model.toggle) {
                Image(systemName: model.engine.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.black.opacity(0.28), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(NotchButtonStyle())
            .accessibilityLabel(model.engine.isRunning ? "Pause" : "Start")
            .help(model.engine.isRunning ? "Pause" : "Start")
            .padding(.trailing, 3)
        }
        .frame(width: NotchLayout.size.width, height: NotchLayout.size.height)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { model.notchScreen = .mode } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.engine.mode == .timer ? "timer" : "stopwatch")
                    Text(model.engine.mode.rawValue)
                    Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle())
            .disabled(model.engine.isRunning)
            .help(model.engine.isRunning ? "Pause to change mode" : "Change mode")

            Button { model.notchScreen = .duration } label: {
                Text(model.time)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .foregroundStyle(model.engine.isFinished ? Style.red : .white)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle())
            .disabled(model.engine.isRunning || model.engine.mode == .stopwatch)
            .accessibilityLabel("Duration, \(model.time)")
            .help(model.engine.isRunning ? "Pause to change duration" : "Change duration")

            iconButton("scope", label: "Focus Mode", action: openBrowserFocus)
            iconButton("arrow.counterclockwise", label: "Reset") {
                model.reset()
            }
            if model.engine.mode == .timer {
                iconButton(model.soundEnabled ? "speaker.wave.2" : "speaker.slash",
                           label: model.soundEnabled ? "Turn completion sound off" : "Turn completion sound on") {
                    model.soundEnabled.toggle()
                }
            }
            iconButton(model.engine.isRunning ? "pause.fill" : "play.fill",
                       label: model.engine.isRunning ? "Pause" : "Start",
                       tint: model.engine.isRunning ? .orange : Style.green) {
                model.toggle()
            }
            .keyboardShortcut(.space, modifiers: [])
        }
        .padding(.horizontal, 12)
        .frame(width: NotchLayout.expandedSize.width, height: NotchLayout.expandedSize.height)
    }

    private var durationPresets: some View {
        HStack(spacing: 8) {
            backButton
            ForEach([5, 15, 25, 45], id: \.self) { minutes in
                choiceButton("\(minutes)m", selected: model.engine.duration == Double(minutes * 60)) {
                    model.setDuration(Double(minutes * 60))
                    model.notchScreen = .controls
                }
                .accessibilityLabel("\(minutes) minutes")
            }
            choiceButton("Custom") {
                draftMinutes = Int(model.engine.duration) / 60
                draftSeconds = Int(model.engine.duration) % 60
                model.notchScreen = .customDuration
            }
        }
        .padding(.horizontal, 10)
        .frame(width: NotchLayout.expandedSize.width, height: NotchLayout.expandedSize.height)
    }

    private var customDuration: some View {
        HStack(spacing: 12) {
            iconButton("chevron.left", label: "Back to presets") { model.notchScreen = .duration }
            durationControl("min", value: $draftMinutes, range: 0...99)
            Text(":").font(.system(size: 16)).foregroundStyle(.tertiary)
            durationControl("sec", value: $draftSeconds, range: 0...59)
            iconButton("checkmark", label: "Apply duration", tint: Style.green) {
                model.setDuration(Double(draftMinutes * 60 + draftSeconds))
                model.notchScreen = .controls
            }
            .disabled(draftMinutes == 0 && draftSeconds == 0)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .frame(width: NotchLayout.expandedSize.width, height: NotchLayout.expandedSize.height)
    }

    private var modeSelection: some View {
        HStack(spacing: 8) {
            backButton
            ForEach(TimerMode.allCases, id: \.self) { mode in
                choiceButton(mode.rawValue, selected: model.engine.mode == mode) {
                    model.setMode(mode)
                    model.notchScreen = .controls
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(width: NotchLayout.expandedSize.width, height: NotchLayout.expandedSize.height)
    }

    private var backButton: some View {
        iconButton("chevron.left", label: "Back to controls") { model.notchScreen = .controls }
    }

    private func iconButton(_ symbol: String, label: String, tint: Color = .secondary,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }

    private func choiceButton(_ title: String, selected: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? Color.white : .white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func durationControl(_ unit: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 5) {
            Text(value.wrappedValue, format: .number.precision(.integerLength(2)))
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Stepper(unit == "min" ? "Minutes" : "Seconds", value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0 }
            ), in: range)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A reusable downward-expanding surface for settings and future notch features.
private struct NotchFeatureContainer<Content: View>: View {
    var title: String
    var symbol: String
    var done: () -> Void
    var dragChanged: (CGPoint) -> Void
    var dragEnded: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: symbol).foregroundStyle(.green)
                    Text(title).font(.headline)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 5)
                    .onChanged { _ in dragChanged(NSEvent.mouseLocation) }
                    .onEnded { _ in dragEnded() })
                .help("Drag the title to move the panel")
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.plain)
                    .modifier(BrowserFocusPointerStyle())
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
                    .accessibilityHint("Collapse to the timer notch")
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            Divider().overlay(.white.opacity(0.08))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
