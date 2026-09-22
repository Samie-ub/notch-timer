import SwiftUI
import TimerCore

private enum Style {
    static let green = Color(nsColor: .systemGreen)
    static let red = Color(nsColor: .systemRed)
}

struct NotchView: View {
    @ObservedObject var model: TimerModel
    var openControls: () -> Void
    var closeControls: () -> Void
    var hoverChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftMinutes = 25
    @State private var draftSeconds = 0

    private var expanded: Bool { model.notchScreen != .compact }
    private var size: CGSize { expanded ? NotchLayout.expandedSize : NotchLayout.size }
    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -3))
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
                }
            }
            .id(model.notchScreen)
            .transition(transition)
        }
        .frame(width: size.width, height: size.height)
        .background(.black)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(expanded ? 0.16 : 0.08), lineWidth: 0.5))
        .animation(NotchLayout.animation(reduceMotion: reduceMotion), value: model.notchScreen)
        .contentShape(Capsule())
        .onHover(perform: hoverChanged)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onExitCommand(perform: closeControls)
    }

    private var compact: some View {
        HStack(spacing: 0) {
            Button(action: openControls) {
                HStack(spacing: 5) {
                    Image(systemName: model.engine.mode == .timer ? "timer" : "stopwatch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(model.engine.isFinished ? Style.red : .secondary)
                    Text(model.time)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(model.engine.isFinished ? Style.red : .primary)
                        .contentTransition(.numericText())
                }
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(model.engine.mode.rawValue), \(model.time). \(model.status)")
            .accessibilityHint("Open notch controls")
            .help("Notch controls")

            Button(action: model.toggle) {
                Image(systemName: model.engine.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(model.engine.isRunning ? Style.red : Style.green)
                    .frame(width: 18, height: 18)
                    .background((model.engine.isRunning ? Style.red : Style.green).opacity(0.16), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
            .disabled(model.engine.isRunning || model.engine.mode == .stopwatch)
            .accessibilityLabel("Duration, \(model.time)")
            .help(model.engine.isRunning ? "Pause to change duration" : "Change duration")

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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
            Stepper(unit == "min" ? "Minutes" : "Seconds", value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }
}
