# UI Patterns and Design Guidelines

This document describes the established UI patterns and design decisions for Gravel First, focusing on user interface architecture and interaction patterns.

## Master-Detail Control Pattern

### Overview

The hierarchical control system implements a master-detail pattern where primary controls govern the visibility and state of dependent controls.

### Implementation

#### Segment Switch Master Control

The measure mode control uses a segment switch as the master control:

- **Green State**: "Redigera" (Edit mode) - Enables all editing functionality
- **Red State**: "View mode" - Disables editing and hides dependent controls

#### Conditional Visibility Pattern

Dependent controls use conditional rendering based on master state:

```dart
// Conditional rendering pattern
if (widget.measureEnabled) // Master control state
  Switch.adaptive(
    value: widget.editModeEnabled, // Dependent control
    onChanged: widget.onEditModeChanged,
  ),
```

#### Auto-disable Logic

When master control switches to restrictive state, dependent controls are automatically disabled:

```dart
onToggleMeasure: () {
  final currentMode = ref.read(measureModeProvider);
  ref.read(measureModeProvider.notifier).state = !currentMode;
  
  // Auto-disable dependent state when master becomes restrictive
  if (currentMode) { // Switching from enabled to disabled
    setState(() {
      _editModeEnabled = false; // Clear dependent state
      ref.read(editingIndexProvider.notifier).state = null; // Clear context
    });
  }
},
```

### Benefits

- **Prevents Inconsistent States**: Dependent controls cannot be active when master is restrictive
- **Clear UX Hierarchy**: Users understand control relationships intuitively  
- **Simplified State Management**: Master control manages dependent visibility and state
- **Professional Interaction Flow**: Follows established UI patterns for complex applications

## Control Panel Architecture

### Bottom Controls Panel Structure

The main control panel follows a layered structure:

```text
BottomControlsPanel
├── DistancePanel (always visible)
│   ├── Segment Switch (master control)
│   ├── Edit Mode Toggle (conditional)
│   ├── Loop Toggle (contextual)
│   └── Distance Markers Toggle (independent)
└── Action Buttons Row
    ├── Undo Button (contextual)
    ├── Save Button (contextual) 
    └── Clear Button (confirmation required)
```

### Visibility Rules

1. **Always Visible**: Core controls that don't depend on state
2. **Conditional**: Controls that depend on master control state
3. **Contextual**: Controls enabled/disabled based on data availability
4. **Confirmation Required**: Destructive actions require user confirmation

## Material Design Integration

### Theme Consistency

All UI components follow Material Design 3 principles:

- **Color Scheme**: Consistent with app theme (light/dark mode support)
- **Typography**: Material Design typography scale
- **Spacing**: 8dp grid system for consistent spacing
- **Iconography**: Material Icons for universal recognition

### Accessibility

- **Touch Targets**: Minimum 48dp touch targets for all interactive elements
- **Color Contrast**: Sufficient contrast ratios for text and backgrounds
- **Screen Reader Support**: Semantic labels for assistive technology
- **Keyboard Navigation**: Proper focus handling for web accessibility

## Interaction Patterns

### Confirmation Dialogs

Destructive actions use consistent confirmation patterns:

```dart
// Standard confirmation dialog pattern
await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Bekräfta åtgärd'),
    content: const Text('Vill du verkligen radera rutten?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Avbryt'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Radera'),
      ),
    ],
  ),
);
```

### Progress Indicators

Long-running operations show progress with overlay pattern:

- **File Operations**: Semi-transparent overlay with circular progress
- **API Requests**: Inline loading states with timeout handling
- **Map Operations**: Visual feedback during tile loading

### State Feedback

User actions provide immediate visual feedback:

- **Button States**: Disabled states for unavailable actions
- **Toggle States**: Clear visual indication of current state
- **Selection States**: Highlighted selected items with proper contrast

## Implementation Guidelines

### Widget Structure

Follow consistent widget structure patterns:

1. **State Declaration**: Declare all state variables at top of widget class
2. **Build Method**: Use helper methods to break down complex UI
3. **Event Handlers**: Separate methods for each user interaction
4. **Conditional Logic**: Use early returns and ternary operators for clarity

### State Management Integration

Integrate with Riverpod following established patterns:

```dart
// Provider reading pattern
final measureMode = ref.watch(measureModeProvider);

// State updates with side effects
onToggle: () {
  ref.read(measureModeProvider.notifier).state = !measureMode;
  // Handle side effects (auto-disable dependent controls)
},
```

### Error Handling

Implement consistent error handling patterns:

- **User-Friendly Messages**: Convert technical errors to user-friendly text
- **Snackbar Notifications**: Use SnackBar for temporary status messages
- **Fallback UI**: Graceful degradation when features are unavailable
- **Recovery Options**: Provide clear paths to resolve error states

## Future Considerations

### Scalability

The established patterns support future feature development:

- **Additional Master Controls**: Pattern can be extended for new control hierarchies
- **Complex Dependencies**: Support for multiple dependent controls per master
- **Dynamic Visibility**: Runtime determination of control visibility
- **Contextual Actions**: State-dependent action button configurations

### Platform Adaptations

Current patterns work across all platforms with potential for:

- **Platform-Specific Controls**: iOS/Android native control variants
- **Desktop Adaptations**: Keyboard shortcuts and desktop-specific interactions
- **Web Enhancements**: Progressive Web App features and web-specific UX

---

*Last updated: 2025-08-28*
*Related documents: `docs/architecture.md`, `docs/state-management.md`*
