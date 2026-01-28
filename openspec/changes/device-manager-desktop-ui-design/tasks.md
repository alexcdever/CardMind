## 1. Rust Infrastructure and Key Management

- [ ] 1.1 Implement libp2p keypair generation and storage
- [ ] 1.2 Create identity/ directory structure for keypair.bin storage
- [ ] 1.3 Add FFI interface for PeerId access
- [ ] 1.4 Implement trusted_devices SQLite table with peerId as key
- [ ] 1.5 Add trust list management APIs (add/remove/query)

## 2. Desktop UI Foundation

- [ ] 2.1 Create desktop-optimized DeviceManagerPage layout
- [ ] 2.2 Implement CurrentDeviceCard with inline editing
- [ ] 2.3 Create large-format DeviceListItem components
- [ ] 2.4 Add device list with multiaddr display
- [ ] 2.5 Implement empty state and not in pool state

## 3. QR Code Upload System

- [ ] 3.1 Create QRCodeUploadTab component
- [ ] 3.2 Implement drag-and-drop file upload
- [ ] 3.3 Add file picker for QR code selection
- [ ] 3.4 Implement QR code parsing and validation
- [ ] 3.5 Support multiple image formats (PNG, JPG, SVG)

## 4. PeerId Integration

- [ ] 4.1 Update Device model to use libp2p PeerId
- [ ] 4.2 Generate QR codes with PeerId + Multiaddrs
- [ ] 4.3 Implement PeerId validation and format checking
- [ ] 4.4 Add connection status based on PeerId discovery

## 5. Verification Code System

- [ ] 5.1 Create VerificationCodeDialog (display side)
- [ ] 5.2 Implement VerificationCodeInput (upload side)
- [ ] 5.3 Add 6-digit code generation and validation
- [ ] 5.4 Implement verification timeout (5 minutes)
- [ ] 5.5 Handle success/failure feedback

## 6. Trust List and Discovery

- [ ] 6.1 Implement mDNS broadcasting for trusted devices only
- [ ] 6.2 Add mDNS discovery with trust list filtering
- [ ] 6.3 Create automatic reconnection logic
- [ ] 6.4 Handle address changes and updates

## 7. Desktop-Specific Features

- [ ] 7.1 Add inline device name editing (no dialogs)
- [ ] 7.2 Implement large screen layout optimization
- [ ] 7.3 Add keyboard shortcuts and navigation
- [ ] 7.4 Create right-click context menus
- [ ] 7.5 Add hover states and tooltips

## 8. File and Error Handling

- [ ] 8.1 Handle file permission errors gracefully
- [ ] 8.2 Add file size validation (10MB limit)
- [ ] 8.3 Implement error recovery mechanisms
- [ ] 8.4 Add detailed error logging
- [ ] 8.5 Create fallback options for failures

## 9. Performance and Optimization

- [ ] 9.1 Optimize QR code generation with caching
- [ ] 9.2 Implement lazy loading for large device lists
- [ ] 9.3 Add virtual scrolling for performance
- [ ] 9.4 Optimize layout for desktop screens
- [ ] 9.5 Minimize widget rebuilds

## 10. Testing and Quality Assurance

- [ ] 10.1 Create comprehensive unit tests for Rust code
- [ ] 10.2 Add Widget tests for desktop components
- [ ] 10.3 Implement file upload testing
- [ ] 10.4 Test drag-and-drop functionality
- [ ] 10.5 Verify PeerId operations and validation
- [ ] 10.6 Test multi-platform compatibility (Windows, macOS, Linux)