## 1. Data Models and State Management

- [ ] 1.1 Create Device data model with type and status enums
- [ ] 1.2 Implement PairingRequest model for pairing flow
- [ ] 1.3 Create state management with Riverpod providers
- [ ] 1.4 Add device sorting and time formatting utilities
- [ ] 1.5 Create unit tests for models and utilities (8 test cases)

## 2. Core Device Manager UI

- [ ] 2.1 Implement DeviceManagerPage main layout structure
- [ ] 2.2 Create CurrentDeviceCard with edit functionality
- [ ] 2.3 Implement DeviceListItem component
- [ ] 2.4 Add device list header with count and pair button
- [ ] 2.5 Implement empty state and not in pool state
- [ ] 2.6 Add device list sorting and filtering logic

## 3. Device Name Editing

- [ ] 3.1 Create EditDeviceNameDialog component
- [ ] 3.2 Implement input validation and length limits
- [ ] 3.3 Add auto-focus and text selection
- [ ] 3.4 Handle save/cancel interactions
- [ ] 3.5 Add error handling for save failures

## 4. QR Code Pairing Dialog

- [ ] 4.1 Implement PairDeviceDialog with tabbed interface
- [ ] 4.2 Create QR code display component (240x240px)
- [ ] 4.3 Add QR code data structure and JSON format
- [ ] 4.4 Implement QR code caching and optimization
- [ ] 4.5 Add tab switching animations and state management

## 5. QR Code Scanning

- [ ] 5.1 Implement camera permission handling
- [ ] 5.2 Create QR code scanner with mobile_scanner
- [ ] 5.3 Add camera preview and scanning frame
- [ ] 5.4 Implement QR code data parsing and validation
- [ ] 5.5 Handle camera resource management (init/release)

## 6. Verification Code System

- [ ] 6.1 Create VerificationCodeDialog (display side)
- [ ] 6.2 Implement VerificationCodeInput (input side)
- [ ] 6.3 Add 6-digit code generation and validation
- [ ] 6.4 Implement auto-advance between input fields
- [ ] 6.5 Add paste support for 6-digit numbers
- [ ] 6.6 Handle verification timeout (5 minutes)
- [ ] 6.7 Add success/failure feedback and retry logic

## 7. Device List and Status

- [ ] 7.1 Implement device list with proper sorting
- [ ] 7.2 Add online/offline status badges
- [ ] 7.3 Create last seen time formatting utilities
- [ ] 7.4 Add device type icons (phone/laptop/tablet)
- [ ] 7.5 Implement list animations and transitions
- [ ] 7.6 Add real-time device status updates

## 8. Error Handling and Edge Cases

- [ ] 8.1 Handle network timeouts and connection errors
- [ ] 8.2 Add verification code error handling
- [ ] 8.3 Implement duplicate device detection
- [ ] 8.4 Handle self-pairing prevention
- [ ] 8.5 Add camera permission denied states
- [ ] 8.6 Create graceful error recovery mechanisms

## 9. Accessibility and Mobile Optimization

- [ ] 9.1 Add semantic labels for screen readers
- [ ] 9.2 Implement proper touch targets (48x48px min)
- [ ] 9.3 Ensure color contrast compliance (4.5:1 text, 3:1 icons)
- [ ] 9.4 Add keyboard navigation support
- [ ] 9.5 Optimize for mobile performance (60fps)

## 10. Testing and Quality Assurance

- [ ] 10.1 Create Widget tests for all components (45 test cases)
- [ ] 10.2 Add integration tests for pairing flow
- [ ] 10.3 Implement performance benchmarks
- [ ] 10.4 Verify camera functionality on real devices
- [ ] 10.5 Test accessibility with screen readers
- [ ] 10.6 Validate error scenarios and edge cases